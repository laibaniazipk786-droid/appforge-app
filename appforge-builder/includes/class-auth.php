<?php
namespace AppForge;

use WP_Error;
use WP_REST_Request;

defined( 'ABSPATH' ) || exit;

/**
 * Authentication: app API keys, JWT login, register, profile.
 */
class Auth {

	public static function init() {
		add_filter( 'determine_current_user', array( __CLASS__, 'determine_user' ), 30 );
	}

	/**
	 * Reads the bearer token from the request headers.
	 */
	public static function bearer_token() {
		$header = '';
		if ( ! empty( $_SERVER['HTTP_AUTHORIZATION'] ) ) {
			$header = wp_unslash( $_SERVER['HTTP_AUTHORIZATION'] ); // phpcs:ignore
		} elseif ( ! empty( $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ) ) {
			$header = wp_unslash( $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ); // phpcs:ignore
		} elseif ( ! empty( $_SERVER['HTTP_X_APPFORGE_TOKEN'] ) ) {
			// Fallback for hosts that strip the Authorization header.
			return trim( wp_unslash( $_SERVER['HTTP_X_APPFORGE_TOKEN'] ) ); // phpcs:ignore
		}
		if ( $header && 0 === stripos( $header, 'Bearer ' ) ) {
			return trim( substr( $header, 7 ) );
		}
		return '';
	}

	/**
	 * Logs the user in for REST requests carrying a valid AppForge JWT.
	 */
	public static function determine_user( $user_id ) {
		if ( $user_id ) {
			return $user_id;
		}
		$request_uri = isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : ''; // phpcs:ignore
		$is_rest     = false !== strpos( $request_uri, '/' . rest_get_url_prefix() . '/' ) || isset( $_GET['rest_route'] ); // phpcs:ignore
		if ( ! $is_rest ) {
			return $user_id;
		}
		$token = self::bearer_token();
		if ( ! $token || substr_count( $token, '.' ) !== 2 ) {
			return $user_id;
		}
		$uid = Jwt::decode( $token );
		return $uid ? $uid : $user_id;
	}

	/**
	 * Permission check for every public app endpoint.
	 * Allowed: valid API key pair, logged in admin (builder preview), or API key check disabled.
	 */
	public static function check_app( WP_REST_Request $request ) {
		if ( current_user_can( 'manage_options' ) ) {
			return true;
		}
		if ( ! Settings::value( 'require_api_key', true ) ) {
			return true;
		}
		$keys   = Settings::keys();
		$key    = (string) $request->get_header( 'x_appforge_key' );
		$secret = (string) $request->get_header( 'x_appforge_secret' );
		if ( $key && $secret && hash_equals( $keys['key'], $key ) && hash_equals( $keys['secret'], $secret ) ) {
			return true;
		}
		return new WP_Error( 'appforge_unauthorized', __( 'Invalid or missing app API key.', 'appforge' ), array( 'status' => 401 ) );
	}

	public static function check_user( WP_REST_Request $request ) {
		$app = self::check_app( $request );
		if ( is_wp_error( $app ) ) {
			return $app;
		}
		if ( ! get_current_user_id() ) {
			return new WP_Error( 'appforge_not_logged_in', __( 'Please log in.', 'appforge' ), array( 'status' => 401 ) );
		}
		return true;
	}

	public static function user_payload( $user_id ) {
		$user = get_userdata( $user_id );
		$data = array(
			'id'           => (int) $user->ID,
			'username'     => $user->user_login,
			'email'        => $user->user_email,
			'first_name'   => $user->first_name,
			'last_name'    => $user->last_name,
			'display_name' => $user->display_name,
			'avatar'       => get_avatar_url( $user->ID, array( 'size' => 192 ) ),
			'roles'        => array_values( $user->roles ),
			'billing'      => (object) array(),
			'shipping'     => (object) array(),
		);
		if ( class_exists( 'WC_Customer' ) ) {
			$customer         = new \WC_Customer( $user->ID );
			$data['billing']  = $customer->get_billing();
			$data['shipping'] = $customer->get_shipping();
		}
		return $data;
	}

	private static function token_response( $user_id ) {
		return rest_ensure_response(
			array(
				'token' => Jwt::encode( $user_id ),
				'user'  => self::user_payload( $user_id ),
			)
		);
	}

	public static function login( WP_REST_Request $request ) {
		$username = sanitize_text_field( (string) $request->get_param( 'username' ) );
		$password = (string) $request->get_param( 'password' );
		if ( '' === $username || '' === $password ) {
			return new WP_Error( 'appforge_missing', __( 'Username and password are required.', 'appforge' ), array( 'status' => 400 ) );
		}
		if ( is_email( $username ) ) {
			$by_email = get_user_by( 'email', $username );
			if ( $by_email ) {
				$username = $by_email->user_login;
			}
		}
		$user = wp_authenticate( $username, $password );
		if ( is_wp_error( $user ) ) {
			return new WP_Error( 'appforge_login_failed', __( 'Incorrect username or password.', 'appforge' ), array( 'status' => 403 ) );
		}
		do_action( 'appforge_user_login', $user->ID );
		return self::token_response( $user->ID );
	}

