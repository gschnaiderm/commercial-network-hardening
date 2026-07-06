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

# Set up Node app
cd /app
if [ ! -f "package.json" ]; then
  npm init -y
fi
npm install pg

echo "Starting Secure DB Access Counter server..."
cat << 'EOF' > server.js
const http = require('http');
const { Client } = require('pg');

const port = process.env.PORT || 80;

const client = new Client({
  user: 'web_client',
  host: '10.0.20.100',
  database: 'webapp_db',
  password: 'web_client_secret',
  port: 5432,
});

client.connect().then(() => {
    console.log("Connected to PostgreSQL successfully as web_client.");
}).catch(err => {
    console.error("Database connection error:", err);
});

const server = http.createServer(async (req, res) => {
  if (req.url !== '/') {
    res.statusCode = 404;
    return res.end('Not found');
  }

  let count = 0;
  try {
    // Safely increment and fetch the new count
    const result = await client.query(`
      UPDATE page_visits
      SET visit_count = visit_count + 1
      WHERE id = 1
      RETURNING visit_count;
    `);
    
    // Fallback if the row didn't exist for some reason
    if (result.rows.length > 0) {
        count = result.rows[0].visit_count;
    } else {
        count = "Error: Row missing";
    }
  } catch (error) {
    console.error(error);
    res.statusCode = 500;
    res.setHeader('Content-Type', 'text/html');
    return res.end('<h1>500 Internal Database Error</h1><p>Check the console logs for details.</p>');
  }

  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.end(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Secure Access Tracker</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #6C5CE7;
            --secondary: #a29bfe;
            --bg-grad-1: #1e1e2e;
            --bg-grad-2: #2d2b55;
            --text: #f8f8f2;
        }
        body {
            margin: 0;
            padding: 0;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            font-family: 'Inter', sans-serif;
            background: linear-gradient(135deg, var(--bg-grad-1), var(--bg-grad-2));
            color: var(--text);
            overflow: hidden;
        }
        .container {
            background: rgba(255, 255, 255, 0.05);
            backdrop-filter: blur(15px);
            border-radius: 20px;
            padding: 3rem 4rem;
            border: 1px solid rgba(255, 255, 255, 0.1);
            box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3);
            text-align: center;
            animation: fadeIn 1s ease-out;
            max-width: 500px;
        }
        h1 {
            margin: 0 0 1rem 0;
            font-size: 2.5rem;
            font-weight: 800;
            background: linear-gradient(to right, var(--secondary), #74b9ff);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        p {
            font-size: 1.1rem;
            color: #b2bec3;
            line-height: 1.6;
        }
        .counter {
            font-size: 5rem;
            font-weight: 800;
            margin: 2rem 0;
            color: var(--text);
            text-shadow: 0 0 20px rgba(108, 92, 231, 0.5);
            animation: popIn 0.5s cubic-bezier(0.175, 0.885, 0.32, 1.275) forwards;
        }
        .badge {
            display: inline-block;
            background: rgba(0, 184, 148, 0.2);
            color: #00b894;
            padding: 0.5rem 1rem;
            border-radius: 50px;
            font-size: 0.8rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-top: 1rem;
            border: 1px solid rgba(0, 184, 148, 0.4);
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
        }
        @keyframes popIn {
            from { opacity: 0; transform: scale(0.5); }
            to { opacity: 1; transform: scale(1); }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome Back</h1>
        <p>This secure application tracks visitor statistics using a least-privilege PostgreSQL connection.</p>
        <div class="counter">${count}</div>
        <p>Total Page Visits</p>
        <div class="badge">Connection Secure</div>
    </div>
</body>
</html>
  `);
});

server.listen(port, () => {
  console.log(`Web application running securely on port ${port}`);
});
EOF
# Configure and start rsyslog
cat << 'RSYSLOG' > /etc/rsyslog.conf
$ModLoad imuxsock
*.* @10.0.30.100:5140
RSYSLOG
rsyslogd

# Background sys-stats loop
(
while true; do
  IDLE=$(top -bn1 | grep '^CPU:' | awk '{print $8}' | tr -d '%')
  if [ -z "$IDLE" ]; then IDLE=100; fi
  CPU_USAGE=$((100 - IDLE))
  RAM_FREE=$(free -m | awk '/Mem:/ {print $4}')
  logger -p local0.info -t sys-stats "CPU_USAGE:${CPU_USAGE}% RAM_FREE:${RAM_FREE}MB"
  sleep 60
done
) &

# Run server and pipe logs
node server.js 2>&1 | logger -p local0.info -t web-app
