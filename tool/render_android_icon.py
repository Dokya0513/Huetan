"""Renders the Android launcher icon, adaptive icon foreground, and Android
12+ splash icon as the "ふえたん" wordmark: "ふえ" above, and a "たん" card
cascade (pink card in front, blue/green stepping to the right behind it,
using the app's usual blue/pink/green trio) below.

Hand-drawn with Pillow, same approach as render_icon.py, since no SVG
rasterizer is available in this environment.
"""

from PIL import Image, ImageDraw, ImageFont

SCALE = 6
CANVAS = 512 * SCALE
BG = (255, 255, 255, 255)
TEXT_COLOR = (28, 25, 23, 255)  # appColors.textPrimary (light)
BLUE = (14, 165, 233, 255)  # box+cards mark blue
PINK = (219, 39, 119, 255)  # box+cards mark pink / AppWordmark card fill
GREEN = (101, 163, 13, 255)  # box+cards mark green
FONT_PATH = "assets/fonts/ZenMaruGothic-Bold.ttf"

MIPMAP_SIZES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def s(v):
    return v * SCALE


def rounded_rect_image(w, h, radius, fill):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=fill)
    return img


def paste_rotated(base, piece, cx, cy, angle_deg):
    rotated = piece.rotate(angle_deg, expand=True, resample=Image.BICUBIC)
    x = int(cx - rotated.width / 2)
    y = int(cy - rotated.height / 2)
    base.alpha_composite(rotated, (x, y))


FUE_LETTER_SPACING_RATIO = 0.125  # gap between "ふ" and "え", relative to font_size


def _fue_metrics(font_size):
    font = ImageFont.truetype(FONT_PATH, font_size)
    scratch = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    fu_bbox = scratch.textbbox((0, 0), "ふ", font=font)
    fu_w = fu_bbox[2] - fu_bbox[0]
    e_bbox = scratch.textbbox((0, 0), "え", font=font)
    e_w = e_bbox[2] - e_bbox[0]
    fue_bbox = scratch.textbbox((0, 0), "ふえ", font=font)
    fue_h = fue_bbox[3] - fue_bbox[1]
    letter_spacing = font_size * FUE_LETTER_SPACING_RATIO
    fue_w = fu_w + letter_spacing + e_w
    return fu_w, e_w, letter_spacing, fue_w, fue_h


def _tan_cascade_metrics(font_size, fue_w):
    """"たん" badge geometry shared by drawing and measuring: pink card in
    front (frontmost, lowest-left), blue then green stepping only to the
    right behind it (no vertical growth) — design "U" from the logo
    exploration round. step_x is widened (never shrunk) so the cascade's
    total width matches fue_w above it, keeping both rows visually
    center-aligned to the same block width."""
    pad_h = font_size * 0.33
    pad_v = font_size * 0.16
    min_step_x = font_size * 0.09
    scratch = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    font = ImageFont.truetype(FONT_PATH, font_size)
    tan_bbox = scratch.textbbox((0, 0), "たん", font=font)
    tan_text_w = tan_bbox[2] - tan_bbox[0]
    tan_text_h = tan_bbox[3] - tan_bbox[1]
    card_w = tan_text_w + pad_h * 2
    card_h = tan_text_h + pad_v * 2
    step_x = max(min_step_x, (fue_w - card_w) / 2)
    return card_w, card_h, step_x


def draw_wordmark_stacked(canvas, cx, cy, font_size):
    """"ふえ" centered above, the "たん" card cascade centered below it,
    both rows matched to the same block width. The cascade only grows
    rightward (not upward), so the two rows can sit close together without
    the card corners touching the text above."""
    font = ImageFont.truetype(FONT_PATH, font_size)
    draw = ImageDraw.Draw(canvas)

    fu_w, e_w, letter_spacing, fue_w, fue_h = _fue_metrics(font_size)
    card_w, card_h, step_x = _tan_cascade_metrics(font_size, fue_w)
    row_gap = font_size * 0.3

    total_h = fue_h + row_gap + card_h
    top = cy - total_h / 2
    row1_center_y = top + fue_h / 2
    row2_center_y = top + fue_h + row_gap + card_h / 2

    fu_x = cx - fue_w / 2
    draw.text((fu_x, row1_center_y), "ふ", font=font, fill=TEXT_COLOR, anchor="lm")
    e_x = fu_x + fu_w + letter_spacing
    draw.text((e_x, row1_center_y), "え", font=font, fill=TEXT_COLOR, anchor="lm")

    cascade_w = card_w + step_x * 2
    tan_cx = cx - cascade_w / 2 + card_w / 2  # left-align cascade to fue_w block
    radius = int(card_h * 0.22)

    green = rounded_rect_image(int(card_w), int(card_h), radius, GREEN)
    paste_rotated(canvas, green, tan_cx + step_x * 2, row2_center_y, 0)
    blue = rounded_rect_image(int(card_w), int(card_h), radius, BLUE)
    paste_rotated(canvas, blue, tan_cx + step_x, row2_center_y, 0)
    pink = rounded_rect_image(int(card_w), int(card_h), radius, PINK)
    paste_rotated(canvas, pink, tan_cx, row2_center_y, 0)

    draw.text(
        (tan_cx, row2_center_y), "たん", font=font, fill=(255, 255, 255, 255), anchor="mm"
    )

    total_w = max(fue_w, cascade_w)
    return total_w, total_h


