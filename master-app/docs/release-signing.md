# Release signing

APSIRA is signed with its own release key (D-002). The key and its passwords live only on Alejandro's computer and
never enter a Claude Code session: no agent generates, requests, prints or stores them. The same holds for the hub's
GitHub token (D-007), which is created by the operator and kept in the hub account's secret file
(`/etc/apsira/github-token`, `10-hub-runbook.md` §7).

APSIRA's certificate matters more than a sibling's: every Apsira app records its fingerprint (`F_APSIRA`) to trust
APSIRA on the device link (D-016), and APSIRA's shelf refuses any APK whose certificate is not the one recorded for
its app (D-007). **A new APSIRA key breaks every app's link until each records the new fingerprint.**

## 1. Creating the key (operator, once, before slice 1's first RC)

As ASTROLABE's and RELAY's: a fresh key of APSIRA's own, never another app's. In the password manager, create an
entry named **APSIRA release key**; every value below goes into it. Then, in a plain terminal outside any Claude
Code session:

```bash
mkdir -p ~/apsira-signing && chmod 700 ~/apsira-signing
keytool -genkeypair -v -keystore ~/apsira-signing/apsira-release.jks -storetype PKCS12 \
  -alias apsira -keyalg RSA -keysize 4096 -validity 10958 \
  -dname "CN=APSIRA, O=Apsira Labs, C=ES"
```

- `-validity 10958` is 30 years in days.
- keytool asks for a keystore password once: generate a long random one in the password manager and paste it. A
  PKCS12 keystore uses it for the key as well.

Save the keystore file as an attachment in the entry, with the password, the alias `apsira` and (§2) the
fingerprint. Keep one offline copy of the keystore at home. Losing it means a release can never update an installed
APSIRA, and every app's `F_APSIRA` must be re-recorded.

## 2. The recorded fingerprint

The operator records the release certificate's SHA-256 here once, before the first RC, as
`apksigner verify --print-certs` prints it: 64 lower-case hex digits, no colons. The release script reads it from
the line below and refuses until it is there; every signed APK must then have exactly this one certificate. The
same value is `F_APSIRA` for every app's link configuration (`contracts/app-link.md`).

- SHA-256: *(to be recorded)*

APSIRA's own trust table holds the other apps' fingerprints, each copied from that app's `release-signing.md`
(`contracts/app-link.md`); an app without its own recorded release fingerprint is not trusted by a release APSIRA.
VIATICUM, signed with the SDK debug key (VIATICUM D-059), is absent until its thread gives it a release key (D-031);
a debug certificate is never recorded.

## 3. Signing an RC and a release

As ASTROLABE's `release-signing.md` §3 and the operator's release model (D-025): one
`~/projects/apsira-builds/v<N>-release.sh`-style script, the password pasted once, idempotent steps, no phone in
any step. It:

1. refuses inside any session (apsira_tools' session guard), then reads §2's fingerprint;
2. checks the inputs, the tag and a clean checkout of it;
3. builds the `prod` flavour, checks the merged manifest against the declared permission list (D-024) and the
   certificate against §2;
4. for an **RC** (candidate mode), leaves the APK with `rc` in its version, its `.sha256` and a `.notes.md` with the
   RC's notes in `~/projects/apsira-builds/`, where the shelf offers it (D-007, D-035). This is the only way an RC is
   made; a session builds `dev` APKs only. Every sibling's release script is asked to write the same `.notes.md`
   sidecar for its RCs (D-036; without it the shelf shows "No notes");
5. for a **release**, writes the notes from the `CHANGELOG.md` section (no section, no release), leaves
   `apsira-<x.y.z>.apk` and its `.sha256`, and publishes the private GitHub Release, which the hub then fetches.

Agents never run the script; a test runs a copy with every tool stubbed.
