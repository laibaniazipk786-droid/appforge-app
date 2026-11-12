/* global jQuery, AppForgeData, wp */
/**
 * AppForge drag & drop app builder.
 * State is a plain object: { settings, screens }. Everything re-renders from state.
 */
(function ($) {
  'use strict';

  var D = window.AppForgeData || {};
  var state = {
    design: { id: D.design.id, name: D.design.name },
    settings: $.extend(true, {}, D.design.settings),
    screens: $.extend(true, {}, D.design.screens),
    designs: D.designs || [],
    store: $.extend({}, D.store),
    keys: $.extend({}, D.keys),
    templates: null,
    importing: null,
    onbIndex: 0,
    tab: 'builder',
    screen: 'home',
    selected: null,
    dirty: false,
    saving: false,
  };

  function isActive() {
    return state.designs.some(function (d) { return d.id === state.design.id && d.active; });
  }

  function loadDesign(full) {
    state.design = { id: full.id, name: full.name };
    state.settings = $.extend(true, {}, full.settings);
    state.screens = $.extend(true, {}, full.screens);
    Object.keys(state.screens).forEach(function (k) {
      if (!$.isArray(state.screens[k].blocks)) state.screens[k].blocks = [];
    });
    state.screen = 'home';
    state.selected = null;
    state.onbIndex = 0;
    state.dirty = false;
  }
  var cache = {};
  var $root;

  /* ---------------- helpers ---------------- */

  function esc(s) {
    return String(s === undefined || s === null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  // Builder icon names → Material Icons ligatures (same mapping as the Flutter app).
  var MI = {
    cart: 'shopping_bag', heart: 'favorite', person: 'person', category: 'grid_view', receipt: 'receipt_long', phone: 'call',
    whatsapp: 'chat', location: 'location_on', help: 'help', policy: 'policy', new: 'fiber_new', sale: 'sell', gift: 'redeem',
    dark_mode: 'dark_mode', woman: 'woman', man: 'man', child: 'child_care', shoe: 'directions_walk', diamond: 'diamond',
    face: 'face_retouching_natural', brush: 'brush', grocery: 'local_grocery_store', fruit: 'eco', egg: 'egg', coffee: 'coffee',
    bakery: 'bakery_dining', baby: 'child_friendly', toys: 'toys', sports: 'sports_soccer', fitness: 'fitness_center', book: 'menu_book',
    car: 'directions_car', tools: 'build', medical: 'medical_services', light: 'lightbulb', camera: 'photo_camera', store: 'storefront',
    article: 'article', notifications: 'notifications', local_offer: 'local_offer', local_shipping: 'local_shipping', info: 'info',
    support_agent: 'support_agent', email: 'mail', star: 'star', language: 'language', logout: 'logout', checkroom: 'checkroom',
    watch: 'watch', spa: 'spa', phone_android: 'phone_android', laptop: 'laptop', headphones: 'headphones', tv: 'tv',
    sports_esports: 'sports_esports', kitchen: 'kitchen', chair: 'chair', bed: 'bed', pets: 'pets', home: 'home', search: 'search', settings: 'settings',
  };
  function mi(name, style) {
    return '<i class="material-icons af-mi-i"' + (style ? ' style="' + style + '"' : '') + '>' + esc(MI[name] || name || 'circle') + '</i>';
  }

  function uid() {
    return 'b' + Math.random().toString(36).slice(2, 9);
  }

  function blocks() {
    return state.screens[state.screen].blocks;
  }

  function findBlock(id) {
    var list = blocks();
    for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i];
    return null;
  }

  function fieldsFor(type) {
    var def = D.blocks[type];
    return def ? def.fields.concat(D.commonFields) : D.commonFields;
  }

  function defaultProps(type) {
    var props = {};
    fieldsFor(type).forEach(function (f) {
      props[f.key] = $.isPlainObject(f.default) || $.isArray(f.default) ? $.extend(true, $.isArray(f.default) ? [] : {}, f.default) : f.default;
    });
    return props;
  }

  function prop(block, key) {
    if (block.props && block.props[key] !== undefined && block.props[key] !== null) return block.props[key];
    var f = fieldsFor(block.type).filter(function (x) { return x.key === key; })[0];
    return f ? f.default : undefined;
  }

  function getPath(obj, path) {
    return path.split('.').reduce(function (o, k) { return o === undefined || o === null ? undefined : o[k]; }, obj);
  }

  function setPath(obj, path, value) {
    var keys = path.split('.');
    var o = obj;
    for (var i = 0; i < keys.length - 1; i++) {
      var k = keys[i];
      if (o[k] === undefined || o[k] === null || typeof o[k] !== 'object') o[k] = /^\d+$/.test(keys[i + 1]) ? [] : {};
      o = o[k];
    }
    o[keys[keys.length - 1]] = value;
  }

  function markDirty() {
    state.dirty = true;
    $root.find('.af-save').prop('disabled', false).text('Save changes');
    $root.find('.af-status').text('Unsaved changes');
  }

  function money(v) {
    var c = D.currency || { symbol: '$', position: 'left', decimals: 2 };
    var n = Number(v || 0).toFixed(c.decimals);
    switch (c.position) {
      case 'right': return n + c.symbol;
      case 'left_space': return c.symbol + ' ' + n;
      case 'right_space': return n + ' ' + c.symbol;
      default: return c.symbol + n;
    }
  }

  function api(path, opts) {
    opts = opts || {};
    return $.ajax({
      url: D.restUrl + path,
      method: opts.method || 'GET',
      data: opts.data ? JSON.stringify(opts.data) : undefined,
      contentType: 'application/json',
      headers: { 'X-WP-Nonce': D.nonce },
    });
  }

  function fetchCached(path) {
    if (!cache[path]) cache[path] = api(path);
    return cache[path];
  }

  function toast(msg, isError) {
    var $t = $('<div class="af-toast' + (isError ? ' af-toast-error' : '') + '">' + esc(msg) + '</div>').appendTo('body');
    setTimeout(function () { $t.addClass('show'); }, 10);
    setTimeout(function () { $t.removeClass('show'); setTimeout(function () { $t.remove(); }, 300); }, 2600);
  }

  /* ---------------- shell ---------------- */

  function renderDesignBadge() {
    return '<div class="af-design-pill"><span class="af-muted">Editing</span> <strong>' + esc(state.design.name) + '</strong>' +
      (isActive() ? '<span class="af-badge af-badge-live">● Live in app</span>' : '<button class="button button-small af-activate-current">Activate</button>') +
      '</div>';
  }

  function renderShell() {
    var tabs = [
      ['builder', 'Screens'],
      ['theme', 'Colors & theme'],
      ['appbar', 'App bar'],
      ['nav', 'Menus'],
      ['product', 'Product page'],
      ['onboarding', 'Onboarding'],
      ['languages', 'Languages'],
      ['designs', 'Designs'],
      ['templates', 'Templates'],
      ['connect', 'Settings'],
    ];
    var html =
      '<div class="af-topbar">' +
      '<div class="af-brand"><span class="dashicons dashicons-smartphone"></span> AppForge</div>' +
      '<div class="af-design-slot">' + renderDesignBadge() + '</div>' +
      '<nav class="af-tabs">' +
      tabs.map(function (t) {
        return '<button class="af-tab' + (state.tab === t[0] ? ' active' : '') + '" data-tab="' + t[0] + '">' + t[1] + '</button>';
      }).join('') +
      '</nav>' +
      '<div class="af-actions"><span class="af-status">' + (state.dirty ? 'Unsaved changes' : 'All changes saved') + '</span>' +
      '<button class="button af-export">Export</button>' +
      '<label class="button af-import">Import<input type="file" accept="application/json" hidden></label>' +
      '<button class="button button-primary af-save"' + (state.dirty ? '' : ' disabled') + '>' + (state.dirty ? 'Save changes' : 'Saved') + '</button></div>' +
      '</div>' +
      '<div class="af-body"></div>';
    $root.html(html);
    renderTab();
  }

  function renderTab() {
    var $body = $root.find('.af-body');
    $root.find('.af-tab').removeClass('active').filter('[data-tab="' + state.tab + '"]').addClass('active');
    if (state.tab === 'builder') {
      $body.html(
        '<div class="af-builder">' +
        '<aside class="af-panel af-left">' + renderScreensBox() + renderPalette() + '</aside>' +
        '<main class="af-stage">' + renderPhoneFrame() + '</main>' +
        '<aside class="af-panel af-right"><div class="af-inspector"></div></aside>' +
        '</div>'
      );
      renderCanvas();
      renderInspector();
      initDrag();
    } else if (state.tab === 'languages') {
      $body.html('<div class="af-panel af-form af-wide">' + renderLanguages() + '</div>');
      if (!state.lang) loadLanguages();
    } else if (state.tab === 'theme' || state.tab === 'nav' || state.tab === 'appbar' || state.tab === 'onboarding' || state.tab === 'product') {
      var form = { theme: renderThemeForm, nav: renderNavForm, appbar: renderAppbarForm, onboarding: renderOnboardingForm, product: renderProductForm }[state.tab]();
      $body.html('<div class="af-split"><div class="af-panel af-form">' + form + '</div><div class="af-stage">' + renderPhoneFrame() + '</div></div>');
      renderCanvas();
    } else if (state.tab === 'designs') {
      $body.html('<div class="af-panel af-form af-wide">' + renderDesigns() + '</div>');
    } else if (state.tab === 'templates') {
      $body.html('<div class="af-panel af-form af-wide">' + renderTemplates() + '</div>');
      if (!state.templates) {
        api('/admin/templates').done(function (list) {
          state.templates = list;
          if (state.tab === 'templates') renderTab();
        });
      }
    } else {
      $body.html('<div class="af-panel af-form af-connect">' + renderConnect() + '</div>');
    }
  }

  function refreshTopbar() {
    $root.find('.af-design-slot').html(renderDesignBadge());
  }

  /* ---------------- left: screens + palette ---------------- */

  var PAGE_TEMPLATES = {
    blank: { title: 'New page', blocks: [] },
    about: { title: 'About us', blocks: [
      { type: 'heading', props: { text: 'About us', size: 22 } },
      { type: 'html', props: { content: '<p>Tell your story here — who you are, what you sell and why customers love you.</p><ul><li>Genuine products</li><li>Fast delivery</li><li>Easy returns</li></ul>' } },
      { type: 'contact_info', props: { title: 'Get in touch', show_form_button: true } },
    ] },
    contact: { title: 'Contact us', blocks: [
      { type: 'heading', props: { text: 'We are here to help', size: 22 } },
      { type: 'text', props: { content: 'Call, WhatsApp or send us a message — we usually reply within a few hours.' } },
      { type: 'contact_info', props: { title: 'Contact details', show_form_button: true } },
    ] },
    faq: { title: 'Help & FAQ', blocks: [
      { type: 'heading', props: { text: 'Frequently asked questions', size: 20 } },
      { type: 'faq', props: { items: [
        { question: 'How long does delivery take?', answer: '<p>Orders are delivered in 2–5 working days.</p>' },
        { question: 'Can I pay cash on delivery?', answer: '<p>Yes, cash on delivery is available.</p>' },
        { question: 'How do I return an item?', answer: '<p>Contact us within 7 days of delivery.</p>' },
      ] } },
      { type: 'links', props: { layout: 'list', items: [
        { label: 'Track my order', icon: 'local_shipping', action: { type: 'route', value: 'track_order' } },
        { label: 'Contact support', icon: 'support_agent', action: { type: 'route', value: 'contact' } },
      ] } },
    ] },
    promo: { title: 'Sale', blocks: [
      { type: 'banner', props: { image: '', height: 180 } },
      { type: 'heading', props: { text: 'Mega sale', size: 22, align: 'center' } },
      { type: 'products', props: { source: 'on_sale', limit: 10, layout: 'grid', columns: 2 } },
    ] },
  };

  function makeScreen(key) {
    var t = PAGE_TEMPLATES[key] || PAGE_TEMPLATES.blank;
    return {
      title: t.title,
      blocks: t.blocks.map(function (b) {
        return { id: uid(), type: b.type, props: $.extend(true, defaultProps(b.type), b.props) };
      }),
    };
  }

  function renderScreensBox() {
    var list = Object.keys(state.screens).map(function (slug) {
      var sc = state.screens[slug];
      return '<li class="' + (slug === state.screen ? 'on' : '') + '" data-screen-open="' + esc(slug) + '"><span>' + esc(sc.title) + '</span><small>' + (slug === 'home' ? 'home' : esc(slug)) + ' · ' + sc.blocks.length + '</small></li>';
    }).join('');
    var tpl = Object.keys(PAGE_TEMPLATES).map(function (k) { return '<option value="' + k + '">' + esc(k === 'blank' ? 'Blank page' : PAGE_TEMPLATES[k].title) + '</option>'; }).join('');
    return '<div class="af-box"><h3>Pages</h3><ul class="af-pages">' + list + '</ul>' +
      '<div class="af-row-btns"><select class="af-page-tpl">' + tpl + '</select><button class="button af-page-new">+ Create</button></div>' +
      '<div class="af-row-btns">' +
      '<button class="button-link af-screen-rename">Rename</button>' +
      (state.screen !== 'home' ? '<button class="button-link" data-screen-to="drawer">+ Sidebar</button><button class="button-link" data-screen-to="bottom">+ Bottom menu</button><button class="button-link af-danger af-screen-delete">Delete</button>' : '') +
      '</div><p class="af-hint">Pages can be opened from menus, banners, buttons and links.</p></div>';
  }

  function renderPalette() {
    var items = Object.keys(D.blocks).map(function (type) {
      var b = D.blocks[type];
      var disabled = b.woo && !D.woo;
      return '<li class="af-palette-item' + (disabled ? ' disabled' : '') + '" data-type="' + esc(type) + '" title="' + (disabled ? 'Requires WooCommerce' : 'Drag to the phone or click to add') + '">' +
        '<span class="dashicons ' + esc(b.icon) + '"></span><span>' + esc(b.label) + '</span></li>';
    }).join('');
    return '<div class="af-box"><h3>Blocks</h3><p class="af-hint">Drag blocks onto the phone.</p><ul class="af-palette">' + items + '</ul></div>';
  }

  /* ---------------- phone preview ---------------- */

  function renderPhoneFrame() {
    return '<div class="af-phone-wrap"><div class="af-mode-toggle">' +
      '<button class="' + (state.previewDark ? '' : 'on') + '" data-preview-mode="light">☀ Light</button>' +
      '<button class="' + (state.previewDark ? 'on' : '') + '" data-preview-mode="dark">☾ Dark</button>' +
      (state.tab === 'builder' || state.tab === 'nav' ? '<button class="' + (state.previewDrawer ? 'on' : '') + '" data-preview-drawer="1">☰ Sidebar</button>' : '') +
      '</div><div class="af-phone"><div class="af-notch"></div><div class="af-screen">' +
      '<div class="af-appbar"></div>' +
      '<ul class="af-canvas" id="af-canvas-list"></ul>' +
      '<div class="af-bottomnav"></div>' +
      '<div class="af-drawer-layer"></div>' +
      '</div></div></div>';
  }

  // Colors actually used by the preview (light or dark palette).
  function palette() {
    var s = state.settings;
    var d = s.dark || {};
    if (!state.previewDark) {
      return {
        primary: s.primary_color, secondary: s.secondary_color, bg: s.background_color, surface: s.surface_color, text: s.text_color,
        muted: s.muted_color, border: s.border_color, abBg: (s.appbar || {}).bg_color, abFg: (s.appbar || {}).fg_color,
        navBg: s.nav_bg_color || s.surface_color, navInactive: s.nav_inactive_color,
      };
    }
    return {
      primary: d.primary_color || s.primary_color, secondary: d.secondary_color || s.secondary_color, bg: d.background_color, surface: d.surface_color,
      text: d.text_color, muted: d.muted_color, border: d.border_color, abBg: d.appbar_bg_color, abFg: d.appbar_fg_color,
      navBg: d.nav_bg_color, navInactive: d.nav_inactive_color,
    };
  }

  function drawerHtml() {
    var s = state.settings;
    var dr = s.drawer || {};
    var pal = palette();
    var head;
    if (dr.header_style === 'image' && dr.header_image) {
      head = '<div class="af-dr-head img" style="background-image:url(' + esc(dr.header_image) + ')">';
    } else if (dr.header_style === 'plain') {
      head = '<div class="af-dr-head plain">';
    } else {
      head = '<div class="af-dr-head" style="background:' + esc(pal.primary) + ';color:' + esc(s.on_primary_color || '#fff') + '">';
    }
    head += (s.logo ? '<img src="' + esc(s.logo) + '">' : '<strong>' + esc(s.app_name) + '</strong>') +
      (dr.show_login ? '<div class="af-dr-user"><span class="af-dr-avatar">' + mi('person') + '</span><div><b>Hello, guest</b><small>Login / Sign up</small></div></div>' : '') + '</div>';
    var items = (dr.items || []).map(function (it) {
      var missing = it.action && it.action.type === 'screen' && !state.screens[it.action.value];
      return '<div class="af-dr-item">' + mi(it.icon) + '<span>' + esc(it.label) + '</span>' + (missing ? '<em title="Screen missing">!</em>' : '') + '</div>';
    }).join('');
    var cats = '';
    if (dr.show_categories) {
      cats = '<div class="af-dr-title">' + esc(dr.categories_title || 'Categories') + '</div><div class="af-dr-cats">Loading…</div>';
    }
    var extra = (dr.show_language ? '<div class="af-dr-item">' + mi('language') + '<span>Language</span></div>' : '') +
      (dr.show_theme_toggle && s.allow_theme_switch ? '<div class="af-dr-item">' + mi('dark_mode') + '<span>Dark mode</span><i class="af-dr-switch"></i></div>' : '');
    return '<div class="af-drawer" style="background:' + esc(pal.surface) + ';color:' + esc(pal.text) + '">' + head + '<div class="af-dr-body">' + items +
      (cats ? '<div class="af-dr-sep"></div>' + cats : '') + (extra ? '<div class="af-dr-sep"></div>' + extra : '') + '</div></div>';
  }

  function paintDrawer() {
    var $layer = $root.find('.af-drawer-layer');
    if (!$layer.length) return;
    var show = state.previewDrawer && (state.tab === 'builder' || state.tab === 'nav');
    $layer.toggleClass('open', !!show).html(show ? drawerHtml() : '');
    if (show && (state.settings.drawer || {}).show_categories && D.woo) {
      fetchCached('/categories?parent=0&limit=' + ((state.settings.drawer || {}).categories_limit || 12)).done(function (cats) {
        $layer.find('.af-dr-cats').html((cats || []).map(function (c) {
          var col = c.icon_color || palette().primary;
          return '<div class="af-dr-item">' + (c.icon ? mi(c.icon, 'color:' + col) : (c.image ? '<img src="' + esc(c.image) + '">' : mi('category', 'color:' + col))) + '<span>' + esc(c.name) + '</span><i class="af-chev">›</i></div>';
        }).join('') || '<small>No categories</small>');
      });
    }
  }

  function themeVars() {
    var s = state.settings;
    var pal = palette();
    var or = function (v, f) { return v ? v : f; };
    return '--af-primary:' + pal.primary + ';--af-onprimary:' + or(s.on_primary_color, '#fff') + ';--af-secondary:' + pal.secondary +
      ';--af-bg:' + pal.bg + ';--af-surface:' + pal.surface + ';--af-text:' + pal.text +
      ';--af-muted:' + or(pal.muted, '#64748B') + ';--af-border:' + or(pal.border, '#E2E8F0') +
      ';--af-price:' + or(s.price_color, pal.primary) + ';--af-sale:' + or(s.sale_color, pal.secondary) +
      ';--af-navbg:' + or(pal.navBg, pal.surface) + ';--af-navactive:' + or(s.nav_active_color, pal.primary) +
      ';--af-navinactive:' + or(pal.navInactive, '#94A3B8') + ';--af-radius:' + (parseInt(s.card_radius, 10) || 0) + 'px;';
  }

  function appbarHtml() {
    var s = state.settings;
    var ab = s.appbar || {};
    var isHome = state.screen === 'home';
    var name = isHome ? s.app_name : state.screens[state.screen].title;
    var logo = s.logo ? '<img src="' + esc(s.logo) + '" alt="">' : '';
    var title;
    switch (isHome ? ab.title_type : 'name') {
      case 'logo': title = logo || '<strong>' + esc(name) + '</strong>'; break;
      case 'name': title = '<strong>' + esc(name) + '</strong>'; break;
      case 'logo_name': title = logo + '<strong>' + esc(name) + '</strong>'; break;
      case 'custom': title = '<strong>' + esc(ab.title_text || name) + '</strong>'; break;
      default: title = logo || '<strong>' + esc(name) + '</strong>';
    }
    var icons = (ab.show_search && !ab.search_bar ? '<i class="af-ab-ico af-ab-search"></i>' : '') +
      (ab.show_account ? '<i class="af-ab-ico af-ab-account"></i>' : '') +
      (ab.show_cart ? '<i class="af-ab-ico af-ab-cart"></i>' : '');
    var menu = (s.drawer || {}).enabled && isHome ? '<i class="af-ab-menu"></i>' : '';
    var bar = '<div class="af-appbar-row' + (ab.center ? ' centered' : '') + '">' + menu + '<div class="af-ab-title">' + title + '</div><div class="af-ab-icons">' + icons + '</div></div>';
    if (ab.search_bar && isHome) {
      bar += '<div class="af-ab-searchbar"><span class="af-ab-ico af-ab-search"></span>' + esc(ab.search_text || 'Search products...') + '</div>';
    }
    return bar;
  }

  function onboardingHtml() {
    var o = state.settings.onboarding || {};
    var slides = o.slides || [];
    if (!slides.length) return '<div class="af-empty">Add onboarding slides on the left</div>';
    var i = Math.min(state.onbIndex, slides.length - 1);
    var sl = slides[i];
    var tc = o.text_color || state.settings.text_color;
    var full = o.style === 'fullscreen';
    var img = sl.image ? '<img src="' + esc(sl.image) + '">' : '<div class="af-ph" style="height:100%">Slide image</div>';
    var last = i === slides.length - 1;
    return '<div class="af-onb' + (full ? ' full' : '') + '" style="background:' + esc(o.bg_color || '#fff') + ';color:' + esc(full ? '#fff' : tc) + '">' +
      '<div class="af-onb-skip">' + esc(o.skip_label) + '</div>' +
      '<div class="af-onb-img">' + img + '</div>' +
      '<div class="af-onb-text"><h3>' + esc(sl.title) + '</h3><p>' + esc(sl.text) + '</p></div>' +
      '<div class="af-onb-foot"><div class="af-dots dark">' + slides.map(function (x, j) { return '<i class="' + (j === i ? 'on' : '') + '"></i>'; }).join('') + '</div>' +
      '<span class="af-p-button">' + esc(last ? o.done_label : o.next_label) + '</span></div></div>';
  }

  function renderCanvas() {
    var $screen = $root.find('.af-screen');
    if (!$screen.length) return;
    $screen.attr('style', themeVars());
    var ab = state.settings.appbar || {};
    var onb = state.tab === 'onboarding';
    $screen.toggleClass('af-onb-mode', onb);
    var pal = palette();
    $screen.toggleClass('af-dark', !!state.previewDark);
    $root.find('.af-appbar').attr('style', 'background:' + (pal.abBg || '#fff') + ';color:' + (pal.abFg || '#111') + (ab.shadow ? ';box-shadow:0 2px 8px rgba(0,0,0,.12)' : '')).html(onb ? '' : appbarHtml());
    paintDrawer();
    if (onb) {
      $root.find('.af-canvas').html('<li class="af-onb-wrap">' + onboardingHtml() + '</li>');
      return;
    }
    var $list = $root.find('.af-canvas').empty();
    var list = blocks();
    if (!list.length) {
      $list.append('<li class="af-empty">Drop blocks here</li>');
    }
    list.forEach(function (block) {
      $list.append(renderBlockShell(block));
      paintBlock(block);
    });
    renderBottomNav();
  }

  function renderBottomNav() {
    var nav = state.settings.bottom_nav || [];
    $root.find('.af-bottomnav').html(nav.map(function (item, i) {
      var lbl = state.settings.nav_labels || 'all';
      var showLabel = lbl === 'all' || (lbl === 'selected' && i === 0);
      return '<div class="af-navitem' + (i === 0 ? ' active' : '') + '">' + mi(item.icon) + (showLabel ? '<small>' + esc(item.label) + '</small>' : '') + '</div>';
    }).join(''));
  }

  function renderBlockShell(block) {
    var def = D.blocks[block.type] || { label: block.type };
    return '<li class="af-block' + (state.selected === block.id ? ' selected' : '') + '" data-block-id="' + esc(block.id) + '">' +
      '<div class="af-block-tools"><span class="af-block-name">' + esc(def.label) + '</span>' +
      '<button data-act="up" title="Move up">↑</button><button data-act="down" title="Move down">↓</button>' +
      '<button data-act="dup" title="Duplicate">⧉</button><button data-act="del" title="Delete">✕</button></div>' +
      '<div class="af-block-body"></div></li>';
  }

  function wrapStyle(block) {
    var bg = prop(block, 'bg_color');
    return 'padding:' + (parseInt(prop(block, 'padding_v'), 10) || 0) + 'px ' + (parseInt(prop(block, 'padding_h'), 10) || 0) + 'px;' + (bg ? 'background:' + bg + ';' : '');
  }

  function placeholderImg(h, label) {
    return '<div class="af-ph" style="height:' + h + 'px">' + esc(label || 'Image') + '</div>';
  }

  function paintBlock(block) {
    var $body = $root.find('[data-block-id="' + block.id + '"] .af-block-body');
    if (!$body.length) return;
    $body.attr('style', wrapStyle(block)).html(previewHtml(block));
    loadRemote(block, $body);
  }

  function previewHtml(b) {
    var p = function (k) { return prop(b, k); };
    switch (b.type) {
      case 'search':
        return '<div class="af-p-search"><span class="dashicons dashicons-search"></span>' + esc(p('placeholder')) + '</div>';
      case 'slider': {
        var items = p('items') || [];
        var first = items[0];
        var img = first && first.image ? '<img src="' + esc(first.image) + '" style="height:' + p('height') + 'px;border-radius:' + p('radius') + 'px">' : placeholderImg(p('height'), 'Slider – add slides');
        var dots = items.length > 1 ? '<div class="af-dots">' + items.map(function (x, i) { return '<i class="' + (i === 0 ? 'on' : '') + '"></i>'; }).join('') + '</div>' : '';
        return '<div class="af-p-slider" style="border-radius:' + p('radius') + 'px">' + img + dots + '</div>';
      }
      case 'banner':
        return p('image') ? '<img class="af-p-banner" src="' + esc(p('image')) + '" style="height:' + p('height') + 'px;border-radius:' + p('radius') + 'px">' : '<div style="border-radius:' + p('radius') + 'px;overflow:hidden">' + placeholderImg(p('height'), 'Banner') + '</div>';
      case 'heading':
        return '<div class="af-p-heading" style="justify-content:' + ({ left: 'space-between', center: 'center', right: 'flex-end' }[p('align')] || 'space-between') + '">' +
          '<span style="font-size:' + p('size') + 'px;' + (p('color') ? 'color:' + p('color') : '') + '">' + esc(p('text')) + '</span>' +
          (p('show_view_all') ? '<a>View all</a>' : '') + '</div>';
      case 'text':
        return '<p class="af-p-text" style="text-align:' + p('align') + ';font-size:' + p('size') + 'px;' + (p('color') ? 'color:' + p('color') : '') + '">' + esc(p('content')).replace(/\n/g, '<br>') + '</p>';
      case 'button':
        return '<div style="text-align:center"><span class="af-p-button" style="background:' + (p('color') || 'var(--af-primary)') + ';color:' + (p('text_color') || '#fff') + ';' + (p('full_width') ? 'display:block' : '') + '">' + esc(p('label')) + '</span></div>';
      case 'spacer':
        return '<div style="height:' + p('height') + 'px" class="af-p-spacer"></div>';
      case 'html':
        return '<div class="af-p-html">' + (p('content') || '') + '</div>';
      case 'links': {
        var links = p('items') || [];
        if (!links.length) return '<div class="af-p-loading">Add links in the inspector</div>';
        if (p('layout') === 'grid') {
          return '<div class="af-grid" style="grid-template-columns:repeat(' + Math.max(2, Math.min(5, parseInt(p('columns'), 10) || 4)) + ',1fr)">' + links.map(function (l) {
            return '<div class="af-link-tile"><span class="af-link-ico">' + mi(l.icon) + '</span><small>' + esc(l.label) + '</small></div>';
          }).join('') + '</div>';
        }
        return '<div class="af-links">' + links.map(function (l) {
          return '<div class="af-link-row"><span class="af-link-ico">' + mi(l.icon) + '</span><span>' + esc(l.label) + '</span><i>›</i></div>';
        }).join('') + '</div>';
      }
      case 'faq': {
        var qs = p('items') || [];
        if (!qs.length) return '<div class="af-p-loading">Add questions in the inspector</div>';
        return '<div class="af-faq">' + qs.map(function (q, i) {
          return '<div class="af-faq-item' + (i === 0 ? ' open' : '') + '"><div class="af-faq-q">' + esc(q.question) + '<b>' + (i === 0 ? '−' : '+') + '</b></div>' +
            (i === 0 ? '<div class="af-faq-a">' + (q.answer || '') + '</div>' : '') + '</div>';
        }).join('') + '</div>';
      }
      case 'contact_info': {
        var c = (state.store && state.store.contact) || {};
        var row = function (icon, v) { return v ? '<div class="af-link-row"><span class="af-link-ico">' + mi(icon) + '</span><span>' + esc(v) + '</span></div>' : ''; };
        var rows = row('phone', c.phone) + row('whatsapp', c.whatsapp) + row('email', c.email) + row('location', c.address) + row('info', c.hours);
        return '<div class="af-links"><strong class="af-ci-title">' + esc(p('title')) + '</strong>' + (rows || '<div class="af-p-loading">Fill contact details in Settings tab</div>') +
          (p('show_form_button') ? '<span class="af-p-button" style="display:block;margin-top:8px">Send us a message</span>' : '') + '</div>';
      }
      case 'divider':
        return '<hr style="border:0;border-top:' + p('thickness') + 'px solid ' + p('color') + ';margin:0">';
      case 'categories':
      case 'products':
      case 'posts':
        return '<div class="af-p-loading">Loading ' + esc(b.type) + '…</div>';
      default:
        return '<div class="af-p-loading">' + esc(b.type) + '</div>';
    }
  }

  function productQuery(b) {
    var q = '?per_page=' + (parseInt(prop(b, 'limit'), 10) || 6);
    var source = prop(b, 'source');
    if (source === 'category') q += '&category=' + (parseInt(prop(b, 'category'), 10) || 0);
    else q += '&source=' + source;
    return '/products' + q;
  }

  function loadRemote(b, $body) {
    if (b.type === 'products') {
      if (!D.woo) return $body.html('<div class="af-p-loading">WooCommerce is not active</div>');
      fetchCached(productQuery(b)).done(function (res) {
        $body.html(productsHtml(b, res.items || []));
      }).fail(function () { $body.html('<div class="af-p-loading">Could not load products</div>'); });
    } else if (b.type === 'categories') {
      if (!D.woo) return $body.html('<div class="af-p-loading">WooCommerce is not active</div>');
      fetchCached('/categories?parent=' + (parseInt(prop(b, 'parent'), 10) || 0) + '&limit=' + (parseInt(prop(b, 'limit'), 10) || 10)).done(function (res) {
        $body.html(categoriesHtml(b, res || []));
      });
    } else if (b.type === 'posts') {
      fetchCached('/posts?per_page=' + (parseInt(prop(b, 'limit'), 10) || 5)).done(function (res) {
        $body.html(postsHtml(b, res.items || []));
      });
    }
  }

  function productCard(p, mode) {
    var style = state.settings.product_card;
    var price = p.on_sale && p.regular_price > p.price ? '<del>' + money(p.regular_price) + '</del> ' : '';
    price += money(p.price) + (p.max_price > p.price ? ' – ' + money(p.max_price) : '');
    return '<div class="af-pcard af-pcard-' + esc(style) + ' af-pcard-' + mode + '">' +
      '<div class="af-pcard-img"><img src="' + esc(p.image) + '" alt="">' + (p.on_sale ? '<span class="af-sale">Sale</span>' : '') + '</div>' +
      '<div class="af-pcard-info"><div class="af-pcard-name">' + esc(p.name) + '</div><div class="af-pcard-price">' + price + '</div></div></div>';
  }

  function productsHtml(b, items) {
    if (!items.length) return '<div class="af-p-loading">No products for this source</div>';
    var layout = prop(b, 'layout');
    var cols = Math.max(1, Math.min(4, parseInt(prop(b, 'columns'), 10) || 2));
    if (layout === 'horizontal') return '<div class="af-hscroll">' + items.map(function (p) { return productCard(p, 'h'); }).join('') + '</div>';
    if (layout === 'list') return '<div class="af-plist">' + items.map(function (p) { return productCard(p, 'l'); }).join('') + '</div>';
    return '<div class="af-grid" style="grid-template-columns:repeat(' + cols + ',1fr)">' + items.map(function (p) { return productCard(p, 'g'); }).join('') + '</div>';
  }

  function categoriesHtml(b, items) {
    if (!items.length) return '<div class="af-p-loading">No categories</div>';
    var shape = prop(b, 'shape') === 'circle' ? '50%' : '12px';
    var showName = prop(b, 'show_name');
    var showCount = prop(b, 'show_count');
    var size = Math.max(36, Math.min(110, parseInt(prop(b, 'item_size'), 10) || 64));
    var useIcon = prop(b, 'display') === 'icon';
    var visual = function (c, sz) {
      if (c.image && !useIcon) return '<img src="' + esc(c.image) + '">';
      var col = c.icon_color || state.settings.primary_color;
      if (c.icon) return mi(c.icon, 'color:' + col + ';font-size:' + Math.round(sz * 0.45) + 'px');
      return '<span style="color:' + col + '">' + esc(c.name.charAt(0)) + '</span>';
    };
    var cell = function (c) {
      var tint = (useIcon || !c.image) && c.icon_color ? 'background:' + c.icon_color + '1f;' : '';
      return '<div class="af-cat"><div class="af-cat-img" style="width:' + size + 'px;height:' + size + 'px;border-radius:' + shape + ';' + tint + '">' + visual(c, size) + '</div>' +
        (showName ? '<small>' + esc(c.name) + '</small>' : '') + (showCount ? '<small class="af-count">' + c.count + ' items</small>' : '') + '</div>';
    };
    var layout = prop(b, 'layout');
    var cols = Math.max(2, Math.min(5, parseInt(prop(b, 'columns'), 10) || 4));
    if (layout === 'grid') {
      return '<div class="af-grid" style="grid-template-columns:repeat(' + cols + ',1fr)">' + items.map(cell).join('') + '</div>';
    }
    if (layout === 'grid_slider') {
      var rows = Math.max(1, Math.min(3, parseInt(prop(b, 'rows'), 10) || 2));
      var per = rows * cols;
      var pages = Math.ceil(items.length / per);
      return '<div class="af-grid" style="grid-template-columns:repeat(' + cols + ',1fr)">' + items.slice(0, per).map(cell).join('') + '</div>' +
        (pages > 1 ? '<div class="af-dots dark" style="justify-content:center;margin-top:8px">' + Array.apply(null, Array(pages)).map(function (x, i) { return '<i class="' + (i === 0 ? 'on' : '') + '"></i>'; }).join('') + '</div>' : '');
    }
    if (layout === 'cards_slider') {
      return '<div class="af-hscroll">' + items.map(function (c) {
        return '<div class="af-catcard" style="border-radius:var(--af-radius)">' + (c.image ? '<img src="' + esc(c.image) + '">' : '<div class="af-catcard-ph">' + visual(c, 120) + '</div>') +
          '<div class="af-catcard-label"><strong>' + esc(c.name) + '</strong>' + (showCount ? '<small>' + c.count + ' items</small>' : '') + '</div></div>';
      }).join('') + '</div>';
    }
    return '<div class="af-hscroll">' + items.map(cell).join('') + '</div>';
  }

  function postsHtml(b, items) {
    if (!items.length) return '<div class="af-p-loading">No posts</div>';
    var horiz = prop(b, 'layout') === 'horizontal';
    return '<div class="' + (horiz ? 'af-hscroll' : 'af-plist') + '">' + items.map(function (p) {
      return '<div class="af-post' + (horiz ? ' h' : '') + '">' + (p.image ? '<img src="' + esc(p.image) + '">' : '<div class="af-ph" style="height:60px"></div>') +
        '<div><strong>' + esc(p.title) + '</strong><small>' + esc(p.excerpt).slice(0, 70) + '…</small></div></div>';
    }).join('') + '</div>';
  }

  /* ---------------- drag & drop ---------------- */

  function initDrag() {
    var $list = $root.find('#af-canvas-list');
    $list.sortable({
      items: '> li.af-block, > li.af-palette-item',
      placeholder: 'af-placeholder',
      tolerance: 'pointer',
      cancel: '.af-block-tools button',
      update: function () { setTimeout(syncFromDom, 0); },
    });
    $root.find('.af-palette-item:not(.disabled)').draggable({
      connectToSortable: '#af-canvas-list',
      helper: 'clone',
      revert: 'invalid',
      appendTo: 'body',
      zIndex: 10000,
    });
  }

  function syncFromDom() {
    var list = blocks();
    var byId = {};
    list.forEach(function (b) { byId[b.id] = b; });
    var next = [];
    var newId = null;
    $root.find('#af-canvas-list > li').each(function () {
      var $li = $(this);
      var id = $li.attr('data-block-id');
      var type = $li.attr('data-type');
      if (id && byId[id]) next.push(byId[id]);
      else if (type && D.blocks[type]) {
        var nb = { id: uid(), type: type, props: defaultProps(type) };
        next.push(nb);
        newId = nb.id;
      }
    });
    state.screens[state.screen].blocks = next;
    if (newId) state.selected = newId;
    markDirty();
    renderCanvas();
    renderInspector();
  }

  function addBlock(type) {
    var nb = { id: uid(), type: type, props: defaultProps(type) };
    blocks().push(nb);
    state.selected = nb.id;
    markDirty();
    renderCanvas();
    renderInspector();
    var $el = $root.find('[data-block-id="' + nb.id + '"]');
    if ($el.length) $el[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
  }

  function blockAction(id, act) {
    var list = blocks();
    var i = -1;
    list.forEach(function (b, idx) { if (b.id === id) i = idx; });
    if (i < 0) return;
    if (act === 'up' && i > 0) list.splice(i - 1, 0, list.splice(i, 1)[0]);
    if (act === 'down' && i < list.length - 1) list.splice(i + 1, 0, list.splice(i, 1)[0]);
    if (act === 'dup') {
      var copy = $.extend(true, {}, list[i]);
      copy.id = uid();
      list.splice(i + 1, 0, copy);
      state.selected = copy.id;
    }
    if (act === 'del') {
      list.splice(i, 1);
      if (state.selected === id) state.selected = null;
    }
    markDirty();
    renderCanvas();
    renderInspector();
  }

  /* ---------------- inspector ---------------- */

  function renderInspector() {
    var $ins = $root.find('.af-inspector');
    if (!$ins.length) return;
    var block = state.selected ? findBlock(state.selected) : null;
    if (!block) {
      $ins.html('<div class="af-box"><h3>Inspector</h3><p class="af-hint">Select a block on the phone to edit it.</p>' +
        '<p class="af-hint">Tip: the preview uses your real products, categories and posts.</p></div>');
      return;
    }
    var def = D.blocks[block.type];
    var main = def.fields.map(function (f) { return fieldHtml(f, 'props.' + f.key, prop(block, f.key)); }).join('');
    var style = D.commonFields.map(function (f) { return fieldHtml(f, 'props.' + f.key, prop(block, f.key)); }).join('');
    $ins.html('<div class="af-box"><h3>' + esc(def.label) + '</h3>' + main + '</div><div class="af-box"><h3>Style</h3>' + style + '</div>');
  }

  function fieldHtml(f, path, value) {
    var label = '<label class="af-label">' + esc(f.label) + '</label>';
    var attr = ' data-path="' + esc(path) + '" data-kind="' + esc(f.type) + '"';
    switch (f.type) {
      case 'text':
        return '<div class="af-field">' + label + '<input type="text" class="widefat"' + attr + ' value="' + esc(value) + '"></div>';
      case 'textarea':
        return '<div class="af-field">' + label + '<textarea rows="' + (f.rows || 4) + '" class="widefat"' + attr + '>' + esc(value) + '</textarea></div>';
      case 'icon':
        return '<div class="af-field">' + label + iconSelect(attr, value) + '</div>';
      case 'number':
        return '<div class="af-field">' + label + '<input type="number" class="small-text"' + attr + ' value="' + esc(value) + '"></div>';
      case 'toggle':
        return '<div class="af-field af-toggle"><label><input type="checkbox"' + attr + (value ? ' checked' : '') + '> ' + esc(f.label) + '</label></div>';
      case 'color':
        return '<div class="af-field">' + label + '<div class="af-color"><input type="color" data-color-for="' + esc(path) + '" value="' + esc(value || '#ffffff') + '">' +
          '<input type="text" placeholder="default"' + attr + ' value="' + esc(value) + '"><button class="button-link af-clear" data-clear="' + esc(path) + '">clear</button></div></div>';
      case 'select':
        return '<div class="af-field">' + label + '<select' + attr + '>' + Object.keys(f.options).map(function (k) {
          return '<option value="' + esc(k) + '"' + (String(value) === k ? ' selected' : '') + '>' + esc(f.options[k]) + '</option>';
        }).join('') + '</select></div>';
      case 'category':
        return '<div class="af-field">' + label + categorySelect(attr, value) + '</div>';
      case 'image':
        return '<div class="af-field">' + label + imagePicker(path, value) + '</div>';
      case 'action':
        return '<div class="af-field">' + label + actionEditor(path, value || { type: 'none', value: '' }) + '</div>';
      case 'items':
        return '<div class="af-field">' + label + itemsEditor(path, value || [], f) + '</div>';
      default:
        return '';
    }
  }

  function categorySelect(attr, value) {
    return '<select' + attr + '>' + D.categories.map(function (c) {
      return '<option value="' + c.id + '"' + (parseInt(value, 10) === c.id ? ' selected' : '') + '>' + esc(c.name) + '</option>';
    }).join('') + '</select>';
  }

  function imagePicker(path, value) {
    return '<div class="af-image">' + (value ? '<img src="' + esc(value) + '">' : '<div class="af-ph" style="height:60px">No image</div>') +
      '<div class="af-row-btns"><button class="button af-media" data-media="' + esc(path) + '">Choose</button>' +
      (value ? '<button class="button-link af-clear" data-clear="' + esc(path) + '">remove</button>' : '') + '</div>' +
      '<input type="text" class="widefat" placeholder="https://…" data-path="' + esc(path) + '" data-kind="image" value="' + esc(value) + '"></div>';
  }

  function actionEditor(path, action) {
    var type = action.type || 'none';
    var typeSel = '<select data-path="' + esc(path) + '.type" data-kind="action-type">' + Object.keys(D.actionTypes).map(function (k) {
      return '<option value="' + k + '"' + (k === type ? ' selected' : '') + '>' + esc(D.actionTypes[k]) + '</option>';
    }).join('') + '</select>';
    var vAttr = ' data-path="' + esc(path) + '.value" data-kind="text"';
    var valueInput = '';
    if (type === 'route') {
      valueInput = '<select' + vAttr + '>' + Object.keys(D.routes).map(function (k) {
        return '<option value="' + k + '"' + (k === action.value ? ' selected' : '') + '>' + esc(D.routes[k]) + '</option>';
      }).join('') + '</select>';
    } else if (type === 'screen') {
      valueInput = '<select' + vAttr + '>' + Object.keys(state.screens).map(function (k) {
        return '<option value="' + esc(k) + '"' + (k === action.value ? ' selected' : '') + '>' + esc(state.screens[k].title) + '</option>';
      }).join('') + '</select>';
    } else if (type === 'category') {
      valueInput = categorySelect(vAttr, action.value);
    } else if (type === 'wp_page') {
      valueInput = '<select' + vAttr + '><option value="">— choose page —</option>' + (D.pages || []).map(function (pg) {
        return '<option value="' + pg.id + '"' + (String(pg.id) === String(action.value) ? ' selected' : '') + '>' + esc(pg.title) + '</option>';
      }).join('') + '</select>';
    } else if (type !== 'none') {
      var ph = { product: 'Product ID', post: 'Post ID', search: 'Keyword', url: 'https://…', external: 'https://…', call: '+92 300 1234567', whatsapp: '923001234567', email: 'hello@store.com' }[type] || '';
      valueInput = '<input type="text" class="widefat" placeholder="' + ph + '"' + vAttr + ' value="' + esc(action.value) + '">';
    }
    return '<div class="af-action">' + typeSel + valueInput + '</div>';
  }

  function iconSelect(attr, value) {
    return '<div class="af-icon-pick"><span class="af-mi">' + esc(value || '') + '</span><select' + attr + '>' + D.icons.map(function (ic) {
      return '<option value="' + esc(ic) + '"' + (ic === value ? ' selected' : '') + '>' + esc(ic) + '</option>';
    }).join('') + '</select></div>';
  }

  function itemDefaults(f) {
    var d = {};
    (f.item_fields || [{ key: 'image', default: '' }, { key: 'action', default: { type: 'none', value: '' } }]).forEach(function (x) {
      d[x.key] = $.isPlainObject(x.default) ? $.extend(true, {}, x.default) : x.default;
    });
    return d;
  }

  function itemsEditor(path, items, f) {
    f = f || {};
    var fields = f.item_fields || [{ key: 'image', label: 'Image', type: 'image' }, { key: 'action', label: 'On tap', type: 'action' }];
    var name = f.item_label || 'Item';
    var rows = items.map(function (item, i) {
      var p = path + '.' + i;
      return '<div class="af-item"><div class="af-item-head"><strong>' + esc(name) + ' ' + (i + 1) + '</strong>' +
        '<span><button class="button-link" data-item-move="' + esc(path) + '" data-i="' + i + '" data-dir="-1">↑</button>' +
        '<button class="button-link" data-item-move="' + esc(path) + '" data-i="' + i + '" data-dir="1">↓</button>' +
        '<button class="button-link af-danger" data-item-del="' + esc(path) + '" data-i="' + i + '">remove</button></span></div>' +
        fields.map(function (x) { return fieldHtml(x, p + '.' + x.key, item[x.key]); }).join('') + '</div>';
    }).join('');
    return '<div class="af-items">' + rows + '<button class="button af-item-add" data-item-add="' + esc(path) + '" data-item-default="' + esc(JSON.stringify(itemDefaults(f))) + '">+ Add ' + esc(name.toLowerCase()) + '</button></div>';
  }

  function coerce(kind, $el) {
    if (kind === 'toggle') return $el.is(':checked');
    if (kind === 'number') return $el.val() === '' ? 0 : Number($el.val());
    if (kind === 'category') return parseInt($el.val(), 10) || 0;
    return $el.val();
  }

  function setBlockValue(path, value, rebuildInspector) {
    var block = findBlock(state.selected);
    if (!block) return;
    setPath(block, path, value);
    markDirty();
    paintBlock(block);
    if (rebuildInspector) renderInspector();
  }

  /* ---------------- theme / app bar / nav / onboarding / connect ---------------- */

  // Generic field bound to a path inside state.settings (or state.store when store=true).
  function settingField(key, label, type, extra, opts) {
    opts = opts || {};
    var src = opts.store ? state.store : state.settings;
    var v = getPath(src, key);
    var attr = ' data-' + (opts.store ? 'store' : 'setting') + '="' + key + '" data-kind="' + type + '"';
    var hint = opts.hint ? '<p class="af-hint">' + esc(opts.hint) + '</p>' : '';
    if (type === 'color') {
      var optional = !!opts.optional;
      return '<div class="af-field"><label class="af-label">' + esc(label) + '</label><div class="af-color">' +
        '<input type="color"' + attr + ' value="' + esc(v || '#ffffff') + '">' +
        '<code>' + esc(v || (optional ? 'auto' : '')) + '</code>' +
        (optional && v ? '<button class="button-link af-clear-setting" data-setting-clear="' + key + '">auto</button>' : '') +
        '</div>' + hint + '</div>';
    }
    if (type === 'toggle') {
      return '<div class="af-field af-toggle"><label><input type="checkbox"' + attr + (v ? ' checked' : '') + '> ' + esc(label) + '</label>' + (extra ? '<p class="af-hint">' + esc(extra) + '</p>' : '') + hint + '</div>';
    }
    if (type === 'select') {
      return '<div class="af-field"><label class="af-label">' + esc(label) + '</label><select' + attr + '>' + Object.keys(extra).map(function (k) {
        return '<option value="' + esc(k) + '"' + (k === String(v) ? ' selected' : '') + '>' + esc(extra[k]) + '</option>';
      }).join('') + '</select>' + hint + '</div>';
    }
    if (type === 'image') {
      return '<div class="af-field"><label class="af-label">' + esc(label) + '</label><div class="af-image">' + (v ? '<img src="' + esc(v) + '">' : '') +
        '<div class="af-row-btns"><button class="button af-media-setting" data-setting-media="' + key + '">Choose</button>' + (v ? '<button class="button-link af-clear-setting" data-setting-clear="' + key + '">remove</button>' : '') + '</div></div>' + hint + '</div>';
    }
    if (type === 'textarea') {
      return '<div class="af-field"><label class="af-label">' + esc(label) + '</label><textarea rows="3" class="widefat"' + attr + '>' + esc(v) + '</textarea>' + hint + '</div>';
    }
    return '<div class="af-field"><label class="af-label">' + esc(label) + '</label><input type="' + (type === 'number' ? 'number' : 'text') + '" class="' + (type === 'number' ? 'small-text' : 'widefat') + '"' + attr + ' value="' + esc(v) + '">' + hint + '</div>';
  }

  var FONTS = { Roboto: 'Roboto', Poppins: 'Poppins', Inter: 'Inter', Lato: 'Lato', Montserrat: 'Montserrat', 'Open Sans': 'Open Sans', Nunito: 'Nunito', 'DM Sans': 'DM Sans', 'Playfair Display': 'Playfair Display (elegant serif)', Cairo: 'Cairo (Arabic)', 'Noto Nastaliq Urdu': 'Noto Nastaliq Urdu' };

  function renderThemeForm() {
    var schemes = Object.keys(D.schemes || {}).map(function (k) {
      var c = D.schemes[k];
      var active = state.settings.color_scheme === k;
      return '<button class="af-scheme' + (active ? ' active' : '') + '" data-scheme="' + esc(k) + '" title="' + esc(c.label) + '">' +
        '<span class="af-scheme-sw"><i style="background:' + c.primary_color + '"></i><i style="background:' + c.secondary_color + '"></i><i style="background:' + c.background_color + '"></i><i style="background:' + c.text_color + '"></i></span>' +
        '<small>' + esc(c.label) + '</small></button>';
    }).join('');
    return '<h2>Brand</h2>' +
      settingField('app_name', 'App name', 'text') +
      settingField('logo', 'Logo', 'image', null, { hint: 'Used in the app bar, login screen and splash. Transparent PNG works best.' }) +
      '<h2>Color scheme</h2><p class="af-hint">One click applies a full palette — then fine-tune any color below.</p><div class="af-schemes">' + schemes + '</div>' +
      '<h3 class="af-sub">Main colors</h3><div class="af-cols">' +
      settingField('primary_color', 'Primary (buttons, links)', 'color') +
      settingField('on_primary_color', 'Text on primary', 'color') +
      settingField('secondary_color', 'Secondary / accent', 'color') +
      settingField('background_color', 'Screen background', 'color') +
      settingField('surface_color', 'Cards & sheets', 'color') +
      settingField('text_color', 'Text', 'color') +
      settingField('muted_color', 'Muted text', 'color') +
      settingField('border_color', 'Borders & dividers', 'color') + '</div>' +
      '<h3 class="af-sub">Shop colors</h3><div class="af-cols">' +
      settingField('price_color', 'Price', 'color', null, { optional: true, hint: 'auto = primary' }) +
      settingField('sale_color', 'Sale badge', 'color', null, { optional: true, hint: 'auto = secondary' }) + '</div>' +
      '<h3 class="af-sub">Bottom navigation colors</h3><div class="af-cols">' +
      settingField('nav_bg_color', 'Background', 'color') +
      settingField('nav_active_color', 'Active tab', 'color', null, { optional: true, hint: 'auto = primary' }) +
      settingField('nav_inactive_color', 'Inactive tab', 'color') + '</div>' +
      '<h2>Dark & light mode</h2><p class="af-hint">Use the ☀ / ☾ buttons above the phone to preview each mode.</p>' +
      settingField('theme_mode', 'App opens in', 'select', { light: 'Light mode', dark: 'Dark mode', system: 'Follow phone setting' }) +
      settingField('allow_theme_switch', 'Let customers switch light / dark in the app', 'toggle') +
      '<h3 class="af-sub">Dark mode colors</h3><div class="af-cols">' +
      settingField('dark.primary_color', 'Primary', 'color', null, { optional: true, hint: 'auto = same as light' }) +
      settingField('dark.secondary_color', 'Secondary', 'color', null, { optional: true, hint: 'auto = same as light' }) +
      settingField('dark.background_color', 'Screen background', 'color') +
      settingField('dark.surface_color', 'Cards & sheets', 'color') +
      settingField('dark.text_color', 'Text', 'color') +
      settingField('dark.muted_color', 'Muted text', 'color') +
      settingField('dark.border_color', 'Borders', 'color') +
      settingField('dark.appbar_bg_color', 'App bar background', 'color') +
      settingField('dark.appbar_fg_color', 'App bar text & icons', 'color') +
      settingField('dark.nav_bg_color', 'Bottom menu background', 'color') +
      settingField('dark.nav_inactive_color', 'Bottom menu inactive', 'color') + '</div>' +
      '<p><button class="button af-dark-preset" data-dark="slate">Slate dark</button> <button class="button af-dark-preset" data-dark="black">True black (OLED)</button> <button class="button af-dark-preset" data-dark="warm">Warm dark</button></p>' +
      '<h2>Style</h2>' +
      settingField('font_family', 'Font (Google Fonts)', 'select', FONTS) +
      settingField('card_radius', 'Corner radius', 'number') +
      settingField('product_card', 'Product card style', 'select', { standard: 'Standard (shadow)', bordered: 'Bordered', minimal: 'Minimal' });
  }

  function renderAppbarForm() {
    var ab = state.settings.appbar || {};
    return '<h2>App bar</h2><p class="af-hint">The top bar of the Home screen. Other screens use the same colors and show their own title.</p>' +
      settingField('appbar.title_type', 'Title shows', 'select', {
        logo_or_name: 'Logo (or app name if no logo)', logo: 'Logo only', name: 'App name only', logo_name: 'Logo + app name', custom: 'Custom text',
      }) +
      (ab.title_type === 'custom' ? settingField('appbar.title_text', 'Custom title', 'text') : '') +
      settingField('appbar.center', 'Center the title', 'toggle') +
      '<div class="af-cols">' + settingField('appbar.bg_color', 'Background', 'color') + settingField('appbar.fg_color', 'Text & icons', 'color') + '</div>' +
      settingField('appbar.shadow', 'Show shadow under app bar', 'toggle') +
      '<h3 class="af-sub">Icons</h3>' +
      settingField('appbar.show_search', 'Search icon', 'toggle') +
      settingField('appbar.show_cart', 'Cart icon (with badge)', 'toggle') +
      settingField('appbar.show_account', 'Account icon', 'toggle') +
      '<h3 class="af-sub">Search bar</h3>' +
      settingField('appbar.search_bar', 'Show a full-width search bar under the app bar (Home)', 'toggle') +
      (ab.search_bar ? settingField('appbar.search_text', 'Placeholder', 'text') : '') +
      '<p><button class="button af-appbar-match">Use primary color for app bar</button> <button class="button af-appbar-light">Light app bar</button></p>';
  }

  function renderOnboardingForm() {
    var o = state.settings.onboarding || {};
    var slides = o.slides || [];
    var rows = slides.map(function (sl, i) {
      var p = 'onboarding.slides.' + i;
      return '<div class="af-item' + (i === state.onbIndex ? ' af-item-focus' : '') + '" data-onb-focus="' + i + '"><div class="af-item-head"><strong>Slide ' + (i + 1) + '</strong><span>' +
        '<button class="button-link" data-onb-move="' + i + '" data-dir="-1">↑</button><button class="button-link" data-onb-move="' + i + '" data-dir="1">↓</button>' +
        '<button class="button-link af-danger" data-onb-del="' + i + '">remove</button></span></div>' +
        settingField(p + '.image', 'Image', 'image') +
        settingField(p + '.title', 'Title', 'text') +
        settingField(p + '.text', 'Description', 'textarea') + '</div>';
    }).join('');
    return '<h2>Onboarding</h2><p class="af-hint">Welcome slides shown the first time someone opens the app.</p>' +
      settingField('onboarding.enabled', 'Show onboarding in the app', 'toggle') +
      settingField('onboarding.style', 'Layout', 'select', { image_top: 'Image on top, text below', fullscreen: 'Full-screen image with text overlay' }) +
      '<div class="af-cols">' + settingField('onboarding.bg_color', 'Background', 'color') + settingField('onboarding.text_color', 'Text color', 'color', null, { optional: true }) + '</div>' +
      '<div class="af-cols3">' + settingField('onboarding.skip_label', 'Skip button', 'text') + settingField('onboarding.next_label', 'Next button', 'text') + settingField('onboarding.done_label', 'Last button', 'text') + '</div>' +
      settingField('onboarding.version', 'Version', 'number', null, { hint: 'Increase this number to show onboarding again to people who already saw it.' }) +
      '<h3 class="af-sub">Slides</h3>' + rows +
      (slides.length < 6 ? '<button class="button af-onb-add">+ Add slide</button>' : '');
  }

  function menuItemsEditor(base, items, name) {
    return items.map(function (item, i) {
      var p = base + '.' + i;
      return '<div class="af-item"><div class="af-item-head"><strong>' + name + ' ' + (i + 1) + '</strong><span>' +
        '<button class="button-link" data-list-move="' + base + '" data-i="' + i + '" data-dir="-1">↑</button><button class="button-link" data-list-move="' + base + '" data-i="' + i + '" data-dir="1">↓</button>' +
        '<button class="button-link af-danger" data-list-del="' + base + '" data-i="' + i + '">remove</button></span></div>' +
        '<div class="af-cols"><div class="af-field"><label class="af-label">Label</label><input type="text" class="widefat" data-nav-path="' + p + '.label" value="' + esc(item.label) + '"></div>' +
        '<div class="af-field"><label class="af-label">Icon</label>' + iconSelect(' data-nav-path="' + p + '.icon"', item.icon) + '</div></div>' +
        '<div class="af-field"><label class="af-label">Opens</label>' + actionEditor('nav:' + p + '.action', item.action || { type: 'route', value: 'products' }) + '</div></div>';
    }).join('');
  }

  function renderNavForm() {
    var nav = state.settings.bottom_nav || [];
    var dr = state.settings.drawer || {};
    return '<div class="af-subtabs"><button class="' + (state.menuTab !== 'drawer' ? 'on' : '') + '" data-menu-tab="bottom">Bottom menu</button><button class="' + (state.menuTab === 'drawer' ? 'on' : '') + '" data-menu-tab="drawer">Sidebar (drawer)</button></div>' +
      (state.menuTab === 'drawer' ?
        '<h2>Sidebar menu</h2><p class="af-hint">Opens from the ☰ button on the Home app bar. Click “☰ Sidebar” above the phone to preview.</p>' +
        settingField('drawer.enabled', 'Enable sidebar', 'toggle') +
        settingField('drawer.header_style', 'Header', 'select', { primary: 'Primary color with logo', image: 'Background image', plain: 'Plain' }) +
        (dr.header_style === 'image' ? settingField('drawer.header_image', 'Header image', 'image') : '') +
        settingField('drawer.show_login', 'Show login / sign up (or the customer’s name)', 'toggle') +
        settingField('drawer.show_categories', 'Show categories with icons', 'toggle', null, { hint: 'Set icons in Products → Categories → edit category → “App icon”.' }) +
        (dr.show_categories ? '<div class="af-cols">' + settingField('drawer.categories_title', 'Categories title', 'text') + settingField('drawer.categories_limit', 'Max categories', 'number') + '</div>' : '') +
        settingField('drawer.show_language', 'Show language switcher', 'toggle') +
        settingField('drawer.show_theme_toggle', 'Show dark mode switch', 'toggle') +
        '<h3 class="af-sub">Menu links</h3>' + menuItemsEditor('drawer.items', dr.items || [], 'Link') +
        '<p><button class="button af-list-add" data-list-add="drawer.items">+ Add link</button> ' +
        '<button class="button af-quick-links">+ Add Contact, About, Track order</button></p>'
        :
        '<h2>Bottom menu</h2><p class="af-hint">2 to 5 tabs. Any tab can open a builder screen, a category, a WordPress page or an app page.</p>' +
        settingField('nav_labels', 'Labels', 'select', { all: 'Show all labels', selected: 'Only on the selected tab', none: 'Icons only' }) +
        menuItemsEditor('bottom_nav', nav, 'Tab') +
        (nav.length < 5 ? '<button class="button af-list-add" data-list-add="bottom_nav">+ Add tab</button>' : ''));
  }

  function renderProductForm() {
    return '<h2>Product page</h2><p class="af-hint">How the single product screen looks in the app.</p>' +
      settingField('product_page.variation_style', 'Variation selector', 'select', {
        auto: 'Auto — color/image swatches when available, otherwise chips', chips: 'Chips (buttons)', dropdown: 'Dropdowns',
      }, { hint: 'Swatch colors/images: Products → Attributes → Configure terms → edit a term.' }) +
      settingField('product_page.show_sku', 'Show SKU', 'toggle') +
      settingField('product_page.show_stock', 'Show stock status / quantity left', 'toggle') +
      settingField('product_page.show_reviews', 'Show reviews', 'toggle') +
      settingField('product_page.show_related', 'Show related products', 'toggle') +
      settingField('product_page.show_share', 'Show share button', 'toggle') +
      settingField('product_page.sticky_buy_bar', 'Sticky “Add to cart / Buy now” bar', 'toggle') +
      '<div class="af-note">Variable products: customers pick options (e.g. Color, Size) — price, image, stock and SKU update for the chosen variation, and combinations that are out of stock are crossed out.</div>';
  }

  var LANG_PRESETS = {
    en: 'English', ur: 'Urdu (اردو)', ar: 'Arabic (العربية)',
  };

  function loadLanguages(cb) {
    api('/admin/languages').done(function (res) {
      state.lang = res;
      state.langEdit = state.langEdit || (res.settings.enabled.filter(function (c) { return c !== 'en'; })[0] || 'en');
      loadPack(state.langEdit, cb);
    });
  }

  function loadPack(code, cb) {
    api('/admin/languages/' + code).done(function (res) {
      state.langPack = res;
      state.langEdit = code;
      if (state.tab === 'languages') renderTab();
      if (cb) cb();
    });
  }

  function renderLanguages() {
    var L = state.lang;
    if (!L) return '<h2>Languages</h2><div class="af-p-loading">Loading…</div>';
    var set = L.settings;
    var rows = Object.keys(L.available).map(function (code) {
      var a = L.available[code];
      var on = set.enabled.indexOf(code) >= 0;
      return '<tr><td><label><input type="checkbox" data-lang-enable="' + esc(code) + '"' + (on ? ' checked' : '') + '> <strong>' + esc(a.name) + '</strong> <span class="af-muted">' + esc(a.native) + ' · ' + esc(code) + (a.rtl ? ' · RTL' : '') + (a.custom ? ' · custom' : '') + '</span></label></td>' +
        '<td><label><input type="radio" name="af-lang-default" data-lang-default="' + esc(code) + '"' + (set.default === code ? ' checked' : '') + (on ? '' : ' disabled') + '> default</label></td>' +
        '<td><button class="button-link" data-lang-edit="' + esc(code) + '">Edit translations</button></td></tr>';
    }).join('');
    var pack = state.langPack || { pack: {}, overrides: {} };
    var filter = (state.langFilter || '').toLowerCase();
    var strings = L.keys.filter(function (k) {
      if (!filter) return true;
      var v = pack.overrides[k] || pack.pack[k] || '';
      return k.toLowerCase().indexOf(filter) >= 0 || v.toLowerCase().indexOf(filter) >= 0;
    }).map(function (k) {
      var ov = pack.overrides[k] || '';
      var base = pack.pack[k] || (state.langEdit === 'en' ? k : '');
      return '<tr><td class="af-src">' + esc(k) + '</td><td><input type="text" class="widefat" data-lang-str="' + esc(k) + '" value="' + esc(ov) + '" placeholder="' + esc(base || 'not translated — English is used') + '"' + (L.available[state.langEdit] && L.available[state.langEdit].rtl ? ' dir="rtl"' : '') + '></td></tr>';
    }).join('');
    var a = L.available[state.langEdit] || { name: state.langEdit };
    return '<div class="af-head-row"><div><h2>Languages</h2><p class="af-hint">Customers pick a language from the sidebar or Settings in the app. Urdu and Arabic switch the whole app to right-to-left. Product content follows WPML / Polylang if installed.</p></div>' +
      '<button class="button button-primary af-lang-save">Save languages</button></div>' +
      '<table class="widefat striped af-lang-table"><tbody>' + rows + '</tbody></table>' +
      '<p><button class="button af-lang-add">+ Add another language</button></p>' +
      '<h3 class="af-sub">Translations — ' + esc(a.name) + '</h3>' +
      '<p class="af-hint">Built-in text is shown as grey placeholder. Type only where you want to change it. ' + L.keys.length + ' app texts.</p>' +
      '<input type="search" class="af-lang-filter" placeholder="Search text…" value="' + esc(state.langFilter || '') + '">' +
      '<div class="af-lang-scroll"><table class="widefat striped af-lang-strings"><thead><tr><th>English</th><th>' + esc(a.name) + '</th></tr></thead><tbody>' + strings + '</tbody></table></div>';
  }

  function fmtDate(ts) {
    if (!ts) return '';
    var d = new Date(ts * 1000);
    return d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  function renderDesigns() {
    var cards = state.designs.map(function (d) {
      var editing = d.id === state.design.id;
      return '<div class="af-dcard' + (d.active ? ' live' : '') + (editing ? ' editing' : '') + '">' +
        '<div class="af-dcard-top" style="background:' + esc(d.appbar_bg || d.colors[2] || '#fff') + '">' +
        (d.logo ? '<img src="' + esc(d.logo) + '">' : '<span style="color:' + esc(d.colors[0]) + '">' + esc(d.name.charAt(0)) + '</span>') +
        '<div class="af-scheme-sw">' + d.colors.map(function (c) { return '<i style="background:' + esc(c) + '"></i>'; }).join('') + '</div></div>' +
        '<div class="af-dcard-body"><strong>' + esc(d.name) + '</strong>' +
        (d.active ? '<span class="af-badge af-badge-live">● Live</span>' : '') + (editing ? '<span class="af-badge">Editing</span>' : '') +
        '<small>' + (d.source ? 'From template “' + esc(d.source) + '” · ' : '') + d.screens + ' screen(s) · updated ' + esc(fmtDate(d.updated)) + '</small>' +
        '<div class="af-row-btns">' +
        (editing ? '' : '<button class="button" data-design-edit="' + esc(d.id) + '">Edit</button>') +
        (d.active ? '' : '<button class="button button-primary" data-design-activate="' + esc(d.id) + '">Activate</button>') +
        '<button class="button" data-design-dup="' + esc(d.id) + '">Duplicate</button>' +
        '<button class="button-link" data-design-rename="' + esc(d.id) + '">Rename</button>' +
        (d.active ? '' : '<button class="button-link af-danger" data-design-del="' + esc(d.id) + '">Delete</button>') +
        '</div></div></div>';
    }).join('');
    return '<div class="af-head-row"><div><h2>Designs</h2><p class="af-hint">Keep several designs (e.g. Normal, Eid, Black Friday). Only the <strong>Live</strong> design is shown in the app — click <strong>Activate</strong> to switch instantly, no app update needed.</p></div>' +
      '<button class="button button-primary af-design-new">+ New blank design</button></div>' +
      '<div class="af-dgrid">' + cards + '</div>';
  }

  function renderTemplates() {
    if (!state.templates) return '<h2>Templates</h2><div class="af-p-loading">Loading templates…</div>';
    var cards = state.templates.map(function (t) {
      var busy = state.importing === t.slug;
      return '<div class="af-tcard">' +
        '<div class="af-tcard-img"><img src="' + esc(t.preview) + '" alt=""></div>' +
        '<div class="af-dcard-body"><strong>' + esc(t.name) + '</strong><small class="af-industry">' + esc(t.industry) + '</small>' +
        '<p>' + esc(t.description) + '</p>' +
        '<div class="af-scheme-sw">' + t.colors.map(function (c) { return '<i style="background:' + esc(c) + '"></i>'; }).join('') + '</div>' +
        '<div class="af-row-btns">' +
        (busy ? '<span class="af-spinner"></span> Importing images…' :
          '<button class="button" data-tpl-import="' + esc(t.slug) + '"' + (state.importing ? ' disabled' : '') + '>Import</button>' +
          '<button class="button button-primary" data-tpl-import="' + esc(t.slug) + '" data-activate="1"' + (state.importing ? ' disabled' : '') + '>Import & activate</button>') +
        '</div></div></div>';
    }).join('');
    return '<h2>Templates</h2><p class="af-hint">Each template creates a <strong>new design</strong> with colors, app bar, onboarding, home + promo screens, and its banner/slider images are copied into your Media Library. Your current designs are not changed.</p>' +
      '<div class="af-tgrid">' + cards + '</div>';
  }

  function renderConnect() {
    var base = D.siteUrl;
    var snippet =
      "// lib/config/app_config.dart\n" +
      "class AppConfig {\n" +
      "  static const String baseUrl = '" + base + "';\n" +
      "  static const String apiKey = '" + state.keys.key + "';\n" +
      "  static const String apiSecret = '" + state.keys.secret + "';\n" +
      "}";
    return '<h2>Store settings</h2><p class="af-hint">These apply to every design.</p>' +
      settingField('guest_checkout', 'Allow guest checkout', 'toggle', null, { store: true }) +
      settingField('enable_register', 'Allow new registrations', 'toggle', null, { store: true }) +
      settingField('hide_out_of_stock', 'Hide out-of-stock products', 'toggle', null, { store: true }) +
      settingField('require_api_key', 'Require API key on app requests', 'toggle', 'Recommended. Blocks other apps/scripts from using your app API.', { store: true }) +
      '<h2>Contact details</h2><p class="af-hint">Used by the Contact us screen, the “Contact info” block and call / WhatsApp buttons.</p>' +
      '<div class="af-cols">' +
      settingField('contact.phone', 'Phone', 'text', null, { store: true }) +
      settingField('contact.whatsapp', 'WhatsApp number (with country code)', 'text', null, { store: true }) +
      settingField('contact.email', 'Email (contact form messages go here)', 'text', null, { store: true }) +
      settingField('contact.hours', 'Opening hours', 'text', null, { store: true }) +
      settingField('contact.facebook', 'Facebook URL', 'text', null, { store: true }) +
      settingField('contact.instagram', 'Instagram URL', 'text', null, { store: true }) + '</div>' +
      settingField('contact.address', 'Address', 'textarea', null, { store: true }) +
      settingField('contact.map_url', 'Google Maps link', 'text', null, { store: true }) +
      settingField('contact.form_enabled', 'Enable the in-app contact form', 'toggle', null, { store: true }) +
      '<h2>Connect the Flutter app</h2>' +
      '<p>Paste these values into <code>lib/config/app_config.dart</code> in the AppForge Flutter project. The app reads the <strong>live design</strong> from this site — saving or activating a design updates the app on next launch (or pull-to-refresh).</p>' +
      '<table class="widefat striped af-keys"><tbody>' +
      '<tr><th>Site URL</th><td><code>' + esc(base) + '</code></td></tr>' +
      '<tr><th>API base</th><td><code>' + esc(D.restUrl) + '</code></td></tr>' +
      '<tr><th>API key</th><td><code>' + esc(state.keys.key) + '</code></td></tr>' +
      '<tr><th>API secret</th><td><code>' + esc(state.keys.secret) + '</code></td></tr>' +
      '</tbody></table>' +
      '<pre class="af-snippet">' + esc(snippet) + '</pre>' +
      '<p><button class="button af-copy-snippet">Copy config</button> <button class="button af-regen">Regenerate keys</button></p>';
  }

  /* ---------------- media ---------------- */

  function pickMedia(cb) {
    var frame = wp.media({ title: 'Choose image', library: { type: 'image' }, multiple: false, button: { text: 'Use image' } });
    frame.on('select', function () {
      var a = frame.state().get('selection').first().toJSON();
      cb(a.sizes && a.sizes.large ? a.sizes.large.url : a.url);
    });
    frame.open();
  }

  /* ---------------- events ---------------- */

  function bind() {
    $root.on('click', '.af-tab', function () {
      state.tab = $(this).data('tab');
      renderTab();
    });

    $root.on('click', '.af-save', function () { save(); });
    $root.on('click', '.af-export', exportJson);
    $root.on('change', '.af-import input', importJson);

    // Screens
    $root.on('change', '.af-screen-select', function () {
      state.screen = $(this).val();
      state.selected = null;
      renderTab();
    });
    $root.on('click', '.af-screen-add', function () {
      var title = window.prompt('Screen title (e.g. Summer Sale)');
      if (!title) return;
      var slug = title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || uid();
      while (state.screens[slug]) slug += '-2';
      state.screens[slug] = { title: title, blocks: [] };
      state.screen = slug;
      state.selected = null;
      markDirty();
      renderTab();
    });
    $root.on('click', '.af-screen-rename', function () {
      var title = window.prompt('New title', state.screens[state.screen].title);
      if (!title) return;
      state.screens[state.screen].title = title;
      markDirty();
      renderTab();
    });
    $root.on('click', '.af-screen-delete', function () {
      if (!window.confirm('Delete this screen?')) return;
      delete state.screens[state.screen];
      state.screen = 'home';
      state.selected = null;
      markDirty();
      renderTab();
    });

    // Palette click-to-add
    $root.on('click', '.af-palette-item:not(.disabled)', function () {
      addBlock($(this).data('type'));
    });

    // Select / block toolbar
    $root.on('click', '.af-canvas .af-block', function (e) {
      var id = $(this).attr('data-block-id');
      var act = $(e.target).closest('[data-act]').data('act');
      if (act) {
        e.stopPropagation();
        return blockAction(id, act);
      }
      state.selected = id;
      $root.find('.af-block').removeClass('selected');
      $(this).addClass('selected');
      renderInspector();
    });

    // Inspector inputs
    $root.on('input change', '.af-inspector [data-path]', function (e) {
      var $el = $(this);
      var kind = $el.data('kind');
      if (e.type === 'input' && (kind === 'select' || kind === 'category' || kind === 'toggle' || kind === 'action-type')) return;
      var value = coerce(kind, $el);
      if ($el.is('select') && /\.value$/.test($el.data('path')) && $el.closest('.af-action').length) {
        // category select inside action editor keeps the id as string
        value = String($el.val());
      }
      if (kind === 'action-type') {
        var blk = findBlock(state.selected);
        if (blk) setPath(blk, $el.data('path').replace(/\.type$/, '.value'), '');
      }
      setBlockValue($el.data('path'), value, kind === 'action-type' || (kind === 'image' && e.type === 'change'));
      if (kind === 'color') $el.siblings('[type=color]').val(value || '#ffffff');
    });
    $root.on('change', '.af-inspector [data-kind="icon"], .af-form [data-kind="select"]', function () {
      $(this).siblings('.af-mi').text($(this).val());
    });
    $root.on('input', '.af-inspector [data-color-for]', function () {
      var path = $(this).data('color-for');
      $(this).siblings('[data-path]').val(this.value);
      setBlockValue(path, this.value, false);
    });
    $root.on('click', '.af-inspector [data-clear]', function (e) {
      e.preventDefault();
      setBlockValue($(this).data('clear'), '', true);
    });
    $root.on('click', '.af-inspector .af-media', function (e) {
      e.preventDefault();
      var path = $(this).data('media');
      pickMedia(function (url) { setBlockValue(path, url, true); });
    });
    $root.on('click', '[data-item-add]', function (e) {
      e.preventDefault();
      var block = findBlock(state.selected);
      var path = $(this).data('item-add');
      var items = getPath(block, path) || [];
      var def = {};
      try { def = JSON.parse($(this).attr('data-item-default') || '{}'); } catch (err) { def = {}; }
      items.push(def);
      setBlockValue(path, items, true);
    });
    $root.on('click', '[data-item-del]', function (e) {
      e.preventDefault();
      var block = findBlock(state.selected);
      var path = $(this).data('item-del');
      var items = getPath(block, path) || [];
      items.splice($(this).data('i'), 1);
      setBlockValue(path, items, true);
    });
    $root.on('click', '[data-item-move]', function (e) {
      e.preventDefault();
      var block = findBlock(state.selected);
      var path = $(this).data('item-move');
      var items = getPath(block, path) || [];
      var i = $(this).data('i');
      var j = i + $(this).data('dir');
      if (j < 0 || j >= items.length) return;
      items.splice(j, 0, items.splice(i, 1)[0]);
      setBlockValue(path, items, true);
    });

    // Design settings (path based: "appbar.bg_color", "onboarding.slides.0.title" …)
    $root.on('input change', '[data-setting]', function (e) {
      var $el = $(this);
      var key = $el.data('setting');
      var kind = $el.data('kind');
      if (e.type === 'input' && (kind === 'select' || kind === 'toggle')) return;
      var v = kind === 'toggle' ? $el.is(':checked') : kind === 'number' ? Number($el.val()) : $el.val();
      setPath(state.settings, key, v);
      if (kind === 'color') {
        $el.siblings('code').text(v);
        if (/_color$/.test(key) && key.indexOf('.') < 0 && key !== 'nav_bg_color') state.settings.color_scheme = 'custom';
      }
      markDirty();
      // Structural changes re-render the form; typing just repaints the phone.
      if (e.type === 'change' && (kind === 'select' || kind === 'toggle') && /^(appbar\.(title_type|search_bar)|onboarding\.)/.test(key)) {
        renderTab();
      } else {
        renderCanvas();
      }
    });
    $root.on('input change', '[data-store]', function () {
      var $el = $(this);
      var kind = $el.data('kind');
      setPath(state.store, $el.data('store'), kind === 'toggle' ? $el.is(':checked') : kind === 'number' ? Number($el.val()) : $el.val());
      state.storeDirty = true;
      markDirty();
    });
    $root.on('click', '[data-setting-media]', function (e) {
      e.preventDefault();
      var key = $(this).data('setting-media');
      pickMedia(function (url) { setPath(state.settings, key, url); markDirty(); renderTab(); });
    });
    $root.on('click', '[data-setting-clear]', function (e) {
      e.preventDefault();
      setPath(state.settings, $(this).data('setting-clear'), '');
      markDirty();
      renderTab();
    });
    $root.on('click', '[data-scheme]', function () {
      var c = D.schemes[$(this).data('scheme')];
      Object.keys(c).forEach(function (k) { if (k !== 'label') state.settings[k] = c[k]; });
      state.settings.color_scheme = $(this).data('scheme');
      state.settings.nav_bg_color = c.surface_color;
      markDirty();
      renderTab();
    });
    $root.on('click', '.af-appbar-match', function () {
      state.settings.appbar.bg_color = state.settings.primary_color;
      state.settings.appbar.fg_color = state.settings.on_primary_color || '#FFFFFF';
      markDirty();
      renderTab();
    });
    $root.on('click', '.af-appbar-light', function () {
      state.settings.appbar.bg_color = state.settings.surface_color || '#FFFFFF';
      state.settings.appbar.fg_color = state.settings.text_color;
      markDirty();
      renderTab();
    });

    // Onboarding slides
    $root.on('click', '.af-onb-add', function () {
      state.settings.onboarding.slides.push({ image: '', title: 'Welcome', text: 'Tell customers why they will love your app.' });
      state.onbIndex = state.settings.onboarding.slides.length - 1;
      markDirty();
      renderTab();
    });
    $root.on('click', '[data-onb-del]', function (e) {
      e.stopPropagation();
      state.settings.onboarding.slides.splice($(this).data('onb-del'), 1);
      state.onbIndex = 0;
      markDirty();
      renderTab();
    });
    $root.on('click', '[data-onb-move]', function (e) {
      e.stopPropagation();
      var sl = state.settings.onboarding.slides;
      var i = $(this).data('onb-move');
      var j = i + $(this).data('dir');
      if (j < 0 || j >= sl.length) return;
      sl.splice(j, 0, sl.splice(i, 1)[0]);
      state.onbIndex = j;
      markDirty();
      renderTab();
    });
    $root.on('focusin click', '[data-onb-focus]', function () {
      var i = $(this).data('onb-focus');
      if (state.onbIndex === i) return;
      state.onbIndex = i;
      $root.find('[data-onb-focus]').removeClass('af-item-focus');
      $(this).addClass('af-item-focus');
      renderCanvas();
    });
    $root.on('click', '.af-onb-foot .af-p-button', function () {
      var n = (state.settings.onboarding.slides || []).length;
      state.onbIndex = n ? (state.onbIndex + 1) % n : 0;
      renderTab();
    });


    // Preview toggles
    $root.on('click', '[data-preview-mode]', function () {
      state.previewDark = $(this).data('preview-mode') === 'dark';
      $root.find('[data-preview-mode]').removeClass('on').filter(this).addClass('on');
      renderCanvas();
    });
    $root.on('click', '[data-preview-drawer]', function () {
      state.previewDrawer = !state.previewDrawer;
      $(this).toggleClass('on', state.previewDrawer);
      paintDrawer();
    });
    $root.on('click', '.af-drawer-layer', function (e) {
      if (e.target === this) { state.previewDrawer = false; $root.find('[data-preview-drawer]').removeClass('on'); paintDrawer(); }
    });
    $root.on('click', '[data-menu-tab]', function () {
      state.menuTab = $(this).data('menu-tab');
      state.previewDrawer = state.menuTab === 'drawer';
      renderTab();
    });

    // Generic settings lists (bottom_nav, drawer.items)
    $root.on('click', '[data-list-add]', function () {
      var path = $(this).data('list-add');
      var list = getPath(state.settings, path) || [];
      list.push(path === 'bottom_nav' ? { label: 'New', icon: 'store', action: { type: 'route', value: 'products' } } : { label: 'New link', icon: 'info', action: { type: 'route', value: 'contact' } });
      setPath(state.settings, path, list);
      markDirty();
      renderTab();
    });
    $root.on('click', '[data-list-del]', function () {
      var path = $(this).data('list-del');
      var list = getPath(state.settings, path) || [];
      if (path === 'bottom_nav' && list.length <= 2) return toast('Keep at least 2 tabs', true);
      list.splice($(this).data('i'), 1);
      markDirty();
      renderTab();
    });
    $root.on('click', '[data-list-move]', function () {
      var list = getPath(state.settings, $(this).data('list-move')) || [];
      var i = $(this).data('i');
      var j = i + $(this).data('dir');
      if (j < 0 || j >= list.length) return;
      list.splice(j, 0, list.splice(i, 1)[0]);
      markDirty();
      renderTab();
    });
    $root.on('click', '.af-quick-links', function () {
      var items = state.settings.drawer.items;
      var want = [
        { label: 'Track order', icon: 'local_shipping', action: { type: 'route', value: 'track_order' } },
        { label: 'About us', icon: 'info', action: { type: 'screen', value: 'about' } },
        { label: 'Contact us', icon: 'support_agent', action: { type: 'route', value: 'contact' } },
      ];
      want.forEach(function (w) {
        var exists = items.some(function (x) { return x.action && x.action.type === w.action.type && x.action.value === w.action.value; });
        if (!exists) items.push(w);
      });
      if (!state.screens.about) state.screens.about = makeScreen('about');
      markDirty();
      renderTab();
    });
    $root.on('click', '.af-dark-preset', function () {
      var presets = {
        slate: { background_color: '#0B1120', surface_color: '#151E2E', text_color: '#E5E7EB', muted_color: '#94A3B8', border_color: '#263244', appbar_bg_color: '#151E2E', appbar_fg_color: '#F1F5F9', nav_bg_color: '#151E2E', nav_inactive_color: '#64748B' },
        black: { background_color: '#000000', surface_color: '#121212', text_color: '#F5F5F5', muted_color: '#A3A3A3', border_color: '#262626', appbar_bg_color: '#000000', appbar_fg_color: '#FFFFFF', nav_bg_color: '#0A0A0A', nav_inactive_color: '#737373' },
        warm: { background_color: '#1C1917', surface_color: '#292524', text_color: '#F5F5F4', muted_color: '#A8A29E', border_color: '#44403C', appbar_bg_color: '#292524', appbar_fg_color: '#FAFAF9', nav_bg_color: '#292524', nav_inactive_color: '#78716C' },
      };
      $.extend(state.settings.dark, presets[$(this).data('dark')]);
      state.previewDark = true;
      markDirty();
      renderTab();
    });

    // Pages
    $root.on('click', '[data-screen-open]', function () {
      state.screen = $(this).data('screen-open');
      state.selected = null;
      renderTab();
    });
    $root.on('click', '.af-page-new', function () {
      var key = $root.find('.af-page-tpl').val();
      var title = window.prompt('Page title', PAGE_TEMPLATES[key].title);
      if (!title) return;
      var slug = title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || uid();
      while (state.screens[slug]) slug += '-2';
      var sc = makeScreen(key);
      sc.title = title;
      state.screens[slug] = sc;
      state.screen = slug;
      state.selected = null;
      markDirty();
      renderTab();
    });
    $root.on('click', '[data-screen-to]', function () {
      var where = $(this).data('screen-to');
      var item = { label: state.screens[state.screen].title, icon: 'info', action: { type: 'screen', value: state.screen } };
      if (where === 'bottom') {
        if (state.settings.bottom_nav.length >= 5) return toast('Bottom menu already has 5 tabs', true);
        item.icon = 'store';
        state.settings.bottom_nav.push(item);
      } else {
        state.settings.drawer.items.push(item);
      }
      markDirty();
      toast('Added to ' + (where === 'bottom' ? 'bottom menu' : 'sidebar'));
    });

    // Languages
    $root.on('change', '[data-lang-enable]', function () {
      var code = $(this).data('lang-enable');
      var en = state.lang.settings.enabled;
      var i = en.indexOf(code);
      if (this.checked && i < 0) en.push(code);
      if (!this.checked && i >= 0) en.splice(i, 1);
      state.langDirty = true;
      renderTab();
    });
    $root.on('change', '[data-lang-default]', function () {
      state.lang.settings.default = $(this).data('lang-default');
      state.langDirty = true;
    });
    $root.on('click', '[data-lang-edit]', function () {
      var go = function () { loadPack($(this).data('lang-edit')); }.bind(this);
      if (state.langDirty && !window.confirm('Discard unsaved translation changes?')) return;
      state.langDirty = false;
      go();
    });
    $root.on('input', '[data-lang-str]', function () {
      state.langPack.overrides[$(this).attr('data-lang-str')] = $(this).val();
      state.langDirty = true;
    });
    $root.on('input', '.af-lang-filter', function () {
      state.langFilter = $(this).val();
      var pos = this.selectionStart;
      renderTab();
      var el = $root.find('.af-lang-filter')[0];
      el.focus();
      el.setSelectionRange(pos, pos);
    });
    $root.on('click', '.af-lang-add', function () {
      var code = (window.prompt('Language code (e.g. hi, fr, ps, sd)') || '').toLowerCase().replace(/[^a-z_-]/g, '');
      if (!code) return;
      if (state.lang.available[code]) return toast('That language already exists', true);
      var name = window.prompt('Language name (e.g. Hindi)') || code;
      var native = window.prompt('Name in that language (e.g. हिन्दी)', name) || name;
      var rtl = window.confirm('Is it written right-to-left (like Urdu/Arabic)?');
      state.lang.settings.custom.push({ code: code, name: name, native: native, rtl: rtl });
      state.lang.available[code] = { name: name, native: native, rtl: rtl, custom: true };
      state.lang.settings.enabled.push(code);
      state.langDirty = true;
      loadPack(code);
    });
    $root.on('click', '.af-lang-save', function () {
      var set = state.lang.settings;
      var strings = {};
      Object.keys(state.langPack.overrides || {}).forEach(function (k) { if (state.langPack.overrides[k]) strings[k] = state.langPack.overrides[k]; });
      api('/admin/languages', { method: 'POST', data: { enabled: set.enabled, default: set.default, custom: set.custom, code: state.langEdit, strings: strings } })
        .done(function (res) {
          state.lang = res;
          state.langDirty = false;
          toast('Languages saved — the app updates on next launch');
          renderTab();
        })
        .fail(function (xhr) { toast((xhr.responseJSON && xhr.responseJSON.message) || 'Save failed', true); });
    });

    // Designs
    $root.on('click', '[data-design-edit]', function () {
      openDesign($(this).data('design-edit'));
    });
    $root.on('click', '[data-design-activate], .af-activate-current', function () {
      var id = $(this).data('design-activate') || state.design.id;
      var go = function () {
        api('/admin/designs/' + id + '/activate', { method: 'POST' }).done(function (list) {
          state.designs = list;
          refreshTopbar();
          if (state.tab === 'designs') renderTab();
          toast('Design is now live in the app');
        });
      };
      if (id === state.design.id && state.dirty) save(go); else go();
    });
    $root.on('click', '[data-design-dup]', function () {
      var id = $(this).data('design-dup');
      api('/admin/designs', { method: 'POST', data: { from: id } }).done(function (full) {
        refreshDesigns();
        toast('Duplicated as “' + full.name + '”');
      });
    });
    $root.on('click', '[data-design-rename]', function () {
      var id = $(this).data('design-rename');
      var d = state.designs.filter(function (x) { return x.id === id; })[0];
      var name = window.prompt('Design name', d ? d.name : '');
      if (!name) return;
      api('/admin/designs/' + id, { method: 'POST', data: { name: name } }).done(function () {
        if (id === state.design.id) state.design.name = name;
        refreshDesigns();
        refreshTopbar();
      });
    });
    $root.on('click', '[data-design-del]', function () {
      var id = $(this).data('design-del');
      if (!window.confirm('Delete this design permanently?')) return;
      api('/admin/designs/' + id + '/delete', { method: 'POST' }).done(function (list) {
        state.designs = list;
        if (id === state.design.id) {
          var live = list.filter(function (d) { return d.active; })[0];
          if (live) openDesign(live.id, true);
        } else {
          renderTab();
        }
        toast('Design deleted');
      }).fail(function (xhr) { toast((xhr.responseJSON && xhr.responseJSON.message) || 'Could not delete', true); });
    });
    $root.on('click', '.af-design-new', function () {
      var name = window.prompt('Name for the new design', 'New design');
      if (!name) return;
      api('/admin/designs', { method: 'POST', data: { name: name } }).done(function (full) {
        refreshDesigns();
        openDesign(full.id, true, full);
      });
    });

    // Templates
    $root.on('click', '[data-tpl-import]', function () {
      var slug = $(this).data('tpl-import');
      var activate = !!$(this).data('activate');
      if (state.dirty && !window.confirm('You have unsaved changes in “' + state.design.name + '”. Import anyway? (They will be lost.)')) return;
      state.importing = slug;
      renderTab();
      api('/admin/templates/' + slug + '/import', { method: 'POST', data: { activate: activate } })
        .done(function (full) {
          state.importing = null;
          loadDesign(full);
          refreshDesigns(function () {
            state.tab = 'builder';
            renderShell();
          });
          toast('Template imported' + (activate ? ' and live in the app' : ' — press Activate when ready'));
        })
        .fail(function (xhr) {
          state.importing = null;
          renderTab();
          toast((xhr.responseJSON && xhr.responseJSON.message) || 'Import failed', true);
        });
    });

    // Navigation
    $root.on('input change', '[data-nav-path]', function () {
      setPath(state.settings, $(this).data('nav-path'), $(this).val());
      $(this).siblings('.af-mi').text($(this).val());
      markDirty();
      renderCanvas();
    });
    $root.on('change', '.af-form [data-path^="nav:"]', function () {
      var path = $(this).data('path').slice(4);
      setPath(state.settings, path, String($(this).val()));
      markDirty();
      if (/\.type$/.test(path)) {
        setPath(state.settings, path.replace(/\.type$/, '.value'), '');
        renderTab();
      }
    });
    $root.on('input', '.af-form input[data-path^="nav:"]', function () {
      setPath(state.settings, $(this).data('path').slice(4), $(this).val());
      markDirty();
    });
    $root.on('click', '.af-nav-add', function () {
      state.settings.bottom_nav.push({ label: 'New', icon: 'store', action: { type: 'route', value: 'products' } });
      markDirty();
      renderTab();
    });
    $root.on('click', '[data-nav-del]', function () {
      if (state.settings.bottom_nav.length <= 2) return toast('Keep at least 2 tabs', true);
      state.settings.bottom_nav.splice($(this).data('nav-del'), 1);
      markDirty();
      renderTab();
    });
    $root.on('click', '[data-nav-move]', function () {
      var nav = state.settings.bottom_nav;
      var i = $(this).data('nav-move');
      var j = i + $(this).data('dir');
      if (j < 0 || j >= nav.length) return;
      nav.splice(j, 0, nav.splice(i, 1)[0]);
      markDirty();
      renderTab();
    });

    // Connection
    $root.on('click', '.af-copy-snippet', function () {
      var text = $root.find('.af-snippet').text();
      if (navigator.clipboard) navigator.clipboard.writeText(text).then(function () { toast('Copied'); });
    });
    $root.on('click', '.af-regen', function () {
      if (!window.confirm('Old keys stop working immediately. Apps using them must be rebuilt. Continue?')) return;
      api('/admin/regenerate-keys', { method: 'POST' }).done(function (keys) {
        state.keys = keys;
        renderTab();
        toast('New keys generated');
      });
    });

    window.addEventListener('beforeunload', function (e) {
      if (state.dirty) { e.preventDefault(); e.returnValue = ''; }
    });
  }

  function refreshDesigns(cb) {
    api('/admin/designs').done(function (list) {
      state.designs = list;
      refreshTopbar();
      if (state.tab === 'designs') renderTab();
      if (cb) cb();
    });
  }

  function openDesign(id, force, full) {
    if (!force && state.dirty && !window.confirm('Discard unsaved changes in “' + state.design.name + '”?')) return;
    var apply = function (d) {
      loadDesign(d);
      cache = {};
      state.tab = 'builder';
      renderShell();
      toast('Editing “' + d.name + '”');
    };
    if (full) return apply(full);
    api('/admin/designs/' + id).done(apply);
  }

  function save(after) {
    if (state.saving) return;
    state.saving = true;
    $root.find('.af-save').prop('disabled', true).text('Saving…');
    var reqs = [api('/admin/designs/' + state.design.id, { method: 'POST', data: { name: state.design.name, settings: state.settings, screens: state.screens } })];
    if (state.storeDirty) reqs.push(api('/admin/store', { method: 'POST', data: { store: state.store } }));
    $.when.apply($, reqs)
      .done(function (res) {
        var full = $.isArray(res) ? res[0] : res;
        if (full && full.settings) state.settings = $.extend(true, {}, full.settings);
        if (full && full.screens) state.screens = full.screens;
        if (!state.screens[state.screen]) state.screen = 'home';
        state.dirty = false;
        state.storeDirty = false;
        $root.find('.af-save').text('Saved');
        $root.find('.af-status').text('All changes saved');
        toast(isActive() ? 'Saved — the app will show the changes' : 'Saved. This design is not live — press Activate to show it in the app');
        refreshDesigns();
        if (typeof after === 'function') after();
      })
      .fail(function (xhr) {
        $root.find('.af-save').prop('disabled', false).text('Save changes');
        toast((xhr.responseJSON && xhr.responseJSON.message) || 'Save failed', true);
      })
      .always(function () { state.saving = false; });
  }

  function exportJson() {
    var blob = new Blob([JSON.stringify({ settings: state.settings, screens: state.screens }, null, 2)], { type: 'application/json' });
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'appforge-design.json';
    a.click();
  }

  function importJson(e) {
    var file = e.target.files[0];
    if (!file) return;
    var reader = new FileReader();
    reader.onload = function () {
      try {
        var data = JSON.parse(reader.result);
        if (data.settings) state.settings = $.extend({}, $.extend(true, {}, D.defaults), data.settings);
        if (data.screens && data.screens.home) state.screens = data.screens;
        state.screen = 'home';
        state.selected = null;
        markDirty();
        renderShell();
        toast('Design imported — press Save to publish');
      } catch (err) {
        toast('Invalid file', true);
      }
    };
    reader.readAsText(file);
    e.target.value = '';
  }

  $(function () {
    $root = $('#appforge-app');
    if (!$root.length) return;
    if (!state.screens.home) state.screens.home = { title: 'Home', blocks: [] };
    Object.keys(state.screens).forEach(function (k) {
      if (!$.isArray(state.screens[k].blocks)) state.screens[k].blocks = [];
    });
    if (!$.isArray(state.settings.bottom_nav)) state.settings.bottom_nav = [];
    renderShell();
    bind();
  });
})(jQuery);
