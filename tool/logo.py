"""Draw the Passy mark: an orange rounded square with a white "P" whose
bowl doubles as a price tag (round hole + string notch)."""
import sys
from PIL import Image, ImageDraw

ORANGE = (255, 111, 50, 255)
DEEP = (232, 84, 24, 255)
WHITE = (255, 255, 255, 255)
S = 2048  # supersample


def mark(bg=True, pad=0.0):
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if bg:
        # vertical gradient square
        grad = Image.new("RGBA", (S, S))
        gd = ImageDraw.Draw(grad)
        for y in range(S):
            t = y / S
            c = tuple(int(ORANGE[i] * (1 - t) + DEEP[i] * t) for i in range(3)) + (255,)
            gd.line([(0, y), (S, y)], fill=c)
        m = Image.new("L", (S, S), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.27), fill=255)
        im.paste(grad, (0, 0), m)
    # content box (shrinks for maskable safe zone)
    o = S * pad
    k = (S - 2 * o) / S

    def P(x, y):
        return (o + x * S * k, o + y * S * k)

    def R(x0, y0, x1, y1):
        a, b = P(x0, y0), P(x1, y1)
        return [a[0], a[1], b[0], b[1]]

    fg = WHITE if bg else ORANGE
    hole = ORANGE if bg else (0, 0, 0, 0)
    # stem
    d.rounded_rectangle(R(0.27, 0.20, 0.45, 0.82), radius=int(S * k * 0.09), fill=fg)
    # bowl: rounded tag shape
    d.rounded_rectangle(R(0.36, 0.20, 0.75, 0.60), radius=int(S * k * 0.20), fill=fg, corners=(False, True, True, False))
    # tag hole
    cx, cy = P(0.57, 0.40)
    r = S * k * 0.075
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=hole)
    return im


def save(im, path, size):
    im.resize((size, size), Image.LANCZOS).save(path)


# Usage: python tool/logo.py <repo root>
out = sys.argv[1]
std = mark()
save(std, f"{out}/assets/brand/passy_mark.png", 512)
save(std, f"{out}/web/icons/Icon-192.png", 192)
save(std, f"{out}/web/icons/Icon-512.png", 512)
save(std, f"{out}/web/favicon.png", 64)
# maskable: full-bleed background, artwork inside 80% safe zone
mk2 = mark(bg=True, pad=0.12)
flat = Image.new("RGBA", (S, S), ORANGE)
flat.alpha_composite(mk2)
save(flat, f"{out}/web/icons/Icon-maskable-192.png", 192)
save(flat, f"{out}/web/icons/Icon-maskable-512.png", 512)
for name, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    save(std, f"{out}/android/app/src/main/res/mipmap-{name}/ic_launcher.png", px)
