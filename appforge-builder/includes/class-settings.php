<?php
namespace AppForge;

defined( 'ABSPATH' ) || exit;

/**
 * Settings are split in two:
 *  - Design settings (theme, colors, app bar, navigation, onboarding) live inside each saved design.
 *  - Store settings (API key requirement, guest checkout, registration) are global.
 */
class Settings {

	const OPT_STORE = 'appforge_store';
	const OPT_KEYS  = 'appforge_keys';

	/** Legacy (v1.0) options, migrated into the first design. */
	const OPT_SETTINGS = 'appforge_settings';
	const OPT_LAYOUTS  = 'appforge_layouts';

	public static function design_defaults() {
		return array(
			'app_name'           => get_bloginfo( 'name' ),
			'logo'               => '',
			'color_scheme'       => 'indigo',
			'primary_color'      => '#4F46E5',
			'on_primary_color'   => '#FFFFFF',
			'secondary_color'    => '#F59E0B',
			'background_color'   => '#F8FAFC',
			'surface_color'      => '#FFFFFF',
			'text_color'         => '#0F172A',
			'muted_color'        => '#64748B',
			'border_color'       => '#E2E8F0',
			'price_color'        => '',
			'sale_color'         => '',
			'nav_bg_color'       => '#FFFFFF',
			'nav_active_color'   => '',
			'nav_inactive_color' => '#94A3B8',
			'font_family'        => 'Roboto',
			'card_radius'        => 12,
			'product_card'       => 'standard', // standard | bordered | minimal
			'appbar'             => array(
				'title_type'   => 'logo_or_name', // logo_or_name | logo | name | logo_name | custom
				'title_text'   => '',
				'center'       => false,
				'bg_color'     => '#FFFFFF',
				'fg_color'     => '#0F172A',
				'shadow'       => false,
				'show_search'  => true,
				'show_cart'    => true,
				'show_account' => false,
				'search_bar'   => false,
				'search_text'  => 'Search products...',
			),
			'onboarding'         => array(
				'enabled'    => false,
				'version'    => 1,
				'style'      => 'image_top', // image_top | fullscreen
				'bg_color'   => '#FFFFFF',
				'text_color' => '',
				'skip_label' => 'Skip',
				'next_label' => 'Next',
				'done_label' => 'Get started',
				'slides'     => array(),
			),
			'theme_mode'         => 'light', // light | dark | system
			'allow_theme_switch' => true,
			'dark'               => array(
				'primary_color'      => '',
				'secondary_color'    => '',
				'background_color'   => '#0B1120',
				'surface_color'      => '#151E2E',
				'text_color'         => '#E5E7EB',
				'muted_color'        => '#94A3B8',
				'border_color'       => '#263244',
				'appbar_bg_color'    => '#151E2E',
				'appbar_fg_color'    => '#F1F5F9',
				'nav_bg_color'       => '#151E2E',
				'nav_inactive_color' => '#64748B',
			),
			'nav_labels'         => 'all', // all | selected | none
			'drawer'             => array(
				'enabled'           => true,
				'header_style'      => 'primary', // primary | image | plain
				'header_image'      => '',
				'show_login'        => true,
				'show_categories'   => true,
				'categories_title'  => 'Categories',
				'categories_limit'  => 12,
				'show_language'     => true,
				'show_theme_toggle' => true,
				'items'             => array(
					array( 'label' => 'Home', 'icon' => 'home', 'action' => array( 'type' => 'screen', 'value' => 'home' ) ),
					array( 'label' => 'Shop', 'icon' => 'store', 'action' => array( 'type' => 'route', 'value' => 'products' ) ),
					array( 'label' => 'Wishlist', 'icon' => 'heart', 'action' => array( 'type' => 'route', 'value' => 'wishlist' ) ),
					array( 'label' => 'Track order', 'icon' => 'local_shipping', 'action' => array( 'type' => 'route', 'value' => 'track_order' ) ),
					array( 'label' => 'About us', 'icon' => 'info', 'action' => array( 'type' => 'screen', 'value' => 'about' ) ),
					array( 'label' => 'Contact us', 'icon' => 'support_agent', 'action' => array( 'type' => 'route', 'value' => 'contact' ) ),
				),
			),
			'product_page'       => array(
				'variation_style' => 'auto', // auto (swatches when available) | chips | dropdown
				'show_wishlist'   => true,
				'show_filters'    => true,
				'show_sku'        => true,
				'show_stock'      => true,
				'show_reviews'    => true,
				'show_related'    => true,
				'show_share'      => true,
				'sticky_buy_bar'  => true,
			),
			'bottom_nav'         => array(
				array( 'label' => 'Home', 'icon' => 'home', 'action' => array( 'type' => 'screen', 'value' => 'home' ) ),
				array( 'label' => 'Categories', 'icon' => 'category', 'action' => array( 'type' => 'route', 'value' => 'categories' ) ),
				array( 'label' => 'Cart', 'icon' => 'cart', 'action' => array( 'type' => 'route', 'value' => 'cart' ) ),
				array( 'label' => 'Account', 'icon' => 'person', 'action' => array( 'type' => 'route', 'value' => 'account' ) ),
			),
		);
	}

