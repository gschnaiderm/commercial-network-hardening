bash /opt/common/router_hardening.sh
bash /opt/common/os_hardening.sh

nft flush ruleset

# NAT Table: DNAT to web server
# Traffic enters through edge_firewall (ports 80, 443) and is
# redirected directly to the web server.
# Layer 7 analysis will be delegated to application nodes using a WAF due to encryption.



WEB_IP="${WEB_IP:-10.0.10.100}"
IDS_IP="${IDS_IP:-10.0.10.200}"

nft add table ip nat
nft add chain ip nat prerouting { type nat hook prerouting priority dstnat \; }
nft add chain ip nat postrouting { type nat hook postrouting priority srcnat \; }

# Masquerade traffic (SNAT) to the web server to prevent asymmetric routing issues
nft add rule ip nat postrouting ip daddr $WEB_IP masquerade

# Duplicate incoming traffic to IDS (Simulate SPAN Port / Port Mirroring)
nft add rule ip nat prerouting tcp dport { 80, 443 } dup to $IDS_IP

# Redirect incoming web traffic to the Web Server
nft add rule ip nat prerouting tcp dport { 80, 443 } dnat to $WEB_IP

# SPI
nft add table inet filter
nft add chain inet filter input { type filter hook input priority filter \; policy drop \; }
nft add chain inet filter forward { type filter hook forward priority filter \; policy drop \; }
nft add chain inet filter output { type filter hook output priority filter \; policy accept \; }

# Allow localhost
nft add rule inet filter input iif lo accept

# Allow traffic for established connections (strict SPI)
nft add rule inet filter input ct state established,related accept
nft add rule inet filter forward ct state established,related accept

# Allow forwarding of new web traffic to the web server
nft add rule inet filter forward ip daddr $WEB_IP tcp dport { 80, 443 } ct state new accept

echo "Edge Firewall configured with nftables (SPI) and direct forwarding to Web Server."

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
