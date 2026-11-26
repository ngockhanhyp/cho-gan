"""Passy icon set: original soft-3D icons drawn as SVG.

Style rules (keep new icons consistent):
- 96x96 viewBox, object sits on a soft ground shadow at y≈86.
- Light from the top-left: every fill is a top-to-bottom gradient
  (light -> base), plus a white highlight at ~35% opacity.
- Warm palette led by Passy orange; accents are limited to PALETTE.
- No outlines except dark "ink" parts (wheels, screen frame).

Usage: python tool/icons.py <repo root>   -> writes assets/icons/*.svg
"""
import sys
from pathlib import Path

PALETTE = {
    "orange": ("#FFA36B", "#FF6F32", "#E0521A"),
    "yellow": ("#FFE08A", "#FFC23D", "#E89B12"),
    "pink": ("#FF9DB0", "#FF5C7C", "#DE3A5C"),
    "teal": ("#7FE0CF", "#25B39B", "#178A77"),
    "sky": ("#9CD2FF", "#4C9BF0", "#2F72C9"),
    "green": ("#9BE38B", "#4CBF5A", "#2F9441"),
    "cream": ("#FFFFFF", "#FFF1E3", "#F1D9C2"),
    "ink": ("#5B6478", "#3A4256", "#262C3B"),
    "steel": ("#F3F6F9", "#D7DEE6", "#AEB9C6"),
}


def grads(*names):
    out = []
    for n in names:
        lo, base, _ = PALETTE[n]
        out.append(
            f'<linearGradient id="{n}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{lo}"/><stop offset="1" stop-color="{base}"/>'
            f"</linearGradient>"
        )
    return "".join(out)


def dark(n):
    return PALETTE[n][2]


SHADOW = '<ellipse cx="48" cy="87" rx="28" ry="4.5" fill="#3A2A1F" opacity=".10"/>'
HI = 'fill="#fff" opacity=".38"'


def svg(body, *g):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">'
        f"<defs>{grads(*g)}</defs>{SHADOW}{body}</svg>"
    )


ICONS = {}

# Mua bán đồ cũ: shopping bag with a price tag
ICONS["shop"] = svg(
    f'<path d="M36 34v-5a12 12 0 0 1 24 0v5" fill="none" stroke="{dark("orange")}" stroke-width="5.5" stroke-linecap="round"/>'
    '<path d="M24 32h48a4 4 0 0 1 4 3.7l3 40A6 6 0 0 1 73 82H23a6 6 0 0 1-6-6.3l3-40A4 4 0 0 1 24 32z" fill="url(#orange)"/>'
    f'<path d="M22 40h52" stroke="{dark("orange")}" stroke-width="2" opacity=".35"/>'
    f'<circle cx="37" cy="42" r="3" fill="{dark("orange")}"/><circle cx="59" cy="42" r="3" fill="{dark("orange")}"/>'
    f'<path d="M25 36h10l-2 30h-9z" {HI}/>'
    '<g transform="rotate(-18 62 64)"><rect x="52" y="54" width="24" height="17" rx="4" fill="url(#yellow)"/>'
    f'<circle cx="57" cy="62.5" r="2.4" fill="{dark("yellow")}"/>'
    f'<path d="M62 60h9M62 65h6" stroke="{dark("yellow")}" stroke-width="2.4" stroke-linecap="round"/></g>',
    "orange", "yellow",
)

# Cho tặng: gift box with ribbon
ICONS["gift"] = svg(
    '<rect x="20" y="46" width="56" height="36" rx="6" fill="url(#pink)"/>'
    '<rect x="15" y="34" width="66" height="16" rx="5" fill="url(#pink)"/>'
    f'<rect x="15" y="44" width="66" height="6" fill="{dark("pink")}" opacity=".25"/>'
    '<rect x="42" y="34" width="12" height="48" fill="url(#yellow)"/>'
    '<path d="M48 34c-4-10-18-14-20-6-2 7 10 7 20 6z" fill="url(#yellow)"/>'
    '<path d="M48 34c4-10 18-14 20-6 2 7-10 7-20 6z" fill="url(#yellow)"/>'
    f'<circle cx="48" cy="33" r="4.5" fill="{dark("yellow")}"/>'
    f'<rect x="18" y="36" width="18" height="5" rx="2.5" {HI}/>',
    "pink", "yellow",
)

