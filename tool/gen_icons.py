#!/usr/bin/env python3
"""Generate macOS app icon PNGs using Pillow."""
import math
import os
from PIL import Image, ImageDraw

OUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'macos', 'Runner',
                       'Assets.xcassets', 'AppIcon.appiconset')
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

    print('Done!')


if __name__ == '__main__':
    main()
