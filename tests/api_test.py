#!/usr/bin/env python3
"""End-to-end tests for the AppForge REST API against a real WordPress + WooCommerce site.

Usage: python3 tests/api_test.py http://127.0.0.1:8080 /tmp/fixtures.json
"""
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = sys.argv[1].rstrip('/') if len(sys.argv) > 1 else 'http://127.0.0.1:8080'
FIX = json.load(open(sys.argv[2] if len(sys.argv) > 2 else '/tmp/fixtures.json'))
KEYS = {'X-AppForge-Key': FIX['api_key'], 'X-AppForge-Secret': FIX['api_secret']}

results = []


def call(method, path, body=None, query=None, token=None, keys=True):
    q = {'rest_route': '/appforge/v1' + path}
    q.update(query or {})
    url = BASE + '/?' + urllib.parse.urlencode(q)
    headers = {'Content-Type': 'application/json', 'Accept': 'application/json'}
    if keys:
        headers.update(KEYS)
    if token:
        headers['X-AppForge-Token'] = token
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read().decode()
            status = r.status
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        status = e.code
    try:
        payload = json.loads(raw)
    except ValueError:
        payload = raw
    return status, payload


def test(name):
    def wrap(fn):
        t0 = time.time()
        try:
            fn()
            results.append((name, True, '', time.time() - t0))
        except AssertionError as e:
            results.append((name, False, str(e)[:400], time.time() - t0))
        except Exception as e:  # noqa
            results.append((name, False, '%s: %s' % (type(e).__name__, str(e)[:400]), time.time() - t0))
        return fn
    return wrap


def ok(status, payload, expect=200):
    assert status == expect, 'HTTP %s (expected %s): %s' % (status, expect, json.dumps(payload)[:400] if not isinstance(payload, str) else payload[:400])
    return payload


state = {}

# ---------------------------------------------------------------- security
@test('Request without API key is rejected (401)')
def _():
    s, p = call('GET', '/config', keys=False)
    ok(s, p, 401)


@test('Wrong API secret is rejected (401)')
def _():
    saved = dict(KEYS)
    KEYS['X-AppForge-Secret'] = 'afs_wrong'
    try:
        s, p = call('GET', '/products')
    finally:
        KEYS.update(saved)
    ok(s, p, 401)


@test('User-only endpoints need login (401)')
def _():
    for path in ['/orders', '/wishlist', '/auth/me']:
        s, p = call('GET', path)
        ok(s, p, 401)


# ---------------------------------------------------------------- config
@test('Config: design, settings, screens, languages')
def _():
    c = ok(*call('GET', '/config'))
    for k in ['version', 'design_id', 'settings', 'screens', 'languages', 'currency', 'server_time']:
        assert k in c, 'missing ' + k
    assert c['woocommerce'] is True
    assert c['currency']['code'] == 'PKR', c['currency']
    assert 'home' in c['screens'] and c['screens']['home']['blocks'], 'home screen empty'
    s = c['settings']
    for k in ['colors', 'bottom_nav', 'drawer', 'product_page', 'appbar', 'onboarding']:
        assert k in s, 'settings missing ' + k
    assert abs(c['server_time'] - time.time()) < 300
    assert len(c['languages'].get('available', c['languages'].get('languages', []))) >= 1, c['languages']
    state['config'] = c


@test('Config: no secrets leak (keys / require_api_key)')
def _():
    raw = json.dumps(state['config'])
    assert FIX['api_secret'] not in raw, 'API secret leaked in config'
    assert 'require_api_key' not in state['config']['settings']


# ---------------------------------------------------------------- catalog
@test('Products: list with paging')
def _():
    p = ok(*call('GET', '/products', query={'per_page': 2}))
    assert p['total'] >= 4, p['total']
    assert len(p['items']) == 2
    assert p['total_pages'] >= 2
    for it in p['items']:
        for k in ['id', 'name', 'price', 'regular_price', 'image', 'in_stock', 'on_sale']:
            assert k in it, 'product missing ' + k


@test('Products: category filter')
def _():
    p = ok(*call('GET', '/products', query={'category': FIX['category']}))
    names = sorted(i['name'] for i in p['items'])
    assert names == ['Canon Pixma Printer', 'Epson L3250 Printer'], names