	public static function store_defaults() {
		return array(
			'require_api_key'   => true,
			'guest_checkout'    => true,
			'enable_register'   => true,
			'hide_out_of_stock' => false,
			'contact'           => array(
				'phone'        => '',
				'whatsapp'     => '',
				'email'        => get_option( 'admin_email' ),
				'address'      => '',
				'hours'        => '',
				'map_url'      => '',
				'facebook'     => '',
				'instagram'    => '',
				'form_enabled' => true,
			),
		);
	}

	/** Backwards compatible: everything the app/config needs. */
	public static function defaults() {
		return array_merge( self::design_defaults(), self::store_defaults() );
	}

	public static function default_layouts() {
		return self::with_about( array(
			'home' => array(
				'title'  => 'Home',
				'blocks' => array(
					array( 'id' => 'b1', 'type' => 'search', 'props' => array( 'placeholder' => 'Search products...' ) ),
					array( 'id' => 'b2', 'type' => 'slider', 'props' => array( 'height' => 170, 'autoplay' => true, 'radius' => 12, 'items' => array() ) ),
					array( 'id' => 'b3', 'type' => 'heading', 'props' => array( 'text' => 'Shop by category', 'align' => 'left', 'size' => 18 ) ),
					array( 'id' => 'b4', 'type' => 'categories', 'props' => array( 'layout' => 'horizontal', 'limit' => 10, 'shape' => 'circle', 'show_name' => true ) ),
					array( 'id' => 'b5', 'type' => 'heading', 'props' => array( 'text' => 'New arrivals', 'align' => 'left', 'size' => 18, 'show_view_all' => true, 'action' => array( 'type' => 'route', 'value' => 'products' ) ) ),
					array( 'id' => 'b6', 'type' => 'products', 'props' => array( 'source' => 'latest', 'limit' => 8, 'layout' => 'horizontal', 'columns' => 2 ) ),
					array( 'id' => 'b7', 'type' => 'heading', 'props' => array( 'text' => 'On sale', 'align' => 'left', 'size' => 18 ) ),
					array( 'id' => 'b8', 'type' => 'products', 'props' => array( 'source' => 'on_sale', 'limit' => 6, 'layout' => 'grid', 'columns' => 2 ) ),
				),
			),
		) );
	}

	public static function with_about( $l ) {
		$l['about'] = self::about_screen();
		return $l;
	}

