"""Build the Apsira Labs brand asset package."""
import io, math, os, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cairosvg
from PIL import Image
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.boundsPen import BoundsPen
from shapely.ops import unary_union
from geom import symbol, to_path

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "apsira-brand")
FONT_B = os.path.join(HERE, "font", "ArchivoExpanded-600.ttf")
FONT_R = os.path.join(HERE, "font", "ArchivoExpanded-400.ttf")

INK, ACC = "#101513", "#00915A"
R_INK, R_ACC, DARK = "#F1F4F2", "#1FB377", "#0E1311"
WAYS = {
    "color":      dict(ink=INK, acc=ACC, word=INK, sub=ACC),
    "reversed":   dict(ink=R_INK, acc=R_ACC, word=R_INK, sub=R_ACC),
    "mono-black": dict(ink="#000000", acc="#000000", word="#000000", sub="#000000", mono=True),
    "mono-white": dict(ink="#FFFFFF", acc="#FFFFFF", word="#FFFFFF", sub="#FFFFFF", mono=True),
}


# ---------------- helpers ----------------
def ensure(p):
    os.makedirs(p, exist_ok=True)
    return p


def svg_doc(w, h, body, title="Apsira Labs", bg=None, extra_defs=""):
    bgr = f'<rect width="{w:.2f}" height="{h:.2f}" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.2f} {h:.2f}" width="{w:.0f}" height="{h:.0f}" role="img">'
            f'<title>{title}</title>{extra_defs}{bgr}{body}</svg>')


def save_svg(path, s):
    with open(path, "w") as f:
        f.write(s)


def save_png(svg, path, width=None, height=None):
    cairosvg.svg2png(bytestring=svg.encode(), write_to=path, output_width=width, output_height=height)


def save_pdf(svg, path):
    cairosvg.svg2pdf(bytestring=svg.encode(), write_to=path)


# ---------------- symbol placement ----------------
def symbol_layers(kind, way):
    W = WAYS[way]
    ink, acc = symbol(kind, mono=W.get("mono", False))
    return [(ink, W["ink"]), (acc, W["acc"])]


def bounds(layers):
    g = unary_union([l[0] for l in layers if not l[0].is_empty])
    return g.bounds


def place(layers, x, y, scale, minx, miny):
    tx = lambda px, py: (x + (px - minx) * scale, y + (py - miny) * scale)
    return "".join(f'<path fill="{c}" fill-rule="evenodd" d="{to_path(g, tx)}"/>' for g, c in layers if not g.is_empty)


def symbol_svg(kind, way, size=1000, pad=0.04, bg=None):
    L = symbol_layers(kind, way)
    minx, miny, maxx, maxy = bounds(L)
    w, h = maxx - minx, maxy - miny
    s = size * (1 - 2 * pad) / max(w, h)
    x = (size - w * s) / 2; y = (size - h * s) / 2
    return svg_doc(size, size, place(L, x, y, s, minx, miny), title=f"Apsira symbol ({kind}, {way})", bg=bg)


# ---------------- wordmark ----------------
class Face:
    def __init__(self, path):
        self.f = TTFont(path)
        self.gs = self.f.getGlyphSet()
        self.cmap = self.f.getBestCmap()
        self.upm = self.f["head"].unitsPerEm
        self.cap = self.f["OS/2"].sCapHeight

    def glyph(self, ch):
        name = self.cmap[ord(ch)]
        g = self.gs[name]
        bp = BoundsPen(self.gs); g.draw(bp)
        sp = SVGPathPen(self.gs); g.draw(sp)
        return dict(adv=g.width, bounds=bp.bounds, d=sp.getCommands())


def set_line(face, text, cap_h, tracking_em=None, target_width=None):
    """Lay out text so cap height = cap_h. Returns (glyph placements, ink x-min, ink width, scale)."""
    s = cap_h / face.cap
    gl = [face.glyph(c) for c in text]
    em = face.upm * s
    if target_width is not None:
        # solve tracking so that ink width == target_width
        inner = sum(g["adv"] for g in gl[:-1]) * s
        ink0 = inner + gl[-1]["bounds"][2] * s - gl[0]["bounds"][0] * s
        t = (target_width - ink0) / (len(gl) - 1)
    else:
        t = tracking_em * em
    x = 0.0; places = []
    for g in gl:
        places.append((x, g))
        x += g["adv"] * s + t
    xmin = gl[0]["bounds"][0] * s
    xmax = places[-1][0] + gl[-1]["bounds"][2] * s
    return places, xmin, xmax - xmin, s


def draw_line(places, s, x0, baseline, xmin, fill):
    out = []
    for x, g in places:
        tx = x0 + x - xmin
        out.append(f'<path fill="{fill}" transform="translate({tx:.2f} {baseline:.2f}) scale({s:.5f} {-s:.5f})" d="{g["d"]}"/>')
    return "".join(out)


