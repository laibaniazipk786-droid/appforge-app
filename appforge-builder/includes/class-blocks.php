<?php
namespace AppForge;

defined( 'ABSPATH' ) || exit;

/**
 * Block registry. This schema drives both the admin inspector (fields) and
 * documents what the Flutter renderer understands (type + props).
 *
 * Field types: text, textarea, number, color, image, select, toggle, action, category, items
 */
class Blocks {

	public static function common_fields() {
		return array(
			array( 'key' => 'bg_color', 'label' => 'Background', 'type' => 'color', 'default' => '' ),
			array( 'key' => 'padding_h', 'label' => 'Padding left/right', 'type' => 'number', 'default' => 16 ),
			array( 'key' => 'padding_v', 'label' => 'Padding top/bottom', 'type' => 'number', 'default' => 8 ),
		);
	}

	public static function registry() {
		$align = array( 'left' => 'Left', 'center' => 'Center', 'right' => 'Right' );

		$blocks = array(
			'search'     => array(
				'label'  => 'Search bar',
				'icon'   => 'dashicons-search',
				'fields' => array(
					array( 'key' => 'placeholder', 'label' => 'Placeholder', 'type' => 'text', 'default' => 'Search products...' ),
				),
			),
			'slider'     => array(
				'label'  => 'Slider',
				'icon'   => 'dashicons-images-alt2',
				'fields' => array(
					array(
						'key'         => 'items',
						'label'       => 'Slides',
						'type'        => 'items',
						'item_label'  => 'Slide',
						'item_fields' => array(
							array( 'key' => 'image', 'label' => 'Image', 'type' => 'image', 'default' => '' ),
							array( 'key' => 'action', 'label' => 'On tap', 'type' => 'action', 'default' => array( 'type' => 'none', 'value' => '' ) ),
						),
						'default'     => array(),
					),
					array( 'key' => 'height', 'label' => 'Height', 'type' => 'number', 'default' => 170 ),
					array( 'key' => 'radius', 'label' => 'Corner radius', 'type' => 'number', 'default' => 12 ),
					array( 'key' => 'autoplay', 'label' => 'Autoplay', 'type' => 'toggle', 'default' => true ),
				),
			),
			'banner'     => array(
				'label'  => 'Banner image',
				'icon'   => 'dashicons-format-image',
				'fields' => array(
					array( 'key' => 'image', 'label' => 'Image', 'type' => 'image', 'default' => '' ),
					array( 'key' => 'height', 'label' => 'Height', 'type' => 'number', 'default' => 140 ),
					array( 'key' => 'radius', 'label' => 'Corner radius', 'type' => 'number', 'default' => 12 ),
					array( 'key' => 'action', 'label' => 'On tap', 'type' => 'action', 'default' => array( 'type' => 'none', 'value' => '' ) ),
				),
			),
			'heading'    => array(
				'label'  => 'Heading',
				'icon'   => 'dashicons-heading',
				'fields' => array(
					array( 'key' => 'text', 'label' => 'Text', 'type' => 'text', 'default' => 'Section title' ),
					array( 'key' => 'size', 'label' => 'Font size', 'type' => 'number', 'default' => 18 ),
					array( 'key' => 'align', 'label' => 'Align', 'type' => 'select', 'options' => $align, 'default' => 'left' ),
					array( 'key' => 'color', 'label' => 'Color', 'type' => 'color', 'default' => '' ),
					array( 'key' => 'show_view_all', 'label' => 'Show "View all"', 'type' => 'toggle', 'default' => false ),
					array( 'key' => 'action', 'label' => '"View all" opens', 'type' => 'action', 'default' => array( 'type' => 'none', 'value' => '' ) ),
				),
			),
			'text'       => array(
				'label'  => 'Text',
				'icon'   => 'dashicons-editor-paragraph',
				'fields' => array(
					array( 'key' => 'content', 'label' => 'Content', 'type' => 'textarea', 'default' => 'Write something...' ),
					array( 'key' => 'size', 'label' => 'Font size', 'type' => 'number', 'default' => 14 ),
					array( 'key' => 'align', 'label' => 'Align', 'type' => 'select', 'options' => $align, 'default' => 'left' ),
					array( 'key' => 'color', 'label' => 'Color', 'type' => 'color', 'default' => '' ),
				),
			),
			'categories' => array(
				'label'  => 'Categories',
				'icon'   => 'dashicons-category',
				'woo'    => true,
				'fields' => array(
					array(
						'key'     => 'layout',
						'label'   => 'Layout',
						'type'    => 'select',
						'options' => array(
							'horizontal'   => 'Horizontal scroll',
							'grid'         => 'Grid',
							'grid_slider'  => 'Grid slider (rows, swipe pages)',
							'cards_slider' => 'Cards slider (big image cards)',
						),
						'default' => 'horizontal',
					),
					array( 'key' => 'columns', 'label' => 'Columns (grid / grid slider)', 'type' => 'number', 'default' => 4 ),
					array( 'key' => 'rows', 'label' => 'Rows (grid slider)', 'type' => 'number', 'default' => 2 ),
					array( 'key' => 'limit', 'label' => 'Max items', 'type' => 'number', 'default' => 10 ),
					array( 'key' => 'parent', 'label' => 'Parent category', 'type' => 'category', 'default' => 0 ),
					array( 'key' => 'display', 'label' => 'Show', 'type' => 'select', 'options' => array( 'image' => 'Category image (icon if no image)', 'icon' => 'App icon (set in Products → Categories)' ), 'default' => 'image' ),
					array( 'key' => 'shape', 'label' => 'Shape', 'type' => 'select', 'options' => array( 'circle' => 'Circle', 'square' => 'Rounded square' ), 'default' => 'circle' ),
					array( 'key' => 'item_size', 'label' => 'Item size', 'type' => 'number', 'default' => 64 ),
					array( 'key' => 'show_name', 'label' => 'Show name', 'type' => 'toggle', 'default' => true ),
					array( 'key' => 'show_count', 'label' => 'Show product count', 'type' => 'toggle', 'default' => false ),
				),
			),
			'products'   => array(
				'label'  => 'Products',
				'icon'   => 'dashicons-cart',
				'woo'    => true,
				'fields' => array(
					array(
						'key'     => 'source',
						'label'   => 'Source',
						'type'    => 'select',
						'options' => array(
							'latest'       => 'Latest',
							'featured'     => 'Featured',
							'on_sale'      => 'On sale',
							'best_selling' => 'Best selling',
							'top_rated'    => 'Top rated',
							'category'     => 'From category',
						),
						'default' => 'latest',
					),
					array( 'key' => 'category', 'label' => 'Category', 'type' => 'category', 'default' => 0 ),
					array( 'key' => 'limit', 'label' => 'Number of products', 'type' => 'number', 'default' => 8 ),
					array( 'key' => 'layout', 'label' => 'Layout', 'type' => 'select', 'options' => array( 'grid' => 'Grid', 'horizontal' => 'Horizontal scroll', 'list' => 'List' ), 'default' => 'grid' ),
					array( 'key' => 'columns', 'label' => 'Grid columns', 'type' => 'number', 'default' => 2 ),
				),
			),
			'button'     => array(
				'label'  => 'Button',
				'icon'   => 'dashicons-button',
				'fields' => array(
					array( 'key' => 'label', 'label' => 'Label', 'type' => 'text', 'default' => 'Shop now' ),
					array( 'key' => 'action', 'label' => 'On tap', 'type' => 'action', 'default' => array( 'type' => 'route', 'value' => 'products' ) ),
					array( 'key' => 'color', 'label' => 'Button color', 'type' => 'color', 'default' => '' ),
					array( 'key' => 'text_color', 'label' => 'Text color', 'type' => 'color', 'default' => '#FFFFFF' ),
					array( 'key' => 'full_width', 'label' => 'Full width', 'type' => 'toggle', 'default' => true ),
				),
			),
			'posts'      => array(
				'label'  => 'Blog posts',
				'icon'   => 'dashicons-admin-post',
				'fields' => array(
					array( 'key' => 'limit', 'label' => 'Number of posts', 'type' => 'number', 'default' => 5 ),
					array( 'key' => 'layout', 'label' => 'Layout', 'type' => 'select', 'options' => array( 'list' => 'List', 'horizontal' => 'Horizontal scroll' ), 'default' => 'list' ),
				),
			),
			'flash_sale'   => array(
				'label'  => 'Flash sale (countdown)',
				'icon'   => 'dashicons-clock',
				'woo'    => true,
				'fields' => array(
					array( 'key' => 'title', 'label' => 'Title', 'type' => 'text', 'default' => 'Flash Sale' ),
					array( 'key' => 'subtitle', 'label' => 'Subtitle', 'type' => 'text', 'default' => 'Hurry up! Offer ends in' ),
					array( 'key' => 'ends_at', 'label' => 'Sale ends at (your site time)', 'type' => 'datetime', 'default' => '' ),
					array( 'key' => 'source', 'label' => 'Products', 'type' => 'select', 'options' => array( 'on_sale' => 'On sale products', 'featured' => 'Featured', 'category' => 'From category' ), 'default' => 'on_sale' ),
					array( 'key' => 'category', 'label' => 'Category', 'type' => 'category', 'default' => 0 ),
					array( 'key' => 'limit', 'label' => 'Number of products', 'type' => 'number', 'default' => 8 ),
					array( 'key' => 'accent', 'label' => 'Accent color', 'type' => 'color', 'default' => '#DC2626' ),
					array( 'key' => 'hide_when_ended', 'label' => 'Hide the block when the sale has ended', 'type' => 'toggle', 'default' => true ),
				),
			),
			'recently_viewed' => array(
				'label'  => 'Recently viewed',
				'icon'   => 'dashicons-backup',
				'woo'    => true,
				'fields' => array(
					array( 'key' => 'title', 'label' => 'Title', 'type' => 'text', 'default' => 'Recently viewed' ),
					array( 'key' => 'limit', 'label' => 'Number of products', 'type' => 'number', 'default' => 10 ),
				),
			),
			'coupon'       => array(
				'label'  => 'Coupon card',
				'icon'   => 'dashicons-tickets-alt',
				'fields' => array(
					array( 'key' => 'code', 'label' => 'Coupon code (from WooCommerce → Coupons)', 'type' => 'text', 'default' => 'WELCOME10' ),
					array( 'key' => 'title', 'label' => 'Title', 'type' => 'text', 'default' => '10% OFF your first order' ),
					array( 'key' => 'description', 'label' => 'Description', 'type' => 'text', 'default' => 'Use this code at checkout' ),
					array( 'key' => 'color', 'label' => 'Card color', 'type' => 'color', 'default' => '' ),
					array( 'key' => 'text_color', 'label' => 'Text color', 'type' => 'color', 'default' => '#FFFFFF' ),
				),
			),
			'html'         => array(
				'label'  => 'Rich text / HTML',
				'icon'   => 'dashicons-editor-code',
				'fields' => array(
					array( 'key' => 'content', 'label' => 'Content (HTML allowed: <p>, <h2>, <strong>, <ul>, <a>, <img> …)', 'type' => 'textarea', 'rows' => 10, 'default' => '<p>Your content here…</p>' ),
				),
			),
			'links'        => array(
				'label'  => 'Menu links',
				'icon'   => 'dashicons-list-view',
				'fields' => array(
					array(
						'key'         => 'items',
						'label'       => 'Links',
						'type'        => 'items',
						'item_label'  => 'Link',
						'item_fields' => array(
							array( 'key' => 'label', 'label' => 'Label', 'type' => 'text', 'default' => 'Link' ),
							array( 'key' => 'icon', 'label' => 'Icon', 'type' => 'icon', 'default' => 'info' ),
							array( 'key' => 'action', 'label' => 'Opens', 'type' => 'action', 'default' => array( 'type' => 'route', 'value' => 'contact' ) ),
						),
						'default'     => array(),
					),
					array( 'key' => 'layout', 'label' => 'Layout', 'type' => 'select', 'options' => array( 'list' => 'List', 'grid' => 'Icon grid' ), 'default' => 'list' ),
					array( 'key' => 'columns', 'label' => 'Grid columns', 'type' => 'number', 'default' => 4 ),
				),
			),
			'faq'          => array(
				'label'  => 'FAQ (accordion)',
				'icon'   => 'dashicons-editor-help',
				'fields' => array(
					array(
						'key'         => 'items',
						'label'       => 'Questions',
						'type'        => 'items',
						'item_label'  => 'Question',
						'item_fields' => array(
							array( 'key' => 'question', 'label' => 'Question', 'type' => 'text', 'default' => 'Question?' ),
							array( 'key' => 'answer', 'label' => 'Answer', 'type' => 'textarea', 'default' => 'Answer.' ),
						),
						'default'     => array(),
					),
				),
			),
			'contact_info' => array(
				'label'  => 'Contact info',
				'icon'   => 'dashicons-phone',
				'fields' => array(
					array( 'key' => 'title', 'label' => 'Title', 'type' => 'text', 'default' => 'Contact us' ),
					array( 'key' => 'show_form_button', 'label' => 'Show "Send a message" button', 'type' => 'toggle', 'default' => true ),
				),
			),
			'spacer'     => array(
				'label'  => 'Spacer',
				'icon'   => 'dashicons-image-flip-vertical',
				'fields' => array(
					array( 'key' => 'height', 'label' => 'Height', 'type' => 'number', 'default' => 16 ),
				),
			),
			'divider'    => array(
				'label'  => 'Divider',
				'icon'   => 'dashicons-minus',
				'fields' => array(
					array( 'key' => 'color', 'label' => 'Color', 'type' => 'color', 'default' => '#E2E8F0' ),
					array( 'key' => 'thickness', 'label' => 'Thickness', 'type' => 'number', 'default' => 1 ),
				),
			),
		);

		return apply_filters( 'appforge_blocks', $blocks );
	}