@test('Products: on_sale filter')
def _():
    p = ok(*call('GET', '/products', query={'on_sale': 1}))
    ids = [i['id'] for i in p['items']]
    assert ids == [FIX['sale']], ids


@test('Products: in_stock filter hides sold out')
def _():
    p = ok(*call('GET', '/products', query={'in_stock': 1, 'per_page': 50}))
    ids = [i['id'] for i in p['items']]
    assert FIX['oos'] not in ids and FIX['sale'] in ids, ids


@test('Products: price range filter')
def _():
    p = ok(*call('GET', '/products', query={'min_price': 20000, 'max_price': 35000, 'per_page': 50}))
    names = [i['name'] for i in p['items']]
    assert names == ['Canon Pixma Printer'], names


@test('Products: color attribute filter')
def _():
    p = ok(*call('GET', '/products', query={'filter_pa_color': 'red'}))
    ids = [i['id'] for i in p['items']]
    assert ids == [FIX['variable']], ids


@test('Products: search')
def _():
    p = ok(*call('GET', '/products', query={'search': 'epson'}))
    assert [i['id'] for i in p['items']] == [FIX['sale']]


@test('Products: sort by price low to high')
def _():
    p = ok(*call('GET', '/products', query={'orderby': 'price', 'order': 'asc', 'in_stock': 1, 'per_page': 50}))
    prices = [i['price'] for i in p['items']]
    assert prices == sorted(prices), prices


@test('Products: include ids (wishlist / recently viewed)')
def _():
    ids = [FIX['simple'], FIX['sale']]
    p = ok(*call('GET', '/products', query={'include': ','.join(map(str, ids))}))
    assert sorted(i['id'] for i in p['items']) == sorted(ids)


@test('Product detail: simple product on sale')
def _():
    p = ok(*call('GET', '/products/%d' % FIX['sale']))
    assert p['price'] == 45000 and p['regular_price'] == 50000 and p['on_sale'] is True, (p['price'], p['regular_price'])
    assert p['sku'] == 'EPS-L3250' and p['stock_quantity'] == 10
    assert p['categories'][0]['id'] == FIX['category']


@test('Product detail: variations + color swatches')
def _():
    p = ok(*call('GET', '/products/%d' % FIX['variable']))
    assert p['type'] == 'variable'
    assert p['price'] == 15000 and p['max_price'] == 16000, (p['price'], p['max_price'])
    assert len(p['variations']) == 2
    attr = p['attributes'][0]
    assert attr['key'] == 'attribute_pa_color' and attr['variation'] is True
    colors = {o['value']: o['color'] for o in attr['options']}
    assert colors == {'red': '#ff0000', 'blue': '#0000ff'}, colors
    state['variable'] = p


@test('Product detail: unknown id gives 404')
def _():
    s, p = call('GET', '/products/999999')
    ok(s, p, 404)


@test('Filters: price range + color terms')
def _():
    f = ok(*call('GET', '/products/filters'))
    assert f['price']['min'] <= 9000 and f['price']['max'] >= 50000, f['price']
    tax = {a['taxonomy']: a for a in f['attributes']}
    assert 'pa_color' in tax, f['attributes']
    terms = {t['slug']: t for t in tax['pa_color']['terms']}
    assert set(terms) == {'red', 'blue'} and terms['red']['color'] == '#ff0000'


@test('Categories: list with icon + count')
def _():
    c = ok(*call('GET', '/categories'))
    items = c if isinstance(c, list) else c.get('items', [])
    byname = {i['name']: i for i in items}
    assert 'Printers' in byname, list(byname)
    assert byname['Printers'].get('icon') == 'print', byname['Printers']
    assert byname['Printers'].get('count') == 2, byname['Printers']


@test('Posts + post detail')
def _():
    p = ok(*call('GET', '/posts'))
    assert any(i['id'] == FIX['post'] for i in p['items'])
    d = ok(*call('GET', '/posts/%d' % FIX['post']))
    assert 'First post' in d.get('content', ''), d.keys()


@test('Page content (About us)')
def _():
    d = ok(*call('GET', '/pages/%d' % FIX['page']))
    assert 'We sell printers' in json.dumps(d)


