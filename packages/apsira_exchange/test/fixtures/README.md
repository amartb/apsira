# Fixtures

Every file here is copied from a released tag of its app, never written by this package
(D-APK-019; assurance focus F6). They are inputs, not code under test: the analyzer skips
this folder.

| Path | From | What |
|---|---|---|
| `relay/relay-v2.0.1.db.gz` | RELAY `v2.0.1` (`09b28810`) | a schema-v11 database: the data of RELAY's `test/data/db/json_dump_test.dart` @ `v2.0.1` (its `_populate`), written by RELAY's own code |
| `relay/relay-v2.0.1.json.gz` | RELAY `v2.0.1` | the `relay.json` RELAY v2.0.1's `JsonDump.write` wrote from that database (`appVersion` `2.0.1`) |
| `relay/make_relay_v2.0.1.dart` | — | the generator that wrote the two, run once in a `git archive v2.0.1` copy of RELAY |
| `viaticum-v0.2.0-<kind>.json` | VIATICUM `v0.2.0` | `exchange/examples/{seed-valid,package-small,results-small}.json` |
| `exchange/viaticum-v1.0.0/` | VIATICUM `v1.0.0` (`78d38e0`) | `exchange/schemas` and `exchange/examples` |
| `exchange/lyceum-v1.0.0/` | LYCEUM `v1.0.0` (`9f4ff27`) | `exchange/schemas` and `exchange/examples` |

The RELAY pair was made as follows, with the generator copied into the archive's
`test/fixture_gen/` (`T14_OUT` names the output folder); RELAY's repository is not touched:

```sh
git -C relay archive v2.0.1 | tar -x -C <scratch>
flutter pub get --offline && T14_OUT=<out> flutter test test/fixture_gen/make_v11_relay_json_test.dart
gzip -9 -n -c <out>/relay-v2.0.1.db > relay/relay-v2.0.1.db.gz
gzip -9 -n -c <out>/relay-v2.0.1.relay.json > relay/relay-v2.0.1.json.gz
```

SHA-256 before compression: database `287a1135825d59aef2246428c4c2e05aab973d6d87a3e7069ac3d662833726a8`,
`relay.json` `64d86d8421a8389d22c3897f00a237a8d3ee959fb295dd5cf749b0b0ead094e3`.
