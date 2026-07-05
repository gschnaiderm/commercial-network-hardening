FROM alpine:latest
RUN apk update && apk add nftables iproute2 iputils tcpdump bash rsyslog ulogd
COPY init.sh /root/init.sh
RUN chmod +x /root/init.sh
