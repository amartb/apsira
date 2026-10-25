# ATRIUM — Brief

Input for a planning thread and then Claude Code. This states what the app is for, which needs it answers, and whether it is feasible. Scope, requirements, design and architecture are decided in planning and during the build, not here.

## What it is

ATRIUM is the phone app for every document that passes through Alejandro's phone, in either direction. It has three legs:

1. **Received**: files other people send him. PDFs, Office documents, images and scans, audio (voice notes included) and video.
2. **Captured**: what he records himself to remember something. Screenshots and reference photos.
3. **Issued**: what he keeps having to send. Standing documents such as his DNI scan, latest payslip, certificado de empadronamiento, insurance, CV, bank certificate. These are always current and ready to send in two taps.

Everything opens inside ATRIUM, with no bouncing between Dropbox, Firefox, Word or the gallery. His own rules sort what he keeps. What he doesn't keep expires, except standing documents, which are kept by definition. As in RELAY and VIATICUM, everything kept is backed up to a folder organised the same way.

The name: the entrance hall of a Roman house, where everything arriving is received and from which everything leaving goes out.

## Who it is for

One user: Alejandro, on his Android phone.

## What he does today and why it doesn't fit

- **Received**: a file arrives in a chat or mail, and opening it means bouncing to Dropbox, Firefox, Word or whichever app grabs that type. Afterwards it's buried in that app or a downloads folder, and finding "that PDF from last month" means searching chat by chat.
- **Captured**: screenshots and photos taken as references (a ticket, a receipt, some information, a product, a place, a conversation) sink into the gallery among everything else and are never cleaned up.
- **Issued**: every time someone asks for his DNI, a payslip or a certificate, he hunts for the latest version across the gallery, downloads, mail and cloud folders.

## What it must let him do

**Leg 1: Received**
- Be the **default app** for the file types he receives: PDFs, Office documents (docx, xlsx, pptx, odt and similar), images and scans, audio and video.
- Be the **"open with" / "share to" target** for files from WhatsApp, Telegram, mail and any other app.
- **Open every type inside ATRIUM**, including playing voice notes and other audio.

**Leg 2: Captured**
- **Screenshots and reference photos sorted into what they are**: ticket, receipt, information, product, place, conversation, or categories he defines.

