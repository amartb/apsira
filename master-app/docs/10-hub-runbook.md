# APSIRA — Hub runbook (amb811)

Status: **written by the APSIRA PLANNING thread, 2026-10-30** (planned; P0 verifies every line marked
**P0 verify**, slice 1 executes §1–§8)

The amb811 side of APSIRA: accounts, groups, paths, services, firewall, certificate, token, the phone's Proton VPN
setting, the manual Proton copy, the move to the SSD, and removal. Decisions: D-005, D-007, D-008, D-010, D-014
and its addendum, D-015, D-028, D-030, D-031, D-033, D-035. Threats and keys: `09-security-model.md`. For the hub's
host layout this file wins over `04` and `05` (D-032).

**The hub holds no content key.** Backups and archive items arrive sealed by the devices with the vault key; the
sync and vault keys are never on amb811 in any form (D-028). Nothing below creates, stores or recovers them; their
recovery is the printed sheet (`contracts/sync-envelope.md` §6).

**Who types what.** Lines marked **[operator]** are privileged (`sudo`) or carry a secret: Alejandro types them in a
plain terminal **outside any Claude Code session**. Unmarked lines are read-only checks anyone may run. Nothing here
is run by an agent against the real host; hub tests use scratch directories (CLAUDE.md §1.8). *P0 may turn §1–§8
into one idempotent `hub/install.sh` that derives every value it can (the LAN prefix, the interface) and asks only
for the secrets.*

---

## 0. The host as found (2026-10-30)

| Fact | Value | Command |
|---|---|---|
| Disk | One 1.8 TB NVMe, btrfs for `/` and `/home`, **no LUKS** | `lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS` |
| Backup SSD | Not bought (D-014) | — |
| LAN | `enp11s0` 192.168.68.108/22 and `wlp12s0` 192.168.68.111/22 | `ip -4 -br addr` |
| Firewall | Zone `FedoraWorkstation`, services `http ssh`, no open ports | `firewall-cmd --list-all` |
| Ports in use | 80 (KEYSTONE), 5355, 27500; loopback 53, 631, 8000, 8010, 55432 | `ss -ltn` |
| `restic` | 0.19.1 (Fedora package) | `restic version` |
| `rest-server` | Not installed | `command -v rest-server` |
| `/srv` | KEYSTONE's directories; Apsira does not use `/srv` | `ls /srv` |
| Operator home | `0700`, no ACL; `~/projects/*-builds/` are `0755` | `stat -c '%A %n' ~ ~/projects/*-builds` |

## 1. Values

| Name | Value | Note |
|---|---|---|
| Data root | `/var/lib/apsira-data` | On the system disk until the SSD; the SSD is later mounted **at the same path** (§9), so no configuration changes |
| Config | `/etc/apsira/` | `root:apsira 0750` |
| Hub port | `8443/tcp`, LAN only | Free on 2026-10-30. **P0 verify** with `ss -ltn` |
| `rest-server` | `127.0.0.1:8100`, loopback only | Free on 2026-10-30. **P0 verify** |
| LAN prefix | `192.168.68.0/22` | **P0 verify** against the router |
| Hub address in the QR | The wired interface's address | **[operator]** reserve it in the router's DHCP so it never changes |

## 2. Accounts and groups

```bash
# [operator]
sudo useradd --system --home-dir /var/lib/apsira-data/hub --no-create-home --shell /usr/sbin/nologin apsira
sudo useradd --system --home-dir /var/lib/apsira-data/store --no-create-home --shell /usr/sbin/nologin apsira-store
sudo groupadd --system apsira-read     # read-only: the store and the archive, both ciphertext (the operator's Proton copy)
sudo groupadd --system apsira-keys     # the repository password: apsira and apsira-store
sudo usermod -aG apsira-read alejandro
sudo usermod -aG apsira-keys apsira
sudo usermod -aG apsira-keys apsira-store
```

Check: `getent passwd apsira apsira-store` · `getent group apsira-read apsira-keys` · `id alejandro` (log out and in
once for the new group).

The builds folders need **no group**: they are reached through read-only bind mounts (§4.3), so `apsira` never
traverses the operator's home.

## 3. Directories

```bash
# [operator]
sudo install -d -o root          -g root        -m 0755 /var/lib/apsira-data
sudo install -d -o apsira        -g apsira      -m 0700 /var/lib/apsira-data/hub
sudo install -d -o apsira        -g apsira-read -m 2750 /var/lib/apsira-data/archive
sudo install -d -o apsira-store  -g apsira-read -m 2750 /var/lib/apsira-data/store
sudo install -d -o root          -g root        -m 0755 /var/lib/apsira-data/rc
sudo install -d -o root          -g apsira      -m 0750 /etc/apsira
```

