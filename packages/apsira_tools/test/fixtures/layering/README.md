<!-- From relay test/fixtures/layering/README.md @ 5f606e9 -->
# test/fixtures/layering

Inputs for `tool/layering_lint.dart` and the `layering` suite (07 P0-09,
08 §3). Each directory is laid out like `lib/`: `package:relay/` maps to it.

- `clean/`: one file per layer that keeps every rule, including the
  composition roots (`main.dart`, `app/bootstrap.dart` import `data/`), the
  router (imports a feature) and a feature using theme and l10n. Comments
  and strings that mention `DateTime.now()` or `Random()` are not calls.
- `violations/`: breaks every rule at least once; the suite pins each
  `file:line`, import or call, and rule. The files need not compile (the
  analyzer skips `test/fixtures/`).

Provenance (P-4): every file in this directory is RELAY's `test/fixtures/layering/` at
`5f606e9`, byte for byte; the suite pins their line numbers, so they carry no
header. Only this README gains the lines naming the source.
