<!-- army:doc type=rules -->
# APSIRA — standing rules for army agents

## Non-negotiables
- **Brand assets are copied unchanged.** Every file under `packages/apsira_ui/lib/{fonts,brand}` matches its `SHA256SUMS`, and the ones `apsira-brand/` holds (the two Archivo Expanded TTFs, the Archivo licence, the reversed lockup) are byte-identical to it; the provenance test proves both. Never recolour, re-encode or "optimise" them.
- **Colour literals live in one file:** `packages/apsira_ui/lib/src/colors.dart`. Nowhere else under any package's `lib/` (`tool/check.sh` greps `lib/`, apsira_tools not scanned: its lint names the rule in its own messages; tests and the tools' own fixtures may hold literals they check).
- **Packages never depend on `build_runner`** or ship generated code (D-APK-001).
- **A package requires the lowest Flutter any live consumer pins** (`apsira_ui`: `>=3.47.0`).
- **Behaviour is the source app's, named in the header.** Every extracted file names its source app, path and commit in a header comment (`// From relay <path> @ 09b28810`, `// From viaticum <path> @ 78d38e0`, `// From lyceum <path> @ 9f4ff27`). A change in behaviour from the source needs a `D-APK-nnn` entry; a rename is not a change in behaviour.
- **Apsira lanes never edit an app repository** (`relay/`, `viaticum/`, `lyceum/`); from here they are read-only references. Adoption runs in an **adoption lane** in the app's own repository, branch and ledger, under that app's `CLAUDE.md`, `docs/agent-rules.md` and decision log (D-APK-009).
- **Versions and tags match:** every package carries the same `version:`, and a release is one shared tag `apsira-vX.Y.Z` (D-APK-007). An apsira dependency is exactly `apsira_<pkg>: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-vX.Y.Z, path: packages/apsira_<pkg> } }`, never `path:` (each package's `example/` app, the consumer proof, excepted), with a committed `pubspec_overrides.yaml` holding the path overrides of its transitive closure (dev_dependencies included, the package itself excepted). Tags and pushes are operator acts (`tool/release.sh`).

## How work is recorded here
- Decisions: `docs/decisions.md`, append-only, `D-APK-nnn`.
- Each package has its own `CHANGELOG.md`, one `## X.Y.Z — <date>` section per shared tag (a "no change" section included), naming any migration a consumer must make.
- Commit subjects: `<type>(<task id>): <summary>`; one squash commit per task.
- Reports and handoffs: `docs/sessions/`.

## This host
- A shared PC (`~/.army/host.toml`): one Flutter gate at a time; `dart test` for the pure packages is cheap, `flutter test` for each Flutter package (every one but `apsira_core` and `apsira_tools`) declares 3 GB.
- No CI. `tool/check.sh` is the full check; its verdict line `check: PASS` is what counts.
