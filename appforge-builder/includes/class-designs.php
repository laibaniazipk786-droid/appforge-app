<?php
namespace AppForge;

use WP_Error;
use WP_REST_Request;

defined( 'ABSPATH' ) || exit;

/**
 * Multiple saved designs. Exactly one is "active" — that's the one the app shows.
 * Each design = { id, name, created, updated, source, settings, screens }.
 */
class Designs {

	const OPT        = 'appforge_designs';
	const OPT_ACTIVE = 'appforge_active_design';

	private static $cache = null;

	private static function new_id() {
		return 'd' . strtolower( wp_generate_password( 8, false, false ) );
	}

	/**
	 * All designs keyed by id. Creates the first design (migrating v1.0 data) when empty.
	 */
	public static function all() {
		if ( null !== self::$cache ) {
			return self::$cache;
		}
		$designs = get_option( self::OPT );
		if ( ! is_array( $designs ) || empty( $designs ) ) {
			$legacy_settings = get_option( Settings::OPT_SETTINGS );
			$legacy_layouts  = get_option( Settings::OPT_LAYOUTS );
			$id              = self::new_id();
			$designs         = array(
				$id => array(
					'id'       => $id,
					'name'     => __( 'My first design', 'appforge' ),
					'created'  => time(),
					'updated'  => time(),
					'source'   => '',
					'settings' => Settings::sanitize_design( is_array( $legacy_settings ) ? $legacy_settings : array() ),
					'screens'  => is_array( $legacy_layouts ) && ! empty( $legacy_layouts['home'] ) ? $legacy_layouts : Settings::default_layouts(),
				),
			);
			update_option( self::OPT, $designs, false );
			update_option( self::OPT_ACTIVE, $id );
		}
		self::$cache = $designs;
		return $designs;
	}

	private static function persist( $designs ) {
		self::$cache = $designs;
		update_option( self::OPT, $designs, false );
	}

	public static function active_id() {
		$all = self::all();
		$id  = get_option( self::OPT_ACTIVE );
		if ( ! $id || ! isset( $all[ $id ] ) ) {
			$id = (string) key( $all );
			update_option( self::OPT_ACTIVE, $id );
		}
		return $id;
	}

	public static function get( $id ) {
		$all = self::all();
		return isset( $all[ $id ] ) ? $all[ $id ] : null;
	}

	public static function active() {
		return self::get( self::active_id() );
	}

	public static function summary( $d ) {
		$s = Settings::normalize_design( $d['settings'] );
		return array(
			'id'      => $d['id'],
			'name'    => $d['name'],
			'created' => (int) $d['created'],
			'updated' => (int) $d['updated'],
			'source'  => isset( $d['source'] ) ? $d['source'] : '',
			'active'  => self::active_id() === $d['id'],
			'colors'  => array( $s['primary_color'], $s['secondary_color'], $s['background_color'], $s['text_color'] ),
			'logo'    => $s['logo'],
			'appbar_bg' => $s['appbar']['bg_color'],
			'screens' => count( $d['screens'] ),
		);
	}

	public static function full( $d ) {
		return array_merge(
			self::summary( $d ),
			array(
				'settings' => Settings::normalize_design( $d['settings'] ),
				'screens'  => $d['screens'],
			)
		);
	}

	public static function create( $name, $settings, $screens, $source = '' ) {
		$all        = self::all();
		$id         = self::new_id();
		$all[ $id ] = array(
			'id'       => $id,
			'name'     => sanitize_text_field( $name ),
			'created'  => time(),
			'updated'  => time(),
			'source'   => sanitize_key( $source ),
			'settings' => Settings::sanitize_design( $settings ),
			'screens'  => Settings::sanitize_screens( $screens ),
		);
		self::persist( $all );
		return $id;
	}

	public static function activate( $id ) {
		update_option( self::OPT_ACTIVE, $id );
		self::touch();
	}

	/** Tells the app that the design changed. */
	public static function touch() {
		update_option( 'appforge_updated_at', time() );
	}

	/* ---------------- REST (admin) ---------------- */

	private static function find( WP_REST_Request $r ) {
		$d = self::get( sanitize_key( $r['id'] ) );
		return $d ? $d : new WP_Error( 'appforge_design_missing', __( 'Design not found.', 'appforge' ), array( 'status' => 404 ) );
	}

	public static function rest_list() {
		$out = array();
		foreach ( self::all() as $d ) {
			$out[] = self::summary( $d );
		}
		usort(
			$out,
			function ( $a, $b ) {
				return $b['updated'] - $a['updated'];
			}
		);
		return rest_ensure_response( $out );
	}

	public static function rest_get( WP_REST_Request $r ) {
		$d = self::find( $r );
		return is_wp_error( $d ) ? $d : rest_ensure_response( self::full( $d ) );
	}

	/**
	 * POST /admin/designs  { name, from? }  — blank design or duplicate of `from`.
	 */
	public static function rest_create( WP_REST_Request $r ) {
		$name = sanitize_text_field( (string) $r->get_param( 'name' ) );
		$from = sanitize_key( (string) $r->get_param( 'from' ) );
		$src  = $from ? self::get( $from ) : null;
		if ( $src ) {
			$id = self::create( $name ? $name : $src['name'] . ' (copy)', $src['settings'], $src['screens'], isset( $src['source'] ) ? $src['source'] : '' );
		} else {
			$id = self::create( $name ? $name : __( 'New design', 'appforge' ), Settings::design_defaults(), Settings::default_layouts() );
		}
		return rest_ensure_response( self::full( self::get( $id ) ) );
	}

	/**
	 * POST /admin/designs/{id}  { name?, settings?, screens? }
	 */
	public static function rest_save( WP_REST_Request $r ) {
		$d = self::find( $r );
		if ( is_wp_error( $d ) ) {
			return $d;
		}
		$all = self::all();
		if ( null !== $r->get_param( 'name' ) && '' !== trim( (string) $r->get_param( 'name' ) ) ) {
			$d['name'] = sanitize_text_field( $r->get_param( 'name' ) );
		}
		if ( is_array( $r->get_param( 'settings' ) ) ) {
			$d['settings'] = Settings::sanitize_design( $r->get_param( 'settings' ) );
		}
		if ( is_array( $r->get_param( 'screens' ) ) ) {
			$d['screens'] = Settings::sanitize_screens( $r->get_param( 'screens' ) );
		}
		$d['updated']       = time();
		$all[ $d['id'] ]    = $d;
		self::persist( $all );
		if ( self::active_id() === $d['id'] ) {
			self::touch();
		}
		return rest_ensure_response( self::full( $d ) );
	}

	public static function rest_activate( WP_REST_Request $r ) {
		$d = self::find( $r );
		if ( is_wp_error( $d ) ) {
			return $d;
		}
		self::activate( $d['id'] );
		return self::rest_list();
	}

	public static function rest_delete( WP_REST_Request $r ) {
		$d = self::find( $r );
		if ( is_wp_error( $d ) ) {
			return $d;
		}
		if ( self::active_id() === $d['id'] ) {
			return new WP_Error( 'appforge_design_active', __( 'Activate another design before deleting this one.', 'appforge' ), array( 'status' => 400 ) );
		}
		$all = self::all();
		unset( $all[ $d['id'] ] );
		self::persist( $all );
		return self::rest_list();
	}

	public static function rest_store( WP_REST_Request $r ) {
		$store = Settings::save_store( (array) $r->get_param( 'store' ) );
		self::touch();
		return rest_ensure_response( $store );
	}
}