	public static function register( WP_REST_Request $request ) {
		if ( ! Settings::value( 'enable_register', true ) ) {
			return new WP_Error( 'appforge_register_disabled', __( 'Registration is disabled.', 'appforge' ), array( 'status' => 403 ) );
		}
		$email    = sanitize_email( (string) $request->get_param( 'email' ) );
		$password = (string) $request->get_param( 'password' );
		$username = sanitize_user( (string) $request->get_param( 'username' ), true );
		$first    = sanitize_text_field( (string) $request->get_param( 'first_name' ) );
		$last     = sanitize_text_field( (string) $request->get_param( 'last_name' ) );

		if ( ! is_email( $email ) ) {
			return new WP_Error( 'appforge_email', __( 'Please enter a valid email.', 'appforge' ), array( 'status' => 400 ) );
		}
		if ( strlen( $password ) < 6 ) {
			return new WP_Error( 'appforge_password', __( 'Password must be at least 6 characters.', 'appforge' ), array( 'status' => 400 ) );
		}
		if ( email_exists( $email ) ) {
			return new WP_Error( 'appforge_email_exists', __( 'An account with this email already exists.', 'appforge' ), array( 'status' => 400 ) );
		}
		if ( $username && username_exists( $username ) ) {
			return new WP_Error( 'appforge_username_exists', __( 'This username is taken.', 'appforge' ), array( 'status' => 400 ) );
		}

		$extra = array( 'first_name' => $first, 'last_name' => $last );
		if ( function_exists( 'wc_create_new_customer' ) ) {
			$user_id = wc_create_new_customer( $email, $username, $password, $extra );
		} else {
			$user_id = wp_insert_user(
				array_merge(
					$extra,
					array(
						'user_login' => $username ? $username : sanitize_user( current( explode( '@', $email ) ) . wp_rand( 100, 999 ), true ),
						'user_email' => $email,
						'user_pass'  => $password,
					)
				)
			);
		}
		if ( is_wp_error( $user_id ) ) {
			return new WP_Error( 'appforge_register_failed', $user_id->get_error_message(), array( 'status' => 400 ) );
		}
		do_action( 'appforge_user_register', $user_id );
		return self::token_response( $user_id );
	}

	public static function forgot( WP_REST_Request $request ) {
		$login = sanitize_text_field( (string) $request->get_param( 'login' ) );
		if ( '' === $login ) {
			return new WP_Error( 'appforge_missing', __( 'Enter your email or username.', 'appforge' ), array( 'status' => 400 ) );
		}
		$result = retrieve_password( $login );
		// Do not reveal whether the account exists.
		if ( is_wp_error( $result ) && 'invalid_email' !== $result->get_error_code() && 'invalidcombo' !== $result->get_error_code() ) {
			return new WP_Error( 'appforge_forgot_failed', $result->get_error_message(), array( 'status' => 500 ) );
		}
		return rest_ensure_response( array( 'success' => true, 'message' => __( 'If the account exists, a reset link has been emailed.', 'appforge' ) ) );
	}

	public static function me( WP_REST_Request $request ) {
		return rest_ensure_response( self::user_payload( get_current_user_id() ) );
	}

	public static function update_me( WP_REST_Request $request ) {
		$uid  = get_current_user_id();
		$args = array( 'ID' => $uid );
		foreach ( array( 'first_name', 'last_name', 'display_name' ) as $f ) {
			if ( null !== $request->get_param( $f ) ) {
				$args[ $f ] = sanitize_text_field( $request->get_param( $f ) );
			}
		}
		$result = wp_update_user( $args );
		if ( is_wp_error( $result ) ) {
			return $result;
		}
		if ( class_exists( 'WC_Customer' ) ) {
			$customer = new \WC_Customer( $uid );
			foreach ( array( 'billing', 'shipping' ) as $type ) {
				$address = $request->get_param( $type );
				if ( is_array( $address ) ) {
					foreach ( $address as $k => $v ) {
						$setter = "set_{$type}_" . sanitize_key( $k );
						if ( is_callable( array( $customer, $setter ) ) ) {
							$customer->{$setter}( sanitize_text_field( $v ) );
						}
					}
				}
			}
			$customer->save();
		}
		return rest_ensure_response( self::user_payload( $uid ) );
	}

	public static function change_password( WP_REST_Request $request ) {
		$uid  = get_current_user_id();
		$user = get_userdata( $uid );
		$old  = (string) $request->get_param( 'old_password' );
		$new  = (string) $request->get_param( 'new_password' );
		if ( ! wp_check_password( $old, $user->user_pass, $uid ) ) {
			return new WP_Error( 'appforge_wrong_password', __( 'Current password is incorrect.', 'appforge' ), array( 'status' => 400 ) );
		}
		if ( strlen( $new ) < 6 ) {
			return new WP_Error( 'appforge_password', __( 'Password must be at least 6 characters.', 'appforge' ), array( 'status' => 400 ) );
		}
		wp_set_password( $new, $uid );
		return self::token_response( $uid );
	}

	/**
	 * Account deletion (required by Apple / Google store policies).
	 */
	public static function delete_me( WP_REST_Request $request ) {
		$uid  = get_current_user_id();
		$user = get_userdata( $uid );
		if ( ! wp_check_password( (string) $request->get_param( 'password' ), $user->user_pass, $uid ) ) {
			return new WP_Error( 'appforge_wrong_password', __( 'Password is incorrect.', 'appforge' ), array( 'status' => 400 ) );
		}
		if ( user_can( $uid, 'manage_options' ) ) {
			return new WP_Error( 'appforge_admin', __( 'Administrators cannot delete their account from the app.', 'appforge' ), array( 'status' => 403 ) );
		}
		require_once ABSPATH . 'wp-admin/includes/user.php';
		wp_delete_user( $uid );
		return rest_ensure_response( array( 'deleted' => true ) );
	}
}
