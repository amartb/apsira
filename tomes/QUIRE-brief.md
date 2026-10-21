# QUIRE — Brief

Input for a planning thread and then Claude Code. This states what the app is for and which needs it answers. Scope, requirements, design and architecture are decided in planning and during the build, not here.

## What it is

QUIRE is Alejandro's own document system: the tool he writes in, from novels to research papers to everyday letters, with his own shorthand, his own templates and full control of the page. It replaces LibreOffice and LaTeX for his writing. He writes in a dialect of his own design; QUIRE compiles it to Typst for print-quality PDF and converts to .docx/.odt when a document has to go to an editor, publisher or journal.

## Who it is for

One user: Alejandro — novelist, historical researcher (the crisol project), and author of his own technical reports and everyday documents.

## What he writes

- Novels and fiction manuscripts.
- Historical research papers and articles (crisol).
- Personal technical reports and documentation.
- Letters, CVs, everyday documents.

One tool for all of it. Today fiction lives in LibreOffice and research in LaTeX, and nothing covers both.

## What he uses today and why it doesn't fit

- LibreOffice: styles and layout fight him, there is no shorthand, long documents are fragile.
- LaTeX: too much ceremony for the result, hard to customise.
- Neither lets him define his own shorthand, his own templates, or where things sit on the page.
- Templates in both are poor. He wants templates far better than what tools offer: made by him, to his liking, per kind of work and per project.

## What it must let him do (his words)

- **Full customisation**: shorthand, templates, styles, placing things on the page — all defined by him, as code, versioned.
- **Shorthand of his own**: write with his own abbreviations and markers (dialogue, scene breaks, citations, whatever he decides) and have them expand correctly for each output.
- **Templates of his own**, per work and per project: a novel template, a crisol paper template, a report template, a letter template — each exactly as he wants it, reusable, evolving with the project.
- **Large documents without fragility**: a full novel or a long research paper as a first-class object, not a file that degrades as it grows.
- **Outputs**: print-quality PDF (book, paper and report layouts) and .docx/.odt for editors, publishers and journals.

## Why build rather than adapt

Typesetting engines exist and QUIRE uses one (Typst) as a library. What no tool gives him is a writing environment where the shorthand, templates and page control are his own, as code, across fiction and research alike, with the office-format outputs the publishing world demands. The gap is fit, not price.

## Fixed

- Authoring in his own dialect, compiled to Typst for PDF. He does not write Typst syntax directly unless he chooses to at the template level.
- Shorthand, templates and styles are code he owns.
- .docx/.odt output is a requirement, not a nice-to-have.

## Left open for the planning thread

- The dialect itself: its syntax and how shorthand is declared.
- Editing experience: editor, preview, how the UI works.
- How .docx/.odt conversion is done and how much fidelity is required for each destination.
- Relationship with LYCEUM (manuscripts, research) and with Obsidian/RELAY notes, if any.
- Ebook/web output: not needed now; keep the door open.
- Everything about structure, project model, UI and internals — to be designed with Claude Code.
- Future: possible product under Apsira; not a consideration now.
