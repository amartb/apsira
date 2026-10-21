# PRISM — Brief

Input for a planning thread and then Claude Code. This states what the app is for and which needs it answers. Scope, requirements, design and architecture are decided in planning and during the build, not here.

## What it is

PRISM is Alejandro's own email client: one place for all his personal mail, organised by rules he writes himself. It brings his accounts together, lets him define inboxes and views the way he thinks about his mail, and automates what happens to a message when it arrives. PC first; phone later.

## Who it is for

One user: Alejandro. Personal mail only — work email stays out.

## What he uses today and why it doesn't fit

- Webmail per provider: too many places to check, each with its own rules and limits.
- Phone apps: fine for reading, useless for organising.
- Nothing lets him shape inboxes, organisation and automation around his own way of working.

## Accounts

- Proton on his own domain (reached through Proton Bridge, which runs on the PC).
- Gmail / Google account.
- Other personal accounts (Outlook, older addresses).

## What it must let him do (his words)

- See all personal accounts in one place.
- **Filters and rules as code.** This is the defining feature, not an option. Inbox definitions, views, filing, flagging, forwarding, extraction — all written by him in code (Python, per his existing plan), readable, editable, versioned, testable. No settings-page rule builder standing in for it.
- **Full customisation** of everything he touches: which inboxes exist, what a view shows, how mail is organised, tagged and labelled, what happens on arrival. Nothing fixed by a vendor's model of how mail should work.
- Organise, tag and label mail his way, through the app's UI, in structures he designs.
- Automate on arrival: file, flag, forward, extract — driven by his rules.
- **Mine his own archive.** Years of mail, across all accounts, read back to reconstruct every account, service, subscription, warranty and recurring charge tied to him — and act on it: deletion requests for dead accounts, cancellations, a live list of warranties and subscriptions. An inward-looking exposure map of his digital life, built from the mail he already has.

## Why build rather than adapt

Unified-inbox clients exist, but none let him write his filters and rules as code, and none let him customise inboxes, views and organisation beyond what the vendor allows. Those two things are the point of PRISM. The gap is fit, not price.

## Left open for the planning thread

- How the rules-as-code engine is structured internally (the requirement itself is fixed: rules are code).
- How mail is stored and synced; implications of Proton Bridge being PC-bound for the later phone version.
- Sending and composing: in scope for V1 or read/organise first.
- Relationship with RELAY and other personal platforms, if any.
- Everything about structure, views, tagging, automation and UI — to be designed with Claude Code.
- Future: possible product under Apsira; not a consideration now.
