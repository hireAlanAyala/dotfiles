# Host-specific configuration

Dotfiles are shared 1:1 between two machines, keyed on **hostname**:

| host | role | hardware notes |
|------|------|----------------|
| `homebase` | desktop (main) | LUKS root, nvidia GPU, wired, runs `sunshine` host + `tiger-cfo` |
| `archdev`  | laptop | battery/`tlp`, wifi (`wifi-prefer`), `battery-monitor` |

Everything not listed here is shared and byte-identical, so the two machines feel the same. Only genuine per-host divergence lives in this split.

## How the split works

**systemd services** are dispatched in `arch/justfile`: the shared `systemd-system` / `systemd-user` recipes enable common units, then call a private per-host recipe:

```
-just -f "{{justfile()}}" "_systemd-user-$(hostnamectl hostname)"
```

So `_systemd-user-homebase` (enables `sunshine`, `rustic-backup.timer`, `guacamole-web.service`) and `_systemd-user-archdev` (enables `battery-monitor.timer` `wifi-prefer.timer`) only run on their machine. `rustic-backup` and `guacamole` (a browser remote-desktop gateway *into* the desktop) are homebase-only because the desktop is the canonical machine you connect to — the laptop is an emergency box that pulls from ssh/github, not a host you remote into. Same pattern for `_systemd-system-*` (`tlp` → archdev). Add a new host = add `_systemd-{user,system}-<hostname>` recipes; an absent recipe is a no-op (the `-` prefix ignores it).

For per-host **files**, put them under `hosts/<hostname>/` and host-select in the recipe. Example — **boot config** lives at `hosts/<host>/boot/loader/`: the `etc` recipe symlinks `/etc/boot/loader` to the host's, and the `sync-boot-entries` pacman hook copies `hosts/$(cat /etc/hostname)/boot/loader/entries/arch.conf` to `/boot` on kernel upgrades.

For per-host **`/etc` configs**, the `etc` recipe dispatches to a private `_etc-<hostname>` recipe (same pattern as systemd). `_etc-archdev` deploys the laptop power-management configs (`tlp.conf`, `sleep.conf.d/hibernate.conf`, `logind.conf.d/lid.conf`); `_etc-homebase` is a no-op. This keeps laptop-only `/etc` files off the desktop entirely rather than deploying them inert.

## TODO — required before provisioning the laptop (`archdev`)

- ✅ **boot config** — DONE. Moved to `hosts/<host>/boot/loader/`; the `etc` recipe + `sync-boot-entries` hook now host-select. ⚠️ Still need to create `hosts/archdev/boot/loader/entries/arch.conf` with the laptop's own LUKS UUID (no nvidia) — see `hosts/archdev/README.md`. Until then the hook fails harmlessly, leaving the laptop's `/boot` untouched.
- ✅ **packages — symmetric per-host lists.** Each host is the source of truth for *itself*: `arch/packages/<host>.txt` + `<host>-aur.txt` hold that machine's explicit package set (`homebase.txt`, `archdev.txt`, …). Nothing is computed or shared — desired set for a host is literally its own file. This makes leaks structurally impossible: a laptop-only package lives only in `archdev.txt` and can never reach the desktop, because homebase installs `homebase.txt` and nothing else. `just packages`/`packages-aur` install this host's list; `just packages-check` reports drift (read-only); `just packages-sync` re-blesses *this host's own* two files from installed state, guarded by a machine-local `.provisioned` sentinel (untracked) so a half-provisioned box can't clobber its desired-state. Because each host only writes its own files, no source-of-truth host restriction is needed. The trade-off vs the old `base ± deltas` model is that the two lists overlap ~90% and a genuinely-shared package must be blessed on both hosts (shows up as `MISSING` on the host that lacks it — fail-visible, never a wrong-host effect). The old auto-clobbering `export-packages` pacman hook is **retired**; a `pre-push` git hook (`arch/githooks/`, wired by `just githooks`) blocks pushing when installed packages drift from tracked desired-state. Add a new host = run `just packages-sync` on it.
- **networks** — `10-ethernet.network` (homebase) vs `20-wireless.network` (archdev); currently both are deployed (harmless, only the matching iface activates) but could be host-split for tidiness.
