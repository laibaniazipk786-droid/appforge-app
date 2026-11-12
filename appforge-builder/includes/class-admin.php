<?php
namespace AppForge;

defined( 'ABSPATH' ) || exit;

/**
 * Admin screen hosting the drag & drop builder.
 */
class Admin {

	const SLUG = 'appforge';

	public static function init() {
		add_action( 'admin_menu', array( __CLASS__, 'menu' ) );
		add_action( 'admin_enqueue_scripts', array( __CLASS__, 'assets' ) );
		add_filter( 'plugin_action_links_' . plugin_basename( APPFORGE_FILE ), array( __CLASS__, 'links' ) );
	}

	public static function menu() {
		add_menu_page(
			__( 'AppForge Builder', 'appforge' ),
			__( 'AppForge', 'appforge' ),
			'manage_options',
			self::SLUG,
			array( __CLASS__, 'render' ),
			'dashicons-smartphone',
			58
		);
	}

	public static function links( $links ) {
		array_unshift( $links, '<a href="' . esc_url( admin_url( 'admin.php?page=' . self::SLUG ) ) . '">' . esc_html__( 'Open builder', 'appforge' ) . '</a>' );
		return $links;
	}

	private static function category_options() {
		$out = array( array( 'id' => 0, 'name' => __( '— Top level / none —', 'appforge' ) ) );
		if ( ! taxonomy_exists( 'product_cat' ) ) {
			return $out;
		}
		$terms = get_terms( array( 'taxonomy' => 'product_cat', 'hide_empty' => false ) );
		if ( ! is_wp_error( $terms ) ) {
			foreach ( $terms as $t ) {
				$out[] = array( 'id' => $t->term_id, 'name' => html_entity_decode( $t->name, ENT_QUOTES, 'UTF-8' ) );
			}
		}
		return $out;
	}

	public static function assets( $hook ) {
		if ( 'toplevel_page_' . self::SLUG !== $hook ) {
			return;
		}
		Settings::ensure_defaults();
		wp_enqueue_media();
		wp_enqueue_style( 'appforge-material-icons', 'https://fonts.googleapis.com/icon?family=Material+Icons', array(), null ); // phpcs:ignore
		wp_enqueue_style( 'appforge-builder', APPFORGE_URL . 'admin/css/builder.css', array(), APPFORGE_VERSION );
		wp_enqueue_script(
			'appforge-builder',
			APPFORGE_URL . 'admin/js/builder.js',
			array( 'jquery', 'jquery-ui-sortable', 'jquery-ui-draggable', 'wp-color-picker' ),
			APPFORGE_VERSION,
			true
		);
		wp_enqueue_style( 'wp-color-picker' );

		wp_localize_script(
			'appforge-builder',
			'AppForgeData',
			array(
				'restUrl'      => esc_url_raw( rest_url( APPFORGE_NS ) ),
				'nonce'        => wp_create_nonce( 'wp_rest' ),
				'siteUrl'      => home_url( '/' ),
				'woo'          => Woo::active(),
				'currency'     => Woo::currency(),
				'blocks'       => Blocks::registry(),
				'commonFields' => Blocks::common_fields(),
				'actionTypes'  => Blocks::action_types(),
				'routes'       => Blocks::routes(),
				'categories'   => self::category_options(),
				'design'       => Designs::full( Designs::active() ),
				'designs'      => array_values( array_map( array( Designs::class, 'summary' ), Designs::all() ) ),
				'store'        => Settings::store(),
				'defaults'     => Settings::design_defaults(),
				'schemes'      => self::color_schemes(),
				'keys'         => Settings::keys(),
				'icons'        => Blocks::icons(),
				'pages'        => Content::page_options(),
			)
		);
	}

	/**
	 * One-click color schemes for the Theme tab.
	 */
	public static function color_schemes() {
		$s = array(
			'indigo'   => array( 'Indigo', '#4F46E5', '#F59E0B', '#F8FAFC', '#FFFFFF', '#0F172A' ),
			'rose'     => array( 'Rose beauty', '#E11D48', '#F9A8D4', '#FFF1F2', '#FFFFFF', '#3F0A1D' ),
			'midnight' => array( 'Midnight tech', '#2563EB', '#22D3EE', '#F1F5F9', '#FFFFFF', '#0B1220' ),
			'emerald'  => array( 'Fresh green', '#16A34A', '#F97316', '#F0FDF4', '#FFFFFF', '#052E16' ),
			'sand'     => array( 'Warm sand', '#A16207', '#0F766E', '#FAF7F2', '#FFFFFF', '#292524' ),
			'noir'     => array( 'Noir fashion', '#111111', '#C8A96A', '#FAFAFA', '#FFFFFF', '#111111' ),
			'gold'     => array( 'Royal gold', '#B8860B', '#7C2D12', '#FFFBEB', '#FFFFFF', '#1C1917' ),
			'purple'   => array( 'Purple pop', '#7C3AED', '#EC4899', '#FAF5FF', '#FFFFFF', '#1E1B4B' ),
			'ocean'    => array( 'Ocean', '#0891B2', '#FB7185', '#ECFEFF', '#FFFFFF', '#083344' ),
			'pakgreen' => array( 'Pak green', '#01411C', '#E9C46A', '#F6FBF7', '#FFFFFF', '#0B2414' ),
		);
		$out = array();
		foreach ( $s as $key => $c ) {
			$out[ $key ] = array(
				'label'              => $c[0],
				'primary_color'      => $c[1],
				'secondary_color'    => $c[2],
				'background_color'   => $c[3],
				'surface_color'      => $c[4],
				'text_color'         => $c[5],
				'on_primary_color'   => '#FFFFFF',
				'nav_active_color'   => '',
				'price_color'        => '',
				'sale_color'         => '',
			);
		}
		return apply_filters( 'appforge_color_schemes', $out );
	}

	public static function render() {
		?>
		<div class="wrap af-wrap">
			<div id="appforge-app" class="af-app">
				<div class="af-loading"><?php esc_html_e( 'Loading builder…', 'appforge' ); ?></div>
			</div>
		</div>
		<?php
	}
}
