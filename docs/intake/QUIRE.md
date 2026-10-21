# Intake brief — QUIRE absorbs Lyceum's documents

Input for a QUIRE planning thread. Written 2026-10-21 by the APSIRA MIGRATION thread.
Ruling: LYCEUM D-003 (`lyceum/docs/02-decision-log.md`); it answers the open question in
`tomes/QUIRE-brief.md` ("Relationship with LYCEUM (manuscripts, research)").

## What moves to QUIRE

Everything document-shaped that Lyceum desktop held:

- **Manuscripts**: the manuscript as a first-class object per work; snapshots (versions
  kept at moments the writer chooses); writing sessions (when, how long, how many words).
  Lyceum Folio's tables were `Manuscripts(work_id)`, `Snapshots(manuscript_id)`,
  `WritingSessions(manuscript_id)`; the desktop's router was `manuscript.py`, with
  `parts.py` for structure and `feedback.py` for reader feedback.
- **Submission formatting**: preparing a work for a publisher or journal (the desktop's
  `preparation.py`, `templates.py`), the document side of translation rights
  (`translation_rights.py`), footnote inventory (`footnote_inventory.py`). The
  *tracking* of submissions stays in LYCEUM.

## What QUIRE already is

A document system (dialect → Typst → PDF, .docx/.odt), Python 3.13 + PySide6, M6 merged
(app shell and editor). Its project model and templates are where manuscripts and
submission preparation naturally land; snapshots may be git.

## Left open for the planning thread

- Whether a "work" in QUIRE is a project, and how LYCEUM's work id is referenced
  (LYCEUM's export bundle carries works with UUIDv7 ids; QUIRE could store that id in
  its project metadata).
- Writing sessions: a QUIRE feature, or dropped.
- Nothing is imported from the desktop (LYCEUM D-007); the data in these modules is
  disposable. Intake is feature intake, not data migration.
- Keep QUIRE's ADR-0015 (Archivo Expanded for all UI text) and its "no AI" stance;
  nothing here changes them.
