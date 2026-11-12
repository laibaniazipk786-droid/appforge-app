<?php
namespace AppForge;

defined( 'ABSPATH' ) || exit;

/**
 * Bootstraps the plugin.
 */
class Plugin {

	/** @var Plugin|null */
	private static $instance = null;

	public static function instance() {
		if ( null === self::$instance ) {
			self::$instance = new self();
		}
		return self::$instance;
	}

	private function __construct() {
		Auth::init();
		Rest::init();
		Cart::init_hooks();
		I18n::init();
		Taxonomy::init();
		if ( is_admin() ) {
			Admin::init();
		}
		// Mark orders that were created from the app.
		add_filter( 'manage_edit-shop_order_columns', array( $this, 'order_column' ) );
		add_action( 'manage_shop_order_posts_custom_column', array( $this, 'order_column_value' ), 10, 2 );
		add_filter( 'manage_woocommerce_page_wc-orders_columns', array( $this, 'order_column' ) );
		add_action( 'manage_woocommerce_page_wc-orders_custom_column', array( $this, 'order_column_value' ), 10, 2 );
	}

	public static function activate() {
		Settings::ensure_defaults();
	}

	public function order_column( $columns ) {
		$columns['appforge'] = __( 'Source', 'appforge' );
		return $columns;
	}

	public function order_column_value( $column, $order ) {
		if ( 'appforge' !== $column ) {
			return;
		}
		$order = is_object( $order ) ? $order : wc_get_order( $order );
		if ( $order && $order->get_meta( '_appforge_order' ) ) {
			echo '<span style="background:#4F46E5;color:#fff;padding:2px 8px;border-radius:10px;font-size:11px">App</span>';
		} else {
			echo '&ndash;';
		}
	}
}
