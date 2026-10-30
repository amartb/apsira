# APSIRA planning documents

APSIRA is the master app of the Apsira ecosystem: on the Android phone and tablet, plus a hub on amb811, it carries
backups home, installs the operator's own releases, brings internet data in for apps that have no network,
governs the Apsira apps' notifications and, from v2, syncs them. These documents are the build plan, written by the
APSIRA PLANNING thread (2026-10-30). Nothing is built yet.

| File | What it answers | State |
|---|---|---|
| [`00-brief.md`](00-brief.md) | The input: the operator's opening message and the roadmap notes it pointed to | 2026-10-30 |
| [`01-vision-and-scope.md`](01-vision-and-scope.md) | What APSIRA is, principles, scope (v1's five slices, later, out), success criteria | planning |
| [`02-decision-log.md`](02-decision-log.md) | Every significant decision, its alternatives and consequences | D-001–D-036 and addenda; living |
| [`03-roadmap.md`](03-roadmap.md) | The slices and their releases (`v0.1.0`–`v1.0.0`), v2 and later | planning |
| [`04-data-model.md`](04-data-model.md) | The app's tables, the hub's storage layout, the store and the archive | design |
| [`05-architecture.md`](05-architecture.md) | Stack, layout, ports and packages, mechanisms, permissions | design |
| [`06-ux-and-screens.md`](06-ux-and-screens.md) | Visual language, navigation, the status screen and every other screen | design |
| [`07-phase-plans.md`](07-phase-plans.md) | Units, task graph, package and adoption work per slice | planning |
| [`08-testing-and-ci.md`](08-testing-and-ci.md) | Gates, critical suites, the sandboxed hub tests, device checks per release | planning |
| [`09-security-model.md`](09-security-model.md) | Threats, trust boundaries, keys and their recovery, a lost device, the console line | design |
| [`10-hub-runbook.md`](10-hub-runbook.md) | The amb811 side: accounts, groups, storage, service, firewall, the SSD move, the Proton copy | planning |
| [`agent-rules.md`](agent-rules.md) | The standing rules for army agents | planning |
| [`assurance-rules.md`](assurance-rules.md) | Proportionate checks: what runs where | planning |
| [`dependencies.md`](dependencies.md) | Packages and hub binaries: decided, candidates to verify, rejected | planning; kept current per task |
| [`building.md`](building.md) | Toolchain, the dev APK, the hub in development, the release | planning |
| [`release-signing.md`](release-signing.md) | The release key, the recorded fingerprint, signing | planning; fingerprint before the first RC |
| [`contracts/app-link.md`](contracts/app-link.md) | What APSIRA offers the Apsira apps on the device: trust, calls, errors (D-016) | design |
| [`contracts/hub-protocol.md`](contracts/hub-protocol.md) | Device ↔ hub: pairing, mutual TLS, endpoints (D-015) | design |
| [`contracts/sync-envelope.md`](contracts/sync-envelope.md) | The language-neutral sync format (D-013, D-APK-023) | design |
| [`contracts/atrium-offload.md`](contracts/atrium-offload.md) | The archive's offload contract, for ATRIUM's thread to take up (D-010) | proposal |
| [`charter-amendments.md`](charter-amendments.md) | The charter and `D-APK` changes APSIRA needs, ready to apply | proposal |
| [`../CLAUDE.md`](../CLAUDE.md) | Non-negotiables, workflow, quick reference, commands | planning; P0 adds commands |

Ecosystem documents: `apsira/README.md` (the charter), `apsira/docs/decisions.md` (`D-APK-nnn`),
`apsira/docs/roadmap/master-app.md` and `sync-and-storage.md` (the rulings M1–M7 and R1–R14), `apsira/packages/`.

Where this index and a document disagree, the document wins. Between documents (D-032): the decision log wins over
everything; the contracts win for interfaces, `10-hub-runbook.md` for the hub's host layout, `09` for threats and keys;
`04` and `05` follow them.
