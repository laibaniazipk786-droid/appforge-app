<?php
namespace AppForge;

use WP_Error;
use WP_REST_Request;

defined( 'ABSPATH' ) || exit;

/**
 * Stateless cart & checkout.
 *
 * The app keeps the cart locally and sends the items on every request. The server rebuilds a
 * WooCommerce cart in memory, so shipping, taxes, coupons and payment gateways are calculated
 * by WooCommerce itself (exactly like the website) without touching the customer's web cart.
 */
class Cart {

	/** Gateways that can be completed without a payment page. */
	public static function native_gateways() {
		return apply_filters( 'appforge_native_gateways', array( 'cod', 'bacs', 'cheque' ) );
	}

	public static function init_hooks() {
		add_action( 'template_redirect', array( __CLASS__, 'maybe_autologin_for_payment' ), 1 );
	}

	/**
	 * Boots WooCommerce session/customer/cart with a memory-only session.
	 */
	private static function boot() {
		require_once APPFORGE_DIR . 'includes/class-memory-session.php';
		add_filter( 'woocommerce_persistent_cart_enabled', '__return_false' );
		add_filter(
			'woocommerce_session_handler',
			function () {
				return 'AppForge\\Memory_Session';
			}
		);
		if ( function_exists( 'wc_load_cart' ) ) {
			wc_load_cart();
		}
		WC()->cart->empty_cart( false );
		wc_clear_notices();
	}

	private static function pop_notice() {
		$notices = wc_get_notices( 'error' );
		wc_clear_notices();
		if ( empty( $notices ) ) {
			return '';
		}
		$last = end( $notices );
		return html_entity_decode( wp_strip_all_tags( is_array( $last ) ? $last['notice'] : $last ), ENT_QUOTES, 'UTF-8' );
	}

	private static function clean_address( $address ) {
		$out = array();
		if ( is_array( $address ) ) {
			foreach ( $address as $k => $v ) {
				$out[ sanitize_key( $k ) ] = 'email' === $k ? sanitize_email( $v ) : sanitize_text_field( $v );
			}
		}
		return $out;
	}

	/**
	 * Rebuilds the cart from request params. Returns item errors.
	 */
	private static function build( WP_REST_Request $r ) {
		self::boot();
		$cart   = WC()->cart;
		$errors = array();

		$items = $r->get_param( 'items' );
		foreach ( is_array( $items ) ? $items : array() as $item ) {
			$pid = isset( $item['product_id'] ) ? (int) $item['product_id'] : 0;
			$vid = isset( $item['variation_id'] ) ? (int) $item['variation_id'] : 0;
			$qty = isset( $item['quantity'] ) ? max( 1, (int) $item['quantity'] ) : 1;
			$var = array();
			if ( ! empty( $item['variation'] ) && is_array( $item['variation'] ) ) {
				foreach ( $item['variation'] as $k => $v ) {
					$k         = sanitize_title( $k );
					$k         = 0 === strpos( $k, 'attribute_' ) ? $k : 'attribute_' . $k;
					$var[ $k ] = sanitize_text_field( $v );
				}
			}
			try {
				$key = $cart->add_to_cart( $pid, $qty, $vid, $var );
			} catch ( \Exception $e ) {
				$key = false;
				wc_add_notice( $e->getMessage(), 'error' );
			}
			if ( ! $key ) {
				$msg      = self::pop_notice();
				$errors[] = array(
					'product_id'   => $pid,
					'variation_id' => $vid,
					'message'      => $msg ? $msg : __( 'This item is not available.', 'appforge' ),
				);
			}
		}

		$billing  = self::clean_address( $r->get_param( 'billing' ) );
		$shipping = self::clean_address( $r->get_param( 'shipping' ) );
		if ( empty( $shipping ) ) {
			$shipping = $billing;
		}
		$customer = WC()->customer;
		foreach ( array( 'country', 'state', 'postcode', 'city', 'address_1', 'address_2' ) as $f ) {
			if ( isset( $shipping[ $f ] ) ) {
				$customer->{"set_shipping_$f"}( $shipping[ $f ] );
			}
			$bval = isset( $billing[ $f ] ) ? $billing[ $f ] : ( isset( $shipping[ $f ] ) ? $shipping[ $f ] : null );
			if ( null !== $bval ) {
				$customer->{"set_billing_$f"}( $bval );
			}
		}
		if ( ! empty( $billing['email'] ) ) {
			$customer->set_billing_email( $billing['email'] );
		}
		$customer->set_calculated_shipping( true );

		$coupon_errors = array();
		$coupons       = $r->get_param( 'coupons' );
		foreach ( is_array( $coupons ) ? $coupons : array() as $code ) {
			$code = wc_format_coupon_code( $code );
			if ( $code && ! $cart->apply_coupon( $code ) ) {
				$coupon_errors[] = array( 'code' => $code, 'message' => self::pop_notice() );
			}
		}
		wc_clear_notices();

		$method = sanitize_text_field( (string) $r->get_param( 'shipping_method' ) );
		if ( $method ) {
			WC()->session->set( 'chosen_shipping_methods', array( $method ) );
		}
		$payment = sanitize_key( (string) $r->get_param( 'payment_method' ) );
		if ( $payment ) {
			WC()->session->set( 'chosen_payment_method', $payment );
		}

		$cart->calculate_totals();

		return array(
			'items'   => $errors,
			'coupons' => $coupon_errors,
		);
	}

