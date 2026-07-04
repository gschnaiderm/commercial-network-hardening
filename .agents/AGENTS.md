# Project Overview: Systems Security Final Project

This document provides context, architectural decisions, and constraints for AI agents working on this repository.

## 1. Goal and Context
This project is a final assignment for a Systems Security (Seguridad de Sistemas) university class. It consists of a containerized (Docker Compose) multi-tier network architecture designed to demonstrate network hardening, intrusion detection, firewalling, and centralized logging.

## 2. Architecture & Networks
The environment uses custom IPAM Docker bridge networks to simulate a routed enterprise topology:
- **`dmz_net` (10.0.10.0/24)**: Public-facing network. Gateway: `10.0.10.253`.
- **`db_net` (10.0.20.0/24)**: Backend database network. Gateway: `10.0.20.253`.
- **`siem_net` (10.0.30.0/24)**: Management/Monitoring network. Gateway: `10.0.30.253`.

## 3. Container Roles and Configuration
All containers initialize using shell scripts (e.g., `init.sh`) mounted as volumes. **Important**: All volume mounts in `docker-compose.yml` use the `:Z` flag to prevent SELinux permission denied errors on the host.

### Edge Firewall (`edge_firewall`)
- **Role**: Perimeter defense and entry point.
- **Network**: `dmz_net` (`10.0.10.254`).
- **Notes**: It performs SNAT (`masquerade`) on output to prevent asymmetric routing when return traffic attempts to bypass the firewall via the default Docker gateway.

### Internal Firewall (`internal_firewall`)
- **Role**: Segmentation and routing between DMZ, DB, and SIEM networks.
- **Networks**: `dmz_net` (`10.0.10.1`), `db_net` (`10.0.20.1`), `siem_net` (`10.0.30.1`).
- **Notes**: Shares `kernel_hardening.sh` and `os_hardening.sh` (located in `firewalls/common/`) with the edge firewall.

### Web Server (`web_server`)
- **Role**: The main application frontend (Next.js or simple dummy app for testing).
- **Network**: `dmz_net` (`10.0.10.100`).

### Database Server (`db_server`)
- **Role**: PostgreSQL 15 database.
- **Network**: `db_net` (`10.0.20.100`).

### Intrusion Detection System (`ids`)
- **Role**: Passive Suricata IDS sniffing traffic.
- **Network**: `dmz_net` (`10.0.10.200`).
- **Hardening Details**: 
  - Runs with the principle of least privilege: starts as root, binds to the network interface (`eth0` with `AF_PACKET`), and drops privileges to the `suricata` user.
  - Container capabilities are explicitly restricted in `docker-compose.yml` (`NET_ADMIN`, `NET_RAW`, `SYS_NICE`).
- **Logging**: Forwards structured JSON alerts (`eve.json`) to the SIEM via a local `rsyslog` daemon.

### SIEM (`siem`)
- **Role**: Centralized syslog aggregator.
- **Network**: `siem_net` (`10.0.30.100`).
- **Configuration**: Runs Ubuntu with `rsyslog` explicitly configured to listen on UDP port 514 (`imudp`).

## 4. Agent Guidelines & Rules
1. **Language**: **ALL code comments MUST be written in English**. If you modify a file, translate existing Spanish comments to English or ensure new ones are in English.
2. **Docker Networking**: Do not alter the custom IPAM setup unless explicitly requested. The `.253` gateways are intentional to prevent Docker's default `.1` gateway from conflicting with the custom router IPs.
3. **Volume Permissions**: When creating or modifying volume mounts, always remember the `:Z` suffix for SELinux compatibility. If `Permission denied` errors occur during container startup, invoke scripts explicitly with `bash /root/init.sh` in the `command` directive.
4. **Hardening Focus**: Always prioritize secure defaults. If adding new services, consider dropping capabilities and running as non-root users.
5. **No Blind Operations**: Do not assume services are running; always check logs (`docker logs <container>`) if troubleshooting. Use `manage_task` to trace background execution.
