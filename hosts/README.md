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

## TODO — required before provisioning the laptop (`archdev`)

- ✅ **boot config** — DONE. Moved to `hosts/<host>/boot/loader/`; the `etc` recipe + `sync-boot-entries` hook now host-select. ⚠️ Still need to create `hosts/archdev/boot/loader/entries/arch.conf` with the laptop's own LUKS UUID (no nvidia) — see `hosts/archdev/README.md`. Until then the hook fails harmlessly, leaving the laptop's `/boot` untouched.
- ✅ **packages — base + computed deltas.** One source of truth: `arch/packages/base.txt` + `base-aur.txt` = homebase's installed state (homebase is canonical). A host's effective set is **computed**, not stored: `(base − <host>.exclude) + <host>.include`. Only `archdev` has deltas (`arch/packages/archdev.{exclude,include,exclude-aur,include-aur}` — out: `nvidia-*`/`sunshine`, in: `archiso`/`exfatprogs`/`which`/`elephant-all-debug`); homebase has none so it falls back to base. `just packages`/`packages-aur` install the computed set; `just packages-check` reports drift (read-only); `just packages-sync` re-blesses base from installed state but is **guarded** (homebase-only + a machine-local `.provisioned` sentinel, untracked) so a half-provisioned box can't clobber desired-state. The old auto-clobbering `export-packages` pacman hook is **retired**; a `pre-push` git hook (`arch/githooks/`, wired by `just githooks`) blocks pushing when installed packages drift from tracked desired-state.
- **networks** — `10-ethernet.network` (homebase) vs `20-wireless.network` (archdev); currently both are deployed (harmless, only the matching iface activates) but could be host-split for tidiness.
