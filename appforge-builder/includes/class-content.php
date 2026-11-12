<?php
namespace AppForge;

use WP_Error;
use WP_REST_Request;

defined( 'ABSPATH' ) || exit;

/**
 * WordPress pages, contact form and guest order tracking.
 */
class Content {

	/* ---------------- WordPress pages ---------------- */

	public static function page( WP_REST_Request $r ) {
		$page = get_post( (int) $r['id'] );
		if ( ! $page || 'page' !== $page->post_type || 'publish' !== $page->post_status || ! empty( $page->post_password ) ) {
			return new WP_Error( 'appforge_not_found', __( 'Page not found.', 'appforge' ), array( 'status' => 404 ) );
		}
		return rest_ensure_response(
			array(
				'id'      => $page->ID,
				'title'   => html_entity_decode( get_the_title( $page ), ENT_QUOTES, 'UTF-8' ),
				'content' => apply_filters( 'the_content', $page->post_content ),
				'image'   => (string) get_the_post_thumbnail_url( $page, 'large' ),
				'link'    => get_permalink( $page ),
			)
		);
	}

	public static function page_options() {
		$out   = array();
		$pages = get_pages( array( 'post_status' => 'publish', 'sort_column' => 'post_title' ) );
		foreach ( $pages as $p ) {
			$out[] = array( 'id' => $p->ID, 'title' => html_entity_decode( $p->post_title, ENT_QUOTES, 'UTF-8' ) );
		}
		return $out;
	}

	/* ---------------- Contact form ---------------- */

	private static function client_ip() {
		$ip = isset( $_SERVER['REMOTE_ADDR'] ) ? sanitize_text_field( wp_unslash( $_SERVER['REMOTE_ADDR'] ) ) : '';
		return $ip ? $ip : 'unknown';
	}

	public static function contact( WP_REST_Request $r ) {
		$store   = Settings::store();
		$contact = $store['contact'];
		if ( empty( $contact['form_enabled'] ) ) {
			return new WP_Error( 'appforge_contact_disabled', __( 'The contact form is disabled.', 'appforge' ), array( 'status' => 403 ) );
		}

		$name    = sanitize_text_field( (string) $r->get_param( 'name' ) );
		$email   = sanitize_email( (string) $r->get_param( 'email' ) );
		$phone   = sanitize_text_field( (string) $r->get_param( 'phone' ) );
		$subject = sanitize_text_field( (string) $r->get_param( 'subject' ) );
		$message = sanitize_textarea_field( (string) $r->get_param( 'message' ) );

		if ( '' === $name || ! is_email( $email ) || strlen( $message ) < 5 ) {
			return new WP_Error( 'appforge_contact_invalid', __( 'Please enter your name, a valid email and a message.', 'appforge' ), array( 'status' => 400 ) );
		}

		// Basic flood protection: 5 messages per hour per IP.
		$key   = 'appforge_contact_' . md5( self::client_ip() );
		$count = (int) get_transient( $key );
		if ( $count >= 5 ) {
			return new WP_Error( 'appforge_contact_limit', __( 'Too many messages. Please try again later.', 'appforge' ), array( 'status' => 429 ) );
		}
		set_transient( $key, $count + 1, HOUR_IN_SECONDS );

		$to   = is_email( $contact['email'] ) ? $contact['email'] : get_option( 'admin_email' );
		$body = sprintf(
			"New message from the app\n\nName: %s\nEmail: %s\nPhone: %s\nSubject: %s\n\n%s\n",
			$name,
			$email,
			$phone,
			$subject,
			$message
		);
		$sent = wp_mail(
			$to,
			/* translators: %s subject */
			sprintf( __( '[App] %s', 'appforge' ), $subject ? $subject : __( 'Contact form', 'appforge' ) ),
			$body,
			array( 'Reply-To: ' . $name . ' <' . $email . '>' )
		);
		do_action( 'appforge_contact_submitted', compact( 'name', 'email', 'phone', 'subject', 'message' ), $sent );

		if ( ! $sent ) {
			return new WP_Error( 'appforge_contact_mail', __( 'Your message could not be sent. Please call or email us instead.', 'appforge' ), array( 'status' => 500 ) );
		}
		return rest_ensure_response( array( 'success' => true, 'message' => __( 'Thank you! We will get back to you soon.', 'appforge' ) ) );
	}

