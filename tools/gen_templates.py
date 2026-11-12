"""Generates the bundled AppForge design templates (images + template.json).

Run: python3 tools/gen_templates.py
Output: appforge-builder/templates/<slug>/{template.json, images/*}
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), '..', 'appforge-builder', 'templates')
FONT_BOLD = '/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf'
FONT_SEMI = '/usr/share/fonts/truetype/google-fonts/Poppins-Medium.ttf'
FONT_REG = '/usr/share/fonts/truetype/google-fonts/Poppins-Regular.ttf'
SS = 2  # supersampling


def font(path, size):
    try:
        return ImageFont.truetype(path, size * SS)
    except OSError:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', size * SS)


def hx(h, a=255):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def mix(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3)) + (255,)


def gradient(w, h, c1, c2, angle=0.35):
    img = Image.new('RGBA', (w, h))
    px = img.load()
    for y in range(h):
        for x in range(0, w):
            t = (x / w) * (1 - angle) + (y / h) * angle
            px[x, y] = mix(c1, c2, t)
    return img


def fast_gradient(w, h, c1, c2):
    # Horizontal gradient stretched, then blended with a vertical one — fast enough at 2x.
    base = Image.new('RGBA', (256, 1))
    for x in range(256):
        base.putpixel((x, 0), mix(c1, c2, x / 255))
    g = base.resize((w, h))
    shade = Image.new('RGBA', (1, 256))
    for y in range(256):
        shade.putpixel((0, y), (0, 0, 0, int(40 * y / 255)))
    return Image.alpha_composite(g, shade.resize((w, h))).convert('RGB')


def blob(d, cx, cy, r, color):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)


def rrect(d, box, r, fill, outline=None, width=0):
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


def shadow_layer(size, shapes_fn, blur=18):
    layer = Image.new('RGBA', size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(layer)
    shapes_fn(sd, (0, 0, 0, 70))
    return layer.filter(ImageFilter.GaussianBlur(blur * SS))


# ---------------------------------------------------------------- product drawings
# Each takes (draw, cx, cy, s, pal) where s is a size unit (px at SS scale).

def draw_cosmetics(d, cx, cy, s, pal, v=0):
    p, sec, light = pal['p'], pal['s'], (255, 255, 255, 255)
    # perfume bottle
    bx = cx - s * 1.2
    rrect(d, [bx - s * .55, cy - s * .2, bx + s * .55, cy + s * 1.1], s * .22, mix(light, sec, .35))
    rrect(d, [bx - s * .45, cy - s * .1, bx + s * .45, cy + s * 1.0], s * .18, mix(light, sec, .15))
    rrect(d, [bx - s * .16, cy - s * .55, bx + s * .16, cy - s * .2], s * .05, p)
    rrect(d, [bx - s * .28, cy - s * .78, bx + s * .28, cy - s * .52], s * .08, mix(p, (0, 0, 0, 255), .2))
    # lipstick
    lx = cx + s * .15
    rrect(d, [lx - s * .3, cy + s * .25, lx + s * .3, cy + s * 1.1], s * .08, (30, 30, 30, 255))
    rrect(d, [lx - s * .24, cy - s * .15, lx + s * .24, cy + s * .3], s * .04, (212, 175, 55, 255))
    d.polygon([(lx - s * .2, cy - s * .15), (lx + s * .2, cy - s * .15), (lx + s * .2, cy - s * .75), (lx - s * .2, cy - s * .5)], fill=p)
    # compact / cream jar
    jx = cx + s * 1.35
    d.ellipse([jx - s * .65, cy + s * .55, jx + s * .65, cy + s * 1.15], fill=mix(sec, (0, 0, 0, 255), .1))
    rrect(d, [jx - s * .65, cy + s * .2, jx + s * .65, cy + s * .85], s * .1, sec)
    d.ellipse([jx - s * .65, cy - s * .05, jx + s * .65, cy + s * .45], fill=mix(light, sec, .3))
    d.ellipse([jx - s * .4, cy + s * .05, jx + s * .4, cy + s * .35], fill=light)


def draw_electronics(d, cx, cy, s, pal, v=0):
    p, sec = pal['p'], pal['s']
    dark = (17, 24, 39, 255)
    # phone
    px_ = cx - s * .9
    rrect(d, [px_ - s * .6, cy - s * 1.1, px_ + s * .6, cy + s * 1.15], s * .16, dark)
    screen = [px_ - s * .52, cy - s * 1.0, px_ + s * .52, cy + s * 1.05]
    rrect(d, screen, s * .12, p)
    for i in range(3):
        rrect(d, [px_ - s * .4, cy - s * .6 + i * s * .45, px_ + s * .4, cy - s * .3 + i * s * .45], s * .06, (255, 255, 255, 90))
    rrect(d, [px_ - s * .16, cy - s * .96, px_ + s * .16, cy - s * .9], s * .03, dark)
    # headphones
    hx_ = cx + s * .9
    d.arc([hx_ - s * .8, cy - s * 1.0, hx_ + s * .8, cy + s * .6], 180, 360, fill=(229, 231, 235, 255), width=int(s * .18))
    rrect(d, [hx_ - s * .95, cy - s * .2, hx_ - s * .45, cy + s * .7], s * .2, dark)
    rrect(d, [hx_ + s * .45, cy - s * .2, hx_ + s * .95, cy + s * .7], s * .2, dark)
    rrect(d, [hx_ - s * .88, cy - s * .1, hx_ - s * .58, cy + s * .6], s * .14, sec)
    rrect(d, [hx_ + s * .58, cy - s * .1, hx_ + s * .88, cy + s * .6], s * .14, sec)
    # watch
    wx, wy = cx + s * .05, cy + s * .75
    rrect(d, [wx - s * .18, wy - s * .65, wx + s * .18, wy + s * .65], s * .08, (55, 65, 81, 255))
    rrect(d, [wx - s * .34, wy - s * .36, wx + s * .34, wy + s * .36], s * .14, dark)
    rrect(d, [wx - s * .27, wy - s * .29, wx + s * .27, wy + s * .29], s * .1, sec)


def draw_fashion(d, cx, cy, s, pal, v=0):
    p, sec = pal['p'], pal['s']
    # dress
    dx = cx - s * .9
    d.polygon([(dx - s * .3, cy - s * 1.0), (dx + s * .3, cy - s * 1.0), (dx + s * .42, cy - s * .2), (dx + s * .95, cy + s * 1.15),
               (dx - s * .95, cy + s * 1.15), (dx - s * .42, cy - s * .2)], fill=sec)
    d.rectangle([dx - s * .42, cy - s * .3, dx + s * .42, cy - s * .15], fill=p)
    d.line([(dx - s * .3, cy - s * 1.0), (dx - s * .2, cy - s * 1.25)], fill=sec, width=int(s * .08))
    d.line([(dx + s * .3, cy - s * 1.0), (dx + s * .2, cy - s * 1.25)], fill=sec, width=int(s * .08))
    # handbag
    bx = cx + s * .9
    d.arc([bx - s * .5, cy - s * .55, bx + s * .5, cy + s * .35], 180, 360, fill=p, width=int(s * .1))
    rrect(d, [bx - s * .85, cy - s * .1, bx + s * .85, cy + s * 1.0], s * .18, p)
    rrect(d, [bx - s * .18, cy + s * .15, bx + s * .18, cy + s * .35], s * .05, sec)
    # sunglasses
    gx, gy = cx + s * .1, cy + s * 1.0
    d.ellipse([gx - s * .75, gy - s * .22, gx - s * .1, gy + s * .25], fill=(20, 20, 20, 255))
    d.ellipse([gx + s * .1, gy - s * .22, gx + s * .75, gy + s * .25], fill=(20, 20, 20, 255))
    d.line([(gx - s * .1, gy - s * .05), (gx + s * .1, gy - s * .05)], fill=(20, 20, 20, 255), width=int(s * .06))


def draw_grocery(d, cx, cy, s, pal, v=0):
    p, sec = pal['p'], pal['s']
    # basket
    rrect(d, [cx - s * 1.5, cy + s * .1, cx + s * 1.5, cy + s * 1.15], s * .2, (180, 120, 60, 255))
    for i in range(6):
        x = cx - s * 1.3 + i * s * .52
        d.line([(x, cy + s * .2), (x, cy + s * 1.05)], fill=(150, 95, 45, 255), width=int(s * .06))
    # fruits
    blob(d, cx - s * .8, cy - s * .05, s * .45, (220, 38, 38, 255))
    blob(d, cx - s * .05, cy - s * .25, s * .5, (249, 115, 22, 255))
    blob(d, cx + s * .8, cy - s * .05, s * .45, (234, 179, 8, 255))
    d.ellipse([cx - s * .78, cy - s * .65, cx - s * .5, cy - s * .45], fill=p)
    d.ellipse([cx - s * .02, cy - s * .9, cx + s * .3, cy - s * .68], fill=p)
    # carrot + leaves
    d.polygon([(cx + s * 1.2, cy - s * .5), (cx + s * 1.55, cy - s * .35), (cx + s * 1.9, cy + s * .9)], fill=(249, 115, 22, 255))
    d.ellipse([cx + s * 1.05, cy - s * .85, cx + s * 1.35, cy - s * .4], fill=p)
    d.ellipse([cx + s * 1.3, cy - s * .9, cx + s * 1.55, cy - s * .45], fill=mix(p, (0, 0, 0, 255), .2))


def draw_furniture(d, cx, cy, s, pal, v=0):
    p, sec = pal['p'], pal['s']
    # sofa
    rrect(d, [cx - s * 1.6, cy - s * .2, cx + s * 1.2, cy + s * .55], s * .2, sec)
    rrect(d, [cx - s * 1.5, cy - s * .7, cx + s * 1.1, cy + s * .1], s * .25, mix(sec, (255, 255, 255, 255), .15))
    rrect(d, [cx - s * 1.8, cy - s * .35, cx - s * 1.4, cy + s * .6], s * .18, mix(sec, (0, 0, 0, 255), .1))
    rrect(d, [cx + s * 1.0, cy - s * .35, cx + s * 1.4, cy + s * .6], s * .18, mix(sec, (0, 0, 0, 255), .1))
    for x in (cx - s * 1.5, cx + s * 1.25):
        d.rectangle([x, cy + s * .55, x + s * .1, cy + s * .85], fill=p)
    rrect(d, [cx - s * .9, cy - s * .55, cx - s * .3, cy - s * .05], s * .12, p)
    # floor lamp
    lx = cx + s * 1.9
    d.line([(lx, cy - s * .7), (lx, cy + s * .85)], fill=(40, 40, 40, 255), width=int(s * .06))
    d.polygon([(lx - s * .45, cy - s * .7), (lx + s * .45, cy - s * .7), (lx + s * .3, cy - s * 1.2), (lx - s * .3, cy - s * 1.2)], fill=p)
    d.ellipse([lx - s * .3, cy + s * .8, lx + s * .3, cy + s * .92], fill=(40, 40, 40, 255))
    # plant
    px_ = cx - s * 2.3
    rrect(d, [px_ - s * .3, cy + s * .3, px_ + s * .3, cy + s * .85], s * .08, p)
    for a in (-40, -10, 20, 50):
        r = math.radians(a - 90)
        ex, ey = px_ + math.cos(r) * s * .7, cy + s * .3 + math.sin(r) * s * .7
        d.line([(px_, cy + s * .3), (ex, ey)], fill=(34, 120, 70, 255), width=int(s * .05))
        d.ellipse([ex - s * .17, ey - s * .1, ex + s * .17, ey + s * .1], fill=(34, 139, 80, 255))


def draw_jewelry(d, cx, cy, s, pal, v=0):
    gold = (212, 175, 55, 255)
    p, sec = pal['p'], pal['s']
    # necklace arc with pearls
    for i in range(15):
        a = math.radians(200 + i * 10)
        x, y = cx - s * .4 + math.cos(a) * s * 1.4, cy - s * .9 - math.sin(a) * s * 1.3
        blob(d, x, y, s * .1, (250, 245, 235, 255))
    # pendant diamond
    dx, dy = cx - s * .4, cy + s * .55
    d.polygon([(dx - s * .35, dy - s * .15), (dx + s * .35, dy - s * .15), (dx, dy + s * .45)], fill=(186, 230, 253, 255))
    d.polygon([(dx - s * .35, dy - s * .15), (dx - s * .18, dy - s * .38), (dx + s * .18, dy - s * .38), (dx + s * .35, dy - s * .15)], fill=(224, 242, 254, 255))
    # ring
    rx, ry = cx + s * 1.25, cy + s * .55
    d.ellipse([rx - s * .55, ry - s * .45, rx + s * .55, ry + s * .6], outline=gold, width=int(s * .14))
    d.polygon([(rx - s * .25, ry - s * .45), (rx + s * .25, ry - s * .45), (rx + s * .15, ry - s * .75), (rx - s * .15, ry - s * .75)], fill=(224, 242, 254, 255))
    # box
    rrect(d, [cx + s * .55, cy - s * .95, cx + s * 1.95, cy - s * .1], s * .1, sec)
    rrect(d, [cx + s * .55, cy - s * 1.2, cx + s * 1.95, cy - s * .85], s * .08, mix(sec, (255, 255, 255, 255), .15))
    d.rectangle([cx + s * 1.18, cy - s * 1.2, cx + s * 1.32, cy - s * .1], fill=gold)


DRAW = {
    'cosmetics': draw_cosmetics, 'electronics': draw_electronics, 'fashion': draw_fashion,
    'grocery': draw_grocery, 'furniture': draw_furniture, 'jewelry': draw_jewelry,
}


# ---------------------------------------------------------------- compositions

def decorate(img, pal, seed):
    rnd = random.Random(seed)
    d = ImageDraw.Draw(img, 'RGBA')
    w, h = img.size
    for _ in range(5):
        r = rnd.randint(int(h * .15), int(h * .55))
        blob(d, rnd.randint(0, w), rnd.randint(0, h), r, (255, 255, 255, rnd.randint(12, 28)))
    for _ in range(18):
        r = rnd.randint(3, 7) * SS
        blob(d, rnd.randint(0, w), rnd.randint(0, h), r, (255, 255, 255, rnd.randint(60, 140)))


def text_block(img, x, y, eyebrow, title, sub, cta, colors, title_size=64, max_w=None):
    d = ImageDraw.Draw(img, 'RGBA')
    fg = colors.get('fg', (255, 255, 255, 255))
    if eyebrow:
        f = font(FONT_SEMI, 20)
        tw = d.textlength(eyebrow.upper(), font=f)
        rrect(d, [x, y, x + tw + 36 * SS, y + 40 * SS], 20 * SS, (255, 255, 255, 50))
        d.text((x + 18 * SS, y + 7 * SS), eyebrow.upper(), font=f, fill=fg)
        y += 60 * SS
    f = font(FONT_BOLD, title_size)
    for line in title.split('\n'):
        d.text((x, y), line, font=f, fill=fg)
        y += int(title_size * 1.12) * SS
    if sub:
        f = font(FONT_REG, 24)
        y += 6 * SS
        d.text((x, y), sub, font=f, fill=fg[:3] + (225,))
        y += 44 * SS
    if cta:
        f = font(FONT_SEMI, 22)
        tw = d.textlength(cta, font=f)
        y += 14 * SS
        rrect(d, [x, y, x + tw + 56 * SS, y + 58 * SS], 29 * SS, colors.get('cta_bg', (255, 255, 255, 255)))
        d.text((x + 28 * SS, y + 13 * SS), cta, font=f, fill=colors.get('cta_fg', (17, 17, 17, 255)))


def save(img, path, w, h, fmt='JPEG'):
    out = img.resize((w, h), Image.LANCZOS)
    if fmt == 'JPEG':
        out = out.convert('RGB')
        out.save(path, 'JPEG', quality=84, optimize=True, progressive=True)
    else:
        out.save(path, 'PNG', optimize=True)


def make_hero(kind, pal, c1, c2, eyebrow, title, sub, cta, path, seed, size=(1200, 600), title_size=76):
    w, h = size[0] * SS, size[1] * SS
    img = fast_gradient(w, h, c1, c2)
    decorate(img, pal, seed)
    s = h * .2
    cx, cy = w * .72, h * .5
    sh = shadow_layer((w, h), lambda sd, col: sd.ellipse([cx - s * 2.3, cy + s * 1.0, cx + s * 2.3, cy + s * 1.45], fill=col), blur=14)
    img = Image.alpha_composite(img.convert('RGBA'), sh).convert('RGB')
    d = ImageDraw.Draw(img, 'RGBA')
    blob(d, cx, cy, s * 2.05, (255, 255, 255, 40))
    DRAW[kind](d, cx, cy, s, pal)
    text_block(img, w * .065, h * (.2 if eyebrow else .26), eyebrow, title, sub, cta,
               {'cta_bg': (255, 255, 255, 255), 'cta_fg': pal['p']}, title_size=title_size)
    save(img, path, *size)


def make_banner(kind, pal, c1, c2, title, sub, path, seed):
    w, h = 1200 * SS, 420 * SS
    img = fast_gradient(w, h, c1, c2)
    decorate(img, pal, seed)
    d = ImageDraw.Draw(img, 'RGBA')
    s = h * .22
    cx, cy = w * .76, h * .5
    blob(d, cx, cy, s * 2.0, (255, 255, 255, 38))
    DRAW[kind](d, cx, cy, s, pal)
    text_block(img, w * .06, h * .22, None, title, sub, 'Shop now', {'cta_bg': (255, 255, 255, 255), 'cta_fg': pal['p']}, title_size=54)
    save(img, path, 1200, 420)


def make_onboard(kind, pal, bg, idx, path):
    w = h = 900 * SS
    img = Image.new('RGB', (w, h), hx(bg)[:3])
    d = ImageDraw.Draw(img, 'RGBA')
    rnd = random.Random(idx * 7 + len(kind))
    big = w * .36
    blob(d, w / 2, h / 2, big, pal['p'][:3] + (36,))
    blob(d, w / 2, h / 2, big * .78, pal['p'][:3] + (50,))
    for _ in range(10):
        r = rnd.randint(6, 16) * SS
        blob(d, rnd.randint(int(w * .1), int(w * .9)), rnd.randint(int(h * .1), int(h * .9)), r, pal['s'][:3] + (150,))
    s = w * .13
    if idx == 0:
        DRAW[kind](d, w / 2, h / 2, s, pal)
    elif idx == 1:
        # delivery box + truck-ish
        rrect(d, [w / 2 - s * 1.6, h / 2 - s * .4, w / 2 + s * .6, h / 2 + s * 1.0], s * .12, pal['p'])
        rrect(d, [w / 2 + s * .6, h / 2, w / 2 + s * 1.6, h / 2 + s * 1.0], s * .2, mix(pal['p'], (0, 0, 0, 255), .2))
        rrect(d, [w / 2 + s * .8, h / 2 + s * .12, w / 2 + s * 1.3, h / 2 + s * .5], s * .08, (255, 255, 255, 200))
        for x in (w / 2 - s * 1.0, w / 2 + s * 1.05):
            blob(d, x, h / 2 + s * 1.05, s * .3, (31, 41, 55, 255))
            blob(d, x, h / 2 + s * 1.05, s * .12, (229, 231, 235, 255))
        rrect(d, [w / 2 - s * 1.1, h / 2 - s * 1.4, w / 2 - s * .1, h / 2 - s * .55], s * .08, pal['s'])
        d.line([(w / 2 - s * .6, h / 2 - s * 1.4), (w / 2 - s * .6, h / 2 - s * .55)], fill=(255, 255, 255, 200), width=int(s * .08))
        for i in range(3):
            d.line([(w / 2 - s * 2.6, h / 2 + i * s * .35), (w / 2 - s * 1.8, h / 2 + i * s * .35)], fill=pal['p'][:3] + (120,), width=int(s * .1))
    else:
        # secure payment card + shield
        rrect(d, [w / 2 - s * 1.7, h / 2 - s * .9, w / 2 + s * .9, h / 2 + s * .75], s * .2, pal['p'])
        d.rectangle([w / 2 - s * 1.7, h / 2 - s * .55, w / 2 + s * .9, h / 2 - s * .25], fill=(17, 24, 39, 200))
        rrect(d, [w / 2 - s * 1.45, h / 2 + s * .05, w / 2 - s * .85, h / 2 + s * .45], s * .06, (212, 175, 55, 255))
        sx, sy = w / 2 + s * 1.1, h / 2 + s * .5
        d.polygon([(sx, sy - s * .9), (sx + s * .8, sy - s * .55), (sx + s * .65, sy + s * .45), (sx, sy + s * .9), (sx - s * .65, sy + s * .45), (sx - s * .8, sy - s * .55)], fill=pal['s'])
        d.line([(sx - s * .35, sy), (sx - s * .05, sy + s * .3), (sx + s * .4, sy - s * .3)], fill=(255, 255, 255, 255), width=int(s * .16), joint='curve')
    save(img, path, 900, 900, 'JPEG')


def make_logo(name, pal, path, dark_bg=False):
    w, h = 640 * SS, 160 * SS
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, 'RGBA')
    r = 56 * SS
    blob(d, 80 * SS, h / 2, r, pal['p'])
    f = font(FONT_BOLD, 60)
    d.text((80 * SS, h / 2), name[0].upper(), font=f, fill=(255, 255, 255, 255), anchor='mm')
    tf = font(FONT_BOLD, 54)
    color = (255, 255, 255, 255) if dark_bg else pal['text']
    d.text((156 * SS, h / 2), name, font=tf, fill=color, anchor='lm')
    bbox = img.getbbox()
    img = img.crop((0, 0, min(w, bbox[2] + 20 * SS), h))
    out = img.resize((img.width // SS, img.height // SS), Image.LANCZOS)
    out.save(path, 'PNG', optimize=True)


def make_preview(tpl, folder):
    w, h = 900 * SS, 600 * SS
    pal = tpl['pal']
    img = fast_gradient(w, h, hx(tpl['settings']['background_color']), mix(hx(tpl['settings']['background_color']), pal['p'], .25))
    d = ImageDraw.Draw(img, 'RGBA')
    # phone mock
    pw, ph = 300 * SS, 560 * SS
    px_, py = w - pw - 60 * SS, 40 * SS
    rrect(d, [px_ - 12 * SS, py - 12 * SS, px_ + pw + 12 * SS, py + ph + 40 * SS], 46 * SS, (17, 17, 17, 255))
    rrect(d, [px_, py, px_ + pw, py + ph + 28 * SS], 36 * SS, hx(tpl['settings']['background_color']))
    ab = tpl['settings']['appbar']
    rrect(d, [px_, py, px_ + pw, py + 70 * SS], 36 * SS, hx(ab['bg_color']))
    d.rectangle([px_, py + 36 * SS, px_ + pw, py + 70 * SS], fill=hx(ab['bg_color']))
    d.text((px_ + pw / 2, py + 44 * SS), tpl['brand'], font=font(FONT_BOLD, 17), fill=hx(ab['fg_color']), anchor='mm')
    hero = Image.open(os.path.join(folder, 'slide-1.jpg')).convert('RGBA').resize((pw - 32 * SS, int((pw - 32 * SS) / 2)))
    mask = Image.new('L', hero.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, hero.width, hero.height], 16 * SS, fill=255)
    img.paste(hero, (px_ + 16 * SS, py + 86 * SS), mask)
    y = py + 86 * SS + hero.height + 18 * SS
    for i in range(4):
        blob(d, px_ + 50 * SS + i * 66 * SS, y + 28 * SS, 24 * SS, mix(pal['p'], (255, 255, 255, 255), .55 + i * .08))
    y += 76 * SS
    for col in range(2):
        x = px_ + 16 * SS + col * (pw / 2 - 8 * SS)
        rrect(d, [x, y, x + pw / 2 - 24 * SS, y + 150 * SS], 14 * SS, (255, 255, 255, 255))
        rrect(d, [x + 8 * SS, y + 8 * SS, x + pw / 2 - 32 * SS, y + 100 * SS], 10 * SS, mix(pal['s'], (255, 255, 255, 255), .5))
        rrect(d, [x + 10 * SS, y + 112 * SS, x + 90 * SS, y + 122 * SS], 5 * SS, (200, 200, 200, 255))
        rrect(d, [x + 10 * SS, y + 130 * SS, x + 60 * SS, y + 140 * SS], 5 * SS, pal['p'])
    # title
    d.text((60 * SS, 200 * SS), tpl['name'], font=font(FONT_BOLD, 44), fill=pal['text'])
    d.text((60 * SS, 262 * SS), tpl['industry'], font=font(FONT_REG, 24), fill=pal['text'][:3] + (170,))
    for i, c in enumerate([tpl['settings']['primary_color'], tpl['settings']['secondary_color'], tpl['settings']['text_color']]):
        blob(d, 80 * SS + i * 52 * SS, 340 * SS, 20 * SS, hx(c))
    save(img, os.path.join(folder, 'preview.jpg'), 900, 600)


# ---------------------------------------------------------------- template data

def img(name):
    return '{{img:%s}}' % name


def act(t='none', v=''):
    return {'type': t, 'value': v}


def nav(items):
    return [{'label': l, 'icon': i, 'action': a} for l, i, a in items]


DEFAULT_NAV = nav([
    ('Home', 'home', act('screen', 'home')),
    ('Categories', 'category', act('route', 'categories')),
    ('Cart', 'cart', act('route', 'cart')),
    ('Account', 'person', act('route', 'account')),
])

TEMPLATES = [
    {
        'slug': 'cosmetics', 'order': 1, 'kind': 'cosmetics', 'name': 'Glow Beauty', 'brand': 'Glow', 'industry': 'Cosmetics & skincare',
        'description': 'Soft rose palette, centered logo, circle categories and a promo screen for beauty stores.',
        'colors': ('#D63A6F', '#F6B8C8', '#FFF5F7', '#FFFFFF', '#3A1020'),
        'font': 'Poppins', 'radius': 16, 'card': 'bordered',
        'appbar': {'title_type': 'logo', 'center': True, 'bg_color': '#FFF5F7', 'fg_color': '#3A1020', 'show_search': True, 'show_cart': True, 'search_bar': False},
        'slides': [('New in', 'Glow Season', 'Up to 40% off skincare', 'Shop now'),
                   ('Bestseller', 'Velvet Lips', 'The new matte collection', 'Discover'),
                   ('Limited', 'Signature\nScents', 'Perfumes from 1,999', 'Explore')],
        'banners': [('Free gift', 'with every order this week'), ('Bundle & save', 'Buy 2 get 1 free')],
        'onboard': [('Beauty, delivered', 'Discover skincare, makeup and fragrance from brands you love.'),
                    ('Fast & free delivery', 'Get your favourites at your door in 2–3 days.'),
                    ('Pay your way', 'Cash on delivery or secure online payment.')],
        'headings': ('Shop by category', 'Trending now', 'Best sellers'),
    },
    {
        'slug': 'electronics', 'order': 2, 'kind': 'electronics', 'name': 'Volt Electronics', 'brand': 'Volt', 'industry': 'Electronics & gadgets',
        'description': 'Dark tech app bar, bold blue accents, grid categories and deal sections for gadget stores.',
        'colors': ('#2563EB', '#22D3EE', '#F1F5F9', '#FFFFFF', '#0B1220'),
        'font': 'Inter', 'radius': 10, 'card': 'standard',
        'appbar': {'title_type': 'logo_name', 'center': False, 'bg_color': '#0B1220', 'fg_color': '#FFFFFF', 'show_search': True, 'show_cart': True, 'search_bar': True},
        'slides': [('Mega sale', 'Tech Week', 'Phones, audio & wearables', 'Shop deals'),
                   ('Just landed', 'Next-gen\nAudio', 'Noise cancelling from 4,999', 'Explore'),
                   ('Smart picks', 'Wear the\nFuture', 'Smartwatches up to 30% off', 'Shop now')],
        'banners': [('Flash deals', 'Ending at midnight'), ('Trade-in & save', 'Upgrade your phone today')],
        'onboard': [('Latest gadgets', 'Phones, laptops, audio and accessories in one place.'),
                    ('Express delivery', 'Fast shipping with live order tracking.'),
                    ('Secure checkout', 'Original products, warranty and safe payments.')],
        'headings': ('Categories', 'Hot deals', 'New arrivals'),
        'nav_bg': '#0B1220', 'nav_active': '#22D3EE', 'nav_inactive': '#64748B',
    },
    {
        'slug': 'fashion', 'order': 3, 'kind': 'fashion', 'name': 'Noir Fashion', 'brand': 'NOIR', 'industry': 'Fashion & apparel',
        'description': 'Minimal black & gold editorial look with big imagery and clean product cards.',
        'colors': ('#111111', '#C8A96A', '#FAFAFA', '#FFFFFF', '#111111'),
        'font': 'Montserrat', 'radius': 4, 'card': 'minimal',
        'appbar': {'title_type': 'name', 'center': True, 'bg_color': '#FFFFFF', 'fg_color': '#111111', 'show_search': True, 'show_cart': True, 'search_bar': False},
        'slides': [('Autumn / Winter', 'The New\nEssentials', 'Timeless pieces for every day', 'Shop the edit'),
                   ('Accessories', 'Statement\nBags', 'Crafted to last', 'Discover'),
                   ('Sale', 'Up to 50%', 'On selected styles', 'Shop sale')],
        'banners': [('Free returns', 'within 14 days'), ('Members get 10%', 'Sign up today')],
        'onboard': [('Your new wardrobe', 'Curated collections, updated every week.'),
                    ('Delivered to you', 'Fast nationwide delivery and easy returns.'),
                    ('Shop with confidence', 'Secure payments and cash on delivery.')],
        'headings': ('Collections', 'New in', 'Most loved'),
        'on_primary': '#FFFFFF', 'sale': '#C8A96A', 'price': '#111111',
    },
    {
        'slug': 'grocery', 'order': 4, 'kind': 'grocery', 'name': 'Fresh Basket', 'brand': 'Fresh', 'industry': 'Grocery & food',
        'description': 'Bright green grocery layout with search in the app bar and quick-add product lists.',
        'colors': ('#16A34A', '#F97316', '#F0FDF4', '#FFFFFF', '#052E16'),
        'font': 'Poppins', 'radius': 14, 'card': 'standard',
        'appbar': {'title_type': 'logo_name', 'center': False, 'bg_color': '#16A34A', 'fg_color': '#FFFFFF', 'show_search': False, 'show_cart': True, 'search_bar': True},
        'slides': [('Farm fresh', 'Fresh Every\nMorning', 'Fruits & vegetables delivered', 'Order now'),
                   ('Weekly deals', 'Save on\nEssentials', 'Up to 25% off groceries', 'See deals'),
                   ('Healthy', 'Organic\nPicks', 'Good for you, good for earth', 'Shop organic')],
        'banners': [('Free delivery', 'on your first order'), ('Daily deals', 'New offers every morning')],
        'onboard': [('Groceries in minutes', 'Fresh produce, dairy and daily essentials.'),
                    ('Doorstep delivery', 'Choose a delivery time that suits you.'),
                    ('Easy payments', 'Cash on delivery or pay online securely.')],
        'headings': ('Shop by aisle', 'Today\'s deals', 'Fresh picks'),
    },
    {
        'slug': 'furniture', 'order': 5, 'kind': 'furniture', 'name': 'Nest Living', 'brand': 'Nest', 'industry': 'Furniture & home decor',
        'description': 'Warm earthy tones, large banners and list layouts for furniture and decor stores.',
        'colors': ('#8B5E3C', '#2F5D50', '#FAF7F2', '#FFFFFF', '#292524'),
        'font': 'Lato', 'radius': 8, 'card': 'bordered',
        'appbar': {'title_type': 'logo', 'center': False, 'bg_color': '#FAF7F2', 'fg_color': '#292524', 'show_search': True, 'show_cart': True, 'search_bar': False},
        'slides': [('New collection', 'Make Home\nCozy', 'Sofas, chairs & more', 'Shop living'),
                   ('Lighting', 'Light Up\nYour Space', 'Lamps from 2,499', 'Explore'),
                   ('Green corner', 'Bring Nature\nIndoors', 'Planters & decor', 'Discover')],
        'banners': [('Free assembly', 'on all sofas this month'), ('Easy installments', '0% markup for 6 months')],
        'onboard': [('Design your home', 'Furniture and decor picked by our stylists.'),
                    ('White-glove delivery', 'We deliver and assemble for you.'),
                    ('Pay in installments', 'Flexible and secure payment options.')],
        'headings': ('Rooms', 'Featured', 'Best sellers'),
    },
    {
        'slug': 'jewelry', 'order': 6, 'kind': 'jewelry', 'name': 'Aurum Jewels', 'brand': 'Aurum', 'industry': 'Jewelry & accessories',
        'description': 'Luxurious gold and maroon palette with elegant serif type and featured collections.',
        'colors': ('#B8860B', '#4A1D1F', '#FFFBF2', '#FFFFFF', '#1C1917'),
        'font': 'Playfair Display', 'radius': 6, 'card': 'minimal',
        'appbar': {'title_type': 'logo', 'center': True, 'bg_color': '#4A1D1F', 'fg_color': '#F5E6C8', 'show_search': True, 'show_cart': True, 'search_bar': False},
        'slides': [('Bridal', 'Timeless\nElegance', 'The bridal collection', 'View collection'),
                   ('Everyday gold', 'Light &\nLovely', 'Pieces from 9,999', 'Shop now'),
                   ('Gifts', 'Gift Her\nSparkle', 'Rings, pendants & sets', 'Find a gift')],
        'banners': [('Certified gold', 'Hallmarked & authentic'), ('Free engraving', 'on all rings')],
        'onboard': [('Fine jewelry', 'Handcrafted pieces in gold, silver and diamonds.'),
                    ('Insured delivery', 'Every order is insured and tracked.'),
                    ('Lifetime exchange', 'Exchange or upgrade anytime.')],
        'headings': ('Collections', 'Featured', 'New designs'),
        'nav_bg': '#FFFBF2',
    },
]


def build_template(t):
    folder = os.path.join(ROOT, t['slug'])
    images = os.path.join(folder, 'images')
    os.makedirs(images, exist_ok=True)
    p, s, bg, surf, text = t['colors']
    pal = {'p': hx(p), 's': hx(s), 'text': hx(text)}
    c_dark = mix(hx(p), (0, 0, 0, 255), .35)
    combos = [(hx(p), c_dark), (mix(hx(p), hx(s), .5), hx(p)), (c_dark, hx(p))]
    if t['slug'] == 'fashion':
        combos = [((30, 30, 30, 255), (70, 60, 45, 255)), ((60, 50, 35, 255), (20, 20, 20, 255)), ((150, 120, 70, 255), (40, 35, 25, 255))]

    for i, (eb, title, sub, cta) in enumerate(t['slides']):
        make_hero(t['kind'], pal, combos[i][0], combos[i][1], eb, title, sub, cta, os.path.join(images, 'slide-%d.jpg' % (i + 1)), seed=i + 11)
    for i, (title, sub) in enumerate(t['banners']):
        c1 = hx(s) if i == 0 else mix(hx(p), (255, 255, 255, 255), .1)
        c2 = mix(hx(s), hx(p), .6) if i == 0 else c_dark
        make_banner(t['kind'], pal, c1, c2, title, sub, os.path.join(images, 'banner-%d.jpg' % (i + 1)), seed=i + 40)
    for i in range(3):
        make_onboard(t['kind'], pal, bg, i, os.path.join(images, 'onboard-%d.jpg' % (i + 1)))
    dark_appbar = sum(hx(t['appbar']['bg_color'])[:3]) < 300
    make_logo(t['brand'], pal, os.path.join(images, 'logo.png'), dark_bg=dark_appbar)

    h1, h2, h3 = t['headings']
    blocks = []
    if not t['appbar'].get('search_bar'):
        blocks.append({'id': 'b1', 'type': 'search', 'props': {'placeholder': 'Search %s...' % t['industry'].split(' ')[0].lower()}})
    blocks += [
        {'id': 'b2', 'type': 'slider', 'props': {'height': 175, 'radius': t['radius'], 'autoplay': True, 'items': [
            {'image': img('slide-1.jpg'), 'action': act('route', 'products')},
            {'image': img('slide-2.jpg'), 'action': act('route', 'products')},
            {'image': img('slide-3.jpg'), 'action': act('screen', 'promo')},
        ]}},
        {'id': 'b3', 'type': 'heading', 'props': {'text': h1, 'size': 18, 'align': 'left', 'show_view_all': True, 'action': act('route', 'categories')}},
        {'id': 'b4', 'type': 'categories', 'props': {'layout': {'electronics': 'grid_slider', 'grocery': 'grid_slider', 'furniture': 'cards_slider'}.get(t['slug'], 'horizontal'), 'columns': 4, 'rows': 2, 'limit': 12,
                                                     'shape': 'square' if t['slug'] in ('electronics', 'furniture') else 'circle', 'show_name': True}},
        {'id': 'b5', 'type': 'heading', 'props': {'text': h2, 'size': 18, 'align': 'left', 'show_view_all': True, 'action': act('route', 'products')}},
        {'id': 'b6', 'type': 'products', 'props': {'source': 'on_sale' if t['slug'] in ('electronics', 'grocery') else 'featured', 'limit': 8, 'layout': 'horizontal', 'columns': 2}},
        {'id': 'b7', 'type': 'banner', 'props': {'image': img('banner-1.jpg'), 'height': 130, 'radius': t['radius'], 'action': act('screen', 'promo')}},
        {'id': 'b8', 'type': 'heading', 'props': {'text': h3, 'size': 18, 'align': 'left', 'show_view_all': True, 'action': act('route', 'products')}},
        {'id': 'b9', 'type': 'products', 'props': {'source': 'best_selling' if t['slug'] != 'furniture' else 'latest', 'limit': 6,
                                                   'layout': 'list' if t['slug'] == 'furniture' else 'grid', 'columns': 2}},
        {'id': 'b10', 'type': 'banner', 'props': {'image': img('banner-2.jpg'), 'height': 130, 'radius': t['radius'], 'action': act('route', 'products')}},
        {'id': 'b11', 'type': 'spacer', 'props': {'height': 8}},
    ]
    promo = [
        {'id': 'p1', 'type': 'banner', 'props': {'image': img('slide-3.jpg'), 'height': 200, 'radius': 0, 'padding_h': 0, 'padding_v': 0, 'action': act()}},
        {'id': 'p2', 'type': 'heading', 'props': {'text': t['slides'][2][1].replace('\n', ' '), 'size': 22, 'align': 'center'}},
        {'id': 'p3', 'type': 'text', 'props': {'content': t['slides'][2][2] + '. Limited time only — while stocks last.', 'size': 14, 'align': 'center', 'color': ''}},
        {'id': 'p4', 'type': 'products', 'props': {'source': 'on_sale', 'limit': 10, 'layout': 'grid', 'columns': 2}},
        {'id': 'p5', 'type': 'button', 'props': {'label': 'See all products', 'action': act('route', 'products'), 'full_width': True, 'text_color': t.get('on_primary', '#FFFFFF')}},
    ]

    appbar = {'title_type': 'logo_or_name', 'title_text': '', 'center': False, 'bg_color': '#FFFFFF', 'fg_color': text,
              'shadow': False, 'show_search': True, 'show_cart': True, 'show_account': False, 'search_bar': False,
              'search_text': 'Search products...'}
    appbar.update(t['appbar'])

    settings = {
        'app_name': '', 'logo': img('logo.png'), 'color_scheme': 'custom',
        'primary_color': p, 'on_primary_color': t.get('on_primary', '#FFFFFF'), 'secondary_color': s,
        'background_color': bg, 'surface_color': surf, 'text_color': text,
        'muted_color': '#6B7280', 'border_color': '#E5E7EB',
        'price_color': t.get('price', ''), 'sale_color': t.get('sale', ''),
        'nav_bg_color': t.get('nav_bg', '#FFFFFF'), 'nav_active_color': t.get('nav_active', ''), 'nav_inactive_color': t.get('nav_inactive', '#9CA3AF'),
        'font_family': t['font'], 'card_radius': t['radius'], 'product_card': t['card'],
        'appbar': appbar,
        'onboarding': {
            'enabled': True, 'version': 1, 'style': 'image_top', 'bg_color': bg, 'text_color': text,
            'skip_label': 'Skip', 'next_label': 'Next', 'done_label': 'Start shopping',
            'slides': [{'image': img('onboard-%d.jpg' % (i + 1)), 'title': ti, 'text': tx} for i, (ti, tx) in enumerate(t['onboard'])],
        },
        'bottom_nav': DEFAULT_NAV,
        'theme_mode': 'light', 'allow_theme_switch': True,
        'dark': {'primary_color': '', 'secondary_color': '', 'background_color': '#0B1120', 'surface_color': '#151E2E', 'text_color': '#E5E7EB',
                 'muted_color': '#94A3B8', 'border_color': '#263244', 'appbar_bg_color': '#151E2E', 'appbar_fg_color': '#F1F5F9',
                 'nav_bg_color': '#151E2E', 'nav_inactive_color': '#64748B'},
        'drawer': {'enabled': True, 'header_style': 'primary', 'header_image': '', 'show_login': True, 'show_categories': True,
                   'categories_title': 'Categories', 'categories_limit': 12, 'show_language': True, 'show_theme_toggle': True,
                   'items': [
                       {'label': 'Home', 'icon': 'home', 'action': act('screen', 'home')},
                       {'label': 'Shop', 'icon': 'store', 'action': act('route', 'products')},
                       {'label': t['slides'][2][1].replace('\n', ' '), 'icon': 'local_offer', 'action': act('screen', 'promo')},
                       {'label': 'Track order', 'icon': 'local_shipping', 'action': act('route', 'track_order')},
                       {'label': 'Help & FAQ', 'icon': 'help', 'action': act('screen', 'help')},
                       {'label': 'About us', 'icon': 'info', 'action': act('screen', 'about')},
                       {'label': 'Contact us', 'icon': 'support_agent', 'action': act('route', 'contact')},
                   ]},
    }
    data = {
        'name': t['name'], 'industry': t['industry'], 'description': t['description'], 'order': t['order'],
        'settings': settings,
        'screens': {
            'home': {'title': 'Home', 'blocks': blocks},
            'promo': {'title': t['slides'][2][1].replace('\n', ' '), 'blocks': promo},
            'about': {'title': 'About us', 'blocks': [
                {'id': 'a1', 'type': 'banner', 'props': {'image': img('banner-1.jpg'), 'height': 150, 'radius': t['radius'], 'action': act()}},
                {'id': 'a2', 'type': 'heading', 'props': {'text': 'About ' + t['name'], 'size': 22, 'align': 'left'}},
                {'id': 'a3', 'type': 'html', 'props': {'content': '<p>%s</p><ul><li>Genuine products</li><li>Fast delivery</li><li>Easy returns</li></ul>' % t['description']}},
                {'id': 'a4', 'type': 'contact_info', 'props': {'title': 'Get in touch', 'show_form_button': True}},
            ]},
            'help': {'title': 'Help & FAQ', 'blocks': [
                {'id': 'h1', 'type': 'links', 'props': {'layout': 'grid', 'columns': 3, 'items': [
                    {'label': 'Track order', 'icon': 'local_shipping', 'action': act('route', 'track_order')},
                    {'label': 'Contact us', 'icon': 'support_agent', 'action': act('route', 'contact')},
                    {'label': 'My orders', 'icon': 'receipt', 'action': act('route', 'orders')},
                ]}},
                {'id': 'h2', 'type': 'heading', 'props': {'text': 'Frequently asked questions', 'size': 18}},
                {'id': 'h3', 'type': 'faq', 'props': {'items': [
                    {'question': 'How long does delivery take?', 'answer': '<p>Most orders arrive in 2–5 working days.</p>'},
                    {'question': 'Can I pay cash on delivery?', 'answer': '<p>Yes — choose Cash on delivery at checkout.</p>'},
                    {'question': 'How do I return an item?', 'answer': '<p>Contact us within 7 days of delivery and we will arrange it.</p>'},
                ]}},
            ]},
        },
    }
    with open(os.path.join(folder, 'template.json'), 'w') as f:
        json.dump(data, f, indent=1)

    t['settings'] = settings
    t['pal'] = pal
    make_preview(t, images)
    print('built', t['slug'])


if __name__ == '__main__':
    for tpl in TEMPLATES:
        build_template(tpl)
