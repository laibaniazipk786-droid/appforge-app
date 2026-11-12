<?php
namespace AppForge;

defined( 'ABSPATH' ) || exit;

/**
 * A WooCommerce session that lives only for the current request.
 * Used by the app cart so it never overwrites the customer's website cart/session.
 */
class Memory_Session extends \WC_Session_Handler {

	public function init() {
		$this->_customer_id = get_current_user_id() ? (string) get_current_user_id() : 't_' . wp_generate_password( 24, false, false );
		$this->_data        = array();
		$this->_dirty       = false;
	}

	public function init_session_cookie() {}

	public function set_customer_session_cookie( $set ) {}

	public function has_session() {
		return true;
	}

	public function save_data( $old_session_key = 0 ) {}

	public function destroy_session() {
		$this->_data = array();
	}

	public function forget_session() {
		$this->_data = array();
	}

	public function get_session( $customer_id, $default = false ) {
		return $default;
	}

	public function delete_session( $customer_id ) {}

	public function update_session_timestamp( $customer_id, $timestamp ) {}
}