def measure_wordmark_stacked(font_size):
    _, _, _, fue_w, fue_h = _fue_metrics(font_size)
    card_w, card_h, step_x = _tan_cascade_metrics(font_size, fue_w)
    row_gap = font_size * 0.3
    total_h = fue_h + row_gap + card_h
    total_w = max(fue_w, card_w + step_x * 2)
    return total_w, total_h


def draw_wordmark_stacked_fit(canvas, cx, cy, target_diagonal_fraction, canvas_size):
    """Solves for a font size so the stacked block's bounding diagonal
    equals target_diagonal_fraction * canvas_size (the safe measure for a
    circular mask), then draws it centered at (cx, cy)."""
    probe = 100
    probe_w, probe_h = measure_wordmark_stacked(probe)
    probe_diag = (probe_w**2 + probe_h**2) ** 0.5
    target_diag = target_diagonal_fraction * canvas_size
    font_size = int(probe * (target_diag / probe_diag))
    draw_wordmark_stacked(canvas, cx, cy, font_size)


# Adaptive icon foreground layers are 108dp for a 72dp "safe zone" circle;
# scaling factors below are the same as MIPMAP_SIZES (48/72/96/144/192 * 2.25).
FOREGROUND_SIZES = {
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432,
}


def render_legacy():
    """Square icon with opaque white background, used pre-Android-8 and as
    the mipmap-anydpi-v26-less fallback. Wordmark-only (no box+cards mark)
    for maximum presence at small sizes — a wide block of solid color reads
    far better than a thin-line pictorial mark once shrunk to 48px."""
    canvas = Image.new("RGBA", (CANVAS, CANVAS), BG)
    draw_wordmark_stacked_fit(canvas, CANVAS / 2, CANVAS / 2, 0.62, CANVAS)

    master = canvas.resize((512, 512), Image.LANCZOS)
    master.save("assets/logo/android_launcher_icon_512.png")

    for density, size in MIPMAP_SIZES.items():
        resized = master.resize((size, size), Image.LANCZOS)
        out_path = f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
        resized.save(out_path)
        print(f"wrote {out_path} ({size}x{size})")


def render_foreground():
    """Transparent-background layer for the adaptive icon. Centered exactly
    on the mask's vertical midpoint, a wide-but-short wordmark can safely
    span close to the full canvas width without corner-clipping under a
    circular mask (the mask's widest point is exactly at that midline)."""
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw_wordmark_stacked_fit(canvas, CANVAS / 2, CANVAS / 2, 0.66, CANVAS)

    master = canvas.resize((512, 512), Image.LANCZOS)
    master.save("assets/logo/android_launcher_foreground_512.png")

    for density, size in FOREGROUND_SIZES.items():
        resized = master.resize((size, size), Image.LANCZOS)
        out_path = f"android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png"
        resized.save(out_path)
        print(f"wrote {out_path} ({size}x{size})")


def render_splash_icon():
    """Wordmark for the Android 12+ system splash screen. Kept a bit more
    conservative in width than the launcher foreground since some OEM
    launchers mask the splash icon more tightly than the home-screen one."""
    import os

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw_wordmark_stacked_fit(canvas, CANVAS / 2, CANVAS / 2, 0.52, CANVAS)

    master = canvas.resize((512, 512), Image.LANCZOS)
    out_dir = "android/app/src/main/res/drawable"
    os.makedirs(out_dir, exist_ok=True)
    master.save(f"{out_dir}/ic_splash_icon.png")
    print(f"wrote {out_dir}/ic_splash_icon.png (512x512)")


def write_splash_theme_xml():
    import os

    v31_dir = "android/app/src/main/res/values-v31"
    os.makedirs(v31_dir, exist_ok=True)
    with open(f"{v31_dir}/styles.xml", "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            '    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">\n'
            '        <item name="android:windowSplashScreenBackground">@color/ic_launcher_background</item>\n'
            '        <item name="android:windowSplashScreenAnimatedIcon">@drawable/ic_splash_icon</item>\n'
            '        <item name="android:windowBackground">@drawable/launch_background</item>\n'
            "    </style>\n"
            "</resources>\n"
        )
    print(f"wrote {v31_dir}/styles.xml")


def write_adaptive_icon_xml():
    import os

    values_dir = "android/app/src/main/res/values"
    os.makedirs(values_dir, exist_ok=True)
    with open(f"{values_dir}/ic_launcher_background.xml", "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            '    <color name="ic_launcher_background">#FFFFFF</color>\n'
            "</resources>\n"
        )

    anydpi_dir = "android/app/src/main/res/mipmap-anydpi-v26"
    os.makedirs(anydpi_dir, exist_ok=True)
    adaptive_xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n"
    )
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(f"{anydpi_dir}/{name}", "w", encoding="utf-8") as f:
            f.write(adaptive_xml)
        print(f"wrote {anydpi_dir}/{name}")
    print(f"wrote {values_dir}/ic_launcher_background.xml")


def main():
    render_legacy()
    render_foreground()
    render_splash_icon()
    write_adaptive_icon_xml()
    write_splash_theme_xml()


if __name__ == "__main__":
    main()
