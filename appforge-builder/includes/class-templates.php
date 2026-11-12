<?php
namespace AppForge;

use WP_Error;
use WP_REST_Request;

defined( 'ABSPATH' ) || exit;

/**
 * Ready-made design templates (templates/<slug>/template.json + images/).
 * Importing copies the images into the Media Library and creates a new design.
 * Image references inside template.json look like "{{img:slide-1.jpg}}".
 */
class Templates {

	const OPT_MEDIA = 'appforge_template_media';

	private static function dir() {
		return APPFORGE_DIR . 'templates/';
	}

	private static function read( $slug ) {
		$slug = sanitize_key( $slug );
		$file = self::dir() . $slug . '/template.json';
		if ( ! $slug || ! file_exists( $file ) ) {
			return null;
		}
		$data = json_decode( (string) file_get_contents( $file ), true ); // phpcs:ignore
		if ( ! is_array( $data ) ) {
			return null;
		}
		$data['slug'] = $slug;
		return $data;
	}

	public static function all() {
		$out = array();
		foreach ( (array) glob( self::dir() . '*/template.json' ) as $file ) {
			$slug = basename( dirname( $file ) );
			$t    = self::read( $slug );
			if ( ! $t ) {
				continue;
			}
			$s     = isset( $t['settings'] ) ? $t['settings'] : array();
			$out[] = array(
				'slug'        => $slug,
				'name'        => isset( $t['name'] ) ? $t['name'] : $slug,
				'description' => isset( $t['description'] ) ? $t['description'] : '',
				'industry'    => isset( $t['industry'] ) ? $t['industry'] : '',
				'preview'     => APPFORGE_URL . 'templates/' . $slug . '/images/preview.jpg',
				'colors'      => array(
					isset( $s['primary_color'] ) ? $s['primary_color'] : '',
					isset( $s['secondary_color'] ) ? $s['secondary_color'] : '',
					isset( $s['background_color'] ) ? $s['background_color'] : '',
					isset( $s['text_color'] ) ? $s['text_color'] : '',
				),
				'order'       => isset( $t['order'] ) ? (int) $t['order'] : 99,
			);
		}
		usort(
			$out,
			function ( $a, $b ) {
				return $a['order'] - $b['order'];
			}
		);
		return apply_filters( 'appforge_templates', $out );
	}

	/**
	 * Copies a bundled image into the Media Library once and returns its URL.
	 */
	private static function media_url( $slug, $file ) {
		$file = basename( $file );
		$path = self::dir() . $slug . '/images/' . $file;
		if ( ! file_exists( $path ) ) {
			return '';
		}
		$map = get_option( self::OPT_MEDIA, array() );
		$key = $slug . '/' . $file;
		if ( ! empty( $map[ $key ] ) ) {
			$url = wp_get_attachment_url( (int) $map[ $key ] );
			if ( $url ) {
				return $url;
			}
		}

		$upload = wp_upload_bits( 'appforge-' . $slug . '-' . $file, null, (string) file_get_contents( $path ) ); // phpcs:ignore
		if ( ! empty( $upload['error'] ) ) {
			// Fallback: serve from the plugin folder.
			return APPFORGE_URL . 'templates/' . $slug . '/images/' . $file;
		}
		$type          = wp_check_filetype( $upload['file'] );
		$attachment_id = wp_insert_attachment(
			array(
				'post_mime_type' => $type['type'],
				'post_title'     => sanitize_text_field( ucwords( str_replace( array( '-', '_' ), ' ', pathinfo( $file, PATHINFO_FILENAME ) ) ) . ' (' . $slug . ')' ),
				'post_status'    => 'inherit',
			),
			$upload['file']
		);
		if ( is_wp_error( $attachment_id ) || ! $attachment_id ) {
			return $upload['url'];
		}
		require_once ABSPATH . 'wp-admin/includes/image.php';
		wp_update_attachment_metadata( $attachment_id, wp_generate_attachment_metadata( $attachment_id, $upload['file'] ) );
		update_post_meta( $attachment_id, '_appforge_template', $slug );

		$map[ $key ] = $attachment_id;
		update_option( self::OPT_MEDIA, $map, false );
		return wp_get_attachment_url( $attachment_id );
	}

	private static function resolve_images( $value, $slug ) {
		if ( is_array( $value ) ) {
			foreach ( $value as $k => $v ) {
				$value[ $k ] = self::resolve_images( $v, $slug );
			}
			return $value;
		}
		if ( is_string( $value ) && preg_match( '/^\{\{img:([a-z0-9._-]+)\}\}$/i', $value, $m ) ) {
			return self::media_url( $slug, $m[1] );
		}
		return $value;
	}

	/**
	 * Creates a new design from a template. Returns the design id.
	 */
	public static function import( $slug, $name = '' ) {
		$t = self::read( $slug );
		if ( ! $t ) {
			return new WP_Error( 'appforge_template_missing', __( 'Template not found.', 'appforge' ), array( 'status' => 404 ) );
		}
		$settings = self::resolve_images( isset( $t['settings'] ) ? $t['settings'] : array(), $t['slug'] );
		$screens  = self::resolve_images( isset( $t['screens'] ) ? $t['screens'] : array(), $t['slug'] );
		if ( empty( $settings['app_name'] ) ) {
			$settings['app_name'] = get_bloginfo( 'name' );
		}
		return Designs::create( $name ? $name : $t['name'], $settings, $screens, $t['slug'] );
	}

	/* ---------------- REST ---------------- */

	public static function rest_list() {
		return rest_ensure_response( self::all() );
	}

	public static function rest_import( WP_REST_Request $r ) {
		if ( function_exists( 'set_time_limit' ) ) {
			@set_time_limit( 120 ); // phpcs:ignore
		}
		$id = self::import( (string) $r['slug'], sanitize_text_field( (string) $r->get_param( 'name' ) ) );
		if ( is_wp_error( $id ) ) {
			return $id;
		}
		if ( $r->get_param( 'activate' ) ) {
			Designs::activate( $id );
		}
		return rest_ensure_response( Designs::full( Designs::get( $id ) ) );
	}
}
