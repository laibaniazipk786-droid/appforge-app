<?php
namespace AppForge;

use WP_REST_Request;
use WP_REST_Server;

defined( 'ABSPATH' ) || exit;

/**
 * Registers all REST routes under /wp-json/appforge/v1
 */
class Rest {

	public static function init() {
		add_action( 'rest_api_init', array( __CLASS__, 'routes' ) );
	}

	private static function route( $path, $methods, $callback, $permission = 'app' ) {
		$perm = array( Auth::class, 'check_app' );
		if ( 'user' === $permission ) {
			$perm = array( Auth::class, 'check_user' );
		} elseif ( 'admin' === $permission ) {
			$perm = function () {
				return current_user_can( 'manage_options' );
			};
		}
		register_rest_route(
			APPFORGE_NS,
			$path,
			array(
				'methods'             => $methods,
				'callback'            => $callback,
				'permission_callback' => $perm,
			)
		);
	}

	public static function routes() {
		$get  = WP_REST_Server::READABLE;
		$post = WP_REST_Server::CREATABLE;

		// App config (theme + screens built in the builder).
		self::route( '/config', $get, array( __CLASS__, 'config' ) );

		// Catalog.
		self::route( '/products', $get, array( Woo::class, 'products' ) );
		self::route( '/products/filters', $get, array( Woo::class, 'filters' ) );
		self::route( '/products/(?P<id>\d+)', $get, array( Woo::class, 'product' ) );
		self::route( '/products/(?P<id>\d+)/reviews', $get, array( Woo::class, 'reviews' ) );
		self::route( '/products/(?P<id>\d+)/reviews', $post, array( Woo::class, 'add_review' ), 'user' );
		self::route( '/categories', $get, array( Woo::class, 'categories' ) );
		self::route( '/posts', $get, array( Woo::class, 'posts' ) );
		self::route( '/posts/(?P<id>\d+)', $get, array( Woo::class, 'post' ) );
		self::route( '/pages/(?P<id>\d+)', $get, array( Content::class, 'page' ) );
		self::route( '/contact', $post, array( Content::class, 'contact' ) );
		self::route( '/orders/track', $post, array( Content::class, 'track' ) );

		// Cart & checkout.
		self::route( '/cart/calculate', $post, array( Cart::class, 'calculate' ) );
		self::route( '/checkout', $post, array( Cart::class, 'checkout' ) );
		self::route( '/countries', $get, array( Cart::class, 'countries' ) );

		// Orders.
		self::route( '/orders', $get, array( Cart::class, 'orders' ), 'user' );
		self::route( '/orders/(?P<id>\d+)', $get, array( Cart::class, 'order' ), 'user' );
		self::route( '/orders/(?P<id>\d+)/cancel', $post, array( Cart::class, 'cancel_order' ), 'user' );

		// Wishlist.
		self::route( '/wishlist', $get, array( Wishlist::class, 'get' ), 'user' );
		self::route( '/wishlist', $post, array( Wishlist::class, 'update' ), 'user' );
		self::route( '/wishlist/sync', $post, array( Wishlist::class, 'sync' ), 'user' );

		// Auth.
		self::route( '/auth/login', $post, array( Auth::class, 'login' ) );
		self::route( '/auth/register', $post, array( Auth::class, 'register' ) );
		self::route( '/auth/forgot', $post, array( Auth::class, 'forgot' ) );
		self::route( '/auth/me', $get, array( Auth::class, 'me' ), 'user' );
		self::route( '/auth/me', $post, array( Auth::class, 'update_me' ), 'user' );
		self::route( '/auth/password', $post, array( Auth::class, 'change_password' ), 'user' );
		self::route( '/auth/delete', $post, array( Auth::class, 'delete_me' ), 'user' );

		// Builder (admin only).
		self::route( '/admin/designs', $get, array( Designs::class, 'rest_list' ), 'admin' );
		self::route( '/admin/designs', $post, array( Designs::class, 'rest_create' ), 'admin' );
		self::route( '/admin/designs/(?P<id>[a-z0-9]+)', $get, array( Designs::class, 'rest_get' ), 'admin' );
		self::route( '/admin/designs/(?P<id>[a-z0-9]+)', $post, array( Designs::class, 'rest_save' ), 'admin' );
		self::route( '/admin/designs/(?P<id>[a-z0-9]+)/activate', $post, array( Designs::class, 'rest_activate' ), 'admin' );
		self::route( '/admin/designs/(?P<id>[a-z0-9]+)/delete', $post, array( Designs::class, 'rest_delete' ), 'admin' );
		self::route( '/admin/store', $post, array( Designs::class, 'rest_store' ), 'admin' );
		self::route( '/admin/templates', $get, array( Templates::class, 'rest_list' ), 'admin' );
		self::route( '/admin/templates/(?P<slug>[a-z0-9_-]+)/import', $post, array( Templates::class, 'rest_import' ), 'admin' );
		self::route( '/admin/languages', $get, array( I18n::class, 'rest_get' ), 'admin' );
		self::route( '/admin/languages', $post, array( I18n::class, 'rest_save' ), 'admin' );
		self::route( '/admin/languages/(?P<code>[a-z0-9_-]+)', $get, array( I18n::class, 'rest_pack' ), 'admin' );
		self::route( '/admin/regenerate-keys', $post, array( __CLASS__, 'admin_regenerate_keys' ), 'admin' );
	}

	public static function config( WP_REST_Request $request ) {
		$settings = Settings::get();
		unset( $settings['require_api_key'] );
		if ( isset( $settings['popup'] ) && is_array( $settings['popup'] ) ) {
			// Changes whenever the popup content changes, so the app shows an edited popup again.
			$settings['popup']['id'] = substr( md5( wp_json_encode( $settings['popup'] ) ), 0, 12 );
		}

		$design = Designs::active();
		$data   = array(
			'version'     => APPFORGE_VERSION,
			'design_id'   => $design['id'],
			'updated_at'  => (int) get_option( 'appforge_updated_at', 0 ),
			'site'        => array(
				'name' => get_bloginfo( 'name' ),
				'url'  => home_url( '/' ),
			),
			'woocommerce' => Woo::active(),
			'currency'    => Woo::currency(),
			'settings'    => $settings,
			'server_time' => time(),
			'screens'     => self::prepare_screens( Settings::layouts() ),
			'languages'   => I18n::config(),
		);
		$response = rest_ensure_response( apply_filters( 'appforge_config', $data ) );
		$response->header( 'Cache-Control', 'no-cache' );
		return $response;
	}

	/**
	 * Adds computed values the app needs (e.g. flash sale end as a UTC timestamp).
	 */
	private static function prepare_screens( $screens ) {
		foreach ( $screens as $slug => $screen ) {
			foreach ( $screen['blocks'] as $i => $block ) {
				if ( 'flash_sale' === $block['type'] ) {
					$ends = isset( $block['props']['ends_at'] ) ? (string) $block['props']['ends_at'] : '';
					$ts   = 0;
					if ( '' !== $ends ) {
						try {
							$ts = ( new \DateTime( $ends, wp_timezone() ) )->getTimestamp();
						} catch ( \Exception $e ) {
							$ts = 0;
						}
					}
					$screens[ $slug ]['blocks'][ $i ]['props']['ends_at_ts'] = $ts;
				}
			}
		}
		return $screens;
	}

	public static function admin_regenerate_keys() {
		$keys = Settings::generate_keys();
		update_option( Settings::OPT_KEYS, $keys, false );
		return rest_ensure_response( $keys );
	}
}
