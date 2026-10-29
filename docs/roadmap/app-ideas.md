# App ideas — long list

From the brainstorm of 2026-10-26 (thread "APSIRA ECOSYSTEM BRAINSTORM"). A list of candidates, not a plan. Each item gets a brief only when it is picked up.

## Ground rules from the brainstorm

- Network goes through the central app only. Folios stay without `INTERNET`.
- No "glorified spreadsheets": apps record things as they happen rather than asking for rows.
- Not rebuilt: Google Pay/Wallet (stays), Maps navigation and business search (an OSM app such as Organic Maps if anything), Drive (covered by [sync-and-storage.md](sync-and-storage.md)).

## Order

1. **STYLUS**, the keyboard. [Brief](../../folios/STYLUS-brief.md).
2. **ASTROLABE**, utilities: clock, alarms, timers, calculator, converter, measuring. [Brief](../../folios/ASTROLABE-brief.md). Its planning (2026-10-26) moved scanning and creating codes to ATRIUM: [atrium-expansions.md](atrium-expansions.md).
3. **PRISM on the phone**, after the central app exists, because mail needs its network gateway. Proton could be kept by running Proton Bridge headless on amb811, or dropped from the phone version.

## Landed for sequencing (2026-10-30)

From the thread "next apps after STYLUS". ASTROLABE v1 and ATRIUM v2 are in development; STYLUS is decided and starts after them; PRISM on the phone waits for the master app. These are the candidates for what comes after STYLUS (or before it, if one proves higher leverage). The order is not yet set.

- **The master app and the console**: two network-holding apps, split by privilege. The console (PC control of amb811 and amb8 over SSH: health, one-tap actions, and the agent-army companion: watch, answer rulings, approve steps; home network now, VPN later) is the first slice. The master app carries sync, backups, the network gateway, the build shelf, the notification inbox, phone automation and a cross-app overview. Consolidated in [master-app.md](master-app.md).
- **The phone editor** (working name), a standalone folio: quick reports and records (minutes, incident notes, technical write-ups) and creative drafts on the phone, created from his own templates with guided fill-in (the template asks for its fields) and fields pulled from other apps through their contracts (LYCEUM entities, VIATICUM trips, RELAY notes). *Claude's call:* it writes a strict subset of QUIRE's `.qr` dialect, so a draft opens in QUIRE unchanged, renders a plain PDF on the phone and leaves print-quality typesetting to QUIRE; so it follows QUIRE's dialect M1. Not a LYCEUM module: LYCEUM D-003/D-013 keep it the creative hub with nothing manuscript-shaped, and reports and records are outside its domain.
- **TRANSIT**, a folio for daily local travel and research trips: offline GTFS timetables and A-to-B trip routing in v1, live arrivals after v1 through the master app's gateway, and a link from VIATICUM for a trip's city.

## Modules recorded from the same thread

- **VIATICUM**: a research toolbox, for a future version: palaeographic abbreviations, old Spanish measures and currencies, Julian/Gregorian and saint's-day dating, regnal years.
- **ASTROLABE**: GPS information (coordinates, altitude) beside the compass already recorded for V2 (ASTROLABE D-029).

## Other folio candidates (unordered)

- **Money**: statement import (Norma 43, CSV) as the backbone, plus capture of bank payment notifications on the phone where banks send them, plus a radar for recurring charges (subscriptions, bills, renewals). The notification listener lives inside Money until the central app's notification inbox exists.
- **House**: rooms, appliances, manuals, warranties and maintenance cycles, with meter readings and consumption.
- **Transit**: offline GTFS timetables for any number of networks (Spain's National Access Point for transport data), his own stops and lines, live arrivals later through the central app.
- **Library**: bookmarks and read-later, with readable copies fetched by the central app; live pages hand off to a browser.

## Modules for existing or planned apps

- **ATRIUM**: Gallery (the photo life: his own structures, cleanup by triage, backup), Renta year box (tax-relevant items marked all year and checked against the draft return in April), document validity (expiry with renewal lead times), and files into the field from STYLUS (insert a kept or standing file into the field he is typing in, such as a chat, from the keyboard; ATRIUM offers the files through a contract STYLUS calls, so the keyboard never reads ATRIUM's store; recorded by the STYLUS planning thread, 2026-10-26, for after STYLUS V1), scanning and creating codes (routed from ASTROLABE) and editing screenshots (crop, draw a circle or an arrow): [atrium-expansions.md](atrium-expansions.md).
  *Taken up by ATRIUM v2 (2026-10-27, `amartb/atrium` D-040):* the Gallery (camera photos and videos from now on, D-049), document validity (D-052), files into the field from STYLUS (the contract, D-055), scanning and creating codes and editing screenshots. The Renta year box stays recorded for later.
- **RELAY**: offline transcription of voice memos.
- **Central app**: homelab console (amb811 health, backups, sync mailbox), notification inbox (rule-based triage that feeds Money's capture), phone automation (rules as code), build shelf (installing his own APKs), alongside sync and the network gateway. *2026-10-30:* the homelab console became the separate console app; the rest stays with the master app ([master-app.md](master-app.md)).

## Deferred

- Space (passes over him, launches, sky tonight, observing log).
- Learning (spaced repetition, learning tracker).
- House (2026-10-30). If taken up, meters and consumption is the part he would use.
- Paperwork and bureaucracy (2026-10-30): ATRIUM covers it (document validity, D-052; the Renta year box, recorded).

## Cold (2026-10-30)

Money and Library: not chosen when the long list was revisited.

## Considered and dropped

Media log, launcher, pantry, "where is it" inventory, kitchen, weather, pass holder, conductor console, journal, events log, idea forge, wardrobe, decision journal, leisure trip planner, things-I-own registry.

From 2026-10-30: reading capture (page-anchored quotes keyed to citation keys), Obsidian vault on the phone over the home network, contacts, authenticator, reader, phone and SMS, sound meter, flashlight.
