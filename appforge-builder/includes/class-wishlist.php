<?php
namespace AppForge;

use WP_Error;
use WP_REST_Request;

defined( 'ABSPATH' ) || exit;

/**
 * Wishlist for logged-in customers (stored in user meta).
 * Guests keep their wishlist on the phone; it is merged here when they log in (/wishlist/sync).
 */
class Wishlist {

	const META = '_appforge_wishlist';
	const MAX  = 200;

	public static function ids( $user_id ) {
		$ids = get_user_meta( $user_id, self::META, true );
		return is_array( $ids ) ? array_values( array_unique( array_map( 'intval', $ids ) ) ) : array();
	}

	private static function save( $user_id, array $ids ) {
		$ids = array_slice( array_values( array_unique( array_filter( array_map( 'intval', $ids ) ) ) ), 0, self::MAX );
		update_user_meta( $user_id, self::META, $ids );
		return $ids;
	}

	private static function valid_product( $id ) {
		$p = function_exists( 'wc_get_product' ) ? wc_get_product( $id ) : null;
		return $p && 'publish' === $p->get_status();
	}

	private static function response( $user_id, $with_products ) {
		$ids  = self::ids( $user_id );
		$data = array( 'ids' => $ids );
		if ( $with_products ) {
			$items = array();
			foreach ( $ids as $id ) {
				$p = wc_get_product( $id );
				if ( $p && 'publish' === $p->get_status() ) {
					$items[] = Woo::format_product( $p );
				}
			}
			$data['items'] = $items;
		}
		return rest_ensure_response( $data );
	}

	/** GET /wishlist?products=1 */
	public static function get( WP_REST_Request $r ) {
		return self::response( get_current_user_id(), (bool) $r->get_param( 'products' ) );
	}

	/** POST /wishlist { product_id, action: add|remove|toggle } */
	public static function update( WP_REST_Request $r ) {
		$uid    = get_current_user_id();
		$id     = (int) $r->get_param( 'product_id' );
		$action = sanitize_key( (string) $r->get_param( 'action' ) );
		if ( ! $id || ! self::valid_product( $id ) ) {
			return new WP_Error( 'appforge_not_found', __( 'Product not found.', 'appforge' ), array( 'status' => 404 ) );
		}
		$ids = self::ids( $uid );
		$has = in_array( $id, $ids, true );
		if ( 'add' === $action || ( 'toggle' === $action && ! $has ) ) {
			if ( ! $has ) {
				array_unshift( $ids, $id );
			}
		} else {
			$ids = array_values( array_diff( $ids, array( $id ) ) );
		}
		self::save( $uid, $ids );
		return self::response( $uid, false );
	}

	/** POST /wishlist/sync { ids: [..] } — merges the phone's list into the account and returns the result. */
	public static function sync( WP_REST_Request $r ) {
		$uid      = get_current_user_id();
		$incoming = array_filter( array_map( 'intval', (array) $r->get_param( 'ids' ) ) );
		$incoming = array_filter( $incoming, array( __CLASS__, 'valid_product' ) );
		self::save( $uid, array_merge( $incoming, self::ids( $uid ) ) );
		return self::response( $uid, false );
	}
}
