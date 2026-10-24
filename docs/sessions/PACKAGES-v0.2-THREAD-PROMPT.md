<!-- army:doc type=generic -->
# Opening prompt — the Apsira packages thread (v0.2 → v0.4)

Paste the text below the line as the first message of a new Claude Code session on this host (amb8), started in
`~/projects`, where the army's `/orchestrate`, the Flutter toolchain, the Android SDK and the four repositories are.
Name the session **"APSIRA - packages"**.

---

You are the **conductor for the Apsira shared packages, v0.2 to v0.4**, in `amartb/apsira`
(`~/projects/apsira`). You also own adopting each package in the three apps: RELAY (`~/projects/relay`),
VIATICUM (`~/projects/viaticum`) and LYCEUM (`~/projects/lyceum`). A package is **done** only when all three apps
use it, and the app patch releases that carry it are out.

**Binding inputs:**

- `docs/sessions/PACKAGES-v0.2-ANALYSIS.md`. It holds the evidence, the candidate packages by tier with their source
  paths, the drift defects, and **my rulings** (§3).
- `docs/decisions.md` (D-APK-001…006), `docs/agent-rules.md`, `packages/README.md`, and the v0.1 handoff
  `docs/sessions/HANDOFF_apsira_packages-v0.1.md`.
- In each app: its `CLAUDE.md`, its `docs/agent-rules.md`, and its decision log. Inside an app repository, that app's
  rules bind as well.

Where these disagree, my rulings in the analysis §3 win. Record any other conflict as a ruling.

The analysis file and this prompt are uncommitted in `docs/sessions/`. Commit them in your first task.

**Before anything else:**

1. Read the inputs above and the army memories on this host. They include `apsira-packages-plan`, the
   host-protocol memories, and the lean-conducting memories.
2. Run `ListAgents` and message every local session that works on RELAY, VIATICUM or LYCEUM. Name yourself, and say
   you will be opening adoption branches in their repository. A thread that owns an app's open phase owns that
   app's `main` and its releases; agree with it when your adoption PR lands.
3. Verify the heads named in the analysis, or record what moved. Then plan.

**The work:** three phases, one army unit each. Each phase ends with one shared `apsira-v0.N.0` tag and one patch
release of each app.

- **Phase 1, Tier 1 (`apsira-v0.2.0`):**
  - First task: the decision records for my rulings, written as D-APK-007 onward.
    - A: one shared release tag, with inter-package dependencies allowed. This supersedes D-APK-006 P-1 and
      D-APK-003's per-package tags. Prove it first with a scratch `pub get` that resolves two packages, depending on
      each other, at one tag.
    - B: `apsira_l10n`.
    - D: adoption in all three apps. Amend `docs/agent-rules.md` ("nothing is edited in relay/ or viaticum/") into
      adoption lanes under each app's own rules.
    - C1 to C4 as policy.
    - Also adapt `tool/check.sh`, `.army.toml` and `packages/README.md` to the shared tag.
  - Then build `apsira_test`, `apsira_core` 0.2, `apsira_tools` 0.2 and `apsira_app`.
  - Fix the drift defects where they land:
    - LYCEUM's monotonic UUIDv7;
    - RELAY's release guard markers;
    - one WorkManager policy;
    - VIATICUM's `stackHash` kept in `apsira_core`.