# Nội thất: sofa
ICONS["couch"] = svg(
    '<rect x="20" y="26" width="56" height="32" rx="12" fill="url(#teal)"/>'
    f'<path d="M48 30v24" stroke="{dark("teal")}" stroke-width="2" opacity=".35" stroke-linecap="round"/>'
    '<rect x="16" y="52" width="64" height="20" rx="8" fill="url(#teal)"/>'
    f'<rect x="16" y="64" width="64" height="8" rx="4" fill="{dark("teal")}" opacity=".35"/>'
    '<rect x="8" y="42" width="16" height="32" rx="8" fill="url(#teal)"/>'
    '<rect x="72" y="42" width="16" height="32" rx="8" fill="url(#teal)"/>'
    f'<rect x="18" y="73" width="6" height="9" rx="2" fill="{dark("teal")}"/><rect x="72" y="73" width="6" height="9" rx="2" fill="{dark("teal")}"/>'
    f'<rect x="25" y="30" width="18" height="5" rx="2.5" {HI}/><rect x="11" y="46" width="5" height="14" rx="2.5" {HI}/>',
    "teal",
)

# Điện tử: laptop
ICONS["laptop"] = svg(
    '<rect x="18" y="18" width="60" height="44" rx="7" fill="url(#ink)"/>'
    '<rect x="23" y="23" width="50" height="34" rx="3.5" fill="url(#sky)"/>'
    '<path d="M23 50l14-12 9 8 9-7 18 14v1a3.5 3.5 0 0 1-3.5 3.5h-43A3.5 3.5 0 0 1 23 54z" fill="#fff" opacity=".35"/>'
    '<circle cx="62" cy="32" r="4.5" fill="url(#yellow)"/>'
    '<path d="M8 64h80l-4 10a6 6 0 0 1-5.6 4H17.6A6 6 0 0 1 12 74z" fill="url(#steel)"/>'
    f'<rect x="40" y="64" width="16" height="3.5" rx="1.75" fill="{dark("steel")}"/>'
    f'<path d="M26 26h14l-11 10h-3z" {HI}/>',
    "ink", "sky", "yellow", "steel",
)

# Khu phố: two neighbouring houses
ICONS["houses"] = svg(
    '<rect x="54" y="38" width="28" height="44" rx="3" fill="url(#cream)"/>'
    '<path d="M50 42l18-16 18 16a3 3 0 0 1-2 5H52a3 3 0 0 1-2-5z" fill="url(#teal)"/>'
    '<rect x="61" y="52" width="14" height="11" rx="2" fill="url(#sky)"/>'
    f'<rect x="54" y="70" width="28" height="12" fill="{dark("cream")}" opacity=".6"/>'
    '<rect x="14" y="48" width="36" height="34" rx="3" fill="url(#cream)"/>'
    '<path d="M9 52l23-21 23 21a3 3 0 0 1-2 5H11a3 3 0 0 1-2-5z" fill="url(#orange)"/>'
    '<path d="M25 82V68a7 7 0 0 1 14 0v14z" fill="url(#orange)"/>'
    f'<circle cx="35" cy="75" r="1.4" fill="{dark("orange")}"/>'
    '<path d="M18 50l14-13 6 5" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" opacity=".5"/>'
    '<path d="M57 39l11-10 5 4.5" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" opacity=".5"/>',
    "cream", "teal", "sky", "orange",
)

