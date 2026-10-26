# ASTROLABE — Brief

Input for a planning thread and then Claude Code. This states what the app is for and which needs it answers. It is a starting point, not a specification: scope, features, requirements, design and architecture are decided in planning and during the build, and the planning thread is free to go beyond or against anything here.

## What it is

ASTROLABE is Alejandro's own utilities folio: the everyday instruments of a phone in one app, made his way. Clock and alarms, timers and stopwatch, calculator, converter, scanner and measuring tools.

The name: the astrolabe was the old all-in-one instrument, used to tell time, measure and compute.

## Who it is for

One user: Alejandro.

## What he uses today and why it doesn't fit

Google Clock, the stock calculator and assorted single-purpose utility apps. They come from different vendors (often ad-filled), none of them can be shaped, and they are part of the Google dependency he is reducing.

## What it must let him do

- **Alarms with rules**: his own repeat patterns, skipping the next occurrence, groups he switches on and off.
- **Timers and stopwatch**: several named timers, and a stopwatch with laps.
- **Calculator with history**: saved calculations, and results he can come back to.
- **Converter**: units, offline. Currency would come later through the central app.
- **Scanner and measuring**: QR and barcode scanning, a spirit level, a ruler.

## Why build rather than adapt

Each tool exists separately. None of them is customisable, and none belongs to his ecosystem.

## Fixed

- An Apsira folio: offline, no `INTERNET` permission, no telemetry.
- One app holds all of these tools. Clock and utilities were deliberately merged, not split.

## Left open for the planning thread

- Everything about features, scope, design and architecture.
- Which tools ship first, and whether more instruments belong.
- How alarms are made reliable on Android (exact alarms, battery optimisation).
- Whether alarms ever read RELAY's calendar. This wasn't asked for at this stage, but isn't ruled out.
- Where scanned codes go (RELAY, ATRIUM, the clipboard).
