<!-- From relay test/fixtures/privacy/README.md @ 5f606e9 -->
# test/fixtures/privacy

Inputs for `tool/privacy/` and the `privacy_guards` suite (08 §3, §9;
D-041, D-050).

- `manifest_declared.xml`: shaped like Gradle's merged `prodRelease`
  manifest, holding exactly `tool/privacy/declared_permissions.txt`. An
  `INTERNET` line inside a comment is not a permission.
- `manifest_with_internet.xml`: the declared set plus `INTERNET`.
- `manifest_extra_permission.xml`: the declared set plus `CAMERA`, written
  as `uses-permission-sdk-23`.
- `deps_with_http.json`: a `dart pub deps --json` closure whose runtime
  side holds `http`; `shelf` is a dev dependency.
- `deps_network_dev_only.json`: network packages reached only through a dev
  dependency, which the runtime check leaves out.
- `note.md`: note text (EN and ES, a task line, a tag) that must never reach
  the log.

Provenance (P-4): every file in this directory is RELAY's `test/fixtures/privacy/` at
`5f606e9`, byte for byte; the suite pins their line numbers, so they carry no
header. Only this README gains the lines naming the source.
