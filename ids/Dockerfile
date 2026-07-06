FROM ubuntu:22.04
RUN apt-get update && apt-get install -y iptables suricata iproute2 iputils-ping tcpdump rsyslog
COPY init.sh /root/init.sh
RUN chmod +x /root/init.sh
