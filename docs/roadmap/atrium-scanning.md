# ATRIUM expansion — scanning and creating codes

Routed from the ASTROLABE planning thread (2026-10-26). A record for ATRIUM's own planning, not a plan: nothing is
decided for ATRIUM here, and nothing is written in ATRIUM's repository until its own thread takes this up.

## Why it moved

ASTROLABE's brief listed "QR and barcode scanning" among the utilities and left open "where scanned codes go
(RELAY, ATRIUM, the clipboard)". In planning the operator ruled that scanning is not an ASTROLABE instrument:
"Scanning codes sounds more like an Atrium expansion, not for astrolabe … Careful with overlaps. All files handling
should be Atrium." Creating codes followed it ("Move to ATRIUM too"). ASTROLABE D-012 records the move; ASTROLABE
keeps no scanner, no code generator and no camera capture.

## What the move covers

- **Scanning QR and barcodes** with the camera.
- **Creating codes**: a QR for text, a link or a Wi-Fi network, shown on screen or shared.

## What ASTROLABE's planning had on the table

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

## Questions for ATRIUM's planning

- Whether scanning is a capture leg feature (a scanned code becomes a captured item) or a tool beside the legs.
- Whether a code read from a received image or screenshot is extracted the way OCR text is, and searchable.
- Which camera ATRIUM uses: the multi-page capture camera already in ATRIUM V1, or a separate scanner view.

## Links

- ASTROLABE: `amartb/astrolabe` `docs/02-decision-log.md` D-012 and D-021.
- ATRIUM: `amartb/atrium` `docs/01-vision-and-scope.md` (the captured leg).
- The long list: [app-ideas.md](app-ideas.md) (ATRIUM modules).
