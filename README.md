# Apsira Labs: brand assets

Start with `00-overview.png` (or `.pdf`), a one-page view of the whole system.

## The symbol

A free-return trajectory: a figure-eight tilted −18° whose two loops cross at 90°.

- **Colour:** the outbound leg is in ink and the return leg in emerald. The colour changes at the two apsides (periapsis and apoapsis).
- **Gears:** a sun gear sits on the central junction. Planet gears sit on both apsides. All gears share one tooth pitch, so the train would genuinely mesh.

Every knockout is a real cut-out in the vector, not a background-coloured stroke. All files work on any background, including transparent use.

## Which symbol to use

| Variant | Use at | Typical use |
|---|---|---|
| `full` | 64 px and up | website header, documents, splash screens, print |
| `simplified` | 24–64 px | app icons, avatars, small UI |
| `micro` | 16–24 px | favicon, browser tabs, tiny UI |

Never use the full symbol below 64 px, because the planet gears clog. In the monochrome micro version, a clearance cut at the crossing keeps the over-under readable.

## Colourways

| Folder suffix | Use on | Ink | Accent |
|---|---|---|---|
| `color` | white / light backgrounds | #101513 | #00915A |
| `reversed` | dark backgrounds (ideally #0E1311) | #F1F4F2 | #1FB377 |
| `mono-black` | single-colour print, stamps, fax, engraving | #000000 | — |
| `mono-white` | single-colour on photos or dark | #FFFFFF | — |

## Colours

| Name | HEX | RGB | Role |
|---|---|---|---|
| Ink | #101513 | 16 21 19 | Main path, wordmark |
| Emerald | #00915A | 0 145 90 | Return path, planets, LABS |
| Ink on dark | #F1F4F2 | 241 244 242 | Main path on dark |
| Emerald on dark | #1FB377 | 31 179 119 | Accent on dark |
| Dark ground | #0E1311 | 14 19 17 | Dark backgrounds, app icon tile |

Contrast: ink on white is 18.4:1; emerald on white is 4.0:1; emerald on dark ground is 6.9:1. Emerald is not for body text on white; use ink.

For print, ask the printer to match the HEX values to CMYK or Pantone on a proof. These are screen colours, and a machine conversion of emerald will look dull.

## Typography

- **Archivo Expanded** (Archivo variable font at width 125), included in `06-fonts/` under the SIL Open Font License. It is free for commercial use, embedding and the web.
  - **APSIRA** is SemiBold 600, tracked +0.08 em.
  - **LABS** is Regular 400 at 36 % of APSIRA's cap height, tracked +0.42 em, in emerald.
- The lockups are outlined vectors, so you never need the font installed to use the logo.
- For web text: Google Fonts `Archivo` with `font-stretch: 125%`, or the bundled TTFs.

## Clear space and minimum sizes

- **Clear space:** keep a margin around every lockup at least equal to the cap height of APSIRA (the A's height). The lockup files already include this margin.
- **Minimum widths:**
  - horizontal lockup: 160 px or 40 mm;
  - stacked lockup: 110 px or 28 mm;
  - wordmark only: 110 px or 28 mm.
- **Below those sizes**, use the symbol alone (simplified or micro).

## Don'ts

- Don't recolour outside the four colourways, add shadows, gradients or outlines, or stretch.
- Don't rotate the symbol. The −18° tilt is part of it.
- Don't swap the leg colours.
- Don't put the colour version on mid-tone or busy images; use mono-white or reversed on a dark plate.

## Folder map

| Folder | Contents |
|---|---|
| `01-symbol/{full,simplified,micro}/{svg,png,pdf}` | Each variant × 4 colourways. Transparent PNGs from 16 to 2048 px depending on the variant. |
| `02-lockups/{horizontal,stacked,wordmark}/{svg,png,pdf}` | 4 colourways each. PNG at 800, 1600 and 3200 px wide. |
| `03-app-icons/` | `ios-app-icon-1024` (square, full-bleed: iOS rounds it). `play-store-icon-512`. `apple-touch-icon-180`. `pwa-icon-192/512` and `pwa-maskable-192/512` (safe-zone sized). `android-adaptive-foreground-432` + `-background-432`. `app-icon-light-1024` (light alternative). `app-icon-master.svg`. |
| `04-favicons/` | `favicon.svg` (switches colours automatically in dark mode). `favicon.ico` (16/32/48). PNGs. |
| `05-social/` | `avatar-400`, `avatar-1000`, `og-image-1200x630`. |
| `06-fonts/` | Archivo Expanded 600 and 400 TTF + licence. |
| `07-source/` | Python sources that generate every file. |

## Website snippet

```html
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="icon" href="/favicon.ico" sizes="any">
<link rel="apple-touch-icon" href="/apple-touch-icon-180.png">
<meta property="og:image" content="https://apsiralabs.com/og-image-1200x630.png">
<meta name="theme-color" content="#0E1311">
```

## Regenerating

Requires Python 3.11+: `pip install shapely cairosvg fonttools pillow`. Then run `python build.py` and `python overview.py` from `07-source/`. Copy `font/` (the two TTFs) next to them first. All dimensions live in `geom.py` (`SPECS`) and at the top of `build.py`.
