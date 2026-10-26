# App ideas — long list

From the brainstorm of 2026-10-26 (thread "APSIRA ECOSYSTEM BRAINSTORM"). A list of candidates, not a plan. Each item gets a brief only when it is picked up.

## Ground rules from the brainstorm

- Network goes through the central app only. Folios stay without `INTERNET`.
- No "glorified spreadsheets": apps record things as they happen rather than asking for rows.
- Not rebuilt: Google Pay/Wallet (stays), Maps navigation and business search (an OSM app such as Organic Maps if anything), Drive (covered by [sync-and-storage.md](sync-and-storage.md)).

## Order

1. **STYLUS**, the keyboard. [Brief](../../folios/STYLUS-brief.md).
2. **ASTROLABE**, utilities: clock, alarms, timers, calculator, converter, scanner, measuring. [Brief](../../folios/ASTROLABE-brief.md).
3. **PRISM on the phone**, after the central app exists, because mail needs its network gateway. Proton could be kept by running Proton Bridge headless on amb811, or dropped from the phone version.

## Other folio candidates (unordered)

- **Money**: statement import (Norma 43, CSV) as the backbone, plus capture of bank payment notifications on the phone where banks send them, plus a radar for recurring charges (subscriptions, bills, renewals). The notification listener lives inside Money until the central app's notification inbox exists.
- **House**: rooms, appliances, manuals, warranties and maintenance cycles, with meter readings and consumption.
- **Transit**: offline GTFS timetables for any number of networks (Spain's National Access Point for transport data), his own stops and lines, live arrivals later through the central app.
- **Library**: bookmarks and read-later, with readable copies fetched by the central app; live pages hand off to a browser.

## Modules for existing or planned apps

- **ATRIUM**: Gallery (the photo life: his own structures, cleanup by triage, backup), Renta year box (tax-relevant items marked all year and checked against the draft return in April), document validity (expiry with renewal lead times).
- **RELAY**: offline transcription of voice memos.
- **Central app**: homelab console (amb811 health, backups, sync mailbox), notification inbox (rule-based triage that feeds Money's capture), phone automation (rules as code), build shelf (installing his own APKs), alongside sync and the network gateway.

## Deferred

- Space (passes over him, launches, sky tonight, observing log).
- Learning (spaced repetition, learning tracker).

## Considered and dropped

Media log, launcher, pantry, "where is it" inventory, kitchen, weather, pass holder, conductor console, journal, events log, idea forge, wardrobe, decision journal, leisure trip planner, things-I-own registry.
