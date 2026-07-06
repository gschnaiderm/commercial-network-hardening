# Guía de Exposición: Demostración en Vivo (Hardening de Redes Comerciales)

Esta guía está diseñada para que expongas el proyecto directamente mostrando la terminal, el código y el SIEM (Kibana) en tiempo real, sin usar diapositivas. Sigue este orden lógico para estructurar tu presentación:

---

## Bloque 1: Introducción y Arquitectura (Contexto)
* **Qué mostrar en pantalla:**
  1. Abre el archivo [docker-compose.yml](file:///home/gschnaiderm/universidad/ss/proyecto_final/docker-compose.yml) para mostrar la definición de contenedores y redes.
* **Qué explicar verbalmente:**
  * "El objetivo de este proyecto es aplicar **Defense in Depth** (Defensa en Profundidad) a una red comercial simulada."
  * "Para ello, segmentamos la red en tres subredes totalmente aisladas a nivel de Capa 2/3 (Docker bridges):
    * `dmz_net` (10.0.10.0/24): Zona desmilitarizada donde está el servidor web expuesto.
    * `db_net` (10.0.20.0/24): Red de backend aislada para la base de datos crítica.
    * `siem_net` (10.0.30.0/24): Red de gestión y monitoreo centralizado."

---

## Bloque 2: La Primera Línea de Defensa (Edge Firewall)
* **Qué mostrar en pantalla:**
  1. Abre el script de inicialización [firewalls/edge/init.sh](file:///home/gschnaiderm/universidad/ss/proyecto_final/firewalls/edge/init.sh).
  2. En una terminal, ejecuta el script de ataque externo:
     ```bash
     ./pentest/test-SYN-scan.sh
     ```
  3. Muestra en Kibana (filtrando por `syslog_hostname: "edge_firewall"`) cómo aparecen los registros de descarte (`nft-drop:`).
* **Qué explicar verbalmente:**
  * "El Edge Firewall es el punto de entrada. Aquí aplicamos **Hardening de Kernel** (`router_hardening.sh` y `os_hardening.sh`) para prevenir IP Spoofing, ignorar redirecciones ICMP maliciosas y mitigar ataques SYN Flood mediante cookies TCP."
  * "En el firewall (`nftables`), la política por defecto es **Default Drop** (SPI - Stateful Packet Inspection). Solo se permite el tráfico web entrante a los puertos 80/443 redirigido al Web Server."
  * "Al ejecutar el escaneo SYN externo de Nmap, demostramos cómo el firewall bloquea todos los intentos de escaneo y los reporta a través de `ulogd` al SIEM. Además, aplicamos **Rate Limiting** en el logueo para que un ataque masivo de denegación de servicio no sature ni bote nuestro servidor de logs."

---

## Bloque 3: Contención y SPAN Port (Internal Firewall)
* **Qué mostrar en pantalla:**
  1. Abre el archivo [firewalls/internal/init.sh](file:///home/gschnaiderm/universidad/ss/proyecto_final/firewalls/internal/init.sh).
  2. Resalta las líneas de:
     * Regla de reenvío (forward) de la base de datos (puerto 5432).
     * Regla de clonado (`dup to`).
* **Qué explicar verbalmente:**
  * "El Internal Firewall controla los flujos internos y aplica **micro-segmentación estricta**. Si el servidor web de la DMZ se ve comprometido por una vulnerabilidad, el atacante no puede moverse libremente. Este firewall solo permite la conexión Web-to-DB hacia el puerto 5432, protegiendo al SIEM y otros recursos."
  * "Para no penalizar el rendimiento del tráfico de producción, implementamos **Port Mirroring/SPAN**. El firewall interno clona de forma pasiva (`dup to`) todo el tráfico destinado a la Base de Datos y lo envía a la IP del IDS (`ids`), realizando una auditoría en paralelo sin añadir latencia a la aplicación."

---

## Bloque 4: Detección Activa de Amenazas (IDS)
* **Qué mostrar en pantalla:**
  1. Ejecuta en la terminal el script de ataque interno desde el Web Server:
     ```bash
     ./pentest/test-nmap-scan-db.sh
     ```
  2. Abre Kibana y filtra por:
     ```kql
     suricata.event_type: "alert"
     ```
  3. Muestra la alerta generada por Suricata (`ET SCAN Suspicious inbound to PostgreSQL port 5432`).
* **Qué explicar verbalmente:**
  * "Acabamos de simular un ataque interno: una conexión sospechosa de red directa a la base de datos desde el Web Server."
  * "Como pueden ver en el SIEM, el IDS Suricata analizó pasivamente el tráfico duplicado, identificó la firma del escaneo/conexión anómala y levantó la alerta de seguridad de inmediato sin interrumpir el servicio de base de datos."
  * "El IDS también ha sido endurecido: corre bajo una cuenta de usuario sin privilegios y tiene sus capacidades de Linux reducidas a lo mínimo necesario (`NET_ADMIN` y `NET_RAW` para sniffing)."

---

## Bloque 5: Gestión Centralizada y Telemetría (SOC/SIEM)
* **Qué mostrar en pantalla:**
  1. Muestra en Kibana los logs generales de todos los contenedores (`edge_firewall`, `internal_firewall`, `web_server`, `db_server`, `ids`).
  2. Haz una búsqueda en Kibana filtrando por:
     ```kql
     syslog_program: "sys-stats"
     ```
  3. Muestra los registros de `CPU_USAGE` y `RAM_FREE` actualizándose.
* **Qué explicar verbalmente:**
  * "Finalmente, la visibilidad completa. Todos los contenedores del sistema operativo y los firewalls envían telemetría activa en segundo plano (CPU y RAM) y logs del sistema al SIEM centralizado de forma segura por Syslog (puerto 5140)."
  * "Esto nos permite monitorear la salud de los routers frente a posibles saturaciones por ataques y garantiza que los logs de auditoría sean inmutables, ya que no residen localmente donde un atacante comprometedor podría borrarlos."

---

## Cierre / Conclusión
* **Qué decir:**
  * "En resumen, hemos expuesto una arquitectura comercial resiliente a ataques: el perímetro bloquea la basura externa, el router interno aísla las redes críticas, el IDS detecta movimientos laterales y el SIEM consolida la visibilidad del sistema. Todo alineado a buenas prácticas de hardening y seguridad de la información."
