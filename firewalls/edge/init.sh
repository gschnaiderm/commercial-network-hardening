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

# Log dropped packets (placed at the end before default drop policy)
nft add rule inet filter input limit rate 10/minute burst 5 packets log prefix \"nft-drop: \" group 0
nft add rule inet filter forward limit rate 10/minute burst 5 packets log prefix \"nft-drop: \" group 0

# Allow forwarding of new web traffic to the web server
nft add rule inet filter forward ip daddr $WEB_IP tcp dport { 80, 443 } ct state new accept

echo "Edge Firewall configured with nftables (SPI) and direct forwarding to Web Server."

# Configure and start rsyslog
cat << 'RSYSLOG' > /etc/rsyslog.conf
$ModLoad imuxsock
*.* @10.0.30.100:5140
RSYSLOG
rsyslogd

# Configure and start ulogd
cat << 'EOF' > /etc/ulogd.conf
[global]
logfile="syslog"
loglevel=5
plugin="/usr/lib/ulogd/ulogd_inppkt_NFLOG.so"
plugin="/usr/lib/ulogd/ulogd_raw2packet_BASE.so"
plugin="/usr/lib/ulogd/ulogd_filter_IFINDEX.so"
plugin="/usr/lib/ulogd/ulogd_filter_IP2STR.so"
plugin="/usr/lib/ulogd/ulogd_filter_PRINTPKT.so"
plugin="/usr/lib/ulogd/ulogd_output_SYSLOG.so"
stack=log1:NFLOG,base1:BASE,ifi1:IFINDEX,ip2str1:IP2STR,print1:PRINTPKT,sys1:SYSLOG
[log1]
group=0
[sys1]
facility=LOG_LOCAL1
level=LOG_INFO
EOF
ulogd -d

# Add route to SIEM network via internal firewall
ip route add 10.0.30.0/24 via 10.0.10.1 dev eth0

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
