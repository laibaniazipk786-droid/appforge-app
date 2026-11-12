"""Extracts every tr('...') key from the Flutter app into appforge-builder/languages/en.json.
Run from the repo root: python3 tools/extract_strings.py"""
import glob, json, os, re

ROOT = os.path.join(os.path.dirname(__file__), '..')
APP = os.path.join(ROOT, 'appforge_app', 'lib')
OUT = os.path.join(ROOT, 'appforge-builder', 'languages', 'en.json')

keys = []


def add(k):
    k = k.replace("\\'", "'")
    if k and re.search(r'[A-Za-z]', k) and k not in keys:
        keys.append(k)


for f in sorted(glob.glob(os.path.join(APP, '**', '*.dart'), recursive=True)):
    s = open(f, encoding='utf-8').read()
    for m in re.finditer(r"""(?<![A-Za-z_])tr\((['"])((?:(?!\1)[^\\\n]|\\.)*)\1""", s):
        add(m.group(2))
    for m in re.finditer(r"""\b(_row|row|_section|_specRow)\('([^'$\n]+)'""", s):
        add(m.group(2))
    for m in re.finditer(r"""_tile\(context, Icons\.\w+, '([^']+)'""", s):
        add(m.group(1))
    for m in re.finditer(r"""_field\([^,]+, '([^'$\n]+)'""", s):
        add(m.group(1))
    for m in re.finditer(r"""\bfield\(_\w+, '([^'$\n]+)'""", s):
        add(m.group(1))
    for blk in re.findall(r"static const _\w+ = \{(.*?)\};", s, re.S):
        for v in re.findall(r":\s*'([^']+)'", blk):
            add(v)

# Labels that come from WordPress defaults / server responses.
for e in ['Home', 'Shop', 'Categories', 'Cart', 'Account', 'Track order', 'About us', 'Contact us', 'Blog',
          'Order placed', 'Processing', 'Shipped', 'Delivered', 'Search products...', 'Shop now', 'View all',
          'Skip', 'Next', 'Get started', 'Start shopping', 'New arrivals', 'On sale', 'Shop by category', 'Sale',
          'Best sellers', 'Featured', 'Trending now', 'Collections', 'Get in touch', 'Contact details', 'Wishlist']:
    add(e)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
json.dump({k: k for k in keys}, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(len(keys), 'strings ->', OUT)

# Built-in Urdu / Arabic packs.
try:
    import sys
    sys.path.insert(0, os.path.dirname(__file__))
    from translations import UR, AR
    for code, table in (('ur', UR), ('ar', AR)):
        path = os.path.join(os.path.dirname(OUT), code + '.json')
        json.dump({k: table[k] for k in keys if k in table}, open(path, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        missing = [k for k in keys if k not in table]
        print(code, len(keys) - len(missing), 'translated', ('missing: %s' % missing) if missing else '')
except ImportError:
    pass