	public static function about_screen() {
		return array(
			'title'  => 'About us',
			'blocks' => array(
				array( 'id' => 'a1', 'type' => 'heading', 'props' => array( 'text' => 'About ' . get_bloginfo( 'name' ), 'size' => 22, 'align' => 'left' ) ),
				array( 'id' => 'a2', 'type' => 'html', 'props' => array( 'content' => '<p>We started with one simple idea: great products, honest prices and friendly service.</p><p>Edit this page in <strong>WordPress → AppForge → Screens → About us</strong>.</p>' ) ),
				array( 'id' => 'a3', 'type' => 'contact_info', 'props' => array( 'title' => 'Get in touch' ) ),
			),
		);
	}

	public static function ensure_defaults() {
		if ( false === get_option( self::OPT_KEYS ) ) {
			add_option( self::OPT_KEYS, self::generate_keys(), '', false );
		}
		if ( false === get_option( 'appforge_jwt_secret' ) ) {
			add_option( 'appforge_jwt_secret', wp_generate_password( 64, true, true ), '', false );
		}
		if ( false === get_option( self::OPT_STORE ) ) {
			$legacy = get_option( self::OPT_SETTINGS );
			$store  = self::store_defaults();
			if ( is_array( $legacy ) ) {
				foreach ( $store as $k => $v ) {
					if ( isset( $legacy[ $k ] ) ) {
						$store[ $k ] = (bool) $legacy[ $k ];
					}
				}
			}
			add_option( self::OPT_STORE, $store );
		}
		Designs::all(); // Triggers migration / first design.
	}

	public static function generate_keys() {
		return array(
			'key'    => 'afk_' . wp_generate_password( 32, false, false ),
			'secret' => 'afs_' . wp_generate_password( 40, false, false ),
		);
	}

	public static function store() {
		$saved = get_option( self::OPT_STORE, array() );
		return self::coerce( is_array( $saved ) ? $saved : array(), self::store_defaults() );
	}

	public static function save_store( array $input ) {
		$clean = self::coerce( array_merge( self::store(), $input ), self::store_defaults() );
		update_option( self::OPT_STORE, $clean );
		return $clean;
	}

	/**
	 * Settings of the ACTIVE design merged with store settings.
	 */
	public static function get() {
		$design = Designs::active();
		return array_merge( self::normalize_design( $design['settings'] ), self::store() );
	}

	public static function value( $key, $fallback = null ) {
		$store = self::store();
		if ( array_key_exists( $key, self::store_defaults() ) ) {
			return $store[ $key ];
		}
		$all = self::get();
		return isset( $all[ $key ] ) ? $all[ $key ] : $fallback;
	}

	public static function layouts() {
		$design = Designs::active();
		return ! empty( $design['screens']['home'] ) ? $design['screens'] : self::default_layouts();
	}

	public static function keys() {
		$keys = get_option( self::OPT_KEYS );
		if ( ! is_array( $keys ) || empty( $keys['key'] ) ) {
			$keys = self::generate_keys();
			update_option( self::OPT_KEYS, $keys, false );
		}
		return $keys;
	}

	public static function jwt_secret() {
		$secret = get_option( 'appforge_jwt_secret' );
		if ( ! $secret ) {
			$secret = wp_generate_password( 64, true, true );
			update_option( 'appforge_jwt_secret', $secret, false );
		}
		return $secret;
	}

	/**
	 * Fills missing keys with defaults (used when reading).
	 */
	public static function normalize_design( $settings ) {
		return self::coerce( is_array( $settings ) ? $settings : array(), self::design_defaults() );
	}

	/**
	 * Sanitizes design settings coming from the builder or a template.
	 */
	public static function sanitize_design( $input ) {
		return self::coerce( is_array( $input ) ? $input : array(), self::design_defaults() );
	}

