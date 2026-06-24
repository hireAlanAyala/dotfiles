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

So `_systemd-user-homebase` (enables `sunshine`) and `_systemd-user-archdev` (enables `battery-monitor.timer` `wifi-prefer.timer`) only run on their machine. Same pattern for `_systemd-system-*` (`tlp` → archdev). Add a new host = add `_systemd-{user,system}-<hostname>` recipes; an absent recipe is a no-op (the `-` prefix ignores it).

For per-host **files**, put them under `hosts/<hostname>/` and host-select in the recipe. Example — **boot config** lives at `hosts/<host>/boot/loader/`: the `etc` recipe symlinks `/etc/boot/loader` to the host's, and the `sync-boot-entries` pacman hook copies `hosts/$(cat /etc/hostname)/boot/loader/entries/arch.conf` to `/boot` on kernel upgrades.

## TODO — required before provisioning the laptop (`archdev`)

- ✅ **boot config** — DONE. Moved to `hosts/<host>/boot/loader/`; the `etc` recipe + `sync-boot-entries` hook now host-select. ⚠️ Still need to create `hosts/archdev/boot/loader/entries/arch.conf` with the laptop's own LUKS UUID (no nvidia) — see `hosts/archdev/README.md`. Until then the hook fails harmlessly, leaving the laptop's `/boot` untouched.
- **per-host packages** — `nvidia-open-dkms`/`nvidia-utils`/`lib32-nvidia-utils` are homebase-only; `tlp`/`tlp-rdw` are archdev-only. Blocked on the `export-packages` pacman hook, which regenerates one list from installed state — it needs to learn to keep a shared list + per-host deltas.
- **networks** — `10-ethernet.network` (homebase) vs `20-wireless.network` (archdev); currently both are deployed (harmless, only the matching iface activates) but could be host-split for tidiness.