	private static function summary( $errors ) {
		$cart = WC()->cart;
		$incl = $cart->display_prices_including_tax();

		$items = array();
		foreach ( $cart->get_cart() as $key => $ci ) {
			/** @var \WC_Product $p */
			$p       = $ci['data'];
			$img_id  = $p->get_image_id() ? $p->get_image_id() : wc_get_product( $ci['product_id'] )->get_image_id();
			$items[] = array(
				'key'          => $key,
				'product_id'   => (int) $ci['product_id'],
				'variation_id' => (int) $ci['variation_id'],
				'quantity'     => (int) $ci['quantity'],
				'variation'    => (object) $ci['variation'],
				'name'         => html_entity_decode( $p->get_name(), ENT_QUOTES, 'UTF-8' ),
				'image'        => $img_id ? wp_get_attachment_image_url( $img_id, 'woocommerce_thumbnail' ) : wc_placeholder_img_src(),
				'price'        => (float) wc_get_price_to_display( $p ),
				'line_total'   => (float) $ci['line_total'] + ( $incl ? (float) $ci['line_tax'] : 0 ),
			);
		}

		$chosen = WC()->session->get( 'chosen_shipping_methods', array() );
		$rates  = array();
		foreach ( WC()->shipping()->get_packages() as $i => $package ) {
			foreach ( $package['rates'] as $rate_id => $rate ) {
				/** @var \WC_Shipping_Rate $rate */
				$cost    = (float) $rate->get_cost() + ( $incl ? array_sum( $rate->get_taxes() ) : 0 );
				$rates[] = array(
					'id'       => $rate_id,
					'package'  => $i,
					'label'    => html_entity_decode( $rate->get_label(), ENT_QUOTES, 'UTF-8' ),
					'cost'     => $cost,
					'selected' => isset( $chosen[ $i ] ) && $chosen[ $i ] === $rate_id,
				);
			}
		}

		$gateways = array();
		foreach ( WC()->payment_gateways()->get_available_payment_gateways() as $id => $g ) {
			$gateways[] = array(
				'id'          => $id,
				'title'       => html_entity_decode( wp_strip_all_tags( $g->get_title() ), ENT_QUOTES, 'UTF-8' ),
				'description' => html_entity_decode( wp_strip_all_tags( $g->get_description() ), ENT_QUOTES, 'UTF-8' ),
				'native'      => in_array( $id, self::native_gateways(), true ),
			);
		}

		$t = $cart->get_totals();
		return array(
			'free_shipping'  => self::free_shipping_info( $cart ),
			'items'          => $items,
			'errors'         => $errors['items'],
			'coupon_errors'  => $errors['coupons'],
			'coupons'        => array_values( $cart->get_applied_coupons() ),
			'needs_shipping' => $cart->needs_shipping(),
			'shipping_rates' => $rates,
			'payment_methods'=> $gateways,
			'prices_include_tax' => $incl,
			'totals'         => array(
				'subtotal' => (float) $t['subtotal'] + ( $incl ? (float) $t['subtotal_tax'] : 0 ),
				'discount' => (float) $t['discount_total'] + ( $incl ? (float) $t['discount_tax'] : 0 ),
				'shipping' => (float) $t['shipping_total'] + ( $incl ? (float) $t['shipping_tax'] : 0 ),
				'tax'      => (float) $t['total_tax'],
				'total'    => (float) $t['total'],
			),
		);
	}

