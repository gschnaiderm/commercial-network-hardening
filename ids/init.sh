#!/bin/bash

# =============================================================
# PASSIVE IDS (Sniffer / SPAN Port)
# =============================================================

# As it is a passive IDS, it MUST NOT route packets.
echo 0 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true

# Flush rules (in case any old configuration remains)
iptables -F
iptables -t nat -F
iptables -t mangle -F

echo "IDS configured in Passive mode."

# -------------------------------------------------------------
# Suricata Hardening (Dropping Privileges)
# -------------------------------------------------------------
# Create suricata user if it doesn't exist
useradd --no-create-home --system --shell /sbin/nologin suricata 2>/dev/null || true

# Ensure the logs and state directories exist with correct ownership/permissions
mkdir -p /var/log/suricata /var/lib/suricata /var/run/suricata
chgrp -R suricata /etc/suricata /var/log/suricata /var/lib/suricata /var/run/suricata 2>/dev/null || true
chmod -R g+r /etc/suricata 2>/dev/null || true
chmod -R g+rw /var/log/suricata /var/lib/suricata /var/run/suricata 2>/dev/null || true

# Update Suricata rules (downloads signatures from Emerging Threats)
suricata-update

# -------------------------------------------------------------
# SIEM Integration (Forward EVE JSON via Rsyslog)
# -------------------------------------------------------------
SIEM_IP="${SIEM_IP:-10.0.30.100}"
INTERNAL_FW_IP="10.0.10.1"

# Route SIEM traffic through internal firewall
ip route add 10.0.30.0/24 via $INTERNAL_FW_IP || true

# Ensure eve.json exists for rsyslog imfile module to monitor
touch /var/log/suricata/eve.json
chgrp suricata /var/log/suricata/eve.json || true
chmod g+rw /var/log/suricata/eve.json || true

echo "Configuring rsyslog to forward EVE JSON to SIEM at $SIEM_IP..."
cat << EOF > /etc/rsyslog.d/suricata.conf
\$ModLoad imfile
\$InputFileName /var/log/suricata/eve.json
\$InputFileTag suricata:
\$InputFileStateFile stat-suricata-eve
\$InputFileSeverity info
\$InputFileFacility local7
\$InputRunFileMonitor
local7.* @$SIEM_IP:5140
EOF

/usr/sbin/rsyslogd

# Remove stale PID file if exists
rm -f /var/run/suricata.pid /var/run/suricata/suricata.pid

# Start Suricata in background listening on the main interface (eth0)
# -i eth0: passive AF_PACKET mode, reads network copies without interfering.
# --user suricata --group suricata: Drops root privileges after initialization for security.
suricata -i eth0 --user suricata --group suricata -D

echo "Passive Suricata IDS running as unprivileged user, monitoring mirrored traffic and forwarding logs to SIEM."
