#!/usr/bin/env python3
"""Generate app icons for macOS and Android from one drawing.

Android shipped the stock Flutter template icon because this script only ever
wrote the macOS asset catalogue. It now emits both, so the two cannot drift.

Android gets two forms:

* Legacy `ic_launcher.png` per density — the whole icon, dark rounded background
  included, for pre-Android-8 launchers.
* An adaptive icon — a separate foreground and background layer, which Android 8+
  masks into whatever shape the launcher uses (circle, squircle, teardrop). The
  foreground must keep its art inside the middle 66% of the canvas: the system
  crops and can zoom for parallax, so anything closer to the edge gets cut.
"""
import math
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), '..')
OUT_DIR = os.path.join(ROOT, 'macos', 'Runner',
                       'Assets.xcassets', 'AppIcon.appiconset')
ANDROID_RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

BACKGROUND = (0x1A, 0x1A, 0x2E, 255)

# Launcher icon edge length in px per density bucket.
ANDROID_LEGACY = {
    'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192,
}
# Adaptive layers are 108dp square regardless of the art inside them.
ANDROID_ADAPTIVE = {
    'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432,
}
# Fraction of the adaptive canvas the art may occupy. The safe zone is 72/108 =
# 0.667; staying just inside it leaves room for the launcher's parallax zoom.
SAFE_ZONE = 0.62
SIZES = [16, 32, 64, 128, 256, 512, 1024]
RENDER_SIZE = 1024  # render at 1024 then downscale


def draw_flower(draw, s):
    cx, cy = s / 2, s * 0.44
    petal_len = s * 0.28
    petal_w = s * 0.16

    colors_even = (0x4A, 0x6C, 0xF7)
    colors_odd = (0x5B, 0x7D, 0xF2)

    for i in range(5):
        angle = math.radians(i * 72 - 90)
        pcx = cx + math.cos(angle) * petal_len * 0.52
        pcy = cy + math.sin(angle) * petal_len * 0.52
        color = colors_even if i % 2 == 0 else colors_odd

        # Draw petal as rotated ellipse
        half_w = petal_w / 2
        half_h = petal_len / 2
        rot_angle = angle + math.pi / 2

        # Draw filled ellipse using polygon approximation
        points = []
        for t in range(64):
            theta = 2 * math.pi * t / 64
            ex = half_w * math.cos(theta)
            ey = half_h * math.sin(theta)
            rx = ex * math.cos(rot_angle) - ey * math.sin(rot_angle)
            ry = ex * math.sin(rot_angle) + ey * math.cos(rot_angle)
            points.append((pcx + rx, pcy + ry))
        draw.polygon(points, fill=color)

    # Center
    r1 = s * 0.07
    draw.ellipse([cx - r1, cy - r1, cx + r1, cy + r1], fill=(0xE8, 0xD4, 0x4D))
    r2 = s * 0.04
    draw.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=(0xD4, 0xA0, 0x17))

    # Stem
    sw = max(2, int(s * 0.025))
    for t in range(100):
        tt = t / 99.0
        x = cx + (1 - tt) * 0 + tt * (-s * 0.015)
        y1 = cy + petal_len * 0.6
        y2 = s * 0.92
        y = y1 + tt * (y2 - y1)
        draw.ellipse([x - sw/2, y - sw/2, x + sw/2, y + sw/2],
                     fill=(0x5C, 0xAD, 0x5C))

    # Left leaf
    leaf_pts = []
    for t in range(32):
        tt = t / 31.0
        x = cx - s * 0.02 + tt * (cx - s * 0.22 - (cx - s * 0.02))
        y = s * 0.7 + tt * (s * 0.68 - s * 0.7)
        leaf_pts.append((x, y))
    for t in range(32):
        tt = t / 31.0
        x = cx - s * 0.22 + tt * (cx - s * 0.02 - (cx - s * 0.22))
        y = s * 0.68 + tt * (s * 0.73 - s * 0.68)
        leaf_pts.append((x, y))
    draw.polygon(leaf_pts, fill=(0x6B, 0xC0, 0x6B))

    # Right leaf
    leaf_pts2 = []
    for t in range(32):
        tt = t / 31.0
        x = cx + s * 0.01 + tt * (cx + s * 0.22 - (cx + s * 0.01))
        y = s * 0.78 + tt * (s * 0.76 - s * 0.78)
        leaf_pts2.append((x, y))
    for t in range(32):
        tt = t / 31.0
        x = cx + s * 0.22 + tt * (cx + s * 0.01 - (cx + s * 0.22))
        y = s * 0.76 + tt * (s * 0.81 - s * 0.76)
        leaf_pts2.append((x, y))
    draw.polygon(leaf_pts2, fill=(0x6B, 0xC0, 0x6B))


