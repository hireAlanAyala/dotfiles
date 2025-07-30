# VPS Configuration Docker Testing

This directory contains Docker-based testing tools for your VPS configuration scripts, allowing you to test changes locally before deploying to your VPS.

## What This Tests

✅ **Compatible Components:**
- Package installation (pacman commands)
- User creation and sudo configuration  
- GPG key import and SOPS functionality
- Home Manager and Nix configuration
- Dotfiles deployment logic
- Basic security hardening (file permissions)

❌ **VPS-Only Components (Not Tested):**
- systemd services (fail2ban, security updates)
- UFW firewall configuration
- SSH daemon port changes
- Kernel parameter hardening (sysctl)

## Quick Start

```bash
# Run the test environment
./test-docker-provision.sh

# Inside the container, run unified setup
/tmp/unified-setup.sh

# Test with GPG key generation
GENERATE_TEST_KEY=true /tmp/unified-setup.sh

# Test Home Manager configuration
cp -r /mnt/config/home-manager ~/.config/
cd ~/.config/home-manager
# Test nix build commands here
```

## Files

- `Dockerfile` - Arch Linux test environment using unified config
- `test-docker-provision.sh` - Main test runner
- `../provision/unified-setup.sh` - Single script for all environments
- `../provision/config.env` - Shared configuration file

## Testing Workflow

1. **Make changes** to your configuration
2. **Run Docker tests** to validate core functionality
3. **Deploy to VPS** for system-level features
4. **Iterate** based on results

This approach gives you ~80% test coverage locally with much faster iteration cycles.