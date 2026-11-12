<?php
namespace AppForge;

use WP_Error;
use WP_REST_Request;

defined( 'ABSPATH' ) || exit;

/**
 * App languages.
 *  - UI strings: built-in packs in /languages/<code>.json (keys are the English text),
 *    plus per-site overrides edited in the builder.
 *  - Content: the app sends ?lang=xx; WPML / Polylang are switched accordingly.
 */
class I18n {

	const OPT = 'appforge_languages';

	public static function init() {
		add_filter( 'rest_pre_dispatch', array( __CLASS__, 'switch_for_request' ), 5, 3 );
	}

	/** Built-in languages that ship with a translation pack. */
	public static function builtin() {
		return apply_filters(
			'appforge_builtin_languages',
			array(
				'en' => array( 'name' => 'English', 'native' => 'English', 'rtl' => false ),
				'ur' => array( 'name' => 'Urdu', 'native' => 'اردو', 'rtl' => true ),
				'ar' => array( 'name' => 'Arabic', 'native' => 'العربية', 'rtl' => true ),
			)
		);
	}

	public static function defaults() {
		return array(
			'default'   => 'en',
			'enabled'   => array( 'en' ),
			'custom'    => array(),
			'overrides' => array(),
		);
	}

	public static function settings() {
		$s = get_option( self::OPT, array() );
		$s = wp_parse_args( is_array( $s ) ? $s : array(), self::defaults() );
		if ( empty( $s['enabled'] ) ) {
			$s['enabled'] = array( 'en' );
		}
		return $s;
	}

	/** All languages (built-in + custom) keyed by code. */
	public static function available() {
		$all = self::builtin();
		foreach ( self::settings()['custom'] as $c ) {
			if ( ! empty( $c['code'] ) ) {
				$all[ $c['code'] ] = array(
					'name'   => $c['name'],
					'native' => ! empty( $c['native'] ) ? $c['native'] : $c['name'],
					'rtl'    => ! empty( $c['rtl'] ),
					'custom' => true,
				);
			}
		}
		return $all;
	}

	public static function pack( $code ) {
		$file = APPFORGE_DIR . 'languages/' . sanitize_key( $code ) . '.json';
		if ( ! file_exists( $file ) ) {
			return array();
		}
		$data = json_decode( (string) file_get_contents( $file ), true ); // phpcs:ignore
		return is_array( $data ) ? $data : array();
	}

	/** English source strings (the keys). */
	public static function keys() {
		return array_keys( self::pack( 'en' ) );
	}

	public static function strings( $code ) {
		$s         = self::settings();
		$overrides = isset( $s['overrides'][ $code ] ) && is_array( $s['overrides'][ $code ] ) ? $s['overrides'][ $code ] : array();
		return array_merge( self::pack( $code ), array_filter( $overrides, 'strlen' ) );
	}

	/** Block sent to the app inside /config. */
	public static function config() {
		$s     = self::settings();
		$avail = self::available();
		$list  = array();
		$str   = array();
		foreach ( $s['enabled'] as $code ) {
			if ( ! isset( $avail[ $code ] ) ) {
				continue;
			}
			$list[]       = array(
				'code'   => $code,
				'name'   => $avail[ $code ]['name'],
				'native' => $avail[ $code ]['native'],
				'rtl'    => (bool) $avail[ $code ]['rtl'],
			);
			$str[ $code ] = (object) self::strings( $code );
		}
		if ( ! $list ) {
			$list[] = array( 'code' => 'en', 'name' => 'English', 'native' => 'English', 'rtl' => false );
		}
		return array(
			'default' => in_array( $s['default'], $s['enabled'], true ) ? $s['default'] : $list[0]['code'],
			'list'    => $list,
			'strings' => (object) $str,
		);
	}

	/* ---------------- content language (WPML / Polylang) ---------------- */

	public static function request_lang( $request = null ) {
		$lang = $request instanceof WP_REST_Request ? $request->get_param( 'lang' ) : null;
		return $lang ? sanitize_key( $lang ) : '';
	}

	public static function switch_for_request( $result, $server, $request ) {
		if ( 0 === strpos( $request->get_route(), '/' . APPFORGE_NS ) ) {
			$lang = self::request_lang( $request );
			if ( $lang && has_action( 'wpml_switch_language' ) ) {
				do_action( 'wpml_switch_language', $lang );
			}
		}
		return $result;
	}

	public static function query_args( $args, $request ) {
		$lang = self::request_lang( $request );
		if ( $lang && function_exists( 'pll_languages_list' ) && in_array( $lang, (array) pll_languages_list(), true ) ) {
			$args['lang'] = $lang;
		}
		return $args;
	}

	/* ---------------- admin REST ---------------- */

	public static function rest_get() {
		return rest_ensure_response(
			array(
				'settings'  => self::settings(),
				'available' => self::available(),
				'keys'      => self::keys(),
			)
		);
	}

	public static function rest_pack( WP_REST_Request $r ) {
		$code = sanitize_key( $r['code'] );
		$s    = self::settings();
		return rest_ensure_response(
			array(
				'code'      => $code,
				'pack'      => (object) self::pack( $code ),
				'overrides' => (object) ( isset( $s['overrides'][ $code ] ) ? $s['overrides'][ $code ] : array() ),
			)
		);
	}

	public static function rest_save( WP_REST_Request $r ) {
		$s = self::settings();

		$custom = array();
		foreach ( (array) $r->get_param( 'custom' ) as $c ) {
			$code = isset( $c['code'] ) ? sanitize_key( $c['code'] ) : '';
			if ( ! $code || isset( self::builtin()[ $code ] ) ) {
				continue;
			}
			$custom[] = array(
				'code'   => $code,
				'name'   => sanitize_text_field( isset( $c['name'] ) ? $c['name'] : $code ),
				'native' => sanitize_text_field( isset( $c['native'] ) ? $c['native'] : '' ),
				'rtl'    => ! empty( $c['rtl'] ),
			);
		}
		$s['custom'] = $custom;
		$valid       = array_keys( self::available() );

		$enabled      = array_values( array_intersect( array_map( 'sanitize_key', (array) $r->get_param( 'enabled' ) ), $valid ) );
		$s['enabled'] = $enabled ? $enabled : array( 'en' );
		$default      = sanitize_key( (string) $r->get_param( 'default' ) );
		$s['default'] = in_array( $default, $s['enabled'], true ) ? $default : $s['enabled'][0];

		$strings = $r->get_param( 'strings' );
		$code    = sanitize_key( (string) $r->get_param( 'code' ) );
		if ( $code && is_array( $strings ) ) {
			$clean = array();
			$keys  = array_flip( self::keys() );
			foreach ( $strings as $k => $v ) {
				if ( isset( $keys[ $k ] ) && '' !== trim( (string) $v ) ) {
					$clean[ $k ] = sanitize_text_field( $v );
				}
			}
			$s['overrides'][ $code ] = $clean;
		}

		update_option( self::OPT, $s );
		Designs::touch();
		return self::rest_get();
	}
}