	/**
	 * "Add Rs 1,200 more for free shipping" — read from the WooCommerce Free shipping
	 * method (minimum order amount) of the zone matching the customer's address.
	 * Returns null when the zone has no free shipping with a minimum amount.
	 */
	private static function free_shipping_info( $cart ) {
		if ( ! $cart->needs_shipping() || ! class_exists( '\WC_Shipping_Zones' ) ) {
			return null;
		}
		$packages = WC()->shipping()->get_packages();
		$package  = $packages ? reset( $packages ) : null;
		if ( ! $package ) {
			return null;
		}
		foreach ( $package['rates'] as $rate ) {
			if ( 'free_shipping' === $rate->get_method_id() ) {
				return array( 'min' => 0, 'remaining' => 0, 'qualified' => true );
			}
		}
		$zone = \WC_Shipping_Zones::get_zone_matching_package( $package );
		$min  = 0;
		$ignore_discounts = false;
		foreach ( $zone->get_shipping_methods( true ) as $method ) {
			if ( 'free_shipping' !== $method->id ) {
				continue;
			}
			$requires = $method->get_option( 'requires' );
			$amount   = (float) $method->get_option( 'min_amount' );
			if ( $amount > 0 && in_array( $requires, array( 'min_amount', 'either', 'both' ), true ) ) {
				$min              = $min ? min( $min, $amount ) : $amount;
				$ignore_discounts = 'yes' === $method->get_option( 'ignore_discounts' );
			}
		}
		if ( ! $min ) {
			return null;
		}
		$total = (float) $cart->get_displayed_subtotal();
		if ( ! $ignore_discounts ) {
			$total -= (float) $cart->get_discount_total();
			if ( $cart->display_prices_including_tax() ) {
				$total -= (float) $cart->get_discount_tax();
			}
		}
		$remaining = max( 0, round( $min - $total, wc_get_price_decimals() ) );
		return array( 'min' => $min, 'remaining' => $remaining, 'qualified' => 0.0 === (float) $remaining );
	}

	/**
	 * POST /cart/calculate
	 */
	public static function calculate( WP_REST_Request $r ) {
		if ( ! Woo::active() ) {
			return new WP_Error( 'appforge_no_woo', 'WooCommerce is not active.', array( 'status' => 400 ) );
		}
		$errors = self::build( $r );
		return rest_ensure_response( self::summary( $errors ) );
	}

	/**
	 * POST /checkout
	 */
	public static function checkout( WP_REST_Request $r ) {
		if ( ! Woo::active() ) {
			return new WP_Error( 'appforge_no_woo', 'WooCommerce is not active.', array( 'status' => 400 ) );
		}
		if ( ! get_current_user_id() && ! Settings::value( 'guest_checkout', true ) ) {
			return new WP_Error( 'appforge_login_required', __( 'Please log in to place an order.', 'appforge' ), array( 'status' => 401 ) );
		}

		$errors = self::build( $r );
		$cart   = WC()->cart;
		if ( ! empty( $errors['items'] ) ) {
			return new WP_Error( 'appforge_cart_item', $errors['items'][0]['message'], array( 'status' => 400, 'errors' => $errors['items'] ) );
		}
		if ( $cart->is_empty() ) {
			return new WP_Error( 'appforge_cart_empty', __( 'Your cart is empty.', 'appforge' ), array( 'status' => 400 ) );
		}

		$billing  = self::clean_address( $r->get_param( 'billing' ) );
		$shipping = self::clean_address( $r->get_param( 'shipping' ) );
		if ( empty( $shipping ) ) {
			$shipping = $billing;
			unset( $shipping['email'], $shipping['phone'] );
		}

		$required = array(
			'first_name' => __( 'First name', 'appforge' ),
			'last_name'  => __( 'Last name', 'appforge' ),
			'email'      => __( 'Email', 'appforge' ),
			'address_1'  => __( 'Address', 'appforge' ),
			'city'       => __( 'City', 'appforge' ),
			'country'    => __( 'Country', 'appforge' ),
		);
		foreach ( $required as $field => $label ) {
			if ( empty( $billing[ $field ] ) ) {
				/* translators: %s field name */
				return new WP_Error( 'appforge_field', sprintf( __( '%s is required.', 'appforge' ), $label ), array( 'status' => 400 ) );
			}
		}
		if ( ! is_email( $billing['email'] ) ) {
			return new WP_Error( 'appforge_field', __( 'Please enter a valid email.', 'appforge' ), array( 'status' => 400 ) );
		}

		if ( $cart->needs_shipping() ) {
			$chosen = WC()->session->get( 'chosen_shipping_methods', array() );
			$valid  = false;
			foreach ( WC()->shipping()->get_packages() as $i => $package ) {
				if ( isset( $chosen[ $i ], $package['rates'][ $chosen[ $i ] ] ) ) {
					$valid = true;
				}
			}
			if ( ! $valid ) {
				return new WP_Error( 'appforge_shipping', __( 'No shipping method available for this address.', 'appforge' ), array( 'status' => 400 ) );
			}
		}

		$pm       = sanitize_key( (string) $r->get_param( 'payment_method' ) );
		$gateways = WC()->payment_gateways()->get_available_payment_gateways();
		if ( $cart->needs_payment() && ! isset( $gateways[ $pm ] ) ) {
			return new WP_Error( 'appforge_payment', __( 'Please choose a valid payment method.', 'appforge' ), array( 'status' => 400 ) );
		}

		$data = array(
			'payment_method'            => $pm,
			'ship_to_different_address' => true,
			'order_comments'            => sanitize_textarea_field( (string) $r->get_param( 'customer_note' ) ),
		);
		foreach ( $billing as $k => $v ) {
			$data[ 'billing_' . $k ] = $v;
		}
		foreach ( $shipping as $k => $v ) {
			$data[ 'shipping_' . $k ] = $v;
		}

		$order_id = WC()->checkout()->create_order( $data );
		if ( is_wp_error( $order_id ) ) {
			return new WP_Error( 'appforge_order_failed', $order_id->get_error_message(), array( 'status' => 500 ) );
		}
		$order = wc_get_order( $order_id );
		$order->update_meta_data( '_appforge_order', 1 );
		$order->set_created_via( 'appforge-app' );
		$order->save();

		do_action( 'woocommerce_checkout_order_processed', $order_id, $data, $order );

		$response = array( 'status' => 'success' );
		if ( ! $order->needs_payment() ) {
			$order->payment_complete();
		} elseif ( in_array( $pm, self::native_gateways(), true ) ) {
			$gateways[ $pm ]->process_payment( $order_id );
		} else {
			$response['status']      = 'pending_payment';
			$response['payment_url'] = self::payment_url( $order );
		}

		$cart->empty_cart( false );
		wc_clear_notices();

		$response['order'] = self::format_order( wc_get_order( $order_id ) );
		return rest_ensure_response( $response );
	}

