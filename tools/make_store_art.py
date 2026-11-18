#!/usr/bin/env python3
"""Génère l'icône et les miniatures de la page du jeu (Roblox) dans assets/store/.

  icon.png                      512 × 512   (icône du jeu)
  thumb_fr_1..3.png, thumb_en_1..3.png   1920 × 1080 (miniatures, français / anglais)

Visuels graphiques aux couleurs du jeu (Flics bleu, Bandits orange, gaz vert-jaune).
Roblox conseille aussi des captures du jeu : voir docs/PAGE_DU_JEU.md.
Usage : python3 tools/make_store_art.py   (nécessite Pillow)
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "store")
SS = 2  # suréchantillonnage (bords lisses)

BLUE = (59, 122, 255)
ORANGE = (255, 138, 41)
ACCENT = (255, 200, 80)
TOXIC = (184, 255, 46)
NAVY = (12, 14, 26)


def font(size, italic=True):
    names = ["FreeSansBoldOblique.ttf" if italic else "FreeSansBold.ttf", "DejaVuSans-Bold.ttf", "LiberationSans-Bold.ttf"]
    for base in ["/usr/share/fonts/truetype/freefont", "/usr/share/fonts/truetype/dejavu", "/usr/share/fonts/truetype/liberation"]:
        for n in names:
            p = os.path.join(base, n)
            if os.path.exists(p):
                return ImageFont.truetype(p, size * SS)
    return ImageFont.load_default()


def canvas(w, h):
    img = Image.new("RGB", (w * SS, h * SS), NAVY)
    d = ImageDraw.Draw(img)
    # Fond : dégradé vertical bleu nuit → violet sombre.
    for y in range(h * SS):
        k = y / (h * SS)
        c = tuple(int(NAVY[i] * (1 - k) + (34, 18, 52)[i] * k) for i in range(3))
        d.line([(0, y), (w * SS, y)], fill=c)
    return img


def glow_split(img):
    """Deux halos : bleu à gauche (Flics), orange à droite (Bandits)."""
    w, h = img.size
    layer = Image.new("RGB", (w, h), (0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([-w * 0.25, h * 0.1, w * 0.45, h * 1.3], fill=BLUE)
    d.ellipse([w * 0.55, -h * 0.3, w * 1.25, h * 0.9], fill=ORANGE)
    layer = layer.filter(ImageFilter.GaussianBlur(w / 9))
    return Image.blend(img, layer, 0.45)


def starburst(d, cx, cy, r_out, r_in, points, fill, rot=0.0):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in * (0.85 + 0.3 * random.random())
        a = rot + i * math.pi / points
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    d.polygon(pts, fill=fill)


def explosion(img, cx, cy, r):
    d = ImageDraw.Draw(img)
    random.seed(int(cx + cy))
    starburst(d, cx, cy, r, r * 0.62, 14, (255, 110, 30))
    starburst(d, cx, cy, r * 0.78, r * 0.48, 12, (255, 170, 40), 0.2)
    starburst(d, cx, cy, r * 0.55, r * 0.33, 10, (255, 230, 120), 0.4)
    d.ellipse([cx - r * 0.25, cy - r * 0.25, cx + r * 0.25, cy + r * 0.25], fill=(255, 250, 225))


def rocket(img, x0, y0, x1, y1, width):
    """Roquette de (x0, y0) (queue) vers (x1, y1) (nez), avec flamme et traînée."""
    d = ImageDraw.Draw(img)
    ang = math.atan2(y1 - y0, x1 - x0)
    ux, uy = math.cos(ang), math.sin(ang)
    px, py = -uy, ux
    L = math.hypot(x1 - x0, y1 - y0)
    # Traînée (points de fumée).
    for i in range(18):
        t = i / 18
        bx, by = x0 - ux * L * (0.2 + t * 1.6), y0 - uy * L * (0.2 + t * 1.6)
        rr = width * (0.35 + t * 0.9)
        g = int(200 - t * 120)
        d.ellipse([bx - rr, by - rr, bx + rr, by + rr], fill=(g, g, g + 10))
    # Flamme.
    flame = [(x0 + px * width * 0.45, y0 + py * width * 0.45), (x0 - ux * width * 2.2, y0 - uy * width * 2.2), (x0 - px * width * 0.45, y0 - py * width * 0.45)]
    d.polygon(flame, fill=(255, 150, 40))
    d.polygon([(x0 + px * width * 0.25, y0 + py * width * 0.25), (x0 - ux * width * 1.3, y0 - uy * width * 1.3), (x0 - px * width * 0.25, y0 - py * width * 0.25)], fill=(255, 240, 150))
    # Corps.
    hw = width / 2
    body = [(x0 + px * hw, y0 + py * hw), (x1 - ux * hw + px * hw, y1 - uy * hw + py * hw), (x1, y1), (x1 - ux * hw - px * hw, y1 - uy * hw - py * hw), (x0 - px * hw, y0 - py * hw)]
    d.polygon(body, fill=(235, 238, 245), outline=(20, 20, 30), width=max(2, int(width * 0.08)))
    # Bandes et ailerons.
    for t in (0.25, 0.55):
        cx, cy = x0 + ux * L * t, y0 + uy * L * t
        d.line([(cx + px * hw, cy + py * hw), (cx - px * hw, cy - py * hw)], fill=ORANGE, width=int(width * 0.22))
    for s in (1, -1):
        fin = [(x0 + px * hw * s, y0 + py * hw * s), (x0 + px * hw * 2.1 * s - ux * width * 0.3, y0 + py * hw * 2.1 * s - uy * width * 0.3), (x0 + ux * width * 1.1 + px * hw * s, y0 + uy * width * 1.1 + py * hw * s)]
        d.polygon(fin, fill=BLUE, outline=(20, 20, 30))


def gas_ring(img, cx, cy, rx, ry):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for k in range(10):
        e = k * rx * 0.02
        d.ellipse([cx - rx - e, cy - ry - e * 0.5, cx + rx + e, cy + ry + e * 0.5], outline=TOXIC + (90 - k * 8,), width=int(rx * 0.05))
    layer = layer.filter(ImageFilter.GaussianBlur(rx * 0.02))
    img.paste(layer, (0, 0), layer)


def title(img, text, x, y, size, fill=ACCENT, anchor="la", italic=True):
    d = ImageDraw.Draw(img)
    f = font(size, italic)
    d.text((x, y), text, font=f, fill=fill, anchor=anchor, stroke_width=int(size * SS * 0.07), stroke_fill=(10, 10, 18))


def finish(img, w, h, name):
    img = img.resize((w, h), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    img.save(path, optimize=True)
    print(path)


def make_icon():
    W = H = 512
    img = glow_split(canvas(W, H))
    s = SS
    explosion(img, 300 * s, 210 * s, 170 * s)
    rocket(img, 70 * s, 400 * s, 260 * s, 250 * s, 46 * s)
    title(img, "CAVALE", 256 * s, 470 * s, 92, anchor="ms")
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([372 * s, 26 * s, 490 * s, 96 * s], radius=16 * s, fill=(20, 22, 34), outline=ACCENT, width=4 * s)
    title(img, "1V1", 431 * s, 61 * s, 46, fill=(255, 255, 255), anchor="mm")
    finish(img, W, H, "icon.png")


TEXTS = {
    "fr": {
        "t1": ("CAVALE", "DUEL 1V1  ·  ROQUETTES  ·  ROCKET JUMPS", "FLICS", "BANDITS"),
        "t2": ("ROCKET JUMP !", "Saute, tire à tes pieds… et envole-toi"),
        "t3": ("LE GAZ SE RESSERRE", "3 VIES PAR MANCHE  ·  PREMIER À 11 POINTS"),
    },
    "en": {
        "t1": ("CAVALE", "1V1 DUEL  ·  ROCKETS  ·  ROCKET JUMPS", "COPS", "ROBBERS"),
        "t2": ("ROCKET JUMP!", "Jump, shoot at your feet… and fly"),
        "t3": ("THE GAS CLOSES IN", "3 LIVES PER ROUND  ·  FIRST TO 11 POINTS"),
    },
}


def make_thumbs(lang):
    W, H = 1920, 1080
    s = SS
    t = TEXTS[lang]
    # 1 : titre, deux camps.
    img = glow_split(canvas(W, H))
    explosion(img, 1560 * s, 420 * s, 320 * s)
    rocket(img, 1020 * s, 940 * s, 1400 * s, 620 * s, 80 * s)
    title(img, t["t1"][0], 110 * s, 170 * s, 230)
    title(img, t["t1"][1], 120 * s, 440 * s, 58, fill=(255, 255, 255), italic=False)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([120 * s, 560 * s, 520 * s, 680 * s], radius=22 * s, fill=BLUE)
    d.rounded_rectangle([560 * s, 560 * s, 960 * s, 680 * s], radius=22 * s, fill=ORANGE)
    title(img, t["t1"][2], 320 * s, 620 * s, 64, fill=(255, 255, 255), anchor="mm")
    title(img, t["t1"][3], 760 * s, 620 * s, 64, fill=(255, 255, 255), anchor="mm")
    title(img, "VS", 540 * s, 620 * s, 44, fill=ACCENT, anchor="mm")
    finish(img, W, H, f"thumb_{lang}_1.png")

    # 2 : rocket jump.
    img = glow_split(canvas(W, H))
    explosion(img, 1560 * s, 930 * s, 280 * s)
    rocket(img, 1560 * s, 820 * s, 1700 * s, 420 * s, 86 * s)
    title(img, t["t2"][0], 110 * s, 220 * s, 170)
    title(img, t["t2"][1], 120 * s, 440 * s, 60, fill=(255, 255, 255), italic=False)
    finish(img, W, H, f"thumb_{lang}_2.png")

    # 3 : gaz lacrymo.
    img = canvas(W, H)
    # Brume verte hors de la zone, anneau de gaz, et les deux joueurs à l'intérieur.
    haze = Image.new("RGB", img.size, TOXIC)
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    md.rectangle([0, 0, W * s, H * s], fill=70)
    md.ellipse([(1300 - 520) * s, (800 - 210) * s, (1300 + 520) * s, (800 + 210) * s], fill=0)
    mask = mask.filter(ImageFilter.GaussianBlur(60 * s))
    img.paste(haze, (0, 0), mask)
    gas_ring(img, 1300 * s, 800 * s, 520 * s, 210 * s)
    d = ImageDraw.Draw(img)
    for (x, col) in ((1080, BLUE), (1520, ORANGE)):
        d.ellipse([(x - 45) * s, 700 * s, (x + 45) * s, 790 * s], fill=col, outline=(10, 10, 18), width=6 * s)
        d.rounded_rectangle([(x - 55) * s, 785 * s, (x + 55) * s, 930 * s], radius=40 * s, fill=col, outline=(10, 10, 18), width=6 * s)
    explosion(img, 1300 * s, 760 * s, 95 * s)
    title(img, t["t3"][0], 110 * s, 170 * s, 140, fill=TOXIC)
    title(img, t["t3"][1], 120 * s, 360 * s, 56, fill=(255, 255, 255), italic=False)
    finish(img, W, H, f"thumb_{lang}_3.png")


if __name__ == "__main__":
    make_icon()
    for lang in ("fr", "en"):
        make_thumbs(lang)
