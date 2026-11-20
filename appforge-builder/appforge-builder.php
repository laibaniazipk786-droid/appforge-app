<?php
/**
 * Plugin Name:       AppForge Builder
 * Description:       Drag & drop mobile app builder for WordPress & WooCommerce. Design your app here, the AppForge Flutter app renders it.
 * Version:           1.3.0
 * Requires at least: 5.8
 * Requires PHP:      7.4
 * Author:            AppForge
 * License:           GPL-2.0-or-later
 * Text Domain:       appforge
 */

defined( 'ABSPATH' ) || exit;

define( 'APPFORGE_VERSION', '1.3.0' );
define( 'APPFORGE_FILE', __FILE__ );
define( 'APPFORGE_DIR', plugin_dir_path( __FILE__ ) );
define( 'APPFORGE_URL', plugin_dir_url( __FILE__ ) );
define( 'APPFORGE_NS', 'appforge/v1' );

require_once APPFORGE_DIR . 'includes/class-settings.php';
require_once APPFORGE_DIR . 'includes/class-blocks.php';
require_once APPFORGE_DIR . 'includes/class-designs.php';
require_once APPFORGE_DIR . 'includes/class-templates.php';
require_once APPFORGE_DIR . 'includes/class-content.php';
require_once APPFORGE_DIR . 'includes/class-taxonomy.php';
require_once APPFORGE_DIR . 'includes/class-i18n.php';
require_once APPFORGE_DIR . 'includes/class-wishlist.php';
require_once APPFORGE_DIR . 'includes/class-jwt.php';
require_once APPFORGE_DIR . 'includes/class-auth.php';
require_once APPFORGE_DIR . 'includes/class-woo.php';
require_once APPFORGE_DIR . 'includes/class-cart.php';
require_once APPFORGE_DIR . 'includes/class-rest.php';
require_once APPFORGE_DIR . 'includes/class-admin.php';
require_once APPFORGE_DIR . 'includes/class-plugin.php';

register_activation_hook( __FILE__, array( 'AppForge\\Plugin', 'activate' ) );
add_action( 'plugins_loaded', array( 'AppForge\\Plugin', 'instance' ) );
