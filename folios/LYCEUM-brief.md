# LYCEUM — Brief

Input for a planning thread and then Claude Code. This states what the app is for and which needs it answers. Scope, requirements, design and architecture are decided in planning and during the build, not here.

## What it is

LYCEUM is Alejandro's writer's creative hub: one phone app that holds the world of each work he writes (its story bible: characters, places, events, threads, groups, outline), the people around his writing (experts, historical figures, institutions, agents, publishers), and the tracking of what he has sent where (submissions, deadlines, responses, portfolio). It captures anything, anywhere (text, photo, voice, shared content) into an inbox that later becomes a bible entity, a contact or a submission note.

It is the successor of two older apps: LYCEUM desktop (retired) and LYCEUM Folio (its phone companion), merged into one standalone Apsira phone app. The name is LYCEUM alone: "folio" is Apsira's word for a phone app.

## Who it is for

One user: Alejandro — novelist and historical researcher.

## What he uses today and why it doesn't fit

- LYCEUM desktop: a web app on the shared KEYSTONE host with five modules, a sync server for the phone that never synced a real phone, and a Tauri desktop shell that was retired. Too much to operate for what it gives, and its Manuscript and Research modules duplicate what QUIRE and Vellum do.
- LYCEUM Folio: the phone companion, standalone-capable but built around a LAN sync client to the desktop, with the desktop's branding and no way to create a work on its own.
- Together they tie the creative hub to a server and a home network. He wants it in his pocket, with nothing to run at home.

## What it must let him do (his words)

- **The bible.** Characters, locations, events, threads, groups, parts, acts and chapters of each work, with their relationships, the timeline, the relationship map and the consistency view. Custom entity types for what the fixed ones don't cover.
- **Contacts.** Experts, historical figures and institutions, and the agents, magazines, publishers and competitions he submits to.
- **Submission tracking.** Which work went where, when, with what status and response; the portfolio of placed work; **a calendar of deadlines and response windows with reminders**. Not the formatting of what is sent: that is QUIRE's.
- **Capture.** Text, photo, voice and shared content into an inbox, converted later into bible entities, contacts or submission notes.
- **Works.** Create, switch and retire works on the phone itself.
- **Collections, tags and search** across everything, so a thing is found by what it is, not where it was filed.
- **Export.** A complete, versioned export of everything, written to a folder he chooses, so the data is never only on the phone and can later be read by QUIRE, Vellum or the central Apsira app.
- Both languages, PIN or biometric lock, dark by default, nothing ever cut off at large text.

## Why build rather than adapt

Writing-organiser apps exist, but none hold a story bible, the writer's contacts and submission tracking in one place, offline, under his own data model and export. The gap is fit, not price — and the code already exists: this is a transformation of LYCEUM Folio, not a new app.

## Fixed

- An Apsira folio: standalone, offline, no `INTERNET` permission, no sync of its own, no telemetry, no AI features, no cloud, single user. Data meets other apps through the export bundle only.
- Built from the LYCEUM Folio repository in place, as RELAY: Flutter, Drift, Riverpod, the Apsira visual language from `apsira_ui`, Apsira's docs and army skeleton.
- Identity `com.apsiralabs.lyceum`, a fresh key, a fresh install: nothing is migrated from the desktop; the few records worth keeping are re-entered by hand.
- Manuscripts, submission formatting and research belong to QUIRE and Vellum, not here.

## Left open for the planning thread

- The exact shape of the submission calendar (reminders, response windows, what counts as overdue).
- Collections: free-form, or typed by what they hold.
- Which desktop capabilities beyond the first release are worth bringing (translation rights tracking is the known candidate).
- How a submission refers to a QUIRE document, once QUIRE has them.
- Future: the central Apsira app reads the export bundle; not a consideration now.
