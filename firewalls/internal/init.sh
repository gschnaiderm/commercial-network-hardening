# Execute common hardening scripts
bash /root/common/kernel_hardening.sh
bash /root/common/os_hardening.sh

# Flush all nftables rules
nft flush ruleset

# FILTER Table: SPI
nft add table inet filter
nft add chain inet filter input { type filter hook input priority filter \; policy drop \; }
nft add chain inet filter forward { type filter hook forward priority filter \; policy drop \; }
nft add chain inet filter output { type filter hook output priority filter \; policy accept \; }

nft add rule inet filter input iif lo accept

# Strict SPI: Allow traffic for established connections
nft add rule inet filter input ct state established,related accept
nft add rule inet filter forward ct state established,related accept

# Strict Access Rules (New Traffic)

WEB_IP="${WEB_IP:-10.0.10.100}"
DB_IP="${DB_IP:-10.0.20.100}"
SIEM_IP="${SIEM_IP:-10.0.30.100}"

# Allow Web Server -> Database (PostgreSQL 5432)
nft add rule inet filter forward ip saddr $WEB_IP ip daddr $DB_IP tcp dport 5432 ct state new accept

# Allow Syslog (UDP 514) from any network to SIEM
nft add rule inet filter forward ip daddr $SIEM_IP udp dport 514 ct state new accept

echo "Internal Firewall configured exclusively with strict SPI (nftables). DPI analysis has been removed."
