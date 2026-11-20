import '../core/api.dart';
import '../models/models.dart';

/// Typed access to every AppForge endpoint.
class Repo {
  Repo._();

  static final Api _api = Api.instance;

  /* -------- Config -------- */

  static Future<Map<String, dynamic>> configRaw() async => toMap(await _api.get('/config'));

  /* -------- Catalog -------- */

  static Future<Paged<Product>> products({
    int page = 1,
    int perPage = 10,
    int? category,
    String? search,
    String? source,
    String? orderby,
    List<int>? include,
    Map<String, dynamic>? filters,
  }) async {
    final res = toMap(await _api.get('/products', query: {
      ...?filters,
      'page': page,
      'per_page': perPage,
      'category': category,
      'search': search,
      'source': source,
      'orderby': orderby,
      'include': include?.join(','),
    }));
    return Paged(
      toList(res['items']).whereType<Map>().map((e) => Product.fromJson(Map<String, dynamic>.from(e))).toList(),
      toInt(res['total_pages']),
    );
  }

  static Future<FilterOptions> filterOptions({int? category}) async =>
      FilterOptions.fromJson(toMap(await _api.get('/products/filters', query: {'category': category})));

  static Future<Product> product(int id) async => Product.fromJson(toMap(await _api.get('/products/$id')));

  static Future<List<Review>> reviews(int productId) async => toList(await _api.get('/products/$productId/reviews'))
      .whereType<Map>()
      .map((e) => Review.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> addReview(int productId, int rating, String content) async {
    await _api.post('/products/$productId/reviews', body: {'rating': rating, 'content': content});
  }

  static Future<List<Category>> categories({int? parent, int? limit}) async =>
      toList(await _api.get('/categories', query: {'parent': parent, 'limit': limit}))
          .whereType<Map>()
          .map((e) => Category.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  static Future<Paged<Post>> posts({int page = 1, int perPage = 10}) async {
    final res = toMap(await _api.get('/posts', query: {'page': page, 'per_page': perPage}));
    return Paged(
      toList(res['items']).whereType<Map>().map((e) => Post.fromJson(Map<String, dynamic>.from(e))).toList(),
      toInt(res['total_pages']),
    );
  }

  static Future<Post> post(int id) async => Post.fromJson(toMap(await _api.get('/posts/$id')));

  static Future<WpPage> page(int id) async => WpPage.fromJson(toMap(await _api.get('/pages/$id')));

  static Future<String> contact(Map<String, dynamic> data) async =>
      toStr(toMap(await _api.post('/contact', body: data))['message']);

  static Future<TrackResult> track(String order, String email) async =>
      TrackResult.fromJson(toMap(await _api.post('/orders/track', body: {'order': order, 'email': email})));

  /* -------- Cart & checkout -------- */

  static Future<CartSummary> calculate(Map<String, dynamic> body) async =>
      CartSummary.fromJson(toMap(await _api.post('/cart/calculate', body: body)));

  static Future<Map<String, dynamic>> checkout(Map<String, dynamic> body) async => toMap(await _api.post('/checkout', body: body));

  static Future<List<Country>> countries() async {
    final res = toMap(await _api.get('/countries'));
    return toList(res['countries']).whereType<Map>().map((e) => Country.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /* -------- Orders -------- */

  static Future<Paged<Order>> orders({int page = 1}) async {
    final res = toMap(await _api.get('/orders', query: {'page': page}));
    return Paged(
      toList(res['items']).whereType<Map>().map((e) => Order.fromJson(Map<String, dynamic>.from(e))).toList(),
      toInt(res['total_pages']),
    );
  }

  static Future<Order> order(int id) async => Order.fromJson(toMap(await _api.get('/orders/$id')));

  static Future<Order> cancelOrder(int id) async => Order.fromJson(toMap(await _api.post('/orders/$id/cancel')));

  /* -------- Wishlist (logged-in customers) -------- */

  static List<int> _ids(dynamic res) => toList(toMap(res)['ids']).map((e) => toInt(e)).toList();

  static Future<List<int>> wishlist() async => _ids(await _api.get('/wishlist'));

  static Future<List<int>> wishlistUpdate(int productId, bool add) async =>
      _ids(await _api.post('/wishlist', body: {'product_id': productId, 'action': add ? 'add' : 'remove'}));

  static Future<List<int>> wishlistSync(List<int> ids) async => _ids(await _api.post('/wishlist/sync', body: {'ids': ids}));

  /* -------- Auth -------- */

  static Future<Map<String, dynamic>> login(String username, String password) async =>
      toMap(await _api.post('/auth/login', body: {'username': username, 'password': password}));

  static Future<Map<String, dynamic>> register(Map<String, dynamic> data) async => toMap(await _api.post('/auth/register', body: data));

  static Future<String> forgot(String login) async =>
      toStr(toMap(await _api.post('/auth/forgot', body: {'login': login}))['message']);

  static Future<AppUser> me() async => AppUser.fromJson(toMap(await _api.get('/auth/me')));

  static Future<AppUser> updateMe(Map<String, dynamic> data) async => AppUser.fromJson(toMap(await _api.post('/auth/me', body: data)));

  static Future<Map<String, dynamic>> changePassword(String oldPass, String newPass) async =>
      toMap(await _api.post('/auth/password', body: {'old_password': oldPass, 'new_password': newPass}));

  static Future<void> deleteAccount(String password) async {
    await _api.post('/auth/delete', body: {'password': password});
  }
}
