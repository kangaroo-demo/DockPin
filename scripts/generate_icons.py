#!/usr/bin/env python3
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Resources"
ICONSET = RESOURCES / "AppIcon.iconset"
ICNS = RESOURCES / "AppIcon.icns"


def rounded_rectangle_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def vertical_gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels = image.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        color = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)) + (255,)
        for x in range(size):
            pixels[x, y] = color
    return image


def draw_app_icon(size: int) -> Image.Image:
    scale = size / 1024
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    inset = int(46 * scale)
    radius = int(210 * scale)
    shadow_draw.rounded_rectangle(
        (inset, inset + int(18 * scale), size - inset, size - inset + int(18 * scale)),
        radius=radius,
        fill=(0, 0, 0, 80),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(28 * scale)))
    image.alpha_composite(shadow)

    mask = rounded_rectangle_mask(size - inset * 2, radius)
    background = vertical_gradient(size - inset * 2, (22, 145, 255), (0, 100, 210))
    icon_body = Image.new("RGBA", (size - inset * 2, size - inset * 2), (0, 0, 0, 0))
    icon_body.alpha_composite(background)

    body_draw = ImageDraw.Draw(icon_body)
    side = size - inset * 2
    body_draw.rounded_rectangle(
        (int(48 * scale), int(50 * scale), side - int(48 * scale), side - int(48 * scale)),
        radius=int(164 * scale),
        outline=(255, 255, 255, 36),
        width=max(2, int(6 * scale)),
    )

    # Keep the mark intentionally simple so it stays readable at Dock size:
    # one display, one Dock edge, one pin dot.
    screen = (
        int(side * 0.22),
        int(side * 0.28),
        int(side * 0.78),
        int(side * 0.60),
    )
    body_draw.rounded_rectangle(
        screen,
        radius=int(42 * scale),
        outline=(236, 247, 255, 248),
        width=max(8, int(48 * scale)),
    )
    body_draw.rounded_rectangle(
        (int(side * 0.28), int(side * 0.68), int(side * 0.72), int(side * 0.725)),
        radius=int(18 * scale),
        fill=(255, 255, 255, 232),
    )

    pin_cx = side * 0.71
    pin_cy = side * 0.31
    pin_r = side * 0.095
    body_draw.ellipse(
        (
            pin_cx - pin_r + int(8 * scale),
            pin_cy - pin_r + int(10 * scale),
            pin_cx + pin_r + int(8 * scale),
            pin_cy + pin_r + int(10 * scale),
        ),
        fill=(0, 72, 145, 42),
    )
    body_draw.ellipse(
        (pin_cx - pin_r, pin_cy - pin_r, pin_cx + pin_r, pin_cy + pin_r),
        fill=(34, 197, 94, 255),
    )
    body_draw.ellipse(
        (pin_cx - pin_r * 0.42, pin_cy - pin_r * 0.42, pin_cx + pin_r * 0.42, pin_cy + pin_r * 0.42),
        fill=(255, 255, 255, 245),
    )

    icon_body.putalpha(Image.composite(mask, Image.new("L", mask.size, 0), mask))
    image.alpha_composite(icon_body, (inset, inset))
    return image


def draw_status_icon(size: int) -> Image.Image:
    scale = size / 18
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    stroke = max(1, round(1.7 * scale))

    draw.rounded_rectangle(
        (2.5 * scale, 3.1 * scale, 15.5 * scale, 12.3 * scale),
        radius=2.0 * scale,
        outline=(0, 0, 0, 255),
        width=stroke,
    )
    draw.line((5.4 * scale, 14.5 * scale, 12.6 * scale, 14.5 * scale), fill=(0, 0, 0, 255), width=stroke)

    cx, cy, radius = 12.8 * scale, 5.6 * scale, 2.2 * scale
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=(0, 0, 0, 255))
    inner = 0.75 * scale
    draw.ellipse((cx - inner, cy - inner, cx + inner, cy + inner), fill=(0, 0, 0, 0))
    return image


def write_iconset() -> None:
    if ICONSET.exists():
        shutil.rmtree(ICONSET)
    ICONSET.mkdir(parents=True)

    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    base = draw_app_icon(1024)
    for pixel_size, filename in sizes:
        resized = base.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
        resized.save(ICONSET / filename)


def write_status_icons() -> None:
    draw_status_icon(18).save(RESOURCES / "StatusIcon.png")
    draw_status_icon(36).save(RESOURCES / "StatusIcon@2x.png")


def main() -> None:
    RESOURCES.mkdir(exist_ok=True)
    write_iconset()
    write_status_icons()
    if ICNS.exists():
        ICNS.unlink()
    subprocess.run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(ICNS)], check=True)
    print(f"Wrote {ICNS.relative_to(ROOT)}")
    print("Wrote Resources/StatusIcon.png and Resources/StatusIcon@2x.png")


if __name__ == "__main__":
    main()
