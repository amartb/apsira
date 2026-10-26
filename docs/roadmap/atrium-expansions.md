# ATRIUM expansions

Features the operator has routed to ATRIUM from outside ATRIUM's own threads. A record for ATRIUM's planning, not a
plan: nothing is decided for ATRIUM here, and nothing is written in ATRIUM's repository until its own thread takes
these up.

| Expansion | From | Date |
|---|---|---|
| [Scanning and creating codes](#1-scanning-and-creating-codes) | ASTROLABE planning thread | 2026-10-26 |
| [Editing screenshots](#2-editing-screenshots) | the operator, during ASTROLABE planning | 2026-10-26 |

## 1. Scanning and creating codes

### Why it moved

ASTROLABE's brief listed "QR and barcode scanning" among the utilities and left open "where scanned codes go
(RELAY, ATRIUM, the clipboard)". In planning the operator ruled that scanning is not an ASTROLABE instrument:
"Scanning codes sounds more like an Atrium expansion, not for astrolabe … Careful with overlaps. All files handling
should be Atrium." Creating codes followed it ("Move to ATRIUM too"). ASTROLABE D-012 records the move; ASTROLABE
keeps no scanner, no code generator and no camera capture.

### What it covers

- **Scanning QR and barcodes** with the camera.
- **Creating codes**: a QR for text, a link or a Wi-Fi network, shown on screen or shared.

### What ASTROLABE's planning had on the table

Listed so ATRIUM's thread does not start from nothing. None of it was ruled for ATRIUM; the operator rejected all of
it *for ASTROLABE* because it is file and capture handling.

| Idea | As it was offered |
|---|---|
| Scan history | every scan kept with date and type, searchable |
| Actions by type | open a link, join a Wi-Fi network, add a contact, copy a code, show a product barcode's number |
| Share out | through the share sheet, so RELAY or other apps receive a code through their existing intake |
| Scan from an image | read the codes in a picked image or a shared screenshot |
| Continuous mode | scan one code after another without leaving the camera |
| Created codes kept | the definitions of codes he makes, shown again later |
| Engine | zxing-cpp (Apache-2.0, fully on-device, no Google component) or ML Kit's bundled model (on-device, but a Google library); the operator had no preference at the time |

### Questions for ATRIUM's planning

- Whether scanning is a capture-leg feature (a scanned code becomes a captured item) or a tool beside the legs.
- Whether a code read from a received image or screenshot is extracted the way OCR text is, and searchable.
- Which camera ATRIUM uses: the multi-page capture camera already in ATRIUM V1, or a separate scanner view.

## 2. Editing screenshots

### What he asked for

The operator, 2026-10-26: screenshots in ATRIUM should be editable — basic edits: **crop** ("recortar"), and
**drawing over the image**, such as **a circle or an arrow**, "etc.".

### Where it touches ATRIUM as planned

- Screenshots arrive as captured items through the catch-up on open (ATRIUM D-011); the gallery original is left in
  place in V1 (D-012).
- ATRIUM's post-V1 list already holds "annotate, highlight, fill forms, sign" for V2 (D-029), written with documents
  in mind; screenshot editing is the image counterpart and may join that item or come before it.
- Everything stays on the device (charter §1.2); no network, no AI features.

### Questions for ATRIUM's planning

- Whether an edit replaces the screenshot or keeps the original beside the edited copy.
- Which marks belong to "etc." beyond the circle and the arrow (the operator named those two as examples).
- Whether the same editor serves reference photos and multi-page captures, or screenshots only.
- Whether it ships in a V1.x before V2's document annotation, or with it.

## Links

- ASTROLABE: `amartb/astrolabe` `docs/02-decision-log.md` D-012 and D-021.
- ATRIUM: `amartb/atrium` `docs/01-vision-and-scope.md` (the captured leg), `docs/02-decision-log.md` D-011, D-012,
  D-029.
- The long list: [app-ideas.md](app-ideas.md) (ATRIUM modules).
