# Explicación de Configuración de Firewalls (Routers)

A continuación se detalla qué políticas y configuraciones se aplican en los scripts de inicialización de los dos firewalls de la arquitectura, y el porqué de cada decisión técnica.

## 1. Edge Firewall (`firewalls/edge/init.sh`)
Este firewall es la primera línea de defensa de la red. Está expuesto a la red pública (atacantes) y su principal objetivo es filtrar ruido, bloquear escaneos masivos y redirigir el tráfico web legítimo.

- **Hardening Base**: Ejecuta `router_hardening.sh` y `os_hardening.sh` para deshabilitar protocolos inseguros, prevenir IP Spoofing (rp_filter) y proteger el stack de red del kernel frente a ataques SYN Flood y similares.
- **Políticas de Denegación por Defecto (Default Drop)**: Las cadenas `input` y `forward` están configuradas en `policy drop`. **Por qué:** Basado en el principio de menor privilegio, todo el tráfico que no esté explícitamente permitido es descartado silenciosamente.
- **Inspección de Estado (SPI)**: Se aceptan paquetes con estado `established,related`. **Por qué:** Permite que las respuestas a conexiones ya autorizadas (ej. el firewall descargando un paquete o enviando un log) fluyan sin necesidad de abrir puertos de entrada fijos.
- **NAT (Redirección y SNAT)**:
  - **DNAT:** Redirige todo el tráfico entrante de los puertos 80 y 443 a la IP del `web_server`.
  - **SNAT (Masquerade):** Enmascara la IP de origen externa. **Por qué:** Evita problemas de *enrutamiento asimétrico*. Si no se aplicara, el servidor web intentaría responderle directamente al cliente a través del gateway por defecto de Docker (bypasseando el firewall de borde) y la conexión se colgaría.
- **Logueo Controlado (ulogd)**: Envía los paquetes bloqueados al SIEM, pero con una restricción (`limit rate 10/minute`). **Por qué:** Si un atacante lanza un ataque de Denegación de Servicio (DDoS), el firewall no saturará de logs al SIEM.
- **Ruta Estática**: Agrega una regla para poder alcanzar la red del SIEM (`10.0.30.0/24`) a través del firewall interno.

## 2. Internal Firewall (`firewalls/internal/init.sh`)
Este firewall actúa como el router centralizador que segmenta la zona DMZ, la red de Base de Datos y la red de Administración (SIEM).

- **Hardening Base y SPI (Drop por Defecto)**: Utiliza la misma filosofía de denegación estricta y estado de sesión que el Edge Firewall.
- **Micro-segmentación Estricta**:
  - Solo permite que el **Web Server** inicie conexiones al **Database Server** (Puerto TCP 5432).
  - Solo permite el reenvío de logs (Puerto UDP 5140) hacia el **SIEM**.
  - **Por qué:** Si un atacante logra comprometer el servidor web en la DMZ, el firewall interno evitará que pueda hacer un escaneo de puertos a otras máquinas de la base de datos o infectar al SIEM, encasillando el ataque.
- **Traffic Duplication (Clonado SPAN Port)**: Utiliza `dup to` en la cadena de prerouting para copiar *exclusivamente* el tráfico destinado a la Base de Datos y enviárselo al IDS. 
  - **Por qué aquí y no en el Edge:** Hacer la duplicación en el perímetro enviaría todos los escaneos mundiales de internet (Nmap, botnets) directamente al IDS, lo cual saturaría el motor Suricata de inmediato. Al clonarlo en el Internal Firewall, el IDS solo analiza el tráfico interno o amenazas que ya lograron vulnerar el perímetro.
- **Telemetría Activa**: Al igual que el Edge, ejecuta un script en segundo plano recolectando `% de CPU` y `RAM libre` para el análisis de rendimiento en el SIEM.
