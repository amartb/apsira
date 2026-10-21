# Intake brief — Vellum absorbs Lyceum's research residue, and Vellum's place in Apsira

Input for a Vellum planning thread. Written 2026-10-21 by the APSIRA MIGRATION thread.
Rulings in force: LYCEUM D-003 (research residue to Vellum), Apsira charter §2 (Vellum's
relation to Apsira is decided in its own thread), operator rulings of 2026-10-21:
Vellum is **core only as VIATICUM's counterpart** (the trip seed/package/results loop
and leads); its archive-querying side is secondary.

## What moves to Vellum (feature intake, no data migration)

Lyceum's research domain: sources and excerpts, historiography, reading queue,
historical events and perspectives, the links from experts and historical figures to
sources, bibliography export, argument scaffold, contradictions, completeness check,
PDF annotations. Much of it overlaps what Vellum already has (documents, claims,
entities, timeline, reading queue, briefs). The intake thread decides what is genuinely
missing in Vellum and what is already covered.

## What leaves Vellum

The LYCEUM peer link (`services/api/app/services/integration/lyceum.py`, the
`lyceum_sync` and `lyceum_cache_refresh` jobs, `models/integration.py`, the UI under
`components/integration/`): its other end is retired (`lyceum/docs/runbook/retirement.md`
phase E). An ADR records it; the `LYCEUM_PEER_TOKEN` secret goes with the code.

## Vellum's Apsira form — the open ruling

Vellum is a React + FastAPI + ARQ web app on the KEYSTONE substrate (shared Postgres,
Valkey, Traefik, sops, KILTER, restic). Apsira has no class for that (charter §2). The
options the planning thread puts to the operator, with the facts:

- **Apsira identity and documents; KEYSTONE stays its infrastructure.** Cheapest; the
  charter gains a sentence that server-form members are the exception to §1.1; Vellum
  keeps the VIATICUM contract as built (ADR-042…045 on `phase-viaticum/exchange-track`).
- **A native tome.** QUIRE-sized rebuild of the trip-counterpart core only (the ruling
  says that is what is core); archive adapters and OCR would be re-planned or dropped.
- **Fold the trip-counterpart core into VIATICUM or the central app.** Removes a
  server; VIATICUM's D-040 ("research findings reach LYCEUM through VELLUM") would be
  superseded.

Inputs the thread needs: the exchange-track branch merged or not; the post-migration
bible owed since P3 closed (2026-07-31); the ADR-041 gap; `VELLUM_STANDARDS.md` §9.3's
unbuilt token system (relevant only if Vellum takes the Apsira skin).