def rounded_rect_mask(size, radius):
    mask = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def full_icon(size):
    """The complete icon: flower on the dark rounded background."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    radius = int(size * 0.22)
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius,
                           fill=BACKGROUND)
    draw_flower(draw, size)
    img.putalpha(rounded_rect_mask(size, radius))
    return img


def flower_layer(size):
    """Just the flower, transparent behind it."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw_flower(ImageDraw.Draw(img), size)
    return img


def adaptive_foreground(size):
    """Flower centred and filling the adaptive icon's safe zone.

    The drawing has its own margins — petals start below the top edge, the stem
    stops short of the bottom — so scaling the whole canvas into the safe zone
    left the flower looking lost inside the mask. Crop to the art's actual
    bounding box first, then fit that, which uses the available room without
    crossing into the region launchers may clip.
    """
    art = flower_layer(size)
    bbox = art.getbbox()  # tight box around non-transparent pixels
    if bbox:
        art = art.crop(bbox)

    target = int(size * SAFE_ZONE)
    w, h = art.size
    scale = target / max(w, h)
    art = art.resize((max(1, int(w * scale)), max(1, int(h * scale))),
                     Image.LANCZOS)

    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(art, ((size - art.width) // 2, (size - art.height) // 2), art)
    return out


def write_android():
    master = full_icon(RENDER_SIZE)
    for bucket, px in ANDROID_LEGACY.items():
        d = os.path.join(ANDROID_RES, f'mipmap-{bucket}')
        os.makedirs(d, exist_ok=True)
        out = os.path.join(d, 'ic_launcher.png')
        master.resize((px, px), Image.LANCZOS).save(out, 'PNG')
        print(f'Generated {out} ({px}x{px})')

    fg_master = adaptive_foreground(RENDER_SIZE)
    for bucket, px in ANDROID_ADAPTIVE.items():
        d = os.path.join(ANDROID_RES, f'mipmap-{bucket}')
        os.makedirs(d, exist_ok=True)
        out = os.path.join(d, 'ic_launcher_foreground.png')
        fg_master.resize((px, px), Image.LANCZOS).save(out, 'PNG')
        print(f'Generated {out} ({px}x{px})')

    # Background is a flat colour, so a drawable beats five more PNGs.
    values = os.path.join(ANDROID_RES, 'values')
    os.makedirs(values, exist_ok=True)
    hex_bg = '#%02X%02X%02X' % BACKGROUND[:3]
    with open(os.path.join(values, 'ic_launcher_background.xml'), 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<resources>\n'
                f'    <color name="ic_launcher_background">{hex_bg}</color>\n'
                '</resources>\n')

    # anydpi-v26 is what Android 8+ picks up in preference to the bitmaps.
    anydpi = os.path.join(ANDROID_RES, 'mipmap-anydpi-v26')
    os.makedirs(anydpi, exist_ok=True)
    xml = ('<?xml version="1.0" encoding="utf-8"?>\n'
           '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
           '    <background android:drawable="@color/ic_launcher_background" />\n'
           '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
           '</adaptive-icon>\n')
    out = os.path.join(anydpi, 'ic_launcher.xml')
    with open(out, 'w') as f:
        f.write(xml)
    print(f'Generated {out}')


WINDOWS_ICO_PATH = os.path.join(ROOT, 'windows', 'runner', 'resources', 'app_icon.ico')
ASSET_FLAX_PNG = os.path.join(ROOT, 'assets', 'flax.png')


def write_windows():
    master = full_icon(RENDER_SIZE)
    ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    os.makedirs(os.path.dirname(WINDOWS_ICO_PATH), exist_ok=True)
    master.save(WINDOWS_ICO_PATH, format='ICO', sizes=ico_sizes)
    print(f'Generated {WINDOWS_ICO_PATH} with sizes: {ico_sizes}')


def write_assets():
    master = full_icon(512)
    master.save(ASSET_FLAX_PNG, 'PNG')
    print(f'Generated {ASSET_FLAX_PNG} (512x512)')


def main():
    s = RENDER_SIZE
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Rounded rect background
    radius = int(s * 0.22)
    draw.rounded_rectangle([0, 0, s - 1, s - 1], radius=radius,
                           fill=(0x1A, 0x1A, 0x2E, 255))

    draw_flower(draw, s)

    # Apply rounded mask
    mask = rounded_rect_mask(s, radius)
    img.putalpha(mask)

    os.makedirs(OUT_DIR, exist_ok=True)
    for size in SIZES:
        resized = img.resize((size, size), Image.LANCZOS)
        out_path = os.path.join(OUT_DIR, f'app_icon_{size}.png')
        resized.save(out_path, 'PNG')
        print(f'Generated {out_path} ({size}x{size})')

    write_android()
    write_windows()
    write_assets()
    print('Done!')


if __name__ == '__main__':
    main()