# Trò chuyện: two speech bubbles
ICONS["chat"] = svg(
    '<path d="M38 14h32a14 14 0 0 1 14 14v12a14 14 0 0 1-14 14h-2l1 9-11-9H38a14 14 0 0 1-14-14V28a14 14 0 0 1 14-14z" fill="url(#orange)"/>'
    '<path d="M24 34h30a13 13 0 0 1 13 13v12a13 13 0 0 1-13 13H34l-12 10 2-10a13 13 0 0 1-13-13V47a13 13 0 0 1 13-13z" fill="url(#sky)"/>'
    '<circle cx="28" cy="53" r="3.6" fill="#fff"/><circle cx="39" cy="53" r="3.6" fill="#fff"/><circle cx="50" cy="53" r="3.6" fill="#fff"/>'
    f'<rect x="18" y="38" width="18" height="4.5" rx="2.25" {HI}/>',
    "orange", "sky",
)

# Đồ đã lưu: heart
ICONS["heart"] = svg(
    '<path d="M48 82C20 64 11 48 11 35c0-12 9-21 20-21 8 0 14 4 17 10 3-6 9-10 17-10 11 0 20 9 20 21 0 13-9 29-37 47z" fill="url(#pink)"/>'
    f'<path d="M48 82C30 70 20 59 15 49c10 9 22 16 33 21 11-5 23-12 33-21-5 10-15 21-33 33z" fill="{dark("pink")}" opacity=".35"/>'
    '<ellipse cx="29" cy="30" rx="9" ry="6" transform="rotate(-30 29 30)" fill="#fff" opacity=".45"/>',
    "pink",
)

# Giao dịch an toàn: shield with check
ICONS["shield"] = svg(
    '<path d="M48 10l30 10v24c0 20-13 33-30 42C31 77 18 64 18 44V20z" fill="url(#green)"/>'
    f'<path d="M48 10v76c17-9 30-22 30-42V20z" fill="{dark("green")}" opacity=".25"/>'
    '<path d="M35 46l9 9 18-19" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>'
    f'<path d="M24 24l20-7v8l-20 6z" {HI}/>',
    "green",
)

# Tất cả: four colourful tiles
ICONS["all"] = svg(
    '<rect x="14" y="12" width="32" height="32" rx="10" fill="url(#orange)"/>'
    '<rect x="50" y="12" width="32" height="32" rx="10" fill="url(#yellow)"/>'
    '<rect x="14" y="48" width="32" height="32" rx="10" fill="url(#teal)"/>'
    '<rect x="50" y="48" width="32" height="32" rx="16" fill="url(#pink)"/>'
    f'<rect x="19" y="17" width="12" height="4" rx="2" {HI}/><rect x="55" y="17" width="12" height="4" rx="2" {HI}/>'
    f'<rect x="19" y="53" width="12" height="4" rx="2" {HI}/>',
    "orange", "yellow", "teal", "pink",
)

# Gia dụng: cooking pot
ICONS["pot"] = svg(
    '<rect x="6" y="46" width="16" height="8" rx="4" fill="url(#ink)"/><rect x="74" y="46" width="16" height="8" rx="4" fill="url(#ink)"/>'
    '<path d="M16 42h64v24a16 16 0 0 1-16 16H32a16 16 0 0 1-16-16z" fill="url(#orange)"/>'
    f'<path d="M16 66a16 16 0 0 0 16 16h32a16 16 0 0 0 16-16v-4H16z" fill="{dark("orange")}" opacity=".3"/>'
    '<path d="M12 40a36 9 0 0 1 72 0v2H12z" fill="url(#steel)"/>'
    '<rect x="40" y="24" width="16" height="9" rx="4.5" fill="url(#ink)"/>'
    f'<rect x="21" y="48" width="6" height="18" rx="3" {HI}/>',
    "ink", "orange", "steel",
)

# Sách: stack of books
ICONS["books"] = svg(
    '<rect x="14" y="66" width="68" height="16" rx="4" fill="url(#teal)"/>'
    '<rect x="70" y="69" width="9" height="10" rx="2" fill="url(#cream)"/>'
    '<rect x="20" y="48" width="60" height="18" rx="4" fill="url(#orange)"/>'
    '<rect x="68" y="51" width="9" height="12" rx="2" fill="url(#cream)"/>'
    '<g transform="rotate(-8 50 38)"><rect x="18" y="30" width="58" height="17" rx="4" fill="url(#sky)"/>'
    '<rect x="64" y="33" width="9" height="11" rx="2" fill="url(#cream)"/>'
    f'<rect x="24" y="36" width="22" height="4" rx="2" {HI}/></g>'
    f'<rect x="20" y="71" width="26" height="4" rx="2" {HI}/><rect x="26" y="54" width="20" height="4" rx="2" {HI}/>',
    "teal", "orange", "sky", "cream",
)

