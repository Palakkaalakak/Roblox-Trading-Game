"""Generates the cel-shaded dragon fireball textures into assets/dragon_fx/.

Blox Fruits look: flat saturated fills, hard edges, dark outlines. Transparent pixels get the
nearest edge colour baked in (avoids dark fringes in Roblox). White-filled textures are meant to
be tinted (ParticleEmitter/Beam Color, ImageLabel.ImageColor3, Decal.Color3); black outlines stay.

Run:  python3 tools/dragon_fx/make_textures.py
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "dragon_fx")
SS = 4  # supersampling

OUTLINE = (20, 8, 12, 255)
ORANGE_SET = [(120, 10, 10), (235, 30, 10), (255, 110, 0), (255, 215, 20), (255, 250, 210)]
VIOLET_SET = [(30, 0, 60), (110, 0, 220), (190, 20, 255), (255, 60, 220), (255, 220, 255)]
CRIMSON_SET = [(40, 0, 5), (180, 0, 30), (240, 50, 0), (255, 150, 0), (255, 235, 150)]


def canvas(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def finish(img, w, h):
    img = img.resize((w, h), Image.LANCZOS)
    return bleed(img)


def bleed(img):
    """Bake nearby opaque colours into transparent pixels (keeps alpha)."""
    a = np.asarray(img).astype(np.float32)
    rgb, alpha = a[..., :3], a[..., 3:4] / 255.0
    acc = rgb * alpha
    wsum = alpha.copy()
    out = rgb.copy()
    cur_acc, cur_w = acc, wsum
    for r in (2, 4, 8, 16, 32):
        ca = Image.fromarray(np.clip(cur_acc, 0, 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(r))
        cw = Image.fromarray(np.clip(cur_w[..., 0] * 255, 0, 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(r))
        ca = np.asarray(ca).astype(np.float32)
        cw = np.asarray(cw).astype(np.float32)[..., None] / 255.0
        fill = ca / np.maximum(cw, 1e-4)
        mask = (wsum[..., 0] < 0.5) & (cw[..., 0] > 0.01)
        out[mask] = fill[mask]
        wsum = np.maximum(wsum, (cw > 0.01).astype(np.float32))
    res = np.concatenate([np.clip(out, 0, 255), a[..., 3:4]], axis=-1).astype(np.uint8)
    return Image.fromarray(res, "RGBA")


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name))
    print("wrote", name, img.size)


# ---------------------------------------------------------------------------------------------
def flame_poly(cx, base, h, w, phase, curl):
    """Teardrop flame tongue with wavy edges and a curled tip (supersampled coords)."""
    pts_l, pts_r = [], []
    n = 28
    for i in range(n + 1):
        t = i / n  # 0 base .. 1 tip
        width = w * math.sin(math.pi * min(t * 1.15, 1.0)) ** 0.8 * (1 - t) ** 0.35
        wave = math.sin(t * 7 + phase) * w * 0.12 * t
        x_off = curl * (t ** 2) * w * 0.8 + wave
        y = base - h * t
        pts_l.append((cx + x_off - width, y))
        pts_r.append((cx + x_off + width, y))
    return pts_l + pts_r[::-1]


def flame_frame(draw, cx, base, size, phase, life, colors):
    """One cel flame: outline + 4 colour layers, shaped by life (0 birth .. 1 death)."""
    grow = min(life / 0.2, 1.0)
    shrink = 1.0 if life < 0.7 else max(0.0, 1 - (life - 0.7) / 0.3)
    s = size * grow * (0.55 + 0.45 * shrink)
    if s <= 1:
        return
    h, w = s * 1.0, s * 0.32
    curl = math.sin(phase * 1.7) * 0.6
    layers = [(1.0, 1.0, OUTLINE), (0.9, 0.86, colors[1]), (0.72, 0.68, colors[2]), (0.5, 0.48, colors[3]), (0.28, 0.27, colors[4])]
    for hs, ws, col in layers:
        poly = flame_poly(cx, base - (1 - hs) * h * 0.05, h * hs, w * ws, phase, curl)
        draw.polygon(poly, fill=col if len(col) == 4 else col + (255,))
    # breakup near death: detached licks above the tip
    if life > 0.6:
        k = (life - 0.6) / 0.4
        for j in range(3):
            r = s * 0.06 * (1 - k)
            x = cx + math.sin(phase + j * 2) * w * 0.8
            y = base - h * (0.95 + 0.15 * j + 0.2 * k)
            draw.ellipse([x - r - 4 * SS, y - r - 4 * SS, x + r + 4 * SS, y + r + 4 * SS], fill=OUTLINE)
            draw.ellipse([x - r, y - r, x + r, y + r], fill=colors[2] + (255,))


def flame_flipbook(colors, name, seed):
    random.seed(seed)
    cell = 256
    img = canvas(cell * 4, cell * 4)
    d = ImageDraw.Draw(img)
    for f in range(16):
        ox, oy = (f % 4) * cell * SS, (f // 4) * cell * SS
        life = f / 15
        cx = ox + cell * SS / 2
        base = oy + cell * SS * 0.92
        # main tongue + two side tongues
        flame_frame(d, cx - cell * SS * 0.16, base, cell * SS * 0.55, f * 0.9 + 1, min(life * 1.1, 1), colors)
        flame_frame(d, cx + cell * SS * 0.17, base, cell * SS * 0.6, f * 0.8 + 3, min(life * 1.05, 1), colors)
        flame_frame(d, cx, base, cell * SS * 0.82, f * 0.7, life, colors)
    save(finish(img, cell * 4, cell * 4), name)


# ---------------------------------------------------------------------------------------------
def blob_cluster(d, cx, cy, R, n, rng, colors, outline_px):
    circles = []
    for _ in range(n):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0, R * 0.55)
        circles.append((cx + math.cos(a) * r, cy + math.sin(a) * r, R * rng.uniform(0.35, 0.6)))
    for x, y, r in circles:
        o = r + outline_px
        d.ellipse([x - o, y - o, x + o, y + o], fill=OUTLINE)
    for x, y, r in circles:
        d.ellipse([x - r, y - r, x + r, y + r], fill=colors[1] + (255,))
    for x, y, r in circles:
        r2 = r * 0.72
        d.ellipse([x - r2, y - r2 - r * 0.12, x + r2, y + r2 - r * 0.12], fill=colors[2] + (255,))
    for x, y, r in circles:
        r3 = r * 0.42
        d.ellipse([x - r3, y - r3 - r * 0.22, x + r3, y + r3 - r * 0.22], fill=colors[3] + (255,))
    return circles


def explosion_flipbook(colors, name, seed):
    rng = random.Random(seed)
    cell = 256
    img = canvas(cell * 4, cell * 4)
    d = ImageDraw.Draw(img)
    S = cell * SS
    for f in range(16):
        ox, oy = (f % 4) * S, (f // 4) * S
        cx, cy = ox + S / 2, oy + S / 2
        life = f / 15
        if f < 3:
            # burst: spiky star + hot core
            R = S * (0.18 + 0.12 * f)
            pts = []
            for i in range(24):
                a = i / 24 * math.tau
                rr = R * (1.0 if i % 2 == 0 else 0.45) * rng.uniform(0.85, 1.15)
                pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
            d.polygon(pts, fill=colors[3] + (255,))
            r = R * 0.5
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colors[4] + (255,))
        else:
            k = (life - 0.2) / 0.8
            R = S * (0.3 + 0.12 * k)
            local = random.Random(seed * 100 + f)
            cols = [colors[0], colors[1] if k < 0.6 else colors[0], colors[2] if k < 0.5 else colors[1], colors[3] if k < 0.35 else colors[2]]
            circles = blob_cluster(d, cx, cy, R, 9, local, cols, 4 * SS)
            if k > 0.45:
                # dissipate: punch holes
                hk = (k - 0.45) / 0.55
                for x, y, r in circles:
                    hr = r * hk * 0.9
                    d.ellipse([x - hr, y - hr + r * 0.2, x + hr, y + hr + r * 0.2], fill=(0, 0, 0, 0))
    save(finish(img, cell * 4, cell * 4), name)


def smoke_flipbook(name):
    rng = random.Random(7)
    cell = 256
    img = canvas(cell * 2, cell * 2)
    d = ImageDraw.Draw(img)
    S = cell * SS
    for f in range(4):
        ox, oy = (f % 2) * S, (f // 2) * S
        cols = [(10, 8, 12), (38, 32, 40), (62, 54, 66), (88, 80, 94)]
        circles = blob_cluster(d, ox + S / 2, oy + S / 2, S * 0.36, 7, rng, cols, 4 * SS)
        if f >= 2:
            for x, y, r in circles[: 2 + f]:
                hr = r * 0.35 * (f - 1)
                d.ellipse([x - hr, y - hr, x + hr, y + hr], fill=(0, 0, 0, 0))
    save(finish(img, cell * 2, cell * 2), name)


# ---------------------------------------------------------------------------------------------
def star(name):
    S = 256 * SS
    img = canvas(256, 256)
    d = ImageDraw.Draw(img)
    c = S / 2

    def star_pts(R, r):
        pts = []
        for i in range(8):
            a = i / 8 * math.tau - math.pi / 2
            rr = R if i % 2 == 0 else r
            pts.append((c + math.cos(a) * rr, c + math.sin(a) * rr))
        return pts

    d.polygon(star_pts(S * 0.48, S * 0.13), fill=OUTLINE)
    d.polygon(star_pts(S * 0.43, S * 0.09), fill=(255, 255, 255, 255))
    d.polygon(star_pts(S * 0.2, S * 0.05), fill=(255, 255, 255, 255))
    save(finish(img, 256, 256), name)


def shock_ring(name):
    S = 512 * SS
    img = canvas(512, 512)
    d = ImageDraw.Draw(img)
    c = S / 2
    rng = random.Random(3)
    outer = []
    inner = []
    for i in range(64):
        a = i / 64 * math.tau
        outer.append((c + math.cos(a) * S * 0.48, c + math.sin(a) * S * 0.48))
        ri = S * (0.36 + (0.05 if i % 2 == 0 else 0.0) * rng.uniform(0.6, 1.4))
        inner.append((c + math.cos(a) * ri, c + math.sin(a) * ri))
    d.polygon(outer, fill=OUTLINE)
    o2 = [(c + (x - c) * 0.96, c + (y - c) * 0.96) for x, y in outer]
    d.polygon(o2, fill=(255, 255, 255, 255))
    i2 = [(c + (x - c) * 1.04, c + (y - c) * 1.04) for x, y in inner]
    d.polygon(i2, fill=OUTLINE)
    d.polygon(inner, fill=(0, 0, 0, 0))
    save(finish(img, 512, 512), name)


def slash(name):
    W, H = 512, 256
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    S = SS

    def arc(R, thick, col):
        pts_o, pts_i = [], []
        for i in range(41):
            t = i / 40
            a = math.pi * (0.1 + 0.8 * t)
            th = thick * math.sin(math.pi * t) ** 0.7
            cx, cy = W * S / 2, H * S * 1.35
            pts_o.append((cx + math.cos(a) * (R + th) * -1, cy - math.sin(a) * (R + th)))
            pts_i.append((cx + math.cos(a) * (R - th * 0.2) * -1, cy - math.sin(a) * (R - th * 0.2)))
        d.polygon(pts_o + pts_i[::-1], fill=col)

    arc(H * S * 1.1, H * S * 0.2, OUTLINE)
    arc(H * S * 1.1, H * S * 0.15, (255, 255, 255, 255))
    save(finish(img, W, H), name)


def lightning_beam(name):
    W, H = 512, 128
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    rng = random.Random(11)
    S = SS
    pts = []
    x = 0
    while x <= W * S:
        pts.append((x, H * S / 2 + rng.uniform(-0.32, 0.32) * H * S))
        x += rng.uniform(18, 40) * S
    pts[-1] = (W * S, pts[0][1])  # tileable
    d.line(pts, fill=OUTLINE, width=int(16 * S), joint="curve")
    d.line(pts, fill=(255, 255, 255, 255), width=int(9 * S), joint="curve")
    # branches
    for i in range(1, len(pts) - 1, 3):
        x0, y0 = pts[i]
        x1, y1 = x0 + rng.uniform(10, 30) * S, y0 + rng.choice([-1, 1]) * rng.uniform(15, 35) * S
        d.line([(x0, y0), (x1, y1)], fill=OUTLINE, width=int(9 * S))
        d.line([(x0, y0), (x1, y1)], fill=(255, 255, 255, 255), width=int(4 * S))
    save(finish(img, W, H), name)


def flame_beam(colors, name):
    """Tileable horizontal flame band for Beams/Trails (U = length, V = width)."""
    W, H = 512, 128
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    S = SS

    def band(scale, col):
        top, bot = [], []
        for i in range(129):
            u = i / 128
            x = u * W * S
            wob = (math.sin(u * math.tau * 4) * 0.12 + math.sin(u * math.tau * 9 + 1) * 0.06) * scale
            th = H * S * 0.46 * scale * (1 + wob)
            top.append((x, H * S / 2 - th))
            bot.append((x, H * S / 2 + th * 0.85))
        d.polygon(top + bot[::-1], fill=col)

    band(1.0, OUTLINE)
    band(0.86, colors[1] + (255,))
    band(0.62, colors[2] + (255,))
    band(0.38, colors[3] + (255,))
    band(0.16, colors[4] + (255,))
    save(finish(img, W, H), name)


def crack_burst(name):
    S = 512 * SS
    img = canvas(512, 512)
    d = ImageDraw.Draw(img)
    rng = random.Random(5)
    c = S / 2
    r0 = S * 0.12
    d.ellipse([c - r0 * 1.3, c - r0 * 1.3, c + r0 * 1.3, c + r0 * 1.3], fill=(25, 10, 10, 230))
    paths = []
    for i in range(14):
        a = i / 14 * math.tau + rng.uniform(-0.15, 0.15)
        x, y = c, c
        pts = [(x, y)]
        L = S * rng.uniform(0.3, 0.47)
        steps = 8
        for s in range(steps):
            a += rng.uniform(-0.45, 0.45)
            x += math.cos(a) * L / steps
            y += math.sin(a) * L / steps
            pts.append((x, y))
        paths.append(pts)
    for pts in paths:
        d.line(pts, fill=OUTLINE, width=int(14 * SS), joint="curve")
    for pts in paths:
        d.line(pts, fill=(255, 90, 0, 255), width=int(9 * SS), joint="curve")
    for pts in paths:
        d.line(pts[: len(pts) // 2 + 1], fill=(255, 220, 30, 255), width=int(4 * SS), joint="curve")
    save(finish(img, 512, 512), name)


def sigil(name):
    S = 512 * SS
    img = canvas(512, 512)
    d = ImageDraw.Draw(img)
    c = S / 2
    W = (255, 255, 255, 255)

    def circle(r, w):
        d.ellipse([c - r - w, c - r - w, c + r + w, c + r + w], fill=OUTLINE)
        d.ellipse([c - r, c - r, c + r, c + r], fill=W)
        ri = r - w * 0.9
        d.ellipse([c - ri - w * 0.5, c - ri - w * 0.5, c + ri + w * 0.5, c + ri + w * 0.5], fill=OUTLINE)
        d.ellipse([c - ri, c - ri, c + ri, c + ri], fill=(0, 0, 0, 0))

    circle(S * 0.47, S * 0.025)
    circle(S * 0.4, S * 0.012)
    pts = []
    for i in range(5):
        a = i / 5 * math.tau - math.pi / 2
        pts.append((c + math.cos(a) * S * 0.39, c + math.sin(a) * S * 0.39))
    order = [pts[0], pts[2], pts[4], pts[1], pts[3], pts[0]]
    d.line(order, fill=OUTLINE, width=int(14 * SS), joint="curve")
    d.line(order, fill=W, width=int(8 * SS), joint="curve")
    # rune ticks between the rings
    for i in range(20):
        a = i / 20 * math.tau
        x0, y0 = c + math.cos(a) * S * 0.415, c + math.sin(a) * S * 0.415
        x1, y1 = c + math.cos(a + 0.08) * S * 0.445, c + math.sin(a + 0.08) * S * 0.445
        d.line([(x0, y0), (x1, y1)], fill=W, width=int(4 * SS))
    save(finish(img, 512, 512), name)


def lava_rock(name):
    W = 256
    rng = np.random.default_rng(9)
    noise = rng.random((W // 8, W // 8))
    noise = np.asarray(Image.fromarray((noise * 255).astype(np.uint8)).resize((W, W), Image.BICUBIC)).astype(np.float32) / 255
    tones = np.array([[28, 20, 22], [46, 34, 36], [66, 50, 50]], dtype=np.float32)
    idx = np.clip((noise * 3).astype(int), 0, 2)
    rgb = tones[idx]
    img = Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA").resize((W * SS, W * SS), Image.NEAREST)
    d = ImageDraw.Draw(img)
    r = random.Random(4)
    for _ in range(9):
        x, y = r.uniform(0, W * SS), r.uniform(0, W * SS)
        a = r.uniform(0, math.tau)
        pts = [(x, y)]
        for _ in range(7):
            a += r.uniform(-0.6, 0.6)
            x += math.cos(a) * 26 * SS
            y += math.sin(a) * 26 * SS
            pts.append((x, y))
        d.line(pts, fill=(10, 4, 4, 255), width=int(9 * SS), joint="curve")
        d.line(pts, fill=(255, 80, 0, 255), width=int(5 * SS), joint="curve")
        d.line(pts, fill=(255, 210, 40, 255), width=int(2 * SS), joint="curve")
    save(img.resize((W, W), Image.LANCZOS), name)


def contact_sheet():
    files = sorted(f for f in os.listdir(OUT) if f.endswith(".png"))
    tiles = []
    for f in files:
        im = Image.open(os.path.join(OUT, f)).convert("RGBA")
        im.thumbnail((256, 256))
        bg = Image.new("RGBA", (260, 280), (70, 110, 160, 255))
        bg.alpha_composite(im, ((260 - im.width) // 2, (260 - im.height) // 2))
        ImageDraw.Draw(bg).text((4, 264), f, fill=(255, 255, 255, 255))
        tiles.append(bg)
    cols = 5
    rows = math.ceil(len(tiles) / cols)
    sheet = Image.new("RGBA", (cols * 260, rows * 280), (40, 40, 40, 255))
    for i, t in enumerate(tiles):
        sheet.alpha_composite(t, ((i % cols) * 260, (i // cols) * 280))
    return sheet


if __name__ == "__main__":
    flame_flipbook(ORANGE_SET, "flame_orange_4x4.png", 1)
    flame_flipbook(VIOLET_SET, "flame_violet_4x4.png", 2)
    flame_flipbook(CRIMSON_SET, "flame_crimson_4x4.png", 3)
    explosion_flipbook(ORANGE_SET, "explosion_orange_4x4.png", 4)
    explosion_flipbook(VIOLET_SET, "explosion_violet_4x4.png", 5)
    explosion_flipbook(CRIMSON_SET, "explosion_crimson_4x4.png", 6)
    smoke_flipbook("smoke_2x2.png")
    star("spark_star.png")
    shock_ring("shock_ring.png")
    slash("slash_arc.png")
    lightning_beam("beam_lightning.png")
    flame_beam(ORANGE_SET, "beam_flame_orange.png")
    flame_beam(VIOLET_SET, "beam_flame_violet.png")
    crack_burst("crack_burst.png")
    sigil("sigil.png")
    lava_rock("lava_rock.png")
    import sys
    if len(sys.argv) > 1:
        contact_sheet().save(sys.argv[1])
        print("sheet", sys.argv[1])
