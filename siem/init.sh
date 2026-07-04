#!/bin/bash
apt-get update && apt-get install -y iproute2
# Initialize routes for SIEM
DMZ_NET="${DMZ_NET:-10.0.10.0/24}"
DB_NET="${DB_NET:-10.0.20.0/24}"
INTERNAL_FW_SIEM_IP="${INTERNAL_FW_SIEM_IP:-10.0.30.1}"

ip route add $DMZ_NET via $INTERNAL_FW_SIEM_IP
ip route add $DB_NET via $INTERNAL_FW_SIEM_IP
echo "SIEM routes configured."

# Start ELK Stack
echo "Starting ELK Stack..."
exec /usr/local/bin/start.sh