| Path | Owner | Holds |
|---|---|---|
| `hub/` | `apsira`, private | Device registry, hub configuration (D-033), sync mailbox and sealed key hand-overs (ciphertext), shelf and gateway caches, `tls/`, the hub's own database |
| `archive/` | `apsira`, group `apsira-read` | ATRIUM's offloaded documents, **sealed on the device** (D-010, D-028): ciphertext only; the service runs with `UMask=0027` so new files stay group-readable |
| `store/` | `apsira-store`, group `apsira-read` | The restic repository (D-008), group-readable (§6) |
| `rc/<app>/` | read-only bind mounts | Each `~/projects/<app>-builds/` (§4.3) |

## 4. Binaries and mounts

### 4.1 `rest-server`

Not in Fedora's repositories as of 2026-10-30 (**P0 verify** `dnf info rest-server`). Install the upstream release
binary for linux/amd64 from `github.com/restic/rest-server/releases`, checking its published SHA-256:

```bash
# [operator], in a scratch directory, with VERSION and the archive name from the release page
sha256sum -c SHA256SUMS --ignore-missing
sudo install -o root -g root -m 0755 rest-server /usr/local/bin/rest-server
```

### 4.2 The hub

Built from `master-app/hub/` with `dart compile exe` (P0 writes the exact command into `building.md`):

```bash
# [operator]
sudo install -o root -g root -m 0755 build/apsira-hub /usr/local/bin/apsira-hub
```

### 4.3 RC bind mounts (one per app with a builds folder)

```bash
# [operator], per app; today: astrolabe, atrium (others as their builds folders appear)
sudo install -d -o root -g root -m 0755 /var/lib/apsira-data/rc/atrium
echo '/home/alejandro/projects/atrium-builds /var/lib/apsira-data/rc/atrium none bind,ro,nosuid,nodev,noexec 0 0' \
  | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount /var/lib/apsira-data/rc/atrium
```

Check: `findmnt /var/lib/apsira-data/rc/atrium` shows `ro`; `sudo -u apsira ls /var/lib/apsira-data/rc/atrium` lists
the APKs; `sudo -u apsira ls /home/alejandro` is refused. **P0 verify** that the mounts stay visible to the service
under `ProtectHome=yes`.

What the shelf takes from a builds folder (D-035, `contracts/hub-protocol.md` §4): an APK whose version part contains
`rc`, with its `.sha256` beside it, signed with the app's **release** certificate — so only an RC from the app's own
release script in candidate mode, run outside any session. An optional `<artifact>.notes.md` sidecar is its notes.
Dev-flavour APKs, debug-signed APKs and APKs without a `.sha256` are ignored. No bind mount for VIATICUM until it has
a release key (D-031).

## 5. The hub's TLS certificate

```bash
# [operator]
sudo -u apsira install -d -m 0700 /var/lib/apsira-data/hub/tls
sudo -u apsira openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -days 3650 \
  -subj "/CN=apsira-hub" -keyout /var/lib/apsira-data/hub/tls/hub.key -out /var/lib/apsira-data/hub/tls/hub.crt
sudo -u apsira openssl x509 -in /var/lib/apsira-data/hub/tls/hub.crt -noout -fingerprint -sha256
```

This server certificate is self-signed and pinned: devices pin its fingerprint from the pairing QR (D-015). A new
certificate means every device re-pairs. Separately, the hub's **device CA** — the key that signs device
certificates at pairing (`contracts/hub-protocol.md` §2) — is created by the hub itself:

```bash
# [operator]
sudo -u apsira /usr/local/bin/apsira-hub init --config /etc/apsira/hub.toml   # creates hub/tls/device-ca.{key,crt} once; refuses if present
```

Neither private key leaves `hub/tls/`; neither opens a backup or a document (D-028).

## 6. The repository and its passwords

```bash
# [operator]: the repository password; save the same value in the password manager entry "APSIRA hub" FIRST
read -rs PW && printf '%s' "$PW" | sudo install -o root -g apsira-keys -m 0640 /dev/stdin /etc/apsira/restic-password; unset PW
# [operator]: the rest-server password (apsira's credential to append)
read -rs RPW && printf '%s' "$RPW" | sudo install -o apsira -g apsira -m 0600 /dev/stdin /etc/apsira/rest-password
printf '%s' "$RPW" | sudo htpasswd -B -i -c /etc/apsira/rest.htpasswd apsira; unset RPW
sudo chown apsira-store:apsira-store /etc/apsira/rest.htpasswd && sudo chmod 0600 /etc/apsira/rest.htpasswd
# [operator]: initialise the repository as its owner
sudo -u apsira-store restic init --repo /var/lib/apsira-data/store --password-file /etc/apsira/restic-password
sudo chmod -R g+rX /var/lib/apsira-data/store
```