	/**
	 * Order-pay URL. Logged-in customers get a one-time token so the in-app browser is signed in.
	 */
	public static function payment_url( $order ) {
		$url = $order->get_checkout_payment_url();
		$uid = (int) $order->get_customer_id();
		if ( $uid ) {
			$token = wp_generate_password( 32, false, false );
			set_transient( 'appforge_pay_' . $token, array( 'user' => $uid, 'order' => $order->get_id() ), 15 * MINUTE_IN_SECONDS );
			$url = add_query_arg( 'appforge_pay', $token, $url );
		}
		return $url;
	}

	public static function maybe_autologin_for_payment() {
		if ( empty( $_GET['appforge_pay'] ) ) { // phpcs:ignore
			return;
		}
		$token = sanitize_key( wp_unslash( $_GET['appforge_pay'] ) ); // phpcs:ignore
		$data  = get_transient( 'appforge_pay_' . $token );
		delete_transient( 'appforge_pay_' . $token );
		if ( is_array( $data ) && ! empty( $data['user'] ) && get_current_user_id() !== (int) $data['user'] ) {
			wp_set_current_user( (int) $data['user'] );
			wp_set_auth_cookie( (int) $data['user'], false );
		}
		wp_safe_redirect( remove_query_arg( 'appforge_pay' ) );
		exit;
	}

	/* ---------- Orders ---------- */

	/**
	 * attribute_pa_color => red, taking "any" values from what the customer chose in the order.
	 */
	private static function variation_attributes( $item, $product ) {
		$out = array();
		foreach ( $product->get_variation_attributes() as $key => $value ) {
			if ( '' === $value ) {
				$value = (string) $item->get_meta( str_replace( 'attribute_', '', $key ), true );
			}
			$out[ $key ] = $value;
		}
		return $out;
	}

