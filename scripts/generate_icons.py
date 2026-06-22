#!/usr/bin/env python3
from __future__ import annotations

import math
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


def pin_points(cx: float, cy: float, radius: float) -> list[tuple[float, float]]:
    return [
        (cx, cy + radius * 1.75),
        (cx - radius * 0.95, cy + radius * 0.2),
        (cx - radius * 0.75, cy - radius * 0.65),
        (cx, cy - radius),
        (cx + radius * 0.75, cy - radius * 0.65),
        (cx + radius * 0.95, cy + radius * 0.2),
    ]


def draw_app_icon(size: int) -> Image.Image:
    scale = size / 1024
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    inset = int(42 * scale)
    radius = int(210 * scale)
    shadow_draw.rounded_rectangle(
        (inset, inset + int(18 * scale), size - inset, size - inset + int(18 * scale)),
        radius=radius,
        fill=(0, 0, 0, 80),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(28 * scale)))
    image.alpha_composite(shadow)

    mask = rounded_rectangle_mask(size - inset * 2, radius)
    background = vertical_gradient(size - inset * 2, (18, 142, 255), (20, 86, 210))
    icon_body = Image.new("RGBA", (size - inset * 2, size - inset * 2), (0, 0, 0, 0))
    icon_body.alpha_composite(background)

    body_draw = ImageDraw.Draw(icon_body)
    body_draw.rounded_rectangle(
        (int(46 * scale), int(48 * scale), size - inset * 2 - int(46 * scale), size - inset * 2 - int(46 * scale)),
        radius=int(164 * scale),
        outline=(255, 255, 255, 55),
        width=max(2, int(8 * scale)),
    )

    body_draw.rectangle(
        (int(170 * scale), int(686 * scale), size - inset * 2 - int(170 * scale), int(742 * scale)),
        fill=(255, 255, 255, 210),
    )
    body_draw.rounded_rectangle(
        (int(210 * scale), int(250 * scale), size - inset * 2 - int(210 * scale), int(642 * scale)),
        radius=int(44 * scale),
        fill=(236, 247, 255, 248),
    )
    body_draw.rounded_rectangle(
        (int(252 * scale), int(292 * scale), size - inset * 2 - int(252 * scale), int(582 * scale)),
        radius=int(28 * scale),
        fill=(39, 123, 220, 35),
    )
    body_draw.rectangle(
        (int(342 * scale), int(646 * scale), size - inset * 2 - int(342 * scale), int(690 * scale)),
        fill=(236, 247, 255, 248),
    )

    icon_body.putalpha(Image.composite(mask, Image.new("L", mask.size, 0), mask))
    image.alpha_composite(icon_body, (inset, inset))

    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    cx = size * 0.66
    cy = size * 0.42
    radius_pin = size * 0.145

    pin_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pin_shadow_draw = ImageDraw.Draw(pin_shadow)
    pin_shadow_draw.polygon(pin_points(cx, cy + size * 0.02, radius_pin), fill=(0, 0, 0, 85))
    pin_shadow = pin_shadow.filter(ImageFilter.GaussianBlur(int(10 * scale)))
    overlay.alpha_composite(pin_shadow)

    draw.polygon(pin_points(cx, cy, radius_pin), fill=(0, 199, 125, 255))
    draw.ellipse(
        (cx - radius_pin * 0.58, cy - radius_pin * 0.58, cx + radius_pin * 0.58, cy + radius_pin * 0.58),
        fill=(255, 255, 255, 245),
    )
    draw.ellipse(
        (cx - radius_pin * 0.28, cy - radius_pin * 0.28, cx + radius_pin * 0.28, cy + radius_pin * 0.28),
        fill=(20, 110, 220, 255),
    )

    # A small dock-edge line under the pin ties the icon to the app's purpose.
    draw.rounded_rectangle(
        (size * 0.38, size * 0.70, size * 0.74, size * 0.745),
        radius=size * 0.02,
        fill=(255, 255, 255, 225),
    )
    image.alpha_composite(overlay)
    return image


def draw_status_icon(size: int) -> Image.Image:
    scale = size / 18
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    stroke = max(1, round(1.7 * scale))

    draw.rounded_rectangle(
        (2.5 * scale, 3.0 * scale, 15.5 * scale, 12.2 * scale),
        radius=2.0 * scale,
        outline=(0, 0, 0, 255),
        width=stroke,
    )
    draw.line((5.2 * scale, 14.5 * scale, 12.8 * scale, 14.5 * scale), fill=(0, 0, 0, 255), width=stroke)
    draw.line((9.0 * scale, 12.4 * scale, 9.0 * scale, 14.2 * scale), fill=(0, 0, 0, 255), width=stroke)

    cx, cy, radius = 12.4 * scale, 6.3 * scale, 2.5 * scale
    draw.polygon(pin_points(cx, cy, radius), fill=(0, 0, 0, 255))
    draw.ellipse((cx - 1.0 * scale, cy - 1.0 * scale, cx + 1.0 * scale, cy + 1.0 * scale), fill=(0, 0, 0, 0))
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
