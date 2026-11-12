<?php
namespace AppForge;

defined( 'ABSPATH' ) || exit;

/**
 * Minimal HS256 JSON Web Token implementation (no external dependency).
 */
class Jwt {

	const TTL = 2592000; // 30 days.

	private static function b64( $data ) {
		return rtrim( strtr( base64_encode( $data ), '+/', '-_' ), '=' );
	}

	private static function unb64( $data ) {
		$pad = strlen( $data ) % 4;
		if ( $pad ) {
			$data .= str_repeat( '=', 4 - $pad );
		}
		return base64_decode( strtr( $data, '-_', '+/' ) );
	}

	public static function encode( $user_id ) {
		$now     = time();
		$header  = array( 'typ' => 'JWT', 'alg' => 'HS256' );
		$payload = array(
			'iss' => get_site_url(),
			'iat' => $now,
			'exp' => $now + (int) apply_filters( 'appforge_jwt_ttl', self::TTL ),
			'uid' => (int) $user_id,
			// Changing the password invalidates old tokens.
			'pwh' => substr( md5( (string) get_userdata( $user_id )->user_pass ), 0, 10 ),
		);
		$segments = self::b64( wp_json_encode( $header ) ) . '.' . self::b64( wp_json_encode( $payload ) );
		$sig      = hash_hmac( 'sha256', $segments, Settings::jwt_secret(), true );
		return $segments . '.' . self::b64( $sig );
	}

	/**
	 * Returns the user ID for a valid token, or 0.
	 */
	public static function decode( $token ) {
		$parts = explode( '.', (string) $token );
		if ( 3 !== count( $parts ) ) {
			return 0;
		}
		list( $h, $p, $s ) = $parts;
		$expected = self::b64( hash_hmac( 'sha256', $h . '.' . $p, Settings::jwt_secret(), true ) );
		if ( ! hash_equals( $expected, $s ) ) {
			return 0;
		}
		$payload = json_decode( self::unb64( $p ), true );
		if ( ! is_array( $payload ) || empty( $payload['uid'] ) || empty( $payload['exp'] ) || $payload['exp'] < time() ) {
			return 0;
		}
		$user = get_userdata( (int) $payload['uid'] );
		if ( ! $user ) {
			return 0;
		}
		if ( empty( $payload['pwh'] ) || substr( md5( (string) $user->user_pass ), 0, 10 ) !== $payload['pwh'] ) {
			return 0;
		}
		return (int) $user->ID;
	}
}
