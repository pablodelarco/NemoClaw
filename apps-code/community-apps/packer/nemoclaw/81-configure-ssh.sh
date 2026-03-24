#!/usr/bin/env bash
set -o errexit -o pipefail

# SSH hardening for NemoClaw appliance image
# Runs during Packer build, not at boot time

# Disable password authentication (key-only after deployment)
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin without-password/' /etc/ssh/sshd_config

# Enable public key authentication
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Disable empty passwords
sed -i 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config

# Disable X11 forwarding
sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
