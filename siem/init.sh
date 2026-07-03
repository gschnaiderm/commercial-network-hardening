#!/bin/bash
# Enable routing (just in case, although SIEM is an endpoint)
echo 1 > /proc/sys/net/ipv4/ip_forward

# Configure routing to DMZ and DB through the Internal Firewall
# Internal Firewall IP on the SIEM network is 10.0.30.1
INTERNAL_FW_SIEM_IP="${INTERNAL_FW_SIEM_IP:-10.0.30.1}"
DMZ_NET="${DMZ_NET:-10.0.10.0/24}"
DB_NET="${DB_NET:-10.0.20.0/24}"
ip route add $DMZ_NET via $INTERNAL_FW_SIEM_IP
ip route add $DB_NET via $INTERNAL_FW_SIEM_IP

echo "SIEM routes configured."

# Configure rsyslog to listen on UDP 514
sed -i '/module(load="imudp")/s/^#//g' /etc/rsyslog.conf
sed -i '/input(type="imudp" port="514")/s/^#//g' /etc/rsyslog.conf

# For older versions of ubuntu/rsyslog that use $ModLoad:
sed -i 's/^#$ModLoad imudp/$ModLoad imudp/' /etc/rsyslog.conf
sed -i 's/^#$UDPServerRun 514/$UDPServerRun 514/' /etc/rsyslog.conf

echo "Rsyslog configured to receive logs on UDP 514."
