<!-- From relay test/fixtures/coverage/README.md @ 5f606e9 -->
# test/fixtures/coverage

Hand-written lcov reports for `tool/coverage_gate.dart` (08 §5), in the
format `flutter test --coverage --branch-coverage` writes.

| file | domain lines | domain branches | meaning |
|---|---|---|---|
| `domain_ok.info` | 19/20 (95 %) | 18/20 (90 %) | passes |
| `domain_below.info` | 17/20 (85 %) | 18/20 (90 %) | fails on lines |
| `domain_branches_below.info` | 19/20 (95 %) | 16/20 (80 %) | fails on branches |
| `no_domain.info` | none | none | only non-domain code: passes with a notice |

Each has an `lib/app/` entry at 0 % that the gate must ignore, and the
domain entries are `lib/domain/notes/note.dart` and
`lib/domain/tags/tag.dart`.

Provenance (P-4): every file in this directory is RELAY's `test/fixtures/coverage/` at
`5f606e9`, byte for byte; the suite pins their line numbers, so they carry no
header. Only this README gains the lines naming the source.
