<!-- army:doc type=rules -->
# APSIRA — standing rules for army agents

## Non-negotiables
- **Brand assets are copied unchanged.** Every file under `packages/apsira_ui/lib/{fonts,brand}` matches its `SHA256SUMS`, and the ones `apsira-brand/` holds (the two Archivo Expanded TTFs, the Archivo licence, the reversed lockup) are byte-identical to it; the provenance test proves both. Never recolour, re-encode or "optimise" them.
- **Colour literals live in one file:** `packages/apsira_ui/lib/src/colors.dart`. Nowhere else under any package's `lib/` (`tool/check.sh` greps `lib/`; tests and the tools' own fixtures may hold literals they check).
- **Packages never depend on `build_runner`** or ship generated code (D-APK-001).
- **A package requires the lowest Flutter any live consumer pins** (`apsira_ui`: `>=3.47.0`).
- **Behaviour is RELAY's.** Every extracted file names its source in a header comment (`// From relay <path> @ 5f606e9`). A change in behaviour from RELAY's needs a `D-APK-nnn` entry; a rename is not a change in behaviour.
- **Nothing is edited in `relay/`, `viaticum/` or any app repository** from this repository's work. They are read-only references.
- **Versions and tags match:** `version:` in a package's `pubspec.yaml` equals the tag it will receive (`apsira_<pkg>-vX.Y.Z`). Tags and pushes are operator acts.

## How work is recorded here
- Decisions: `docs/decisions.md`, append-only, `D-APK-nnn`.
- Each package has its own `CHANGELOG.md`, one section per tag, naming any migration a consumer must make.
- Commit subjects: `<type>(<task id>): <summary>`; one squash commit per task.
- Reports and handoffs: `docs/sessions/`.

## This host
- A shared PC (`~/.army/host.toml`): one Flutter gate at a time; `dart test` for the pure packages is cheap, `flutter test` for `apsira_ui` declares 3 GB.
- No CI. `tool/check.sh` is the full check; its verdict line `check: PASS` is what counts.
