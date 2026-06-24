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

For per-host **files** (boot entries, network configs, etc.), put them under `hosts/<hostname>/` and have the relevant justfile recipe pick `hosts/$(hostnamectl hostname)/...`.

## TODO — required before provisioning the laptop (`archdev`)

- ⚠️ **boot config** — `arch/etc/boot/loader/entries/arch.conf` is homebase-specific (its LUKS UUID + `nvidia_drm.modeset=1`). The `etc` recipe currently symlinks `etc/boot/loader` wholesale, which on archdev would point at the **wrong LUKS UUID → unbootable**. Move the boot entry to `hosts/<host>/` and host-select it in `etc` before running `just etc` on the laptop.
- **per-host packages** — `nvidia-open-dkms`/`nvidia-utils`/`lib32-nvidia-utils` are homebase-only; `tlp`/`tlp-rdw` are archdev-only. Blocked on the `export-packages` pacman hook, which regenerates one list from installed state — it needs to learn to keep a shared list + per-host deltas.
- **networks** — `10-ethernet.network` (homebase) vs `20-wireless.network` (archdev); currently both are deployed (harmless, only the matching iface activates) but could be host-split for tidiness.
