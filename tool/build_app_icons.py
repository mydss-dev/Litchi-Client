"""Rebuild Litchi app icon assets from the brand mark source.

The design source is a 96x96 PNG (charcoal rounded square + white glyph), far
too small to upsample into launcher icons: a plain resize either blurs the edge
or, after thresholding, leaves a staircase. This script instead converts the
glyph coverage into a signed distance field, upsamples that (distance fields
interpolate cleanly), and re-thresholds at sub-pixel precision, so strokes keep
their designed weight and round caps stay round at 1024px.

Usage:
    python tool/build_app_icons.py <source.png>

Writes:
    assets/images/app_icon.png             1024 full-bleed rounded square
    assets/images/app_icon_background.png  1024 adaptive background
    assets/images/app_icon_foreground.png  1024 adaptive foreground (safe zone)
    assets/images/app_icon_mono.png        1024 monochrome notification glyph
    windows/runner/resources/app_icon.ico  multi-size Windows icon
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]

BG_COLOR = (44, 44, 44, 255)  # #2C2C2C charcoal, measured from the source
MARK_COLOR = (255, 255, 255, 255)
SOURCE_SIZE = 96
GLYPH_BOX = (12, 12, 84, 84)  # glyph occupies the inner 72px
CORNER_RATIO = 13 / SOURCE_SIZE
GLYPH_RATIO = 72 / SOURCE_SIZE
ADAPTIVE_SAFE = 0.62  # Android adaptive icons keep art inside the 66/108 circle
WORK_SIZE = 1024
SUPERSAMPLE = 4
SDF_UPSCALE = 16  # distance field resolution multiplier before resampling


def _edt_1d(f: list[float]) -> list[float]:
    """Felzenszwalb & Huttenlocher exact 1D squared distance transform."""
    n = len(f)
    d = [0.0] * n
    v = [0] * n
    z = [0.0] * (n + 1)
    k = 0
    v[0] = 0
    z[0] = -math.inf
    z[1] = math.inf
    for q in range(1, n):
        while True:
            s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k])
            if s <= z[k] and k > 0:
                k -= 1
                continue
            break
        if s <= z[k]:
            k = 0
        k += 1
        v[k] = q
        z[k] = s
        z[k + 1] = math.inf
    k = 0
    for q in range(n):
        while z[k + 1] < q:
            k += 1
        d[q] = (q - v[k]) * (q - v[k]) + f[v[k]]
    return d


def _edt2d(grid: list[list[float]]) -> list[list[float]]:
    rows = [_edt_1d(row) for row in grid]
    height = len(rows)
    width = len(rows[0])
    cols = [[rows[y][x] for y in range(height)] for x in range(width)]
    cols = [_edt_1d(col) for col in cols]
    return [[cols[x][y] for x in range(width)] for y in range(height)]


def glyph_coverage(source: Path) -> list[list[float]]:
    """Anti-aliased glyph coverage in [0,1], cropped to the glyph box."""
    src = Image.open(source).convert("RGBA")
    if src.size != (SOURCE_SIZE, SOURCE_SIZE):
        src = src.resize((SOURCE_SIZE, SOURCE_SIZE), Image.LANCZOS)
    src = src.crop(GLYPH_BOX)
    luma = src.convert("L")
    alpha = src.getchannel("A")
    width, height = src.size
    cover: list[list[float]] = []
    for y in range(height):
        row: list[float] = []
        for x in range(width):
            # A glyph pixel is bright and inside the rounded square; coverage is
            # the brightness itself, which carries the anti-aliased edge.
            a = alpha.getpixel((x, y)) / 255.0
            v = max(0.0, (luma.getpixel((x, y)) - 44) / (255 - 44))
            row.append(min(1.0, v * a))
        cover.append(row)
    return cover


SDF_CLAMP = 10.0  # beyond this the coverage is fully saturated either way


def signed_distance(cover: list[list[float]]) -> list[list[float]]:
    """Signed distance in source pixels: negative inside the glyph."""
    height = len(cover)
    width = len(cover[0])
    big = 1e6
    # Grids whose zero set is the glyph / the background respectively, so the
    # transforms yield "distance to glyph" and "distance to background".
    to_glyph = [[0.0 if cover[y][x] >= 0.5 else big for x in range(width)] for y in range(height)]
    to_bg = [[0.0 if cover[y][x] < 0.5 else big for x in range(width)] for y in range(height)]
    d_glyph = _edt2d(to_glyph)
    d_bg = _edt2d(to_bg)
    sdf: list[list[float]] = []
    for y in range(height):
        row: list[float] = []
        for x in range(width):
            outside = max(math.sqrt(d_glyph[y][x]) - 0.5, 0.0)
            inside = max(math.sqrt(d_bg[y][x]) - 0.5, 0.0)
            # Coverage refines the half-pixel quantisation of the binary mask.
            value = outside - inside + (0.5 - cover[y][x])
            row.append(max(-SDF_CLAMP, min(SDF_CLAMP, value)))
        sdf.append(row)
    return sdf


def render_glyph(sdf: list[list[float]], size: int, ratio: float) -> Image.Image:
    """Rasterise the distance field as a white glyph on transparency."""
    height = len(sdf)
    width = len(sdf[0])
    span = int(round(size * ratio))
    scale = span / width  # target pixels per source pixel

    # Encode the field into 8 bits with a ±SDF_CLAMP range, then resample the
    # *encoded* field: distances are smooth, so this resamples cleanly, and the
    # byte range is wide enough that quantisation stays under a tenth of a pixel.
    step = 127.0 / SDF_CLAMP
    field = Image.new("L", (width, height))
    field.putdata([int(round(128 + v * step)) for row in sdf for v in row])
    # The 72px source quantises the outline into whole pixels, which leaves a
    # sub-pixel scallop in the distance field. A light low-pass at source
    # resolution removes that ripple without moving the zero crossing.
    field = field.filter(ImageFilter.GaussianBlur(radius=0.6))
    big = field.resize((span * SUPERSAMPLE, span * SUPERSAMPLE), Image.BICUBIC)

    # Decode and turn the distance into coverage in a single C-level LUT pass.
    edge = scale * SUPERSAMPLE  # source-pixel distance -> high-res pixels
    lut = []
    for raw in range(256):
        d = (raw - 128) / step
        cov = 0.5 - d * edge
        lut.append(0 if cov <= 0 else 255 if cov >= 1 else int(round(cov * 255)))
    alpha = big.point(lut).resize((span, span), Image.LANCZOS)

    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset = (size - span) // 2
    layer.paste(Image.new("RGBA", (span, span), MARK_COLOR), (offset, offset), alpha)
    return layer


def rounded_bg(size: int, radius_ratio: float = CORNER_RATIO) -> Image.Image:
    s = size * SUPERSAMPLE
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle(
        (0, 0, s - 1, s - 1), radius=int(round(s * radius_ratio)), fill=BG_COLOR
    )
    return img.resize((size, size), Image.LANCZOS)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    source = Path(sys.argv[1]).expanduser().resolve()
    if not source.exists():
        print(f"source not found: {source}")
        return 1

    images_dir = ROOT / "assets" / "images"
    images_dir.mkdir(parents=True, exist_ok=True)

    sdf = signed_distance(glyph_coverage(source))

    app_icon = rounded_bg(WORK_SIZE)
    app_icon.alpha_composite(render_glyph(sdf, WORK_SIZE, GLYPH_RATIO))
    app_icon.save(images_dir / "app_icon.png")

    Image.new("RGBA", (WORK_SIZE, WORK_SIZE), BG_COLOR).save(
        images_dir / "app_icon_background.png"
    )
    # Adaptive foreground sits inside the launcher's safe circle.
    render_glyph(sdf, WORK_SIZE, GLYPH_RATIO * ADAPTIVE_SAFE / 0.75).save(
        images_dir / "app_icon_foreground.png"
    )
    render_glyph(sdf, WORK_SIZE, GLYPH_RATIO).save(images_dir / "app_icon_mono.png")

    ico_path = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    ico_path.parent.mkdir(parents=True, exist_ok=True)
    app_icon.save(
        ico_path,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )

    for path in (
        images_dir / "app_icon.png",
        images_dir / "app_icon_background.png",
        images_dir / "app_icon_foreground.png",
        images_dir / "app_icon_mono.png",
        ico_path,
    ):
        print(f"wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
