<!-- army:doc type=rules -->
# APSIRA — assurance rules (bind the assurance planner, the validator and the conductor)

As the siblings' (ASTROLABE, ATRIUM): a validation is **designed from the work it covers**, bundled around a seam,
scoped to the tests that touch it, with a stated focus. It is never a default, a filler or a ritual at a milestone.
The full check runs **once** in v1.

## 1. What runs where

| When | Runs | Never |
|---|---|---|
| A task, in its lane | `dart format`, `flutter analyze` (or `dart analyze` in `hub/`), the tests it wrote or changed | an area gate, the suite, an APK, anything on the real hub |
| A merge | `analyze` and `codegen`; the static gates its paths touch once per 3–5 merges | any test |
| A bundle validation (`07` §3) | the bundle's scope through the area gates with `APSIRA_TEST_SCOPE`, `APSIRA_VALIDATION=1`; its focus and negative controls | the full check; tests outside the scope |
| A fix | its own tests and those touching the files it changed (delta check) | re-running the bundle |
| A milestone close | a delta check on the tagged tree, then the RC and its device session (`08` §6) | the full check; a re-run of a green bundle |
| The v1 exit | `check` once (`APSIRA_FULL_CHECK=1`) plus `coverage` on the RC tree | a second full run |
| A package tag (apsira lane) | the repository's `tool/check.sh` as its own rules say | this lane's gates |

## 2. How a bundle is designed

- A bundle groups **3–6 tasks** meeting at a **seam**: producer and consumer of a contract (`docs/contracts/`),
  the app and its hub counterpart, a package adapter and the APSIRA side it calls.
- Each bundle states before the plan is approved: why these tasks, the scope (test paths and Kotlin classes from the
  tasks' owned files), the focus (two to four properties), the negative controls, and when (on its last task's
  merge).
- A task belongs to one bundle or none.
- **Ratio:** v1 plans seven bundles and one full run (`07` §3). A check per task, a bundle without a seam, or a full
  run before the v1 exit is sent back.

## 3. Focus, not breadth

- **Data safety first** wherever it appears: never lost, append-only, restore equals source, retention exact, the hub
  sees ciphertext only (D-028).
- **Trust** in every bundle that crosses a boundary: pinning, revocation, the per-call fingerprint check, the
  network bar. Negative controls are mandatory for these.
- **Secrets:** any bundle touching keys (device, sync, vault), the token, pairing codes or the store password plants
  a secret in a log path and watches the secrets gate fail.
- **Sandbox:** a validator confirms the hub tests ran in their scratch root and left nothing behind.
- Peer reviews: none by default; one pack (≤ 2 angles, security first) when a bundle touches the link, pairing or
  the store and a validator names a defect class tests cannot see. *Proposed:* V-1 and V-3 get that pack by default,
  since a defect there is costly and silent.

## 4. Record

`02-assurance.md` per unit lists each bundle with its items, the agents it uses and its verdict, and the delta check
at the close. The conductor refuses an assurance plan that breaks §1 or §2.