**Leg 3: Issued (standing documents)**
- A set of **standing documents**, each with a name (e.g. "DNI", "Payslip", "Empadronamiento") and a **current version**. Replacing it with a newer one (next month's payslip, a renewed certificate) keeps that slot up to date, and older versions are retained or dropped as he decides.
- **Send in two taps**: from ATRIUM to any chat or mail via the share sheet, and ideally **picked from inside other apps**. When WhatsApp or mail asks for a document, ATRIUM's standing documents appear in the file picker.
- **Never expire.** Standing documents are kept by definition.
- Promoting something that arrived (e.g. a certificate received by mail) or was captured (a photo of a paper) into a standing document is one action.

**Across all three legs**
- **His own rules** sort what he keeps: by type, source app, file name, content keywords, and whatever else he defines. Rules are his, editable, and part of the app's customisation.
- **Expire unless kept.** Anything not explicitly kept disappears after a period he sets (except standing documents). Keeping is a deliberate act; clutter goes by default.
- **Backup** of everything kept to a folder organised the same way as the app, as RELAY and VIATICUM do. Cloud sync is not ATRIUM's job; when the Apsira master app exists, it handles sync and external backups for the whole ecosystem.
- **Full customisation where it matters to him**, as with the rest of his apps.

## Version 2 (recorded now, not for V1)

- **Act on files**: annotate, highlight, fill forms, sign.
- **Turn captures into action**: a screenshot becomes a RELAY note or task, or a KAIROS event.
- **Voice note transcription**: received voice notes turned into text on the device, so they can be read and their text matched by rules. In V1 voice notes are kept and played like any other audio.

## Fixed

- Three legs: received, captured, issued.
- **Links and shared text are out of scope.** RELAY covers them.
- **The sender limitation is accepted** (see Feasibility). Rules work on what Android provides; sender is not required.
- Standing documents never expire.
- Backup to an organised folder, as in RELAY and VIATICUM.
- No cloud sync of its own; that belongs to the future master app.
- In line with the master app being the ecosystem's single internet gateway, ATRIUM works on the device without network access. That includes opening Office documents (and, in V2, transcription).

## Feasibility

Summary: **feasible**. Office rendering is immature, the sender limitation is accepted, and screenshot expiry needs confirming in planning.

**Default app, "open with", "share to"**
- Standard Android. An app declares the file types it handles and becomes a choice in "open with", "share to" and the default-app setting.

**Opening Office documents on the device, without network**
- It's possible but immature. An on-device library renders PDF, docx, xlsx and pptx with no network permission. It is very new (version 0.1.0) and does not render charts, pivot tables, conditional formatting or data validation; spreadsheets are cut off at 3,000 rows ([offline_document_viewer](https://pub.dev/packages/offline_document_viewer)). That's adequate for received documents, not for complex spreadsheets.
- The proven reference is LibreOffice Viewer for Android. It opens docx, xlsx, pptx, odt and the legacy doc/xls/ppt, is open source (MPL-2.0) and actively maintained (last release 7 Sep 2026), but it's a standalone app ([LibreOffice Viewer](https://apt.izzysoft.de/fdroid/index/apk/org.documentfoundation.libreoffice?repo=main)). Planning decides how ATRIUM gets the fidelity it needs.
- PDF, images, audio and video are routine. That includes WhatsApp voice notes (Opus audio), which Android can play natively.

**Sender (accepted limitation)**
- When WhatsApp or Telegram hands a file to another app, Android passes the file and, at best, which app it came from. It does not pass who sent it. Rules by type, source app, file name and content work; sender would need manual tagging.

**Screenshots**
- Detecting new screenshots and sorting them on the device (OCR plus categories) is proven. Shots Studio, an open-source organiser, categorises, tags, OCRs and searches screenshots with on-device AI ([Shots Studio](https://apt.izzysoft.de/fdroid/index/apk/com.ansah.shots_studio?repo=main)).
- **Expiry needs confirming in planning.** Deleting gallery photos the app didn't create normally triggers a confirmation from Android. A special "media management" permission (Android 12+) may avoid it. The alternative is for ATRIUM to hold its own copies and expire those freely.

**Standing documents**
- Sharing from ATRIUM via the share sheet is standard.
- Appearing inside other apps' file pickers is something Android allows: an app can publish its files to the system document picker, which apps such as WhatsApp's "Document" attachment and mail clients use. Confirm in planning against the apps he actually uses.
- These are his most sensitive files (identity documents). Having no network access helps. How they're protected on the device (app lock, encryption) is a planning decision.

**Voice note transcription (V2, for reference)**
- No machine learning has to be built. It means embedding an existing open-source engine (whisper.cpp) with ready-trained multilingual Whisper models, which cover Spanish, running entirely on the device with no internet. Voxscribe, an open-source Android app, already does exactly this without the internet permission ([Voxscribe](https://zff.dev/y20k/voxscribe)).
- The real costs are integration effort, decoding voice notes into plain audio first, a model file of tens to a few hundred MB that has to reach the phone once (side-loaded or via the master app), and speed, which depends on his phone and must be measured there.

## What exists and why build

- **Office viewers** (LibreOffice Viewer, MA Office) are single-purpose viewers, and MA Office depends on an external server ([F-Droid](https://f-droid.org/zh_Hans/packages/com.vayunmathur.office/)). Neither keeps or organises anything.
- **Screenshot organisers** (Shots Studio and others) handle screenshots only. Expiry isn't mentioned for Shots Studio.
- **WhatsApp file managers** are storage cleaners ([AnExplorer](https://anexplorer.io/features/whatsapp-manager)).
- **Personal document organisers** exist. DocSafe stores IDs, insurance and bank papers locally, highlights expiring documents and shares via the share sheet, but it's iPhone-only ([DocSafe](https://apps.apple.com/mx/app/docsafe-document-organiser/id6759522531)). That is the closest thing to the "issued" leg.
- None of them combines received, captured and issued documents in one Android app with his own rules, expiry by default, standing documents with current versions available inside other apps' pickers, no network access, and backup to his organised folder. The gap is fit.

## Left open for the planning thread

- How Office documents are rendered, and the fidelity required.
- How rules are defined (in the UI, as code, or both) and what they can match on.
- Default expiry period and whether it differs per category or leg.
- Screenshot intake: watching the screenshots folder automatically, sharing to ATRIUM, or both.
- Whether expired items are deleted outright or go to a holding area first.
- Standing documents: the initial set, version history kept or not, whether a send can be stamped (e.g. with purpose and date on an ID copy), and how they are protected on the device.
- Folder structure of the backup and how it mirrors the app.
- Search across kept items, if wanted.
- Exact interface to the future master app (sync, backups, and in V2 delivery of the transcription model).
- Everything about UI and internals — to be designed with Claude Code.
- Future: possible product under Apsira; not a consideration now.
