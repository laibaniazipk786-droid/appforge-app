<?php
namespace AppForge;

use WP_Error;
use WP_Query;
use WP_REST_Request;

defined( 'ABSPATH' ) || exit;

/**
 * Catalog endpoints: products, categories, reviews, posts.
 */
class Woo {

	public static function active() {
		return class_exists( 'WooCommerce' );
	}

	public static function currency() {
		if ( ! self::active() ) {
			return null;
		}
		return array(
			'code'               => get_woocommerce_currency(),
			'symbol'             => html_entity_decode( get_woocommerce_currency_symbol(), ENT_QUOTES, 'UTF-8' ),
			'position'           => get_option( 'woocommerce_currency_pos', 'left' ),
			'decimals'           => wc_get_price_decimals(),
			'decimal_separator'  => wc_get_price_decimal_separator(),
			'thousand_separator' => wc_get_price_thousand_separator(),
		);
	}

	private static function image_url( $id, $size = 'woocommerce_single' ) {
		$url = $id ? wp_get_attachment_image_url( $id, $size ) : '';
		return $url ? $url : ( function_exists( 'wc_placeholder_img_src' ) ? wc_placeholder_img_src( $size ) : '' );
	}

	/**
	 * Formats a product for the app.
	 *
	 * @param \WC_Product $p    Product.
	 * @param bool        $full Include description, gallery, attributes, variations.
	 */
	public static function format_product( $p, $full = false ) {
		$price   = (float) wc_get_price_to_display( $p );
		$regular = $p->get_regular_price() !== '' ? (float) wc_get_price_to_display( $p, array( 'price' => $p->get_regular_price() ) ) : $price;
		$max     = $price;

		if ( $p->is_type( 'variable' ) ) {
			$price   = (float) $p->get_variation_price( 'min', true );
			$max     = (float) $p->get_variation_price( 'max', true );
			$regular = (float) $p->get_variation_regular_price( 'min', true );
		}

		$data = array(
			'id'            => $p->get_id(),
			'name'          => html_entity_decode( $p->get_name(), ENT_QUOTES, 'UTF-8' ),
			'type'          => $p->get_type(),
			'price'         => $price,
			'max_price'     => $max,
			'regular_price' => $regular,
			'on_sale'       => $p->is_on_sale(),
			'image'         => self::image_url( $p->get_image_id(), 'woocommerce_thumbnail' ),
			'rating'        => (float) $p->get_average_rating(),
			'rating_count'  => (int) $p->get_rating_count(),
			'in_stock'      => $p->is_in_stock(),
			'purchasable'   => $p->is_purchasable(),
			'permalink'     => get_permalink( $p->get_id() ),
		);

		if ( ! $full ) {
			return $data;
		}

		$images = array( self::image_url( $p->get_image_id() ) );
		foreach ( $p->get_gallery_image_ids() as $img_id ) {
			$images[] = self::image_url( $img_id );
		}

		$attributes = array();
		foreach ( $p->get_attributes() as $key => $attr ) {
			/** @var \WC_Product_Attribute $attr */
			if ( ! $attr->get_visible() && ! $attr->get_variation() ) {
				continue;
			}
			$options  = array();
			$is_color = (bool) preg_match( '/colou?r|rang/i', $attr->get_name() . ' ' . wc_attribute_label( $attr->get_name(), $p ) );
			if ( $attr->is_taxonomy() ) {
				foreach ( $attr->get_terms() as $term ) {
					$color = (string) get_term_meta( $term->term_id, 'appforge_swatch_color', true );
					if ( '' === $color && $is_color ) {
						$color = Taxonomy::guess_color( $term->name );
					}
					$options[] = array(
						'value' => $term->slug,
						'label' => html_entity_decode( $term->name, ENT_QUOTES, 'UTF-8' ),
						'color' => $color,
						'image' => (string) get_term_meta( $term->term_id, 'appforge_swatch_image', true ),
					);
				}
			} else {
				foreach ( $attr->get_options() as $opt ) {
					$options[] = array(
						'value' => $opt,
						'label' => $opt,
						'color' => $is_color ? Taxonomy::guess_color( $opt ) : '',
						'image' => '',
					);
				}
			}
			$attributes[] = array(
				'key'       => 'attribute_' . sanitize_title( $key ),
				'name'      => wc_attribute_label( $attr->get_name(), $p ),
				'variation' => (bool) $attr->get_variation(),
				'options'   => $options,
			);
		}

		$variations = array();
		if ( $p->is_type( 'variable' ) ) {
			foreach ( $p->get_available_variations( 'objects' ) as $v ) {
				/** @var \WC_Product_Variation $v */
				$attrs = array();
				foreach ( $v->get_variation_attributes() as $k => $val ) {
					$attrs[ $k ] = $val; // '' means "any".
				}
				$variations[] = array(
					'id'            => $v->get_id(),
					'attributes'    => (object) $attrs,
					'price'         => (float) wc_get_price_to_display( $v ),
					'regular_price' => (float) wc_get_price_to_display( $v, array( 'price' => $v->get_regular_price() ) ),
					'on_sale'       => $v->is_on_sale(),
					'in_stock'      => $v->is_in_stock(),
					'image'         => $v->get_image_id() ? self::image_url( $v->get_image_id() ) : '',
					'max_qty'       => $v->get_max_purchase_quantity(),
					'sku'           => $v->get_sku(),
					'stock_quantity'=> $v->get_stock_quantity(),
					'description'   => wp_strip_all_tags( $v->get_description() ),
				);
			}
		}

		$cats = array();
		foreach ( wc_get_product_terms( $p->get_id(), 'product_cat' ) as $term ) {
			$cats[] = array( 'id' => $term->term_id, 'name' => html_entity_decode( $term->name, ENT_QUOTES, 'UTF-8' ) );
		}

		return array_merge(
			$data,
			array(
				'images'            => array_values( array_unique( array_filter( $images ) ) ),
				'description'       => wpautop( do_shortcode( $p->get_description() ) ),
				'short_description' => wpautop( do_shortcode( $p->get_short_description() ) ),
				'sku'               => $p->get_sku(),
				'stock_quantity'    => $p->get_stock_quantity(),
				'max_qty'           => $p->get_max_purchase_quantity(),
				'attributes'        => $attributes,
				'variations'        => $variations,
				'categories'        => $cats,
				'related_ids'       => array_map( 'intval', wc_get_related_products( $p->get_id(), 8 ) ),
				'reviews_allowed'   => $p->get_reviews_allowed(),
			)
		);
	}

