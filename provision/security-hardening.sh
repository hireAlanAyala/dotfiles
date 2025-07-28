#!/bin/bash
set -euo pipefail

# Security Hardening Script for Linode VPS
# This script installs and configures security tools and applies kernel hardening

# Configuration
SSH_PORT="${SSH_PORT:-2222}"
SECURITY_PACKAGES="${SECURITY_PACKAGES:-fail2ban rkhunter lynis}"

echo "=== Installing security packages ==="
time pacman -S --noconfirm $SECURITY_PACKAGES

# Configure fail2ban for SSH protection
echo "=== Configuring fail2ban ==="
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
destemail = root@localhost
action = %(action_mwl)s

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

systemctl enable fail2ban
systemctl start fail2ban

# Configure automatic security updates
echo "=== Setting up automatic security updates ==="

# Create systemd service for security updates
cat > /etc/systemd/system/security-updates.service << 'EOF'
[Unit]
Description=Automatic Security Updates
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/pacman -Syu --noconfirm
StandardOutput=journal
StandardError=journal
EOF

# Create systemd timer for daily security updates
cat > /etc/systemd/system/security-updates.timer << 'EOF'
[Unit]
Description=Daily Security Updates
Persistent=true

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable security-updates.timer
systemctl start security-updates.timer

# Additional hardening
echo "=== Applying additional security hardening ==="

# Kernel hardening via sysctl
cat >> /etc/sysctl.d/99-security.conf << 'EOF'
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Log Martians
net.ipv4.conf.all.log_martians = 1

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore Directed pings
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable TCP/IP SYN cookies
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 2
EOF

sysctl -p /etc/sysctl.d/99-security.conf

# Set secure permissions on sensitive files
chmod 600 /etc/ssh/sshd_config
chmod 700 /root
chmod 644 /etc/passwd
chmod 644 /etc/group
chmod 600 /etc/shadow
chmod 600 /etc/gshadow

# Show security status
echo "=== Security configuration summary ==="
fail2ban-client status
systemctl list-timers security-updates.timer
ufw status verbose

echo "✅ Security hardening completed successfully"