	/**
	 * Recursively shapes $value like $default (types, allowed keys).
	 */
	private static function coerce( $value, $default, $key = '' ) {
		if ( is_array( $default ) ) {
			$is_list = array() === $default || array_keys( $default ) === range( 0, count( $default ) - 1 );
			if ( $is_list ) {
				return is_array( $value ) ? array_values( self::clean_deep( $value ) ) : $default;
			}
			$value = is_array( $value ) ? $value : array();
			$out   = array();
			foreach ( $default as $k => $d ) {
				$out[ $k ] = array_key_exists( $k, $value ) ? self::coerce( $value[ $k ], $d, $k ) : $d;
			}
			return $out;
		}
		if ( is_bool( $default ) ) {
			return is_string( $value ) ? in_array( strtolower( $value ), array( '1', 'true', 'yes', 'on' ), true ) : (bool) $value;
		}
		if ( is_int( $default ) ) {
			return (int) $value;
		}
		$value = is_scalar( $value ) ? (string) $value : '';
		if ( '_color' === substr( $key, -6 ) ) {
			$hex = sanitize_hex_color( $value );
			return $hex ? $hex : ( '' === $value ? '' : $default );
		}
		if ( 'logo' === $key ) {
			return esc_url_raw( $value );
		}
		return sanitize_text_field( $value );
	}

	public static function sanitize_screens( $layouts ) {
		$clean = array();
		foreach ( is_array( $layouts ) ? $layouts : array() as $slug => $screen ) {
			$slug = sanitize_key( $slug );
			if ( '' === $slug || ! is_array( $screen ) ) {
				continue;
			}
			$blocks = array();
			if ( ! empty( $screen['blocks'] ) && is_array( $screen['blocks'] ) ) {
				foreach ( $screen['blocks'] as $block ) {
					if ( empty( $block['type'] ) || ! Blocks::exists( $block['type'] ) ) {
						continue;
					}
					$blocks[] = array(
						'id'    => sanitize_key( isset( $block['id'] ) ? $block['id'] : wp_generate_password( 6, false ) ),
						'type'  => sanitize_key( $block['type'] ),
						'props' => isset( $block['props'] ) && is_array( $block['props'] ) ? self::clean_deep( $block['props'] ) : array(),
					);
					if ( 'html' === $block['type'] && isset( $block['props']['content'] ) ) {
						$blocks[ count( $blocks ) - 1 ]['props']['content'] = wp_kses_post( (string) $block['props']['content'] );
					}
					if ( 'faq' === $block['type'] && ! empty( $block['props']['items'] ) && is_array( $block['props']['items'] ) ) {
						foreach ( $block['props']['items'] as $i => $item ) {
							if ( isset( $item['answer'] ) ) {
								$blocks[ count( $blocks ) - 1 ]['props']['items'][ $i ]['answer'] = wp_kses_post( (string) $item['answer'] );
							}
						}
					}
				}
			}
			$clean[ $slug ] = array(
				'title'  => sanitize_text_field( isset( $screen['title'] ) ? $screen['title'] : $slug ),
				'blocks' => $blocks,
			);
		}
		if ( empty( $clean['home'] ) ) {
			$clean['home'] = array( 'title' => 'Home', 'blocks' => array() );
		}
		return $clean;
	}

	/**
	 * Recursively sanitizes builder values. Keeps numbers/bools, cleans strings.
	 */
	public static function clean_deep( $value, $key = '' ) {
		if ( is_array( $value ) ) {
			$out = array();
			foreach ( $value as $k => $v ) {
				$ck         = is_int( $k ) ? $k : sanitize_key( $k );
				$out[ $ck ] = self::clean_deep( $v, is_int( $k ) ? '' : $ck );
			}
			return $out;
		}
		if ( is_bool( $value ) || is_int( $value ) || is_float( $value ) || null === $value ) {
			return $value;
		}
		$value = (string) $value;
		if ( in_array( $key, array( 'image', 'logo' ), true ) ) {
			return preg_match( '#^https?://#i', $value ) ? esc_url_raw( $value ) : '';
		}
		if ( preg_match( '#^https?://#i', $value ) ) {
			return esc_url_raw( $value );
		}
		return sanitize_textarea_field( $value );
	}
}
