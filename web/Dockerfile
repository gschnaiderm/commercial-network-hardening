FROM node:20-alpine
# iproute2 for routing, git to clone, rsyslog for logging
RUN apk update && apk add --no-cache bash iproute2 git rsyslog
WORKDIR /app
COPY init.sh /root/init.sh
RUN chmod +x /root/init.sh
