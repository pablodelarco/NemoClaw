#!/usr/bin/env bash
set -o errexit -o pipefail

# Install OpenNebula context hooks for NemoClaw appliance
# These hooks are called by the context agent at boot time

# Ensure context hook directory exists
mkdir -p /etc/one-context.d

# Set permissions on context hooks
chmod 0755 /etc/one-context.d/net-90-service-appliance 2>/dev/null || true
chmod 0755 /etc/one-context.d/net-99-report-ready 2>/dev/null || true

# Ensure service manager is executable
chmod 0755 /etc/one-appliance/service 2>/dev/null || true

# Ensure one-appliance libraries have correct permissions
chmod 0644 /etc/one-appliance/common.sh 2>/dev/null || true
chmod 0644 /etc/one-appliance/functions.sh 2>/dev/null || true

# Enable the context service if available
systemctl enable one-context.service 2>/dev/null || true
systemctl enable one-context-reconfigure.service 2>/dev/null || true