H = 100.0            # APSIRA cap height = layout unit
SUB = 0.36 * H       # LABS cap height
GAP = 0.36 * H       # APSIRA baseline to LABS cap top


def wordmark_parts(way):
    W = WAYS[way]
    fb, fr = Face(FONT_B), Face(FONT_R)
    p1, xmin1, w1, s1 = set_line(fb, "APSIRA", H, tracking_em=0.08)
    p2, xmin2, w2, s2 = set_line(fr, "LABS", SUB, tracking_em=0.42)
    def render(x, y, align="left", width=None):
        # y = top of APSIRA caps
        x1 = x if align == "left" else x + (width - w1) / 2
        body = draw_line(p1, s1, x1, y + H, xmin1, W["word"])
        x2 = x1 if align == "left" else x + (width - w2) / 2
        body += draw_line(p2, s2, x2, y + H + GAP + SUB, xmin2, W["sub"])
        return body
    return render, w1, H + GAP + SUB


def lockup_svg(kind, way, bg=None):
    render, tw, th = wordmark_parts(way)
    pad = 1.0 * H                      # clear space = 1 × cap height
    if kind == "wordmark":
        w, h = tw + 2 * pad, th + 2 * pad
        return svg_doc(w, h, render(pad, pad), title=f"Apsira Labs wordmark ({way})", bg=bg)
    L = symbol_layers("full", way)
    minx, miny, maxx, maxy = bounds(L)
    mw, mh = maxx - minx, maxy - miny
    if kind == "horizontal":
        mark_h = th * 1.30
        s = mark_h / mh
        gap = 0.62 * H
        w = pad + mw * s + gap + tw + pad
        h = pad + max(mark_h, th) + pad
        my = pad + (max(mark_h, th) - mark_h) / 2
        ty = pad + (max(mark_h, th) - th) / 2
        body = place(L, pad, my, s, minx, miny) + render(pad + mw * s + gap, ty)
        return svg_doc(w, h, body, title=f"Apsira Labs horizontal lockup ({way})", bg=bg)
    if kind == "stacked":
        mark_w = tw * 0.92
        s = mark_w / mw
        gap = 0.70 * H
        inner_w = max(mark_w, tw)
        w = pad + inner_w + pad
        h = pad + mh * s + gap + th + pad
        body = place(L, pad + (inner_w - mark_w) / 2, pad, s, minx, miny)
        body += render(pad, pad + mh * s + gap, align="center", width=inner_w)
        return svg_doc(w, h, body, title=f"Apsira Labs stacked lockup ({way})", bg=bg)
    raise ValueError(kind)


# ---------------- app icons, favicons, social ----------------
def tile_svg(size, kind="simple", way="reversed", bg=DARK, mark_frac=0.72, radius=0.0, transparent=False):
    L = symbol_layers(kind, way)
    minx, miny, maxx, maxy = bounds(L)
    w, h = maxx - minx, maxy - miny
    s = size * mark_frac / max(w, h)
    x = (size - w * s) / 2; y = (size - h * s) / 2
    bgel = "" if transparent else (f'<rect width="{size}" height="{size}" rx="{radius*size:.2f}" fill="{bg}"/>')
    return svg_doc(size, size, bgel + place(L, x, y, s, minx, miny), title="Apsira Labs")


def favicon_adaptive_svg():
    L = symbol_layers("micro", "color")
    minx, miny, maxx, maxy = bounds(L)
    size = 64; w, h = maxx - minx, maxy - miny
    s = size * 0.96 / max(w, h); x = (size - w * s) / 2; y = (size - h * s) / 2
    tx = lambda px, py: (x + (px - minx) * s, y + (py - miny) * s)
    (ink, _), (acc, _) = L
    style = (f'<style>.i{{fill:{INK}}}.a{{fill:{ACC}}}'
             f'@media (prefers-color-scheme: dark){{.i{{fill:{R_INK}}}.a{{fill:{R_ACC}}}}}</style>')
    body = f'<path class="i" fill-rule="evenodd" d="{to_path(ink, tx)}"/><path class="a" fill-rule="evenodd" d="{to_path(acc, tx)}"/>'
    return svg_doc(size, size, body, title="Apsira Labs", extra_defs=style)


def og_svg():
    render_lock = lockup_svg("horizontal", "reversed")
    # embed the lockup as nested svg, centred on a 1200x630 dark canvas
    inner = render_lock.replace('<svg xmlns="http://www.w3.org/2000/svg"', '<svg', 1)
    vb = render_lock.split('viewBox="')[1].split('"')[0].split()
    lw, lh = float(vb[2]), float(vb[3])
    W_, H_ = 1200, 630
    target_w = 820
    th = target_w * lh / lw
    inner = inner.replace(f'width="{lw:.0f}" height="{lh:.0f}"', f'x="{(W_-target_w)/2:.1f}" y="{(H_-th)/2:.1f}" width="{target_w}" height="{th:.1f}"', 1)
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W_} {H_}" width="{W_}" height="{H_}"><rect width="{W_}" height="{H_}" fill="{DARK}"/>{inner}</svg>'


