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
    draw = ImageDraw.Draw(image)

    # Flat, bright brand mark: two display layers held by a single Dock rail.
    # Keep the geometry bold and literal-detail-free so it survives at 16 px.
    inset = int(42 * scale)
    radius = int(190 * scale)
    draw.rounded_rectangle(
        (inset, inset, size - inset, size - inset),
        radius=radius,
        fill=(244, 248, 255, 255),
    )

    navy = (28, 54, 105, 255)
    cobalt = (42, 103, 239, 255)
    cyan = (13, 198, 196, 255)
    coral = (255, 106, 86, 255)

    # Connector first, so the two layers read as one stable system.
    draw.rounded_rectangle(
        (int(474 * scale), int(350 * scale), int(550 * scale), int(674 * scale)),
        radius=int(38 * scale),
        fill=navy,
    )
    # Upper and lower display layers.
    draw.rounded_rectangle(
        (int(188 * scale), int(220 * scale), int(836 * scale), int(424 * scale)),
        radius=int(70 * scale),
        fill=cobalt,
    )
    draw.rounded_rectangle(
        (int(188 * scale), int(600 * scale), int(836 * scale), int(804 * scale)),
        radius=int(70 * scale),
        fill=cyan,
    )
    # The Dock rail is the recognizable brand accent, not a map marker.
    draw.rounded_rectangle(
        (int(276 * scale), int(442 * scale), int(748 * scale), int(582 * scale)),
        radius=int(62 * scale),
        fill=coral,
    )
    draw.ellipse(
        (int(462 * scale), int(468 * scale), int(562 * scale), int(568 * scale)),
        fill=(244, 248, 255, 255),
    )
    draw.ellipse(
        (int(493 * scale), int(499 * scale), int(531 * scale), int(537 * scale)),
        fill=navy,
    )
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
