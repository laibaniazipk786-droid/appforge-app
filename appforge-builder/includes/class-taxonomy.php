<?php
namespace AppForge;

defined( 'ABSPATH' ) || exit;

/**
 * Extra fields on WooCommerce terms:
 *  - Product categories: app icon + icon color (used in the sidebar and category blocks).
 *  - Attribute terms (pa_color, pa_size …): swatch color + swatch image for the product page.
 */
class Taxonomy {

	public static function init() {
		add_action( 'product_cat_add_form_fields', array( __CLASS__, 'cat_add_fields' ) );
		add_action( 'product_cat_edit_form_fields', array( __CLASS__, 'cat_edit_fields' ) );
		add_action( 'created_product_cat', array( __CLASS__, 'save_cat' ) );
		add_action( 'edited_product_cat', array( __CLASS__, 'save_cat' ) );
		add_action( 'admin_init', array( __CLASS__, 'attribute_hooks' ) );
		add_action( 'admin_enqueue_scripts', array( __CLASS__, 'assets' ) );
	}

	public static function assets( $hook ) {
		if ( 'edit-tags.php' !== $hook && 'term.php' !== $hook ) {
			return;
		}
		wp_enqueue_media();
		wp_add_inline_script(
			'jquery-core',
			"jQuery(function($){\$(document).on('click','.af-term-media',function(e){e.preventDefault();var t=\$(this),f=wp.media({title:'Swatch image',multiple:false,library:{type:'image'}});f.on('select',function(){var a=f.state().get('selection').first().toJSON();t.siblings('input').val(a.url);t.siblings('img').attr('src',a.url).show();});f.open();});});"
		);
	}

	/* ---------- Categories ---------- */

	private static function icon_select( $value ) {
		$html = '<select name="appforge_icon" id="appforge_icon"><option value="">— ' . esc_html__( 'none (use category image)', 'appforge' ) . ' —</option>';
		foreach ( Blocks::icons() as $icon ) {
			$html .= '<option value="' . esc_attr( $icon ) . '"' . selected( $value, $icon, false ) . '>' . esc_html( $icon ) . '</option>';
		}
		return $html . '</select>';
	}

	public static function cat_add_fields() {
		?>
		<div class="form-field">
			<label for="appforge_icon"><?php esc_html_e( 'App icon (AppForge)', 'appforge' ); ?></label>
			<?php echo self::icon_select( '' ); // phpcs:ignore ?>
			<p><?php esc_html_e( 'Shown in the app sidebar and in category blocks set to "App icon".', 'appforge' ); ?></p>
		</div>
		<div class="form-field">
			<label for="appforge_icon_color"><?php esc_html_e( 'App icon color', 'appforge' ); ?></label>
			<input type="color" name="appforge_icon_color" id="appforge_icon_color" value="#4F46E5">
		</div>
		<?php
	}

	public static function cat_edit_fields( $term ) {
		$icon  = get_term_meta( $term->term_id, 'appforge_icon', true );
		$color = get_term_meta( $term->term_id, 'appforge_icon_color', true );
		?>
		<tr class="form-field">
			<th scope="row"><label for="appforge_icon"><?php esc_html_e( 'App icon (AppForge)', 'appforge' ); ?></label></th>
			<td><?php echo self::icon_select( $icon ); // phpcs:ignore ?>
				<p class="description"><?php esc_html_e( 'Shown in the app sidebar and in category blocks set to "App icon".', 'appforge' ); ?></p></td>
		</tr>
		<tr class="form-field">
			<th scope="row"><label for="appforge_icon_color"><?php esc_html_e( 'App icon color', 'appforge' ); ?></label></th>
			<td><input type="color" name="appforge_icon_color" id="appforge_icon_color" value="<?php echo esc_attr( $color ? $color : '#4F46E5' ); ?>"></td>
		</tr>
		<?php
	}

	public static function save_cat( $term_id ) {
		if ( ! current_user_can( 'manage_product_terms' ) && ! current_user_can( 'manage_options' ) ) {
			return;
		}
		// phpcs:disable WordPress.Security.NonceVerification -- core term screens verify their own nonce.
		if ( isset( $_POST['appforge_icon'] ) ) {
			$icon = sanitize_key( wp_unslash( $_POST['appforge_icon'] ) );
			update_term_meta( $term_id, 'appforge_icon', in_array( $icon, Blocks::icons(), true ) ? $icon : '' );
		}
		if ( isset( $_POST['appforge_icon_color'] ) ) {
			$color = sanitize_hex_color( wp_unslash( $_POST['appforge_icon_color'] ) );
			update_term_meta( $term_id, 'appforge_icon_color', $color ? $color : '' );
		}
		// phpcs:enable
	}

	/* ---------- Attribute swatches ---------- */

