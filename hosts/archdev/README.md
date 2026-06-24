# archdev (laptop) — boot entry TODO

This host's boot entry does **not exist yet**. Before running `just etc` or a
kernel upgrade on the laptop, create:

    hosts/archdev/boot/loader/entries/arch.conf

Model it on `hosts/homebase/boot/loader/entries/arch.conf`, but:
- use the **laptop's own LUKS UUID** — `cryptsetup luksUUID <root-partition>` (or `blkid`)
- **drop** `nvidia_drm.modeset=1` (the laptop is Intel graphics)

Until that file exists, the `sync-boot-entries` pacman hook fails harmlessly
(no source to copy), leaving the laptop's existing `/boot` entry untouched — so
a half-provisioned laptop never gets homebase's (wrong) LUKS config.