	public static function format_order( $order ) {
		$items = array();
		foreach ( $order->get_items() as $item ) {
			/** @var \WC_Order_Item_Product $item */
			$product = $item->get_product();
			$meta    = array();
			foreach ( $item->get_formatted_meta_data() as $m ) {
				$meta[] = array( 'key' => wp_strip_all_tags( $m->display_key ), 'value' => wp_strip_all_tags( $m->display_value ) );
			}
			$items[] = array(
				'product_id' => $item->get_product_id(),
				'variation_id' => $item->get_variation_id(),
				'variation'  => (object) ( $product && $product->is_type( 'variation' ) ? self::variation_attributes( $item, $product ) : array() ),
				'available'  => $product && $product->is_purchasable() && $product->is_in_stock(),
				'price'      => $product ? (float) wc_get_price_to_display( $product ) : 0,
				'name'       => html_entity_decode( $item->get_name(), ENT_QUOTES, 'UTF-8' ),
				'quantity'   => $item->get_quantity(),
				'total'      => (float) $item->get_total() + (float) $item->get_total_tax(),
				'image'      => $product && $product->get_image_id() ? wp_get_attachment_image_url( $product->get_image_id(), 'woocommerce_thumbnail' ) : '',
				'meta'       => $meta,
			);
		}
		$status = $order->get_status();
		return array(
			'id'             => $order->get_id(),
			'number'         => $order->get_order_number(),
			'status'         => $status,
			'status_label'   => wc_get_order_status_name( $status ),
			'date'           => $order->get_date_created() ? $order->get_date_created()->format( DATE_ATOM ) : '',
			'currency'       => $order->get_currency(),
			'total'          => (float) $order->get_total(),
			'subtotal'       => (float) $order->get_subtotal(),
			'shipping_total' => (float) $order->get_shipping_total() + (float) $order->get_shipping_tax(),
			'discount_total' => (float) $order->get_discount_total(),
			'tax_total'      => (float) $order->get_total_tax(),
			'payment_method' => $order->get_payment_method_title(),
			'shipping_method'=> $order->get_shipping_method(),
			'billing'        => $order->get_address( 'billing' ),
			'shipping'       => $order->get_address( 'shipping' ),
			'customer_note'  => $order->get_customer_note(),
			'items'          => $items,
			'needs_payment'  => $order->needs_payment(),
			'can_cancel'     => in_array( $status, apply_filters( 'appforge_cancellable_statuses', array( 'pending', 'on-hold' ) ), true ),
		);
	}

	public static function orders( WP_REST_Request $r ) {
		$result = wc_get_orders(
			array(
				'customer_id' => get_current_user_id(),
				'limit'       => 10,
				'page'        => max( 1, (int) $r->get_param( 'page' ) ),
				'paginate'    => true,
				'orderby'     => 'date',
				'order'       => 'DESC',
			)
		);
		$items = array();
		foreach ( $result->orders as $order ) {
			$items[] = self::format_order( $order );
		}
		return rest_ensure_response( array( 'items' => $items, 'total_pages' => (int) $result->max_num_pages ) );
	}

	private static function own_order( $id ) {
		$order = wc_get_order( (int) $id );
		if ( ! $order || (int) $order->get_customer_id() !== get_current_user_id() ) {
			return new WP_Error( 'appforge_not_found', __( 'Order not found.', 'appforge' ), array( 'status' => 404 ) );
		}
		return $order;
	}

	public static function order( WP_REST_Request $r ) {
		$order = self::own_order( $r['id'] );
		if ( is_wp_error( $order ) ) {
			return $order;
		}
		$data = self::format_order( $order );
		if ( $order->needs_payment() ) {
			$data['payment_url'] = self::payment_url( $order );
		}
		return rest_ensure_response( $data );
	}

	public static function cancel_order( WP_REST_Request $r ) {
		$order = self::own_order( $r['id'] );
		if ( is_wp_error( $order ) ) {
			return $order;
		}
		$data = self::format_order( $order );
		if ( ! $data['can_cancel'] ) {
			return new WP_Error( 'appforge_cannot_cancel', __( 'This order can no longer be cancelled.', 'appforge' ), array( 'status' => 400 ) );
		}
		$order->update_status( 'cancelled', __( 'Cancelled by customer from the app.', 'appforge' ) );
		return rest_ensure_response( self::format_order( wc_get_order( $order->get_id() ) ) );
	}

	public static function countries() {
		if ( ! Woo::active() ) {
			return rest_ensure_response( array() );
		}
		$wc_countries = WC()->countries;
		$out          = array();
		foreach ( $wc_countries->get_allowed_countries() as $code => $name ) {
			$states = array();
			foreach ( (array) $wc_countries->get_states( $code ) as $s_code => $s_name ) {
				$states[] = array( 'code' => (string) $s_code, 'name' => html_entity_decode( $s_name, ENT_QUOTES, 'UTF-8' ) );
			}
			$out[] = array( 'code' => $code, 'name' => html_entity_decode( $name, ENT_QUOTES, 'UTF-8' ), 'states' => $states );
		}
		return rest_ensure_response(
			array(
				'countries' => $out,
				'default'   => $wc_countries->get_base_country(),
			)
		);
	}
}
