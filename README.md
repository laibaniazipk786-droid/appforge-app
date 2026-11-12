# AppForge — WordPress drag & drop app builder + Flutter app

Two parts that work together:

| Folder | What it is |
|---|---|
| `appforge-builder/` | WordPress plugin. Gives you a drag & drop builder in WP admin, and a REST API (`/wp-json/appforge/v1`) connected to WooCommerce. |
| `appforge_app/` | Flutter app (Android + iOS). It downloads the design from the plugin and draws the same screens with live WooCommerce data. |

**How it works:** you design in WordPress → press **Save** → the plugin stores the design as JSON → the app reads `/config` and renders every block (slider, categories, products…) with real data. No app update is needed when you change the design.

---

## 1. Install the plugin

1. Zip the `appforge-builder` folder (or use `appforge-builder.zip`).
2. WordPress → Plugins → Add New → Upload → Activate.
3. WooCommerce must be active (blog features work without it).
4. Open **WP Admin → AppForge**.

### Builder tabs
- **Screens**: drag blocks onto the phone, then click a block to edit it on the right. Make extra screens with **+ New** (for example "Eid Sale") and open them from any banner or button.
- **Colors & theme**: app name, logo, 10 one-click color schemes, and 13 adjustable colors (primary, text on primary, secondary, background, cards, text, muted, borders, price, sale badge, and three bottom-nav colors). Also font, corner radius and product card style.
- **App bar**: title (logo, name, logo + name or custom text), centered or left, background and icon colors, shadow, search/cart/account icons, and an optional full-width search bar.
- **Navigation**: 2–5 bottom tabs, each with a label, an icon and what it opens.
- **Onboarding**: welcome slides with image, title and text. Choose the layout (image on top or full-screen), colors and button labels. Raise **Version** to show the slides again to existing users.
- **Designs**: keep several saved designs (for example Normal, Eid, Black Friday). Edit, duplicate, rename or delete them. **Activate** makes a design live in the app straight away, with no app update.
- **Templates**: 6 ready-made designs (Cosmetics, Electronics, Fashion, Grocery, Furniture, Jewelry). **Import** creates a new design, copies the template's banner, slider, onboarding and logo images into your Media Library, and leaves your other designs unchanged.
- **Settings**: store options (guest checkout, registration, hide out-of-stock, API key) and the keys for the Flutter app.

### Adding your own template
Create `appforge-builder/templates/<slug>/template.json` and put its images in `images/`. Inside the JSON, write an image as `"{{img:my-banner.jpg}}"`; the importer uploads it to the Media Library. Add a `preview.jpg` (3:2) for the gallery card. `tools/gen_templates.py` is the script that generated the bundled templates.


### Blocks
Search bar, Slider, Banner, Heading (with "View all"), Text, Categories (horizontal/grid), Products (latest / featured / on sale / best selling / top rated / one category; grid / horizontal / list), Button, Blog posts, Spacer, Divider. Every block also has background color and padding.

### What a tap can open (actions)
Product, category, builder screen, app page (products, categories, cart, account, orders, blog, search), search keyword, blog post, URL in an in-app browser, URL in the external browser.

---

### New in 1.2
- **Sidebar (drawer)**, in Menus → Sidebar: the header shows login/sign up or the customer's name, the menu links each have an icon, categories are listed with icons, and there are a language switcher and a dark mode switch. Category icons are set under **Products → Categories → edit → "App icon"**.
- **Pages**, in the Screens tab: create app pages from templates (About us, Contact us, Help & FAQ, Sale) and add any page to the sidebar or bottom menu in one click. New blocks: **Rich text / HTML**, **Menu links**, **FAQ accordion** and **Contact info**.
- **Built-in screens**: Contact us (contact form, call, WhatsApp, email, map), Track order (order number + email; works for guests and reads Shipment Tracking plugins), WordPress page viewer, and app Settings.
- **Bottom menu**: label style (all, selected only, icons only); any tab can open a page, category, WordPress page or app screen.
- **Product page**, in the Product page tab: variation selector (auto color/image swatches, chips or dropdowns), SKU, stock left, share button, and a sticky buy bar. Swatches are set under **Products → Attributes → terms → "App swatch color / image"**.
- **Light & dark theme**, in Colors & theme: a full dark palette, the app's default mode, and an option to let customers switch. The phone preview has ☀ / ☾ buttons.
- **Languages**: English, Urdu and Arabic ship with 217 app texts translated. Urdu and Arabic switch the whole app to RTL. You can add any other language and edit every text. Product content follows WPML / Polylang.
- **Categories block**: four layouts (horizontal, grid, grid slider with rows and swipe pages, image cards slider), image or icon, item size and product count.

## 2. Build the APK on GitHub (no Flutter install needed)

1. Push this whole folder to a GitHub repository.
2. Go to **GitHub → your repo → Actions → "Build Android APK" → Run workflow**, then enter your site URL, API key, API secret, app name and package id. You can also save them once as repository secrets: `APPFORGE_SITE_URL`, `APPFORGE_API_KEY`, `APPFORGE_API_SECRET`, `APPFORGE_APP_NAME`, `APPFORGE_PACKAGE_ID`.
3. After about 8–12 minutes, download the APK from the run page under **Artifacts → android-apk**.

The APK is signed with a debug key, so it installs on any phone for testing. Publishing on the Play Store needs your own upload keystore (planned next).