# Thời trang: t-shirt
ICONS["tshirt"] = svg(
    '<path d="M34 14c2 7 7 11 14 11s12-4 14-11l22 10c3 1.4 4 4.7 2.4 7.5l-6 10.5a4 4 0 0 1-5.4 1.6L71 42v34a6 6 0 0 1-6 6H31a6 6 0 0 1-6-6V42l-4.4 2.4a4 4 0 0 1-5.4-1.6l-6-10.5A5.4 5.4 0 0 1 12 24z" fill="url(#sky)"/>'
    f'<path d="M34 14c2 7 7 11 14 11s12-4 14-11l-4-2c-1 5-5 8-10 8s-9-3-10-8z" fill="{dark("sky")}" opacity=".45"/>'
    '<circle cx="48" cy="52" r="9" fill="url(#yellow)"/>'
    f'<path d="M30 30l-12-5 6 12z" {HI}/>',
    "sky", "yellow",
)

# Hero props
ICONS["plant"] = svg(
    '<path d="M48 50C34 48 22 38 22 24c14 0 26 10 26 26z" fill="url(#green)"/>'
    '<path d="M48 50c14-2 26-12 26-26-14 0-26 10-26 26z" fill="url(#green)"/>'
    '<path d="M48 54c-6-10-6-28 0-40 6 12 6 30 0 40z" fill="url(#green)"/>'
    f'<path d="M48 54V30" stroke="{dark("green")}" stroke-width="2.5" stroke-linecap="round"/>'
    '<path d="M26 52h44l-6 26a6 6 0 0 1-5.8 4.6H37.8A6 6 0 0 1 32 78z" fill="url(#orange)"/>'
    '<rect x="22" y="48" width="52" height="10" rx="4" fill="url(#orange)"/>'
    f'<rect x="22" y="55" width="52" height="3" fill="{dark("orange")}" opacity=".4"/>',
    "green", "orange",
)

ICONS["bicycle"] = svg(
    f'<circle cx="24" cy="62" r="16" fill="none" stroke="#3A4256" stroke-width="6"/>'
    f'<circle cx="72" cy="62" r="16" fill="none" stroke="#3A4256" stroke-width="6"/>'
    f'<path d="M24 62l14-26h26l8 26M38 36l12 26 14-26M50 62H24" fill="none" stroke="{PALETTE["orange"][1]}" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round"/>'
    f'<path d="M64 36l-3-10h9" fill="none" stroke="{PALETTE["ink"][1]}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>'
    '<rect x="30" y="28" width="16" height="7" rx="3.5" fill="url(#ink)"/>'
    f'<circle cx="50" cy="62" r="4" fill="{dark("orange")}"/>',
    "ink",
)

ICONS["pin"] = svg(
    '<path d="M48 84S20 56 20 36a28 28 0 0 1 56 0c0 20-28 48-28 48z" fill="url(#orange)"/>'
    f'<path d="M48 84S76 56 76 36A28 28 0 0 0 52 8.3C64 14 68 26 66 40 63 58 48 84 48 84z" fill="{dark("orange")}" opacity=".3"/>'
    '<circle cx="48" cy="36" r="11" fill="#fff"/>'
    f'<ellipse cx="34" cy="22" rx="6" ry="4" transform="rotate(-35 34 22)" {HI}/>',
    "orange",
)

if __name__ == "__main__":
    out = Path(sys.argv[1]) / "assets" / "icons"
    out.mkdir(parents=True, exist_ok=True)
    for name, body in ICONS.items():
        (out / f"{name}.svg").write_text(body, encoding="utf-8")
    print("wrote", len(ICONS), "icons to", out)