- `htpasswd` comes from `httpd-tools` (**P0 verify** it is installed).
- restic keeps a repository group-readable once its `config` file is (**P0 verify** on 0.19.1 that new pack files
  stay `g+r`); `rest-server` gets `--group-accessible-repos` for the same.
- Without the recovery copy, the restic layer cannot be opened if `/etc/apsira` is lost (`09` §3).
- The repository password guards the restic layer only. What it holds is already sealed by the devices with the
  vault key (D-028); this password never opens a backup's content.

## 7. The GitHub read-only token (D-007)

**[operator], on github.com, never in a session.** Settings → Developer settings → Fine-grained tokens → Generate:

| Field | Value |
|---|---|
| Name | `apsira-hub-shelf` |
| Resource owner | `amartb` |
| Expiration | One year; renewing it is a yearly operator act (the shelf shows a token error when it lapses) |
| Repository access | Only select repositories: `relay`, `lyceum`, `atrium`, `astrolabe` (add each new app once it has its own release key; `viaticum` only after D-031 is met) |
| Permissions | Repository → **Contents: Read-only** (Metadata: Read-only is added automatically). Nothing else |

```bash
# [operator]
read -rs TOKEN && printf '%s' "$TOKEN" | sudo install -o apsira -g apsira -m 0600 /dev/stdin /etc/apsira/github-token; unset TOKEN
```

## 8. Services and firewall

### 8.1 Units

`/etc/systemd/system/apsira-store.service` (the append-only door):

```ini
[Unit]
Description=APSIRA snapshot store (rest-server, append-only)
After=network.target
[Service]
User=apsira-store
Group=apsira-store
ExecStart=/usr/local/bin/rest-server --path /var/lib/apsira-data/store --listen 127.0.0.1:8100 \
  --append-only --group-accessible-repos --htpasswd-file /etc/apsira/rest.htpasswd
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/apsira-data/store
NoNewPrivileges=yes
PrivateTmp=yes
UMask=0027
[Install]
WantedBy=multi-user.target
```

`/etc/systemd/system/apsira-hub.service`:

```ini
[Unit]
Description=APSIRA hub
After=network-online.target apsira-store.service
Wants=network-online.target
Requires=apsira-store.service
[Service]
User=apsira
Group=apsira
SupplementaryGroups=apsira-keys
ExecStart=/usr/local/bin/apsira-hub --config /etc/apsira/hub.toml
Restart=on-failure
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/apsira-data/hub /var/lib/apsira-data/archive
ReadOnlyPaths=/var/lib/apsira-data/rc
NoNewPrivileges=yes
PrivateTmp=yes
UMask=0027
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
CapabilityBoundingSet=
[Install]
WantedBy=multi-user.target
```