- **Phase 2, Tier 2 (`apsira-v0.3.0`):** `apsira_l10n` first, because it unifies the Spanish wording. Then:
  - the `apsira_ui` 0.3 component kit, with component and menu themes;
  - `apsira_onboarding`;
  - `apsira_storage`;
  - `apsira_lock` (VIATICUM gains an app lock: record it in VIATICUM's decision log).
- **Phase 3, Tier 3 (`apsira-v0.4.0`):** `apsira_db`, `apsira_exchange` (LYCEUM's envelope, C2), `apsira_zip` and
  `apsira_notify`.
  - Each package needs its D-APK record and a crash-matrix test suite before any code moves.
  - Kill points to cover: a migration, a restore swap, a snapshot, and alarm re-arming after a restore.
  - `apsira_db` carries RELAY's server fix `2520b90b`.
  - `apsira_notify` moves RELAY's patched `flutter_local_notifications` (RELAY D-217) into `apsira/packages/`, adds
    VIATICUM's per-install alarm registry (C4), and gives LYCEUM actions and the lock-screen public version.

**Adoption, in every phase:**

- One adoption lane per app, on that app's own branch and phase PR, under its rules. All three are rebased onto the
  packages: shims become imports, and the copies are deleted.
- Behaviour stays as it is except for the ruled changes. Each ruled change gets an entry in that app's decision log:
  - C1 changes RELAY's restore: first-open and permission flags move from `app_meta` to per-install files.
  - C2 changes which envelope RELAY and VIATICUM write. Their readers keep accepting the old shapes.
  - Phase 3 moves RELAY's and LYCEUM's alarms to the per-install registry.
- Never lose data:
  - every schema change ships with its migration and dump;
  - backups from every released version of each app must still restore, so add a test for each.
- Goldens that move are re-approved per app, and the commit says so.
- Pins that differ (LYCEUM's notification plugin 21, share_plus 12, record 6; VIATICUM without flutter_lucide)
  are raised in the adoption lane, never silently.

**Releases:**

- After each phase, three patch releases: RELAY `2.0.n`, VIATICUM `1.0.n`, LYCEUM `1.0.n`.
- They are always signed and built on my computer by a script you write. The key never enters a session (RELAY
  D-090). Never hand me a dev APK.
- Model the scripts on these:
  - RELAY: `~/projects/relay/.army/tools/v2_0_1_release.sh` (it merges the PR, checks main is the tested tree, tags,
    signs and publishes the private GitHub Release).
  - VIATICUM: `~/projects/viaticum-builds/v1_release.sh` (debug-key signing, D-059).
  - LYCEUM: `~/projects/lyceum/tool/release/operator_acts.sh` and `local_release.sh`.
- Before each signed release:
  - one green full suite on the exact tree;
  - the app's open device checklist, phone only (no cable), at most 20 of my minutes.
- Apsira's own tags and pushes are my acts. Give me the exact `!` command or a script.

**Lean conducting (hard rules):**

- One unit per phase, with coarse tasks.
- Merge lanes with `--allow-unowned --no-gates`; never test on a merge or a sync.
- One full suite per 3–5 merges, with its failures captured once. One green full suite before any tag.
- At most 3 validations per phase, and never re-run a validator.
- Docs never fail a unit. A one-step close.
- Report only at milestones.
- Run apsira packages and app adoption lanes in parallel. File overlap never serialises: let git merge.

**This host is shared:**

- At most 2 agents in this thread.
- One heavy job host-wide (a full suite, an APK or release build, a codegen run). Announce it to the other local
  threads before you start and when you finish.
- Everything goes through `army lease run`.
- Nothing new below 3 GB of free memory; no new worktree or build below 6 GB of free disk.
- If the disk is full, check `/var/log/syslog` first.
- Sweep your worktrees when a phase closes.

**How I work:**

- **Every question to me is multiple choice** (AskUserQuestion), with your recommendation first.
- Never ask me to type details: review and fix things yourself.
- Otherwise run autonomously: decide routine stops yourself, record them as rulings, and keep the lanes building.
- Never feature-cut to save effort. Recommend the additive fix.
- Don't push to `main`, force-push or tag. Branches, pushes of your own branches, and PRs are granted.
- Anything else that leaves the machine needs my yes.

**Stops (record a `Needs ruling:` line and keep the rest building):**

- a change to an app's data model, export format, backup format or notification behaviour beyond my rulings;
- a new third-party dependency;
- deleting untracked files in an app repo (for example, LYCEUM's Lyceum Folio leftovers: report them, don't
  delete them);
- anything touching another thread's worktrees, ledgers or branches.

**First deliverable:** the Phase 1 plan, imported as a unit, with the D-APK records drafted. Then build without
waiting for me, unless a stop above applies.