	/**
	 * GET /products
	 * Params: page, per_page, category, search, source (latest|featured|on_sale|best_selling|top_rated),
	 * orderby (date|price|price-desc|popularity|rating), include (comma ids), min_price, max_price.
	 */
	public static function products( WP_REST_Request $request ) {
		if ( ! self::active() ) {
			return new WP_Error( 'appforge_no_woo', 'WooCommerce is not active.', array( 'status' => 400 ) );
		}
		$page     = max( 1, (int) $request->get_param( 'page' ) );
		$per_page = min( 50, max( 1, (int) ( $request->get_param( 'per_page' ) ? $request->get_param( 'per_page' ) : 10 ) ) );
		$source   = sanitize_key( (string) $request->get_param( 'source' ) );
		$orderby  = sanitize_text_field( (string) $request->get_param( 'orderby' ) );

		$args = array(
			'post_type'      => 'product',
			'post_status'    => 'publish',
			'posts_per_page' => $per_page,
			'paged'          => $page,
			'tax_query'      => array( 'relation' => 'AND' ), // phpcs:ignore
			'meta_query'     => array(), // phpcs:ignore
		);

		// Respect catalog visibility.
		$exclude_terms = array( 'exclude-from-catalog' );
		if ( 'yes' === get_option( 'woocommerce_hide_out_of_stock_items' ) || Settings::value( 'hide_out_of_stock' ) ) {
			$exclude_terms[] = 'outofstock';
		}
		$args['tax_query'][] = array(
			'taxonomy' => 'product_visibility',
			'field'    => 'slug',
			'terms'    => $exclude_terms,
			'operator' => 'NOT IN',
		);

		$category = (int) $request->get_param( 'category' );
		if ( $category ) {
			$args['tax_query'][] = array(
				'taxonomy'         => 'product_cat',
				'field'            => 'term_id',
				'terms'            => array( $category ),
				'include_children' => true,
			);
		}

		$search = sanitize_text_field( (string) $request->get_param( 'search' ) );
		if ( '' !== $search ) {
			$args['s'] = $search;
		}

		$include = $request->get_param( 'include' );
		if ( $include ) {
			$ids                    = array_filter( array_map( 'intval', is_array( $include ) ? $include : explode( ',', $include ) ) );
			$args['post__in']       = $ids ? $ids : array( 0 );
			$args['orderby']        = 'post__in';
			$args['posts_per_page'] = count( $args['post__in'] );
		}

		switch ( $source ) {
			case 'featured':
				$args['tax_query'][] = array(
					'taxonomy' => 'product_visibility',
					'field'    => 'slug',
					'terms'    => array( 'featured' ),
				);
				break;
			case 'on_sale':
				$sale             = wc_get_product_ids_on_sale();
				$args['post__in'] = $sale ? $sale : array( 0 );
				break;
			case 'best_selling':
				$orderby = 'popularity';
				break;
			case 'top_rated':
				$orderby = 'rating';
				break;
		}

		$min = $request->get_param( 'min_price' );
		$max = $request->get_param( 'max_price' );
		if ( '' !== (string) $min || '' !== (string) $max ) {
			$args['meta_query'][] = array(
				'key'     => '_price',
				'value'   => array( (float) $min, '' !== (string) $max ? (float) $max : PHP_INT_MAX ),
				'compare' => 'BETWEEN',
				'type'    => 'DECIMAL(10,2)',
			);
		}

		if ( empty( $args['orderby'] ) ) {
			switch ( $orderby ) {
				case 'price':
					$args['meta_key'] = '_price'; // phpcs:ignore
					$args['orderby']  = 'meta_value_num';
					$args['order']    = 'ASC';
					break;
				case 'price-desc':
					$args['meta_key'] = '_price'; // phpcs:ignore
					$args['orderby']  = 'meta_value_num';
					$args['order']    = 'DESC';
					break;
				case 'popularity':
					$args['meta_key'] = 'total_sales'; // phpcs:ignore
					$args['orderby']  = 'meta_value_num';
					$args['order']    = 'DESC';
					break;
				case 'rating':
					$args['meta_key'] = '_wc_average_rating'; // phpcs:ignore
					$args['orderby']  = 'meta_value_num';
					$args['order']    = 'DESC';
					break;
				default:
					$args['orderby'] = '' !== $search ? 'relevance' : 'date';
					$args['order']   = 'DESC';
			}
		}

		$args  = I18n::query_args( $args, $request );
		$args  = apply_filters( 'appforge_products_query_args', $args, $request );
		$query = new WP_Query( $args );
		$items = array();
		foreach ( $query->posts as $post ) {
			$product = wc_get_product( $post );
			if ( $product ) {
				$items[] = self::format_product( $product );
			}
		}

		return rest_ensure_response(
			array(
				'items'       => $items,
				'total'       => (int) $query->found_posts,
				'total_pages' => (int) $query->max_num_pages,
				'page'        => $page,
			)
		);
	}

