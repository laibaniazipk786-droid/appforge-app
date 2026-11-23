<?php
/**
 * Seeds a fresh WordPress + WooCommerce install with test data.
 * Run with: wp eval-file tests/setup.php
 */

update_option( 'woocommerce_currency', 'PKR' );
update_option( 'woocommerce_default_country', 'PK:PB' );
update_option( 'woocommerce_calc_taxes', 'no' );
update_option( 'woocommerce_enable_guest_checkout', 'yes' );
update_option( 'woocommerce_enable_reviews', 'yes' );
update_option( 'woocommerce_review_rating_verification_required', 'no' );
update_option( 'comment_moderation', '0' );
update_option( 'comment_previously_approved', '0' );
update_option( 'woocommerce_cod_settings', array( 'enabled' => 'yes', 'title' => 'Cash on delivery' ) );
update_option( 'woocommerce_bacs_settings', array( 'enabled' => 'yes', 'title' => 'Bank transfer' ) );

// Shipping: one zone for Pakistan with a flat rate.
$zone = new WC_Shipping_Zone();
$zone->set_zone_name( 'Pakistan' );
$zone->add_location( 'PK', 'country' );
$zone->save();
$iid = $zone->add_shipping_method( 'flat_rate' );
update_option( 'woocommerce_flat_rate_' . $iid . '_settings', array( 'enabled' => 'yes', 'title' => 'Flat rate', 'cost' => '200', 'tax_status' => 'none' ) );

// Categories.
$cat = wp_insert_term( 'Printers', 'product_cat' );
$cat2 = wp_insert_term( 'Cameras', 'product_cat' );
$cat_id  = $cat['term_id'];
$cat2_id = $cat2['term_id'];
update_term_meta( $cat_id, 'appforge_icon', 'print' );

// Global attribute with swatch colors.
wc_create_attribute( array( 'name' => 'Color', 'slug' => 'color', 'type' => 'select' ) );
register_taxonomy( 'pa_color', array( 'product' ), array( 'hierarchical' => false ) );
$red  = wp_insert_term( 'Red', 'pa_color' );
$blue = wp_insert_term( 'Blue', 'pa_color' );
update_term_meta( $red['term_id'], 'appforge_swatch_color', '#ff0000' );
update_term_meta( $blue['term_id'], 'appforge_swatch_color', '#0000ff' );

$ids = array();

$p = new WC_Product_Simple();
$p->set_name( 'Epson L3250 Printer' );
$p->set_regular_price( '50000' );
$p->set_sale_price( '45000' );
$p->set_category_ids( array( $cat_id ) );
$p->set_manage_stock( true );
$p->set_stock_quantity( 10 );
$p->set_sku( 'EPS-L3250' );
$ids['sale'] = $p->save();

$p = new WC_Product_Simple();
$p->set_name( 'Canon Pixma Printer' );
$p->set_regular_price( '30000' );
$p->set_category_ids( array( $cat_id ) );
$ids['simple'] = $p->save();

$p = new WC_Product_Simple();
$p->set_name( 'Old Camera (sold out)' );
$p->set_regular_price( '9000' );
$p->set_category_ids( array( $cat2_id ) );
$p->set_stock_status( 'outofstock' );
$ids['oos'] = $p->save();

// Variable product with color variations.
$attr = new WC_Product_Attribute();
$attr->set_id( wc_attribute_taxonomy_id_by_name( 'pa_color' ) );
$attr->set_name( 'pa_color' );
$attr->set_options( array( $red['term_id'], $blue['term_id'] ) );
$attr->set_visible( true );
$attr->set_variation( true );

$v = new WC_Product_Variable();
$v->set_name( 'Action Camera' );
$v->set_category_ids( array( $cat2_id ) );
$v->set_attributes( array( $attr ) );
$vid = $v->save();
wp_set_object_terms( $vid, array( 'red', 'blue' ), 'pa_color' );
$var_ids = array();
foreach ( array( 'red' => '15000', 'blue' => '16000' ) as $slug => $price ) {
	$var = new WC_Product_Variation();
	$var->set_parent_id( $vid );
	$var->set_attributes( array( 'pa_color' => $slug ) );
	$var->set_regular_price( $price );
	$var_ids[ $slug ] = $var->save();
}
WC_Product_Variable::sync( $vid );
$ids['variable']   = $vid;
$ids['var_red']    = $var_ids['red'];
$ids['var_blue']   = $var_ids['blue'];

// Coupon.
$c = new WC_Coupon();
$c->set_code( 'WELCOME10' );
$c->set_discount_type( 'percent' );
$c->set_amount( 10 );
$c->save();

// A page for the "Open page" action.
$ids['page'] = wp_insert_post( array( 'post_type' => 'page', 'post_status' => 'publish', 'post_title' => 'About us', 'post_content' => '<p>We sell printers.</p>' ) );
$ids['post'] = wp_insert_post( array( 'post_type' => 'post', 'post_status' => 'publish', 'post_title' => 'Hello app', 'post_content' => '<p>First post.</p>' ) );

$ids['category']  = $cat_id;
$ids['category2'] = $cat2_id;

$keys = \AppForge\Settings::keys();
$ids['api_key']    = $keys['key'];
$ids['api_secret'] = $keys['secret'];

file_put_contents( getenv( 'FIXTURES' ) ?: '/tmp/fixtures.json', wp_json_encode( $ids ) );
echo "Seeded: " . wp_json_encode( $ids ) . "\n";
