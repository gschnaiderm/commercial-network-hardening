#!/bin/bash

# =============================================================
# PASSIVE IDS (Sniffer / SPAN Port)
# =============================================================

# As it is a passive IDS, it MUST NOT route packets.
echo 0 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true

# Do not flush iptables rules as it breaks Docker's embedded DNS resolution

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

# Configure Suricata to alert on all traffic regardless of direction (useful for this lab)
sed -i 's/^[[:space:]]*HOME_NET:.*$/    HOME_NET: "any"/' /etc/suricata/suricata.yaml
sed -i 's/^[[:space:]]*EXTERNAL_NET:.*$/    EXTERNAL_NET: "any"/' /etc/suricata/suricata.yaml

# Update Suricata rules (downloads signatures from Emerging Threats)
echo "nameserver 8.8.8.8" > /etc/resolv.conf
# Enable specific Nmap rules that are disabled by default in ET Open
echo "re:ET SCAN NMAP" > /etc/suricata/enable.conf
suricata-update --enable-conf /etc/suricata/enable.conf

# Disable noisy logs (flow and stats) to prevent SIEM saturation. Only log alerts!
# Properly disable stats and flow in eve-log by commenting them out, since they don't have 'enabled: yes' by default
sed -i '/- eve-log:/,/- pcap-log:/ s/^[[:space:]]*- stats:/#        - stats:/' /etc/suricata/suricata.yaml
sed -i '/- eve-log:/,/- pcap-log:/ s/^[[:space:]]*- flow$/#        - flow/' /etc/suricata/suricata.yaml

# Fix rule path (suricata-update downloads to /var/lib/suricata/rules, but yaml defaults to /etc/suricata/rules)
sed -i 's|default-rule-path: /etc/suricata/rules|default-rule-path: /var/lib/suricata/rules|g' /etc/suricata/suricata.yaml

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
# -k none: Disables checksum validation. Duplicated packets from firewall might have invalid checksums due to offloading.
suricata -i eth0 -k none --user suricata --group suricata -D

echo "Passive Suricata IDS running as unprivileged user, monitoring mirrored traffic and forwarding logs to SIEM."

# Background sys-stats loop (System Telemetry)
(
while true; do
  IDLE=$(top -bn1 | grep '^CPU:' | awk '{print $8}' | tr -d '%')
  if [ -z "$IDLE" ]; then IDLE=100; fi
  CPU_USAGE=$((100 - IDLE))
  RAM_FREE=$(free -m | awk '/Mem:/ {print $4}')
  logger -p local7.info -t sys-stats "CPU_USAGE:${CPU_USAGE}% RAM_FREE:${RAM_FREE}MB"
  sleep 60
done
) &