	public static function product( WP_REST_Request $request ) {
		if ( ! self::active() ) {
			return new WP_Error( 'appforge_no_woo', 'WooCommerce is not active.', array( 'status' => 400 ) );
		}
		$product = wc_get_product( (int) $request['id'] );
		if ( ! $product || 'publish' !== $product->get_status() ) {
			return new WP_Error( 'appforge_not_found', __( 'Product not found.', 'appforge' ), array( 'status' => 404 ) );
		}
		return rest_ensure_response( self::format_product( $product, true ) );
	}

	public static function categories( WP_REST_Request $request ) {
		if ( ! self::active() ) {
			return rest_ensure_response( array() );
		}
		$args = array(
			'taxonomy'   => 'product_cat',
			'hide_empty' => (bool) ( null === $request->get_param( 'hide_empty' ) ? true : $request->get_param( 'hide_empty' ) ),
			'orderby'    => 'menu_order',
			'order'      => 'ASC',
		);
		if ( null !== $request->get_param( 'parent' ) && '' !== $request->get_param( 'parent' ) ) {
			$args['parent'] = (int) $request->get_param( 'parent' );
		}
		if ( $request->get_param( 'limit' ) ) {
			$args['number'] = (int) $request->get_param( 'limit' );
		}
		$uncat = (int) get_option( 'default_product_cat' );
		$terms = get_terms( $args );
		$out   = array();
		if ( ! is_wp_error( $terms ) ) {
			foreach ( $terms as $t ) {
				if ( $t->term_id === $uncat && ! $t->count ) {
					continue;
				}
				$thumb = (int) get_term_meta( $t->term_id, 'thumbnail_id', true );
				$out[] = array(
					'id'         => $t->term_id,
					'name'       => html_entity_decode( $t->name, ENT_QUOTES, 'UTF-8' ),
					'slug'       => $t->slug,
					'parent'     => $t->parent,
					'count'      => (int) $t->count,
					'image'      => $thumb ? wp_get_attachment_image_url( $thumb, 'woocommerce_thumbnail' ) : '',
					'icon'       => (string) get_term_meta( $t->term_id, 'appforge_icon', true ),
					'icon_color' => (string) get_term_meta( $t->term_id, 'appforge_icon_color', true ),
				);
			}
		}
		return rest_ensure_response( $out );
	}

