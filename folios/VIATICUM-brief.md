# VIATICUM — Brief

Input for a planning thread and then Claude Code. This states what the app is for and which needs it answers. Scope, requirements, design and architecture are decided in planning and during the build, not here.

## What it is

VIATICUM is Alejandro's own planner for research trips to archives, end to end: before the trip, during the visits, after the trip, and across trips. Planning is the priority; everything else serves it. It complements Bellum, which handles the archives and their material; VIATICUM handles the trip itself and everything the trip generates and consumes.

The name: *viaticum*, Latin — the provisions one prepares for a journey.

## Who it is for

One user: Alejandro, as historical researcher (crisol). Trips are self-funded and time-boxed, so every hour in a reading room and every euro spent has to count.

## What he uses today and why it doesn't fit

Nothing. Trip planning and execution happen in notes, spreadsheets, email and memory. There is no software for this — researchers everywhere do it by hand, and the guidance that exists is advice, not tooling.

## What it must let him do (his words: all four phases hurt)

- **Pre-trip.** Plan the trip: build the request list, decide what to see and in what order; track orders, permissions and advance bookings; reading-room rules per archive; logistics (travel, lodging, hours) and budget in euros; a plan that knows what is worth the time.
- **During.** A daily plan for the reading room; a capture log per box/legajo/folio as he goes; to-dos that arise on the spot; time spent per box; what was seen, skipped, or denied — all usable in the room itself.
- **Post-trip.** Processing backlog of what was captured; reconciliation with Bellum; expenses; what remains undone and why.
- **Across trips.** Per-archive knowledge that accumulates: what has been seen, what is pending, contacts, quirks of each place, what worked and what didn't.

## Why build rather than adapt

No product covers any phase of a research trip, let alone the whole lifecycle, and none would know about Bellum. The gap is total.

## Fixed

- Its focus is planning first: the trip, its execution and what it leaves behind. Catalogue access or fetching, if any, is secondary and decided in planning, not here.
- Complements Bellum; does not replace or duplicate it.
- Covers all four phases; "across trips" is a first-class part, not an afterthought.

## Left open for the planning thread

- Which parts must work in the reading room (phone) and which on the PC; offline needs in archives.
- Relationship with Bellum: what flows between them and in which direction.
- Relationship with RELAY (capture) and QUIRE/LYCEUM, if any.
- Everything about structure, UI and internals — to be designed with Claude Code.
- Future: possible product under Apsira for other researchers; not a consideration now.