# ---------------- build ----------------
def build():
    if os.path.exists(OUT):
        shutil.rmtree(OUT)
    # 01 symbol
    for kind in ("full", "simple", "micro"):
        name = {"full": "full", "simple": "simplified", "micro": "micro"}[kind]
        d_svg = ensure(os.path.join(OUT, "01-symbol", name, "svg"))
        d_png = ensure(os.path.join(OUT, "01-symbol", name, "png"))
        d_pdf = ensure(os.path.join(OUT, "01-symbol", name, "pdf"))
        sizes = {"full": (256, 512, 1024, 2048), "simple": (64, 128, 256, 512, 1024, 2048), "micro": (16, 24, 32, 48, 64, 256, 512, 1024)}[kind]
        for way in WAYS:
            s = symbol_svg(kind, way)
            base = f"apsira-symbol-{name}-{way}"
            save_svg(os.path.join(d_svg, base + ".svg"), s)
            save_pdf(s, os.path.join(d_pdf, base + ".pdf"))
            for px in sizes:
                save_png(s, os.path.join(d_png, f"{base}-{px}.png"), px, px)
    # 02 lockups
    for kind in ("horizontal", "stacked", "wordmark"):
        d_svg = ensure(os.path.join(OUT, "02-lockups", kind, "svg"))
        d_png = ensure(os.path.join(OUT, "02-lockups", kind, "png"))
        d_pdf = ensure(os.path.join(OUT, "02-lockups", kind, "pdf"))
        for way in WAYS:
            s = lockup_svg(kind, way)
            base = f"apsira-labs-{kind}-{way}"
            save_svg(os.path.join(d_svg, base + ".svg"), s)
            save_pdf(s, os.path.join(d_pdf, base + ".pdf"))
            for px in (800, 1600, 3200):
                save_png(s, os.path.join(d_png, f"{base}-{px}w.png"), width=px)
    # 03 app icons
    d = ensure(os.path.join(OUT, "03-app-icons"))
    s = tile_svg(1024); save_svg(os.path.join(d, "app-icon-master.svg"), s)
    save_png(s, os.path.join(d, "ios-app-icon-1024.png"), 1024, 1024)
    save_png(s, os.path.join(d, "play-store-icon-512.png"), 512, 512)
    save_png(tile_svg(180), os.path.join(d, "apple-touch-icon-180.png"), 180, 180)
    for px in (192, 512):
        save_png(tile_svg(px, radius=0.0), os.path.join(d, f"pwa-icon-{px}.png"), px, px)
        save_png(tile_svg(px, mark_frac=0.58), os.path.join(d, f"pwa-maskable-{px}.png"), px, px)
    s = tile_svg(432, mark_frac=0.55, transparent=True)
    save_svg(os.path.join(d, "android-adaptive-foreground.svg"), s)
    save_png(s, os.path.join(d, "android-adaptive-foreground-432.png"), 432, 432)
    save_png(f'<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432"><rect width="432" height="432" fill="{DARK}"/></svg>',
             os.path.join(d, "android-adaptive-background-432.png"), 432, 432)
    s = tile_svg(1024, way="color", bg="#FFFFFF"); save_png(s, os.path.join(d, "app-icon-light-1024.png"), 1024, 1024)
    # 04 favicons
    d = ensure(os.path.join(OUT, "04-favicons"))
    save_svg(os.path.join(d, "favicon.svg"), favicon_adaptive_svg())
    imgs = []
    for px in (16, 32, 48):
        p = os.path.join(d, f"favicon-{px}.png")
        save_png(tile_svg(px, kind="micro", mark_frac=0.86, radius=0.2), p, px, px)
        imgs.append(Image.open(p).convert("RGBA"))
    imgs[-1].save(os.path.join(d, "favicon.ico"), sizes=[(16, 16), (32, 32), (48, 48)], append_images=imgs[:-1])
    # 05 social
    d = ensure(os.path.join(OUT, "05-social"))
    save_png(tile_svg(400, mark_frac=0.60), os.path.join(d, "avatar-400.png"), 400, 400)
    save_png(tile_svg(1000, mark_frac=0.60), os.path.join(d, "avatar-1000.png"), 1000, 1000)
    save_png(og_svg(), os.path.join(d, "og-image-1200x630.png"), 1200, 630)
    # 06 fonts
    d = ensure(os.path.join(OUT, "06-fonts"))
    for f in ("ArchivoExpanded-600.ttf", "ArchivoExpanded-400.ttf", "LICENSE-Archivo.txt"):
        shutil.copy(os.path.join(HERE, "font", f), os.path.join(d, f))


if __name__ == "__main__":
    build()
    n = sum(len(fs) for _, _, fs in os.walk(OUT))
    print("files:", n)