	public static function reviews( WP_REST_Request $request ) {
		$comments = get_comments(
			array(
				'post_id' => (int) $request['id'],
				'status'  => 'approve',
				'type'    => 'review',
				'number'  => 20,
				'offset'  => ( max( 1, (int) $request->get_param( 'page' ) ) - 1 ) * 20,
			)
		);
		$out = array();
		foreach ( $comments as $c ) {
			$out[] = array(
				'id'       => (int) $c->comment_ID,
				'author'   => $c->comment_author,
				'avatar'   => get_avatar_url( $c->comment_author_email, array( 'size' => 96 ) ),
				'rating'   => (int) get_comment_meta( $c->comment_ID, 'rating', true ),
				'content'  => wp_strip_all_tags( $c->comment_content ),
				'date'     => mysql_to_rfc3339( $c->comment_date_gmt ),
				'verified' => (bool) get_comment_meta( $c->comment_ID, 'verified', true ),
			);
		}
		return rest_ensure_response( $out );
	}

	public static function add_review( WP_REST_Request $request ) {
		$user    = wp_get_current_user();
		$product = wc_get_product( (int) $request['id'] );
		if ( ! $product || ! $product->get_reviews_allowed() ) {
			return new WP_Error( 'appforge_reviews_closed', __( 'Reviews are closed for this product.', 'appforge' ), array( 'status' => 400 ) );
		}
		if ( 'yes' === get_option( 'woocommerce_review_rating_verification_required' ) && ! wc_customer_bought_product( $user->user_email, $user->ID, $product->get_id() ) ) {
			return new WP_Error( 'appforge_review_verified', __( 'Only verified buyers can review this product.', 'appforge' ), array( 'status' => 403 ) );
		}
		$rating  = max( 1, min( 5, (int) $request->get_param( 'rating' ) ) );
		$content = sanitize_textarea_field( (string) $request->get_param( 'content' ) );
		if ( '' === $content ) {
			return new WP_Error( 'appforge_review_empty', __( 'Please write a review.', 'appforge' ), array( 'status' => 400 ) );
		}
		$id = wp_insert_comment(
			array(
				'comment_post_ID'      => $product->get_id(),
				'comment_author'       => $user->display_name,
				'comment_author_email' => $user->user_email,
				'comment_content'      => $content,
				'comment_type'         => 'review',
				'user_id'              => $user->ID,
				'comment_approved'     => get_option( 'comment_moderation' ) ? 0 : 1,
			)
		);
		if ( ! $id ) {
			return new WP_Error( 'appforge_review_failed', __( 'Could not save review.', 'appforge' ), array( 'status' => 500 ) );
		}
		update_comment_meta( $id, 'rating', $rating );
		update_comment_meta( $id, 'verified', (int) wc_customer_bought_product( $user->user_email, $user->ID, $product->get_id() ) );
		\WC_Comments::clear_transients( $product->get_id() );
		return rest_ensure_response( array( 'success' => true, 'id' => $id ) );
	}

	/* ---------- Blog ---------- */

	private static function format_post( $post, $full = false ) {
		$data = array(
			'id'      => $post->ID,
			'title'   => html_entity_decode( get_the_title( $post ), ENT_QUOTES, 'UTF-8' ),
			'excerpt' => wp_trim_words( wp_strip_all_tags( $post->post_excerpt ? $post->post_excerpt : $post->post_content ), 22 ),
			'image'   => (string) get_the_post_thumbnail_url( $post, 'large' ),
			'date'    => mysql_to_rfc3339( $post->post_date_gmt ),
			'author'  => get_the_author_meta( 'display_name', $post->post_author ),
			'link'    => get_permalink( $post ),
		);
		if ( $full ) {
			$data['content'] = apply_filters( 'the_content', $post->post_content );
		}
		return $data;
	}

	public static function posts( WP_REST_Request $request ) {
		$query = new WP_Query(
			I18n::query_args( array(
				'post_type'      => 'post',
				'post_status'    => 'publish',
				'posts_per_page' => min( 50, max( 1, (int) ( $request->get_param( 'per_page' ) ? $request->get_param( 'per_page' ) : 10 ) ) ),
				'paged'          => max( 1, (int) $request->get_param( 'page' ) ),
				'cat'            => (int) $request->get_param( 'category' ),
				's'              => sanitize_text_field( (string) $request->get_param( 'search' ) ),
			), $request )
		);
		$items = array();
		foreach ( $query->posts as $post ) {
			$items[] = self::format_post( $post );
		}
		return rest_ensure_response( array( 'items' => $items, 'total_pages' => (int) $query->max_num_pages ) );
	}

	public static function post( WP_REST_Request $request ) {
		$post = get_post( (int) $request['id'] );
		if ( ! $post || 'publish' !== $post->post_status || ! empty( $post->post_password ) ) {
			return new WP_Error( 'appforge_not_found', __( 'Post not found.', 'appforge' ), array( 'status' => 404 ) );
		}
		return rest_ensure_response( self::format_post( $post, true ) );
	}
}
