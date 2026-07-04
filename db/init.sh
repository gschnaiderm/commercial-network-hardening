#!/bin/bash
# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Configure routing to DMZ and SIEM through the Internal Firewall
# Internal Firewall IP on the DB network is 10.0.20.1
INTERNAL_FW_DB_IP="${INTERNAL_FW_DB_IP:-10.0.20.1}"
DMZ_NET="${DMZ_NET:-10.0.10.0/24}"
SIEM_NET="${SIEM_NET:-10.0.30.0/24}"
ip route add $DMZ_NET via $INTERNAL_FW_DB_IP
ip route add $SIEM_NET via $INTERNAL_FW_DB_IP

echo "DB Server routes configured."

# Configure and start rsyslog
cat << 'RSYSLOG' > /etc/rsyslog.conf
$ModLoad imuxsock
*.* @10.0.30.100:5140
RSYSLOG
rsyslogd

# Background sys-stats loop
(
while true; do
  IDLE=$(top -bn1 | grep '^CPU:' | awk '{print $8}' | tr -d '%')
  if [ -z "$IDLE" ]; then IDLE=100; fi
  CPU_USAGE=$((100 - IDLE))
  RAM_FREE=$(free -m | awk '/Mem:/ {print $4}')
  logger -p local0.info -t sys-stats "CPU_USAGE:${CPU_USAGE}% RAM_FREE:${RAM_FREE}MB"
  sleep 60
done
) &
