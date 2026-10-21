<!-- From relay test/fixtures/l10n/README.md @ 5f606e9 -->
# test/fixtures/l10n

Inputs for `tool/l10n_check.dart` and the `l10n_complete` suite (07 P0-07).
Each must fail the check:

- `missing_key/`: `noteDeleted` is in `app_en.arb` but not `app_es.arb`.
- `placeholder_mismatch/`: `notesInFolder` uses `{folder}` in English and
  `{carpeta}` in Spanish.
- `hard_coded_text/`: `note_tile.dart` passes `'Untitled note'` to `Text(`.

Provenance (P-4): every file in this directory is RELAY's `test/fixtures/l10n/` at
`5f606e9`, byte for byte; the suite pins their line numbers, so they carry no
header. Only this README gains the lines naming the source.