	public static function exists( $type ) {
		$registry = self::registry();
		return isset( $registry[ $type ] );
	}

	/**
	 * Action types used by "action" fields. The app understands all of these.
	 */
	public static function action_types() {
		return array(
			'none'     => 'Nothing',
			'product'  => 'Open product (ID)',
			'category' => 'Open category (ID)',
			'screen'   => 'Open builder screen (slug)',
			'route'    => 'Open app page',
			'search'   => 'Search (keyword)',
			'post'     => 'Open blog post (ID)',
			'wp_page'  => 'Open WordPress page',
			'url'      => 'Open URL (in-app browser)',
			'external' => 'Open URL (external browser)',
			'call'     => 'Call phone number',
			'whatsapp' => 'WhatsApp chat (number)',
			'email'    => 'Send email',
		);
	}

	public static function routes() {
		return array(
			'products'   => 'All products',
			'categories' => 'Categories',
			'cart'       => 'Cart',
			'account'    => 'Account',
			'orders'     => 'My orders',
			'posts'       => 'Blog',
			'search'      => 'Search',
			'contact'     => 'Contact us (form)',
			'track_order' => 'Track order',
			'settings'    => 'App settings (theme & language)',
			'login'       => 'Login / Sign up',
			'wishlist'    => 'Wishlist',
		);
	}

	/**
	 * Icon names the app understands (Material icons). Used by menus, links and category icons.
	 */
	public static function icons() {
		return array(
			'home', 'store', 'category', 'cart', 'person', 'search', 'heart', 'article', 'notifications', 'settings',
			'local_offer', 'receipt', 'local_shipping', 'info', 'support_agent', 'phone', 'email', 'whatsapp', 'location',
			'help', 'policy', 'star', 'new', 'sale', 'gift', 'language', 'dark_mode', 'logout',
			'checkroom', 'woman', 'man', 'child', 'shoe', 'watch', 'diamond', 'face', 'spa', 'brush',
			'phone_android', 'laptop', 'headphones', 'tv', 'camera', 'sports_esports', 'kitchen', 'chair', 'bed', 'light',
			'grocery', 'fruit', 'egg', 'coffee', 'bakery', 'pets', 'baby', 'toys', 'sports', 'fitness', 'book', 'car', 'tools', 'medical',
		);
	}
}