# ---------------------------------------------------------------- cart
CART = lambda extra=None: dict({
    'items': [
        {'product_id': FIX['sale'], 'quantity': 2},
        {'product_id': FIX['variable'], 'variation_id': FIX['var_blue'], 'quantity': 1, 'variation': {'attribute_pa_color': 'blue'}},
    ],
    'billing': {'first_name': 'Ali', 'last_name': 'Khan', 'email': 'ali@example.com', 'phone': '03001234567',
                'address_1': 'Mall Road 1', 'city': 'Lahore', 'state': 'PB', 'postcode': '54000', 'country': 'PK'},
}, **(extra or {}))


@test('Cart: totals, shipping rates, payment methods')
def _():
    c = ok(*call('POST', '/cart/calculate', CART()))
    assert c['errors'] == [], c['errors']
    assert c['totals']['subtotal'] == 106000, c['totals']
    assert c['shipping_rates'], 'no shipping rates'
    ids = [g['id'] for g in c['payment_methods']]
    assert 'cod' in ids and 'bacs' in ids, ids
    state['rate'] = c['shipping_rates'][0]['id']


@test('Cart: coupon WELCOME10 gives 10% off')
def _():
    c = ok(*call('POST', '/cart/calculate', CART({'coupons': ['welcome10'], 'shipping_method': state['rate']})))
    assert c['coupons'] == ['welcome10'], c['coupons']
    assert c['totals']['discount'] == 10600, c['totals']
    assert c['totals']['total'] == 106000 - 10600 + 200, c['totals']


@test('Cart: wrong coupon returns a message')
def _():
    c = ok(*call('POST', '/cart/calculate', CART({'coupons': ['NOPE123']})))
    assert c['coupon_errors'] and c['coupon_errors'][0]['message'], c['coupon_errors']


@test('Cart: sold-out product is reported')
def _():
    c = ok(*call('POST', '/cart/calculate', {'items': [{'product_id': FIX['oos'], 'quantity': 1}]}))
    assert c['errors'] and c['errors'][0]['product_id'] == FIX['oos'], c['errors']


@test('Checkout: missing fields rejected')
def _():
    body = CART({'payment_method': 'cod', 'shipping_method': state['rate']})
    body['billing'] = dict(body['billing'], city='')
    s, p = call('POST', '/checkout', body)
    ok(s, p, 400)


@test('Checkout: guest Cash on delivery order')
def _():
    p = ok(*call('POST', '/checkout', CART({'payment_method': 'cod', 'shipping_method': state['rate'], 'coupons': ['WELCOME10']})))
    assert p['status'] == 'success', p
    o = p['order']
    assert o['status'] in ('processing', 'on-hold'), o['status']
    assert float(o['total']) == 106000 - 10600 + 200, o['total']
    state['guest_order'] = o


@test('Track order by number + email')
def _():
    o = state['guest_order']
    t = ok(*call('POST', '/orders/track', {'order': str(o.get('number', o['id'])), 'email': 'ali@example.com'}))
    assert t.get('status') == state['guest_order']['status'], t
    s, p = call('POST', '/orders/track', {'order': str(o['id']), 'email': 'wrong@example.com'})
    ok(s, p, 404)


@test('Contact form validation')
def _():
    s, p = call('POST', '/contact', {'name': '', 'email': 'bad', 'message': ''})
    ok(s, p, 400)


# ---------------------------------------------------------------- account
EMAIL = 'sara%d@example.com' % int(time.time())


@test('Register new customer returns token')
def _():
    p = ok(*call('POST', '/auth/register', {'email': EMAIL, 'password': 'secret123', 'first_name': 'Sara', 'last_name': 'Ahmed'}))
    assert p['token'] and p['user']['email'] == EMAIL, p
    state['token'] = p['token']


@test('Register duplicate email rejected')
def _():
    s, p = call('POST', '/auth/register', {'email': EMAIL, 'password': 'secret123'})
    ok(s, p, 400)


@test('Login with email + wrong password')
def _():
    p = ok(*call('POST', '/auth/login', {'username': EMAIL, 'password': 'secret123'}))
    assert p['token']
    state['token'] = p['token']
    s, p = call('POST', '/auth/login', {'username': EMAIL, 'password': 'nope'})
    ok(s, p, 403)


@test('Profile: me + update')
def _():
    me = ok(*call('GET', '/auth/me', token=state['token']))
    assert me['email'] == EMAIL
    me = ok(*call('POST', '/auth/me', {'first_name': 'Sara B', 'billing': {'phone': '03111111111', 'city': 'Karachi'}}, token=state['token']))
    assert me['first_name'] == 'Sara B', me