## 3. Run the Flutter app locally

Requires Flutter 3.24 or newer.

```bash
cd appforge_app
flutter create --org com.yourstore --project-name appforge_app .   # adds android/ & ios/ folders, keeps lib/
flutter pub get
```

Open `lib/config/app_config.dart` and paste the values from **WP Admin → AppForge → App connection**:

```dart
static const String baseUrl   = 'https://yourstore.com/';
static const String apiKey    = 'afk_...';
static const String apiSecret = 'afs_...';
```

**Android:** in `android/app/src/main/AndroidManifest.xml`, add this line above `<application`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Then run it:

```bash
flutter run
```

Build for release: `flutter build appbundle` (Play Store) / `flutter build ipa` (App Store).

---

## 4. What the app does

- **Onboarding** on first launch, built in the admin panel.
- **App bar** (title, colors, icons, search bar) and the **full color scheme**, including price, sale and nav colors, all from the admin panel.
- Home and custom screens drawn from the **live design**, with pull-to-refresh to get the latest version.
- Bottom navigation from the builder, with a cart badge.
- Products: infinite list, sort, grid/list toggle, search with history, category browser.
- Product page: gallery, variable products (attribute chips, out-of-stock combinations crossed out), quantity, description, specs, reviews (read and write), related products.
- Cart: saved on the phone. Totals, coupons, tax and shipping are calculated **by WooCommerce itself**, so they match the website.
- Checkout:
  - billing and shipping address, country/state lists from WooCommerce, live shipping rates, payment methods, order note;
  - **COD / bank transfer / cheque** finish inside the app;
  - **any other gateway** (Stripe, PayPal, JazzCash, Easypaisa…) opens the secure WooCommerce payment page inside the app. Logged-in customers are signed in automatically for that page.
- Account: login, register, forgot password, edit profile and billing address, change password, delete account (required by Apple and Google).
- Orders: list, details, pay a pending order, cancel (pending / on-hold).
- Blog: list and post detail.
- Orders placed from the app get an **"App"** label in WooCommerce → Orders.

---

## 5. Security

- Every app request must send `X-AppForge-Key` and `X-AppForge-Secret`. You can turn this off on the App connection tab, which is not recommended.
- Logins use a JWT signed with a secret generated per site. It lasts 30 days, and changing the password ends all old logins.
- The cart runs in a memory-only WooCommerce session, so it never overwrites the customer's cart on the website.
- If your host strips the `Authorization` header, the app also sends the token in `X-AppForge-Token`.

---

## 6. REST API reference (`/wp-json/appforge/v1`)

| Method | Route | Purpose |
|---|---|---|
| GET | `/config` | Live design: theme, colors, app bar, onboarding, navigation, screens, currency |
| GET | `/products` | `page, per_page, category, search, source, orderby, include, min_price, max_price` |
| GET | `/products/{id}` | Full product with variations |
| GET/POST | `/products/{id}/reviews` | List / add review (login) |
| GET | `/categories` | `parent, limit, hide_empty` |
| GET | `/posts`, `/posts/{id}` | Blog |
| POST | `/cart/calculate` | `items, coupons, billing, shipping, shipping_method, payment_method` → totals, rates, gateways |
| POST | `/checkout` | Same as above plus `customer_note` → creates the order |
| GET | `/countries` | Allowed countries and states |
| GET | `/pages/{id}` | WordPress page content |
| POST | `/contact` | `name, email, phone, subject, message` (rate limited) |
| POST | `/orders/track` | `order, email`: status steps, notes, tracking numbers |
| GET | `/orders`, `/orders/{id}` | Customer orders (login) |
| POST | `/orders/{id}/cancel` | Cancel (login) |
| POST | `/auth/login`, `/auth/register`, `/auth/forgot` | Auth |
| GET/POST | `/auth/me` | Profile |
| POST | `/auth/password`, `/auth/delete` | Change password / delete account |
| GET/POST | `/admin/designs`, `/admin/designs/{id}` | List, create or duplicate, read, save designs (admin) |
| POST | `/admin/designs/{id}/activate`, `/delete` | Make live / delete (admin) |
| GET | `/admin/templates` | Template gallery (admin) |
| POST | `/admin/templates/{slug}/import` | `activate` (bool), imports images and creates a design (admin) |

### Extending
- Add a new block: hook the `appforge_blocks` filter in PHP (it then appears in the builder), and add a `case` for its type in `lib/builder/block_renderer.dart`.
- Other hooks: `appforge_config`, `appforge_products_query_args`, `appforge_native_gateways`, `appforge_cancellable_statuses`, `appforge_jwt_ttl`.

---

## Changelog
- **1.2.0**: sidebar with category icons, pages and new blocks, Contact / Track order / WordPress page screens, dark mode, languages with RTL (EN/UR/AR), product swatches, category sliders, GitHub Actions APK build.
- **1.1.0**: multiple designs with Activate, 6 templates with images that import into the Media Library, onboarding builder, app bar builder, extended color schemes.
- **1.0.0**: first release.

## Roadmap (next phases)
Wishlist, push notifications (OneSignal/FCM), Google/Apple/phone login, multi-language/RTL, onboarding screens, product filters (price/attributes), countdown and flash-sale blocks, vendors (Dokan/WCFM), points & rewards, native Stripe/JazzCash SDKs, dark mode.