	/* ---------------- Order tracking ---------------- */

	/**
	 * POST /orders/track { order, email }  — works for guests (email must match the billing email).
	 */
	public static function track( WP_REST_Request $r ) {
		if ( ! Woo::active() ) {
			return new WP_Error( 'appforge_no_woo', 'WooCommerce is not active.', array( 'status' => 400 ) );
		}
		$number = trim( (string) $r->get_param( 'order' ) );
		$number = ltrim( $number, '#' );
		$email  = strtolower( trim( (string) $r->get_param( 'email' ) ) );

		$key   = 'appforge_track_' . md5( self::client_ip() );
		$tries = (int) get_transient( $key );
		if ( $tries >= 20 ) {
			return new WP_Error( 'appforge_track_limit', __( 'Too many attempts. Please try again later.', 'appforge' ), array( 'status' => 429 ) );
		}
		set_transient( $key, $tries + 1, HOUR_IN_SECONDS );

		$order = null;
		if ( ctype_digit( $number ) ) {
			$order = wc_get_order( (int) $number );
		}
		if ( ! $order ) {
			// Custom order numbers (Sequential Order Numbers plugins).
			$found = wc_get_orders( array( 'limit' => 1, 'meta_key' => '_order_number', 'meta_value' => $number ) ); // phpcs:ignore
			$order = $found ? $found[0] : null;
		}

		$owner = $order && get_current_user_id() && (int) $order->get_customer_id() === get_current_user_id();
		if ( ! $order || ( ! $owner && strtolower( $order->get_billing_email() ) !== $email ) ) {
			return new WP_Error( 'appforge_track_not_found', __( 'No order found with that number and email.', 'appforge' ), array( 'status' => 404 ) );
		}

		$data = Cart::format_order( $order );

		// Status timeline.
		$status = $order->get_status();
		$map    = array(
			'pending'    => 0,
			'on-hold'    => 0,
			'processing' => 1,
			'shipped'    => 2,
			'completed'  => 3,
		);
		$data['progress'] = isset( $map[ $status ] ) ? $map[ $status ] : -1;
		$data['steps']    = array(
			array( 'key' => 'pending', 'label' => __( 'Order placed', 'appforge' ) ),
			array( 'key' => 'processing', 'label' => __( 'Processing', 'appforge' ) ),
			array( 'key' => 'shipped', 'label' => __( 'Shipped', 'appforge' ) ),
			array( 'key' => 'completed', 'label' => __( 'Delivered', 'appforge' ) ),
		);

		// Customer-visible notes.
		$notes = array();
		foreach ( wc_get_order_notes( array( 'order_id' => $order->get_id(), 'type' => 'customer' ) ) as $note ) {
			$notes[] = array(
				'date'    => $note->date_created ? $note->date_created->format( DATE_ATOM ) : '',
				'content' => wp_strip_all_tags( $note->content ),
			);
		}
		$data['notes'] = $notes;

		// Shipment tracking (WooCommerce Shipment Tracking / Advanced Shipment Tracking).
		$tracking = array();
		$items    = $order->get_meta( '_wc_shipment_tracking_items' );
		if ( is_array( $items ) ) {
			foreach ( $items as $t ) {
				$tracking[] = array(
					'provider' => isset( $t['tracking_provider'] ) ? $t['tracking_provider'] : ( isset( $t['custom_tracking_provider'] ) ? $t['custom_tracking_provider'] : '' ),
					'number'   => isset( $t['tracking_number'] ) ? $t['tracking_number'] : '',
					'url'      => isset( $t['custom_tracking_link'] ) ? $t['custom_tracking_link'] : '',
				);
			}
		}
		$data['tracking'] = apply_filters( 'appforge_order_tracking', $tracking, $order );

		// Never expose the full address to guests.
		if ( ! $owner ) {
			$data['billing']  = array( 'first_name' => $order->get_billing_first_name() );
			$data['shipping'] = array( 'city' => $order->get_shipping_city() );
		}
		return rest_ensure_response( $data );
	}
}
