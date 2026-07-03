#!/bin/bash
# firewalls/common/kernel_hardening.sh

# Enable routing 
echo 1 > /proc/sys/net/ipv4/ip_forward

# Attack mitigation part
# Enable strict Reverse Path Filtering (Mitigates IP spoofing by ensuring the return route matches)
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/conf/default/rp_filter 2>/dev/null || true

# Disable Source Routing (Prevents sender from dictating packet route, bypassing firewalls)
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route 2>/dev/null || true
echo 0 > /proc/sys/net/ipv4/conf/default/accept_source_route 2>/dev/null || true

# Ignore ICMP Redirects and Secure Redirects (Prevents malicious routing table modifications)
echo 0 > /proc/sys/net/ipv4/conf/all/accept_redirects 2>/dev/null || true
echo 0 > /proc/sys/net/ipv4/conf/default/accept_redirects 2>/dev/null || true
echo 0 > /proc/sys/net/ipv4/conf/all/secure_redirects 2>/dev/null || true
echo 0 > /proc/sys/net/ipv4/conf/default/secure_redirects 2>/dev/null || true

# Do not send ICMP Redirects
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects 2>/dev/null || true
echo 0 > /proc/sys/net/ipv4/conf/default/send_redirects 2>/dev/null || true

# DDoS protection
# Enable SYN cookies and increase connection queue
echo 1 > /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null || true
echo 2048 > /proc/sys/net/ipv4/tcp_max_syn_backlog 2>/dev/null || true

# Ignore broadcast PING responses (smurf attacks)
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts 2>/dev/null || true

# Ignore bogus/malformed ICMP error responses
echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses 2>/dev/null || true


# Log packets marked as invalid to detect spoofing in logs
echo 1 > /proc/sys/net/ipv4/conf/all/log_martians 2>/dev/null || true
