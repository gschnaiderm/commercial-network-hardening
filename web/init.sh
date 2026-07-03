#!/bin/bash

# Enable routing (just in case)
echo 1 > /proc/sys/net/ipv4/ip_forward || true

# Configure routing to DB and SIEM through the Internal Firewall
INTERNAL_FW_DMZ_IP="${INTERNAL_FW_DMZ_IP:-10.0.10.1}"
DB_NET="${DB_NET:-10.0.20.0/24}"
SIEM_NET="${SIEM_NET:-10.0.30.0/24}"
ip route add $DB_NET via $INTERNAL_FW_DMZ_IP
ip route add $SIEM_NET via $INTERNAL_FW_DMZ_IP
echo "Web Server routes configured."

# -------------------------------------------------------------
# Dynamic Deployment from GitHub (COMMENTED FOR TESTING)
# -------------------------------------------------------------
# echo "Starting deployment process from repository..."
# 
# if [ -z "$GIT_REPO_URL" ]; then
#   echo "Error: GIT_REPO_URL variable is not defined."
#   # Keep container alive for debugging
#   tail -f /dev/null
# fi
# 
# cd /app
# 
# if [ ! -d "/app/.git" ]; then
#   echo "Cloning repository $GIT_REPO_URL..."
#   git clone $GIT_REPO_URL .
# else
#   echo "Repository exists. Updating with git pull..."
#   # Reset any local changes and fetch the latest
#   git fetch --all
#   git reset --hard origin/main
#   git pull
# fi
# 
# echo "Installing dependencies (npm install)..."
# npm install
# 
# echo "Building Next.js application (npm run build)..."
# npm run build
# 
# echo "Starting Next.js server on port $PORT..."
# npm start

# -------------------------------------------------------------
# QUICK TEST: "Hello World" Server
# -------------------------------------------------------------
echo "Starting Hello World test server..."
cd /app
cat << 'EOF' > server.js
const http = require('http');
const port = process.env.PORT || 80;
const server = http.createServer((req, res) => {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.end('<h1>Hello World!</h1><p>Traffic successfully passed through the Edge Firewall (SPI) and reached the web server via DMZ.</p>');
});
server.listen(port, () => {
  console.log(`Test server running on port ${port}`);
});
EOF
node server.js
