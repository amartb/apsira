# STYLUS — Brief

Input for a planning thread and then Claude Code. This states what the app is for and which needs it answers. It is a starting point, not a specification: scope, features, requirements, design and architecture are decided in planning and during the build, and the planning thread is free to go beyond or against anything here.

## What it is

STYLUS is Alejandro's own Android keyboard: the surface he types through in every app, shaped entirely by him, and connected to the Apsira apps.

The name: *stylus*, Latin — the tool that wrote on wax tablets; also the root of "style".

## Who it is for

One user: Alejandro, typing in Spanish and English.

## What he uses today and why it doesn't fit

Gboard.

- **He can't shape it.** Layouts, rows and symbols are fixed by Google.
- **Shortcuts are weak.** The personal-dictionary shortcuts are too limited for real text expansion.
- **No link to his apps.** Nothing lets him act on Apsira from where he types.

## What it must let him do

- **Full customisability**: everything he touches on the keyboard is his to define.
- **His own layouts**: rows, symbol pages, and layouts he designs.
- **Snippets and expansion**: his own shortcuts expanding to text, templates and the like.
- **Apsira actions**: act on Apsira apps from where he types (for example, send the selection to RELAY).
- **Spanish and English prediction and autocorrect**, offline. This is the typing core he relies on.

## Why build rather than adapt

Open-source keyboards exist (HeliBoard, FlorisBoard) and prove offline bilingual prediction is achievable. None is shaped around his customisation or knows about Apsira. Whether to build on one of them, borrow from them or start clean is for planning.

## Fixed

- An Apsira folio: offline, no `INTERNET` permission, no telemetry. Anything networked would come later through the central app.
- Typed text never leaves the phone.

## Left open for the planning thread

- Everything about features, scope, design and architecture, including how layouts, snippets and actions are defined.
- Building on an open-source keyboard versus from scratch, and the licence consequences.
- How prediction and dictionaries work, and how they learn.
- How Apsira actions reach the other apps.
- Whether swipe typing, offline voice typing, clipboard history or emoji search belong, now or later. None was asked for at this stage, but none is ruled out.