@test('Bad token is rejected')
def _():
    s, p = call('GET', '/auth/me', token='abc.def.ghi')
    assert s in (401, 403), s


@test('Wishlist: add, toggle, sync, products')
def _():
    t = state['token']
    w = ok(*call('POST', '/wishlist', {'product_id': FIX['sale'], 'action': 'add'}, token=t))
    assert w['ids'] == [FIX['sale']], w
    w = ok(*call('POST', '/wishlist/sync', {'ids': [FIX['simple'], 999999]}, token=t))
    assert sorted(w['ids']) == sorted([FIX['sale'], FIX['simple']]), w
    w = ok(*call('POST', '/wishlist', {'product_id': FIX['simple'], 'action': 'toggle'}, token=t))
    assert w['ids'] == [FIX['sale']], w
    w = ok(*call('GET', '/wishlist', query={'products': 1}, token=t))
    assert [i['id'] for i in w['items']] == [FIX['sale']], w
    s, p = call('POST', '/wishlist', {'product_id': 999999, 'action': 'add'}, token=t)
    ok(s, p, 404)


@test('Logged-in checkout (bank transfer) + my orders')
def _():
    t = state['token']
    p = ok(*call('POST', '/checkout', CART({'payment_method': 'bacs', 'shipping_method': state['rate']}), token=t))
    o = p['order']
    assert o['status'] == 'on-hold', o['status']
    state['my_order'] = o
    lst = ok(*call('GET', '/orders', token=t))
    assert [i['id'] for i in lst['items']] == [o['id']], lst
    d = ok(*call('GET', '/orders/%d' % o['id'], token=t))
    assert d['can_cancel'] is True and len(d['items']) == 2, d


@test('Cannot open someone else\'s order')
def _():
    s, p = call('GET', '/orders/%d' % state['guest_order']['id'], token=state['token'])
    ok(s, p, 404)


@test('Cancel my order')
def _():
    o = ok(*call('POST', '/orders/%d/cancel' % state['my_order']['id'], token=state['token']))
    assert o['status'] == 'cancelled', o['status']
    s, p = call('POST', '/orders/%d/cancel' % state['my_order']['id'], token=state['token'])
    ok(s, p, 400)


@test('Write a review + read reviews')
def _():
    t = state['token']
    ok(*call('POST', '/products/%d/reviews' % FIX['simple'], {'rating': 5, 'content': 'Bohat acha printer'}, token=t))
    r = ok(*call('GET', '/products/%d/reviews' % FIX['simple']))
    items = r if isinstance(r, list) else r.get('items', [])
    assert any('Bohat acha' in json.dumps(i) for i in items), r
    s, p = call('POST', '/products/%d/reviews' % FIX['simple'], {'rating': 4, 'content': ''}, token=t)
    assert s == 400, (s, p)


@test('Change password')
def _():
    t = state['token']
    ok(*call('POST', '/auth/password', {'old_password': 'secret123', 'new_password': 'secret456'}, token=t))
    p = ok(*call('POST', '/auth/login', {'username': EMAIL, 'password': 'secret456'}))
    state['token'] = p['token']


@test('Delete account')
def _():
    ok(*call('POST', '/auth/delete', {'password': 'secret456'}, token=state['token']))
    s, p = call('POST', '/auth/login', {'username': EMAIL, 'password': 'secret456'})
    ok(s, p, 403)


# ---------------------------------------------------------------- report
passed = sum(1 for r in results if r[1])
print('\nAppForge API tests: %d/%d passed\n' % (passed, len(results)))
for name, good, msg, dur in results:
    print('%s %-55s %5.2fs %s' % ('PASS' if good else 'FAIL', name, dur, ('\n      ' + msg) if msg else ''))
with open('test-report.md', 'w') as f:
    f.write('## AppForge API tests: %d/%d passed\n\n| | Test | Time |\n|---|---|---|\n' % (passed, len(results)))
    for name, good, msg, dur in results:
        f.write('| %s | %s%s | %.2fs |\n' % ('✅' if good else '❌', name, (' — `' + msg.replace('|', '/').replace('\n', ' ') + '`') if msg else '', dur))
sys.exit(0 if passed == len(results) else 1)
