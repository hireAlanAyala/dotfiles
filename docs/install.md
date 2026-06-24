> ⚠️ STALE: describes the old Nix + home-manager install. The repo is now native
> (pacman/AUR/mise + `just all` / `just packages-all`); install.sh is pending a
> rewrite, and the gpg steps below are superseded by native ~/.gnupg config.

Step 1: inside of this directory run ./install.sh
Step 2: sign into gh cli using token

# pgp (decrypts secrets)
if ~/.gnupg/gpg-agent.conf is empty
echo 'allow-loopback-pinentry' > ~/.gnupg/gpg-agent.conf

if ~/.gnupg/gpg.conf is empty
echo 'use-agent' > ~/.gnupg/gpg.conf

gpgconf --kill gpg-agent
gpg-agent --daemon

force gpg to use loopback pinentry mode to avoid the gui and handle the passphrase
gpg --batch --yes --pinentry-mode loopback --passphrase 'your-passphrase' --sign --armor < /dev/null
