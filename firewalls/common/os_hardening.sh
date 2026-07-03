#!/bin/bash
# firewalls/common/os_hardening.sh
# OS hardening (services, ports and permissions)

# Lock the root password 
passwd -l root 2>/dev/null || true

# Restrict strict permissions to critical folders and files
chmod 600 /etc/shadow 2>/dev/null || true
chmod 644 /etc/passwd 2>/dev/null || true
chmod 700 /root 2>/dev/null || true

# Disable unneeded services in a pure routing container 
apk del openssh 2>/dev/null || true  # administration is done via secure in-band or through the host (Docker exec).
rc-update del crond 2>/dev/null || true
apk del curl wget 2>/dev/null || true