	public static function attribute_hooks() {
		if ( ! function_exists( 'wc_get_attribute_taxonomy_names' ) ) {
			return;
		}
		foreach ( wc_get_attribute_taxonomy_names() as $tax ) {
			add_action( $tax . '_add_form_fields', array( __CLASS__, 'swatch_add_fields' ) );
			add_action( $tax . '_edit_form_fields', array( __CLASS__, 'swatch_edit_fields' ) );
			add_action( 'created_' . $tax, array( __CLASS__, 'save_swatch' ) );
			add_action( 'edited_' . $tax, array( __CLASS__, 'save_swatch' ) );
		}
	}

	public static function swatch_add_fields() {
		?>
		<div class="form-field">
			<label><?php esc_html_e( 'App swatch color (AppForge)', 'appforge' ); ?></label>
			<input type="text" name="appforge_swatch_color" placeholder="#000000">
			<p><?php esc_html_e( 'Optional. Shows a color circle instead of text on the app product page.', 'appforge' ); ?></p>
		</div>
		<div class="form-field">
			<label><?php esc_html_e( 'App swatch image', 'appforge' ); ?></label>
			<img src="" style="display:none;max-width:60px;border-radius:6px"><input type="hidden" name="appforge_swatch_image">
			<button class="button af-term-media"><?php esc_html_e( 'Choose image', 'appforge' ); ?></button>
		</div>
		<?php
	}

	public static function swatch_edit_fields( $term ) {
		$color = get_term_meta( $term->term_id, 'appforge_swatch_color', true );
		$image = get_term_meta( $term->term_id, 'appforge_swatch_image', true );
		?>
		<tr class="form-field">
			<th scope="row"><label><?php esc_html_e( 'App swatch color (AppForge)', 'appforge' ); ?></label></th>
			<td><input type="text" name="appforge_swatch_color" value="<?php echo esc_attr( $color ); ?>" placeholder="#000000">
				<p class="description"><?php esc_html_e( 'Optional. Shows a color circle instead of text on the app product page.', 'appforge' ); ?></p></td>
		</tr>
		<tr class="form-field">
			<th scope="row"><label><?php esc_html_e( 'App swatch image', 'appforge' ); ?></label></th>
			<td><img src="<?php echo esc_url( $image ); ?>" style="<?php echo $image ? '' : 'display:none;'; ?>max-width:60px;border-radius:6px">
				<input type="hidden" name="appforge_swatch_image" value="<?php echo esc_attr( $image ); ?>">
				<button class="button af-term-media"><?php esc_html_e( 'Choose image', 'appforge' ); ?></button></td>
		</tr>
		<?php
	}

	public static function save_swatch( $term_id ) {
		if ( ! current_user_can( 'manage_product_terms' ) && ! current_user_can( 'manage_options' ) ) {
			return;
		}
		// phpcs:disable WordPress.Security.NonceVerification
		if ( isset( $_POST['appforge_swatch_color'] ) ) {
			$c = sanitize_hex_color( trim( wp_unslash( $_POST['appforge_swatch_color'] ) ) );
			update_term_meta( $term_id, 'appforge_swatch_color', $c ? $c : '' );
		}
		if ( isset( $_POST['appforge_swatch_image'] ) ) {
			update_term_meta( $term_id, 'appforge_swatch_image', esc_url_raw( wp_unslash( $_POST['appforge_swatch_image'] ) ) );
		}
		// phpcs:enable
	}

	/**
	 * Common color names → hex, used when a color attribute has no swatch set.
	 */
	public static function guess_color( $name ) {
		$map = array(
			'black' => '#111111', 'white' => '#FFFFFF', 'red' => '#DC2626', 'maroon' => '#7F1D1D', 'pink' => '#EC4899',
			'rose' => '#F43F5E', 'orange' => '#F97316', 'yellow' => '#FACC15', 'gold' => '#D4AF37', 'green' => '#16A34A',
			'olive' => '#6B8E23', 'mint' => '#98FF98', 'teal' => '#0D9488', 'blue' => '#2563EB', 'navy' => '#1E3A8A',
			'sky' => '#38BDF8', 'purple' => '#7C3AED', 'violet' => '#8B5CF6', 'lavender' => '#C4B5FD', 'brown' => '#7C4A1E',
			'beige' => '#E8DCC4', 'cream' => '#FFFDD0', 'grey' => '#9CA3AF', 'gray' => '#9CA3AF', 'silver' => '#C0C0C0',
			'khaki' => '#C3B091', 'peach' => '#FFCBA4', 'mustard' => '#E1AD01', 'skin' => '#E8B796', 'nude' => '#E3BC9A',
		);
		$key = strtolower( trim( $name ) );
		if ( isset( $map[ $key ] ) ) {
			return $map[ $key ];
		}
		foreach ( $map as $k => $hex ) {
			if ( false !== strpos( $key, $k ) ) {
				return $hex;
			}
		}
		return '';
	}
}
