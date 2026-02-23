# systemd

User units go in `arch/systemd/user/` (not `~/.config/systemd/user/` directly).

To add a new service:
1. Create the `.service` or `.timer` file in `arch/systemd/user/`
2. Run `just systemd-symlinks` to symlink and reload
3. Add the enable command to the `systemd-user` recipe in `arch/justfile`
4. Run `just systemd-user`

`arch/systemd-ignore.txt` lists services intentionally not tracked in git. A pre-commit hook uses this to suppress warnings about untracked systemd files.

# User Bin scripts
Write bin scripts to arch/bin instead of ~/.local/bin to ensure they are version controllded

Symlink with
cd ~/.config/arch && just bin
