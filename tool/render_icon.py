"""Renders assets/logo/icon.svg (box + cards mark) as a high-res PNG using
Pillow, then exports a multi-size .ico for the Windows app icon. Redrawn by
hand instead of parsed from the SVG since no SVG rasterizer is available in
this environment; geometry mirrors icon.svg's viewBox (0 0 88 88).
"""

from PIL import Image, ImageDraw

SCALE = 12  # 88 * 12 = 1056, downsampled later for antialiasing
SIZE = 88 * SCALE


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


def main():
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    def s(v):
        return v * SCALE

    # Three cards piling into the box (matches icon.svg).
    card1 = rounded_rect_image(s(26), s(18), s(4), (14, 165, 233, 255))  # blue
    paste_rotated(canvas, card1, s(33), s(19), -10)

    card2 = rounded_rect_image(s(26), s(18), s(4), (219, 39, 119, 255))  # pink
    paste_rotated(canvas, card2, s(55), s(15), 10)

    card3 = rounded_rect_image(s(26), s(18), s(4), (101, 163, 13, 255))  # green
    paste_rotated(canvas, card3, s(43), s(29), -2)

    draw = ImageDraw.Draw(canvas)

    # Box body (white fill, blue outline) — path approximated as a polygon.
    box_points = [
        (s(14), s(42)),
        (s(74), s(42)),
        (s(67), s(80)),
        (s(61), s(86)),
        (s(27), s(86)),
        (s(21), s(80)),
    ]
    draw.polygon(box_points, fill=(255, 255, 255, 255))
    draw.line(box_points + [box_points[0]], fill=(2, 132, 199, 255), width=s(4), joint="curve")

    # Box lid (solid bar across the top of the box).
    draw.rounded_rectangle(
        [s(10), s(38), s(78), s(48)], radius=s(4), fill=(2, 132, 199, 255)
    )

    final = canvas.resize((256, 256), Image.LANCZOS)
    final.save("assets/logo/icon_1024.png")

    sizes = [16, 24, 32, 48, 64, 128, 256]
    icons = [final.resize((s, s), Image.LANCZOS) for s in sizes]
    icons[0].save(
        "windows/runner/resources/app_icon.ico",
        format="ICO",
        sizes=[(s, s) for s in sizes],
        append_images=icons[1:],
    )
    print("done")


if __name__ == "__main__":
    main()
