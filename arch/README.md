# Arch Setup

Deploy everything: `just all`

## Adding things

**Package:** Just install it (`pacman -S` / `yay -S`), then `just packages-sync` to bless it into this host's own list (`packages/<host>.txt` / `<host>-aur.txt`). Each host is the source of truth for itself — a laptop-only package simply lives in `archdev.txt` and never touches the desktop. A genuinely-shared package must be installed + blessed on both hosts. `just packages-check` shows drift; the pre-push hook blocks pushing while stale. To converge a machine: `just packages` / `just packages-aur`.

**Bin script:** Create in `bin/`, run `just bin`. Symlinks to `~/.local/bin/`.

**User systemd unit:** Create `.service`/`.timer` in `systemd/user/`, run `just systemd-symlinks`, add enable command to `systemd-user` recipe, run `just systemd-user`.

**System systemd unit:** Create in `etc/systemd/system/`, run `just etc` (copies to `/etc/`), add enable command to `systemd-system` recipe, run `just systemd-system`.

**Etc config:** Add file under `etc/`, add symlink/copy line to `etc` recipe, run `just etc`.

## Notes

- User units are symlinked (edits apply after `daemon-reload`)
- System units are copied (re-run `just etc` after edits)
- `just check` shows what will be linked
