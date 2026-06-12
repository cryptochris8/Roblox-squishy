"""Generate the 9 Phase D product icons (3 Game Passes + 6 premium cosmetics).

512x512 PNGs into marketing/product_icons/, designed for Roblox's CIRCULAR
crop: every important detail stays inside the inscribed circle. One shared
look: soft pastel radial background, white inner ring, sparkles, one big
friendly motif. Drawn at 4x and downscaled for smooth edges.

Run:  python marketing/make_product_icons.py
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter

S = 2048          # supersampled canvas (4x)
OUT = 512         # final size
HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "product_icons")

# ── palette ──────────────────────────────────────────────────────────────────
CREAM = (255, 247, 240)
INK = (96, 74, 96)
PINK = (255, 138, 180)
PINK_DEEP = (225, 90, 150)
GOLD = (255, 201, 84)
GOLD_DEEP = (240, 160, 40)
WHITE = (255, 255, 255)


def radial_bg(c_in, c_out):
    """Square canvas with a radial gradient from c_in (center) to c_out (edge)."""
    img = Image.new("RGB", (S, S), c_out)
    px = img.load()
    cx = cy = S / 2
    maxd = math.hypot(cx, cy)
    for y in range(S):
        for x in range(0, S, 2):  # 2px steps, then smooth via final resize
            d = math.hypot(x - cx, y - cy) / maxd
            t = min(1.0, d * 1.25)
            col = tuple(int(a + (b - a) * t) for a, b in zip(c_in, c_out))
            px[x, y] = col
            if x + 1 < S:
                px[x + 1, y] = col
    return img


def sparkle(d, x, y, r, color=WHITE):
    """A soft 4-point sparkle (two squashed diamonds)."""
    d.polygon([(x, y - r), (x + r * 0.22, y), (x, y + r), (x - r * 0.22, y)], fill=color)
    d.polygon([(x - r, y), (x, y + r * 0.22), (x + r, y), (x, y - r * 0.22)], fill=color)


def soft_shadow(base, shape_fn, offset=(0, 26), blur=42, alpha=70):
    """Draw shape_fn into an alpha layer, blur it, composite as a soft shadow."""
    lay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    shape_fn(d, (40, 30, 50, alpha))
    lay = lay.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(lay, offset)


def kawaii_face(d, cx, cy, scale, ink=INK):
    """Closed-happy eyes + smile + blush, the Squishy face."""
    ew = 46 * scale  # eye arc width
    for sx in (-1, 1):
        ex = cx + sx * 95 * scale
        d.arc([ex - ew, cy - ew * 0.9, ex + ew, cy + ew * 1.1], 200, 340, fill=ink, width=int(16 * scale))
    d.arc([cx - 52 * scale, cy + 10 * scale, cx + 52 * scale, cy + 86 * scale], 20, 160, fill=ink, width=int(15 * scale))
    for sx in (-1, 1):
        bx = cx + sx * 150 * scale
        d.ellipse([bx - 38 * scale, cy + 26 * scale, bx + 38 * scale, cy + 70 * scale], fill=(255, 170, 190))


def blob(img, d, cx, cy, r, color, face_scale=None, squash=0.88):
    """A squishy blob: squashed ball + glossy highlight (+ optional face)."""
    top = cy - r * squash
    d.ellipse([cx - r, top, cx + r, cy + r * squash], fill=color)
    hi = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hi)
    hd.ellipse([cx - r * 0.5, top + r * 0.16, cx - r * 0.14, top + r * 0.4], fill=(255, 255, 255, 150))
    img.alpha_composite(hi.filter(ImageFilter.GaussianBlur(8)))
    if face_scale:
        kawaii_face(d, cx, cy - r * 0.05, face_scale)


def frame(bg_in, bg_out, ring=WHITE):
    """Standard icon base: radial bg + white ring just inside the circle crop."""
    img = radial_bg(bg_in, bg_out).convert("RGBA")
    d = ImageDraw.Draw(img)
    m = int(S * 0.045)
    d.ellipse([m, m, S - m, S - m], outline=ring + (235,), width=int(S * 0.016))
    return img, d


def finish(img, name):
    img = img.convert("RGB").resize((OUT, OUT), Image.LANCZOS)
    path = os.path.join(OUTDIR, name + ".png")
    img.save(path)
    print("wrote", path)


# ── 1) Extra Buddy Slot: two happy blobs side by side ───────────────────────
def icon_buddy_slot():
    img, d = frame((255, 228, 240), (255, 170, 200))
    c1, c2 = (255, 176, 196), (176, 214, 255)  # pink + blue buddy

    def shadows(sd, col):
        sd.ellipse([S * 0.16, S * 0.40, S * 0.56, S * 0.78], fill=col)
        sd.ellipse([S * 0.44, S * 0.44, S * 0.82, S * 0.80], fill=col)

    soft_shadow(img, shadows)
    blob(img, d, S * 0.62, S * 0.62, S * 0.185, c2, face_scale=1.5)
    blob(img, d, S * 0.37, S * 0.58, S * 0.205, c1, face_scale=1.7)
    sparkle(d, S * 0.50, S * 0.255, 64)
    sparkle(d, S * 0.745, S * 0.36, 44)
    sparkle(d, S * 0.265, S * 0.345, 38)
    finish(img, "pass_extra_buddy_slot")


# ── 2) Coin Boost: big star-stamped coin + rising sparkles ───────────────────
def icon_coin_boost():
    img, d = frame((255, 240, 210), (255, 196, 110))
    cx, cy, r = S * 0.5, S * 0.54, S * 0.26

    soft_shadow(img, lambda sd, col: sd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=GOLD_DEEP)
    r2 = r * 0.86
    d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=GOLD)
    # embossed star
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rr = r * 0.52 if i % 2 == 0 else r * 0.22
        pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    d.polygon(pts, fill=(255, 232, 150), outline=GOLD_DEEP, width=14)
    # glossy sweep
    hi = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hi)
    hd.ellipse([cx - r * 0.7, cy - r * 0.95, cx + r * 0.1, cy - r * 0.25], fill=(255, 255, 255, 90))
    img.alpha_composite(hi.filter(ImageFilter.GaussianBlur(30)))
    # rising sparkles = "boost"
    sparkle(d, S * 0.745, S * 0.295, 66)
    sparkle(d, S * 0.62, S * 0.20, 44)
    sparkle(d, S * 0.83, S * 0.43, 38)
    sparkle(d, S * 0.25, S * 0.30, 40)
    finish(img, "pass_coin_boost")


# ── 3) Sparkle Club VIP: golden rosette ribbon badge ─────────────────────────
def icon_vip():
    img, d = frame((255, 226, 238), (240, 150, 190))
    cx, cy = S * 0.5, S * 0.46
    R = S * 0.24

    # ribbon tails
    def tails(td, col):
        for sx in (-1, 1):
            x0 = cx + sx * R * 0.42
            td.polygon([
                (x0 - 90, cy + R * 0.55), (x0 + 90, cy + R * 0.55),
                (x0 + sx * 60 + 40, S * 0.84), (x0 + sx * 60 - 6, S * 0.78),
                (x0 + sx * 60 - 60, S * 0.84),
            ], fill=col)

    soft_shadow(img, lambda sd, col: (tails(sd, col), sd.ellipse([cx - R, cy - R, cx + R, cy + R], fill=col)))
    tails(d, PINK_DEEP)
    # scalloped rosette
    for i in range(12):
        ang = i * math.pi / 6
        px_, py_ = cx + R * 0.92 * math.cos(ang), cy + R * 0.92 * math.sin(ang)
        d.ellipse([px_ - R * 0.3, py_ - R * 0.3, px_ + R * 0.3, py_ + R * 0.3], fill=GOLD_DEEP)
    d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=GOLD)
    r2 = R * 0.78
    d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=(255, 232, 150))
    # star
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rr = R * 0.52 if i % 2 == 0 else R * 0.22
        pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    d.polygon(pts, fill=WHITE, outline=GOLD_DEEP, width=14)
    sparkle(d, S * 0.26, S * 0.26, 52)
    sparkle(d, S * 0.76, S * 0.30, 64)
    sparkle(d, S * 0.70, S * 0.70, 40)
    finish(img, "pass_sparkle_club_vip")


# ── 4) Strawberry Beret: tilted berry-red beret on a peach blob ──────────────
def icon_beret():
    img, d = frame((255, 232, 226), (255, 178, 170))
    cx, cy = S * 0.5, S * 0.62
    r = S * 0.23

    soft_shadow(img, lambda sd, col: sd.ellipse([cx - r, cy - r * 0.9, cx + r, cy + r * 0.9], fill=col))
    blob(img, d, cx, cy, r, (255, 214, 186), face_scale=1.6)

    # beret: tilted squashed disc + rim + stem, strawberry seeds
    bx, by = cx - r * 0.12, cy - r * 1.06
    lay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    ld.ellipse([bx - 360, by - 150, bx + 360, by + 130], fill=(232, 64, 92))
    ld.ellipse([bx - 250, by + 30, bx + 290, by + 150], fill=(206, 44, 74))   # rim underside
    ld.ellipse([bx - 300, by - 130, bx + 160, by + 10], fill=(244, 92, 116))  # sheen
    for sx_, sy_ in [(-220, -30), (-80, -84), (70, -60), (200, -16), (-10, 18), (140, 40), (-150, 40)]:
        ld.ellipse([bx + sx_ - 14, by + sy_ - 20, bx + sx_ + 14, by + sy_ + 20], fill=(255, 226, 150))
    ld.rectangle([bx - 16, by - 196, bx + 16, by - 120], fill=(124, 176, 96))  # stem
    ld.ellipse([bx - 40, by - 230, bx + 40, by - 170], fill=(148, 200, 116))   # leaf nub
    lay = lay.rotate(-8, center=(bx, by), resample=Image.BICUBIC)
    img.alpha_composite(lay)
    sparkle(ImageDraw.Draw(img), S * 0.77, S * 0.32, 54)
    sparkle(ImageDraw.Draw(img), S * 0.24, S * 0.42, 40)
    finish(img, "prod_strawberry_beret")


# ── 5) Rainbow Heart Balloon ─────────────────────────────────────────────────
def icon_heart_balloon():
    img, d = frame((255, 235, 242), (255, 184, 210))
    cx, cy = S * 0.5, S * 0.42
    w = S * 0.27

    def heart_pts(scale=1.0):
        pts = []
        for i in range(120):
            t = i / 119 * 2 * math.pi
            x = 16 * math.sin(t) ** 3
            y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
            pts.append((cx + x * w / 16 * scale, cy - y * w / 16 * scale))
        return pts

    soft_shadow(img, lambda sd, col: sd.polygon(heart_pts(), fill=col), offset=(0, 34))
    # rainbow bands clipped to the heart
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).polygon(heart_pts(), fill=255)
    bands = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bands)
    cols = [(255, 110, 130), (255, 168, 90), (255, 220, 110), (132, 212, 140), (120, 180, 255), (190, 150, 255)]
    y0, y1 = cy - w * 1.15, cy + w * 1.25
    bh = (y1 - y0) / len(cols)
    for i, c in enumerate(cols):
        bd.rectangle([0, y0 + i * bh, S, y0 + (i + 1) * bh + 2], fill=c)
    img.paste(bands, (0, 0), mask)
    # outline + gloss + knot + string
    d.polygon(heart_pts(), outline=(214, 80, 120), width=16)
    # two crisp balloon-shine dots instead of a blurred sheen
    d.ellipse([cx - w * 0.58, cy - w * 0.62, cx - w * 0.3, cy - w * 0.34], fill=(255, 255, 255, 215))
    d.ellipse([cx - w * 0.30, cy - w * 0.40, cx - w * 0.18, cy - w * 0.28], fill=(255, 255, 255, 190))
    bot = max(p[1] for p in heart_pts())
    d.polygon([(cx, bot - 6), (cx - 36, bot + 56), (cx + 36, bot + 56)], fill=(214, 80, 120))
    pts = [(cx + math.sin(i / 9) * 40, bot + 50 + i * 24) for i in range(16)]
    d.line(pts, fill=(214, 80, 120), width=12, joint="curve")
    sparkle(d, S * 0.26, S * 0.30, 50)
    sparkle(d, S * 0.76, S * 0.27, 60)
    finish(img, "prod_rainbow_heart_balloon")


# ── 6) Unicorn Horn: golden spiral horn on a white blob ──────────────────────
def icon_unicorn_horn():
    img, d = frame((242, 232, 255), (200, 178, 255))
    cx, cy = S * 0.5, S * 0.66
    r = S * 0.22

    soft_shadow(img, lambda sd, col: sd.ellipse([cx - r, cy - r * 0.9, cx + r, cy + r * 0.9], fill=col))
    blob(img, d, cx, cy, r, (255, 252, 248), face_scale=1.55)

    # horn: tapering golden cone with spiral bands, slight tilt
    lay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    hx, hy = cx, cy - r * 0.86
    hw, hh = 100, 660
    ld.polygon([(hx - hw, hy), (hx + hw, hy), (hx, hy - hh)], fill=GOLD)
    for i in range(1, 7):
        t = i / 7
        y = hy - hh * t
        wdt = hw * (1 - t)
        ld.line([(hx - wdt, y), (hx + wdt, y - 52)], fill=GOLD_DEEP, width=22)
    lay = lay.rotate(7, center=(hx, hy), resample=Image.BICUBIC)
    img.alpha_composite(lay)
    d = ImageDraw.Draw(img)
    sparkle(d, S * 0.30, S * 0.24, 46)
    sparkle(d, S * 0.72, S * 0.22, 62)
    sparkle(d, S * 0.79, S * 0.47, 40)
    finish(img, "prod_unicorn_horn")


# ── 7) Comet Trail: comet ball + swooshing tail across the disc ───────────────
def icon_comet():
    img, d = frame((220, 234, 255), (140, 170, 240))
    # tail: layered translucent swooshes from upper-left to the ball
    tail = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    td = ImageDraw.Draw(tail)
    bx, by = S * 0.63, S * 0.62
    for wdt, col in [(290, (255, 255, 255, 95)), (200, (255, 246, 200, 160)), (118, (255, 228, 140, 235))]:
        pts = []
        for i in range(40):
            t = i / 39
            x = S * 0.10 + (bx - S * 0.10) * t
            y = S * 0.20 + (by - S * 0.20) * t + math.sin(t * math.pi) * -S * 0.09
            pts.append((x, y))
        td.line(pts, fill=col, width=wdt, joint="curve")
    img.alpha_composite(tail.filter(ImageFilter.GaussianBlur(12)))
    # little stars swept along the tail
    td2 = ImageDraw.Draw(img)
    for tx, ty, tr in [(0.24, 0.245, 34), (0.38, 0.315, 26), (0.33, 0.45, 22)]:
        sparkle(td2, S * tx, S * ty, tr)
    # the comet ball
    r = S * 0.165
    soft_shadow(img, lambda sd, col: sd.ellipse([bx - r, by - r, bx + r, by + r], fill=col), offset=(0, 20), blur=30)
    d = ImageDraw.Draw(img)
    d.ellipse([bx - r, by - r, bx + r, by + r], fill=GOLD)
    d.ellipse([bx - r * 0.66, by - r * 0.66, bx + r * 0.66, by + r * 0.66], fill=(255, 236, 160))
    star = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rr = r * 0.5 if i % 2 == 0 else r * 0.21
        star.append((bx + rr * math.cos(ang), by + rr * math.sin(ang)))
    d.polygon(star, fill=WHITE)
    sparkle(d, S * 0.30, S * 0.62, 44)
    sparkle(d, S * 0.48, S * 0.33, 36)
    sparkle(d, S * 0.78, S * 0.36, 56)
    finish(img, "prod_comet_trail")


# ── 8) Golden Halo: glowing ring floating over a blob ─────────────────────────
def icon_halo():
    img, d = frame((255, 244, 222), (250, 206, 130))
    cx, cy = S * 0.5, S * 0.64
    r = S * 0.22

    soft_shadow(img, lambda sd, col: sd.ellipse([cx - r, cy - r * 0.9, cx + r, cy + r * 0.9], fill=col))
    blob(img, d, cx, cy, r, (255, 240, 214), face_scale=1.55)
    # glow
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    hw, hh = r * 1.25, r * 0.42
    hy = cy - r * 1.32
    gd.ellipse([cx - hw, hy - hh, cx + hw, hy + hh], outline=(255, 214, 90, 200), width=110)
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(36)))
    # crisp ring (perspective ellipse)
    d = ImageDraw.Draw(img)
    d.ellipse([cx - hw, hy - hh, cx + hw, hy + hh], outline=GOLD_DEEP, width=64)
    d.ellipse([cx - hw + 18, hy - hh + 18, cx + hw - 18, hy + hh - 18], outline=GOLD, width=30)
    sparkle(d, S * 0.27, S * 0.30, 48)
    sparkle(d, S * 0.74, S * 0.25, 62)
    sparkle(d, S * 0.78, S * 0.52, 38)
    finish(img, "prod_golden_halo")


# ── 9) Aurora Ribbon: flowing northern-lights ribbon + stars ──────────────────
def icon_aurora():
    img, d = frame((226, 222, 255), (150, 140, 230))
    cols = [(120, 230, 200, 235), (140, 190, 255, 235), (190, 150, 255, 235), (255, 150, 210, 235)]
    lay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    bandw = 86
    for bi, col in enumerate(cols):
        pts = []
        for i in range(64):
            t = i / 63
            x = S * (0.14 + 0.72 * t)
            y = S * 0.52 + math.sin(t * math.pi * 1.6 + bi * 0.55) * S * 0.16 + (bi - 1.5) * bandw
            pts.append((x, y))
        ld.line(pts, fill=col, width=bandw, joint="curve")
    img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(6)))
    glow = lay.filter(ImageFilter.GaussianBlur(60))
    img.alpha_composite(Image.eval(glow, lambda a: a // 2))
    d = ImageDraw.Draw(img)
    sparkle(d, S * 0.26, S * 0.27, 52)
    sparkle(d, S * 0.72, S * 0.24, 40)
    sparkle(d, S * 0.78, S * 0.71, 56)
    sparkle(d, S * 0.32, S * 0.74, 44)
    finish(img, "prod_aurora_ribbon")


if __name__ == "__main__":
    os.makedirs(OUTDIR, exist_ok=True)
    icon_buddy_slot()
    icon_coin_boost()
    icon_vip()
    icon_beret()
    icon_heart_balloon()
    icon_unicorn_horn()
    icon_comet()
    icon_halo()
    icon_aurora()
    print("done — 9 icons in", OUTDIR)
