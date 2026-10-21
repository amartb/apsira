# RELAY — Brief

Input for a planning thread and then Claude Code. This states what the app is for and which needs it answers. Scope, requirements, design and architecture are decided in planning and during the build, not here.

## What it is

RELAY is a phone app for notes and tasks, built for Alejandro's own use, designed by him. Not a PC app: on the PC he uses Obsidian for notes. RELAY is what he reaches for on the phone when something has to be captured now — a thought, a voice memo, a photo, a scan, a screenshot, a task — and then organised, tagged, labelled and structured exactly the way he wants.

## Who it is for

One user: Alejandro, on an Android phone. He builds his own software because off-the-shelf tools don't fit how he works.

## What he uses today and why it doesn't fit

- Phone: a Google Keep-style app. PC: Obsidian.
- The phone side is the problem. Current apps:
  - don't let him organise, tag and label the way he wants;
  - have no proper structures and no real customisation — behaviour is fixed by the vendor;
  - are not his: the data and the behaviour belong to someone else;
  - are too slow to capture in the moment.

## What it must let him do (his words, lightly ordered)

- Capture fast: voice memos, photos, scans, screenshots, text, tasks — "things like that."
- Take notes in whichever format he wants, store them, organise them, tag them, label them, structure them, all through the app's UI, in the way he designs it.
- Handle tasks in the same app. Whether a task grows out of a note or stands alone depends on the situation; the app must support both without forcing either.
- Customise deeply where it matters to him. The customisation is the point, not an add-on.

## Why build rather than adapt

No existing note app gives him ownership of data and behaviour together with the freedom to shape structure and organisation to his own habits. The gap is fit, not price.

## Left open for the planning thread

- Form: PWA vs. native Android; whether a backend is needed and where it runs.
- Relationship with Obsidian on the PC, if any (export, sync, none).
- Whether anything flows to other personal platforms (PRISM, QUIRE, LYCEUM) and how.
- Everything about structure, organisation model, tagging, task behaviour, and UI — to be designed with Claude Code.
- Future: possible product under Apsira; not a consideration now.