The hub schedules its own work (fetches at each source's cadence, D-011; the archive's daily snapshot into the
store; the shelf's release check) from its **hub configuration** (D-033, `contracts/hub-protocol.md` §7a), and
catches up after downtime. Systemd only keeps it running. The one timer is pruning, which the hub must not be able to
do:

`/etc/systemd/system/apsira-prune.service` and `.timer`:

```ini
[Service]
Type=oneshot
User=apsira-store
Group=apsira-store
SupplementaryGroups=apsira-keys
ExecStart=/usr/bin/restic forget --repo /var/lib/apsira-data/store --password-file /etc/apsira/restic-password \
  --group-by host,tags --keep-within 30d --keep-within-weekly 1y --keep-monthly -1 --prune
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/apsira-data/store
```

```ini
[Timer]
OnCalendar=Sun 04:00
Persistent=true
[Install]
WantedBy=timers.target
```

The flags encode D-008's thinning: everything for 30 days, one a week for a year, one a month forever. **P0 verify**
`--keep-monthly -1` (unlimited) and `--keep-within-weekly` on restic 0.19.1 with a scratch repository.

```bash
# [operator]
sudo systemctl daemon-reload
sudo systemctl enable --now apsira-store.service apsira-hub.service apsira-prune.timer
```

Check: `systemctl status apsira-store apsira-hub` · `systemctl list-timers apsira-prune.timer` ·
`journalctl -u apsira-hub -n 50`.

### 8.2 Firewall: the hub port on the LAN only

```bash
# [operator]
sudo firewall-cmd --permanent --zone=FedoraWorkstation \
  --add-rich-rule='rule family="ipv4" source address="192.168.68.0/22" port port="8443" protocol="tcp" accept'
sudo firewall-cmd --reload
```

Check: `firewall-cmd --zone=FedoraWorkstation --list-rich-rules`. Port 8100 stays on loopback and is never opened.

### 8.3 The outbound host allowlist (tier 2, D-005)

`/etc/apsira/hub.toml` names the only hosts the hub may fetch from; anything else is refused before a connection is
made.

| Host | For | State |
|---|---|---|
| `api.github.com` and the release-asset download host it redirects to | The shelf's releases (D-007) | **P0 verify** the redirect host for private release assets |
| `www.ecb.europa.eu` | `currency.rates.ecb` (D-011) | P3 verify the daily reference-rates URL |
| `openholidaysapi.org` | `kairos.holidays.*` (D-030) | Listed but **dark**: never fetched until RELAY's thread accepts D-030 |
| `nap.transportes.gob.es` and each picked feed's publisher | `gtfs.static.*` (D-011) | P3 verify; feed hosts added as he picks feeds |

## 9. The phone: Proton VPN and the LAN

Proton VPN is always on (D-005). For APSIRA to reach the hub at home: Proton VPN → Settings → **Allow LAN
connections** on. **P0 verify** on the phone that the hub answers with Proton VPN connected, and that Android's
"Block connections without VPN" does not stop LAN traffic. Away from home nothing changes: the hub is unreachable by
design.

## 10. The manual Proton copy (v1, D-008)

From the operator's own login (member of `apsira-read`), no logout and no second account:

```bash
ls /var/lib/apsira-data/store /var/lib/apsira-data/archive   # readable, not writable
systemctl list-timers apsira-prune.timer                      # copy outside the prune window (Sunday 04:00)
```

Upload `/var/lib/apsira-data/store` and `/var/lib/apsira-data/archive` — both ciphertext, so Proton holds ciphertext
throughout (R5, D-028) — with the Proton Drive CLI
(`sync-and-storage.md` §3.3) or the Proton Drive app. **P0 verify** the CLI's upload command and record it here.
restic's pack files never change after they are written, so repeated uploads only add the new ones; a prune
removes old packs, and the next copy should mirror that.

## 11. Moving to the backup SSD

When the SSD is fitted (status screen says "not independent" until then; the hub compares the data root's device with
`/`'s):

```bash
# [operator]
lsblk -o NAME,SIZE,MODEL,SERIAL                       # identify the new disk; triple-check the name
sudo cryptsetup luksFormat --type luks2 /dev/<ssd>
sudo systemd-cryptenroll --tpm2-device=auto /dev/<ssd>   # unattended unlock at boot; keep the recovery key below
sudo systemd-cryptenroll --recovery-key /dev/<ssd>       # save it in the password manager entry "APSIRA hub"
sudo cryptsetup open /dev/<ssd> apsira-ssd && sudo mkfs.btrfs -L apsira-data /dev/mapper/apsira-ssd
sudo mkdir -p /mnt/apsira-new && sudo mount /dev/mapper/apsira-ssd /mnt/apsira-new
sudo systemctl stop apsira-hub apsira-store apsira-prune.timer
sudo rsync -aHAX --numeric-ids /var/lib/apsira-data/ /mnt/apsira-new/   # bind mounts under rc/ are excluded: unmount them first
sudo -u apsira-store restic check --repo /mnt/apsira-new/store --password-file /etc/apsira/restic-password
```

Then add the SSD to `/etc/crypttab` and `/etc/fstab` **at `/var/lib/apsira-data`**, move the old directory aside
(`/var/lib/apsira-data.old`), mount, re-create the `rc/` mount points, start the units, check the status screen
shows "independent", and delete `.old` only after a restore has been proved from the SSD.

## 12. Removal and rollback

```bash
# [operator]
sudo systemctl disable --now apsira-hub.service apsira-store.service apsira-prune.timer
sudo firewall-cmd --permanent --zone=FedoraWorkstation \
  --remove-rich-rule='rule family="ipv4" source address="192.168.68.0/22" port port="8443" protocol="tcp" accept'
sudo firewall-cmd --reload
sudo umount /var/lib/apsira-data/rc/*        # and remove their /etc/fstab lines
sudo rm /etc/systemd/system/apsira-*.service /etc/systemd/system/apsira-prune.timer && sudo systemctl daemon-reload
```

The data root, `/etc/apsira` and the accounts are kept: deleting them destroys the backup history and the archive's
only copy. Removing them is a separate, explicit operator decision (`sudo userdel apsira`, `apsira-store`; the
groups; the directories), taken only after a Proton copy is verified.
