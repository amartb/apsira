import os
from PIL import Image, ImageDraw, ImageFont
O = "apsira-brand"
FB = ImageFont.truetype("font/ArchivoExpanded-600.ttf", 34)
FR = ImageFont.truetype("font/ArchivoExpanded-400.ttf", 20)
FS = ImageFont.truetype("font/ArchivoExpanded-400.ttf", 16)
def L(p, w=None, h=None):
    im = Image.open(os.path.join(O, p)).convert("RGBA")
    if w: im = im.resize((w, max(1, round(im.height*w/im.width))), Image.LANCZOS)
    if h: im = im.resize((max(1, round(im.width*h/im.height)), h), Image.LANCZOS)
    return im
W, H = 2400, 2080
INK, ACC, DK, RI, RA, GR = "#101513", "#00915A", "#0E1311", "#F1F4F2", "#1FB377", "#5B6460"
sh = Image.new("RGBA", (W, H), "#FFFFFF"); d = ImageDraw.Draw(sh)
def label(x, y, t, c=GR, f=FS): d.text((x, y), t.upper(), font=f, fill=c)
d.text((80, 64), "APSIRA LABS  ·  BRAND ASSETS", font=FB, fill=INK)
label(80, 116, "Symbol, lockups, colourways, app icons and favicons", f=FR)
# Row 1: hero horizontal lockups
y = 180
d.rounded_rectangle([80, y, 1180, y+400], 24, outline="#DDE1DF", width=2)
sh.alpha_composite(L("02-lockups/horizontal/png/apsira-labs-horizontal-color-3200w.png", 1040), (110, y+40))
d.rounded_rectangle([1220, y, 2320, y+400], 24, fill=DK)
sh.alpha_composite(L("02-lockups/horizontal/png/apsira-labs-horizontal-reversed-3200w.png", 1040), (1250, y+40))
label(80, y+414, "Horizontal lockup · colour"); label(1220, y+414, "Horizontal lockup · reversed")
# Row 2: responsive symbols
y = 650
x = 80
for k, nm, rng, a, b in (("full", "Full", "64 px and up", 128, 64), ("simplified", "Simplified", "24–64 px · app icons", 64, 32), ("micro", "Micro", "16–24 px · favicon", 24, 16)):
    d.rounded_rectangle([x, y, x+520, y+340], 24, outline="#DDE1DF", width=2)
    sh.alpha_composite(L(f"01-symbol/{k}/png/apsira-symbol-{k}-color-512.png", 300), (x+20, y+20))
    sh.alpha_composite(L(f"01-symbol/{k}/png/apsira-symbol-{k}-color-512.png", a), (x+340, y+170-a//2))
    sh.alpha_composite(L(f"01-symbol/{k}/png/apsira-symbol-{k}-color-512.png", b), (x+340+a+20, y+170-b//2))
    label(x, y+354, f"{nm} · {rng}")
    x += 560
d.rounded_rectangle([1760, y, 2320, y+340], 24, outline="#DDE1DF", width=2)
sh.alpha_composite(L("02-lockups/stacked/png/apsira-labs-stacked-color-1600w.png", h=320), (1760 + (560-L("02-lockups/stacked/png/apsira-labs-stacked-color-1600w.png", h=320).width)//2, y+10))
label(1760, y+354, "Stacked lockup")
# Row 3: monochrome
y = 1060
d.rounded_rectangle([80, y, 1180, y+300], 24, outline="#DDE1DF", width=2)
sh.alpha_composite(L("02-lockups/horizontal/png/apsira-labs-horizontal-mono-black-3200w.png", 700), (100, y+40))
sh.alpha_composite(L("01-symbol/micro/png/apsira-symbol-micro-mono-black-512.png", 220), (900, y+40))
d.rounded_rectangle([1220, y, 2320, y+300], 24, fill="#000000")
sh.alpha_composite(L("02-lockups/horizontal/png/apsira-labs-horizontal-mono-white-3200w.png", 700), (1240, y+40))
sh.alpha_composite(L("01-symbol/micro/png/apsira-symbol-micro-mono-white-512.png", 220), (2040, y+40))
label(80, y+314, "Monochrome · black"); label(1220, y+314, "Monochrome · white")
# Row 4: icons + favicons + palette
y = 1430
x = 80
for p, s in (("03-app-icons/ios-app-icon-1024.png", 260), ("03-app-icons/app-icon-light-1024.png", 260), ("05-social/avatar-400.png", 260)):
    im = L(p, s)
    m = Image.new("L", (s, s), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, s-1, s-1], int(s*0.225), fill=255)
    tile = Image.new("RGBA", (s, s), (0,0,0,0)); tile.paste(im, (0, 0), m)
    if "light" in p: d.rounded_rectangle([x-1, y-1, x+s, y+s], int(s*0.225), outline="#DDE1DF", width=2)
    sh.alpha_composite(tile, (x, y)); x += s + 40
label(80, y+274, "App icon · dark / light · avatar (shown with OS rounding)")
fx = x + 20
for px in (48, 32, 16):
    sh.alpha_composite(L(f"04-favicons/favicon-{px}.png"), (fx, y + 200 - px)); fx += px + 30
label(x+20, y+274, "Favicons")
# palette
y = 1790
sw = [("Ink", INK, "16 21 19"), ("Emerald", ACC, "0 145 90"), ("Ink on dark", RI, "241 244 242"), ("Emerald on dark", RA, "31 179 119"), ("Dark ground", DK, "14 19 17")]
x = 80
for nm, hx, rgb in sw:
    d.rounded_rectangle([x, y, x+400, y+200], 20, fill=hx, outline="#DDE1DF", width=2)
    tc = "#FFFFFF" if hx in (INK, ACC, DK) else INK
    d.text((x+24, y+24), nm.upper(), font=FR, fill=tc)
    d.text((x+24, y+130), hx, font=FR, fill=tc); d.text((x+24, y+160), "RGB " + rgb, font=FS, fill=tc)
    x += 450
label(80, y+220, "Typeface: Archivo Expanded (SemiBold 600 for APSIRA, Regular 400 for LABS) · SIL Open Font License")
sh.convert("RGB").save(os.path.join(O, "00-overview.png"))
sh.convert("RGB").save(os.path.join(O, "00-overview.pdf"), resolution=200)
