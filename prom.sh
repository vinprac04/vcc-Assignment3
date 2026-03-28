#!/bin/bash

set -e

PROM_VERSION="2.52.0"
NODE_EXPORTER_VERSION="1.8.1"

echo "🔹 Detecting architecture..."
ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
  ARCH_TYPE="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
  ARCH_TYPE="arm64"
else
  echo "❌ Unsupported architecture: $ARCH"
  exit 1
fi

echo "✅ Architecture: $ARCH_TYPE"

echo "🔹 Updating system..."
sudo apt update -y
sudo apt install -y wget curl tar

# -----------------------------
# 🔹 Create Users
# -----------------------------
sudo useradd --no-create-home --shell /bin/false prometheus 2>/dev/null || true
sudo useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true

# -----------------------------
# 🔹 Install Prometheus
# -----------------------------
echo "🔹 Installing Prometheus..."
cd /tmp

PROM_FILE="prometheus-${PROM_VERSION}.linux-${ARCH_TYPE}.tar.gz"

if [ ! -f "$PROM_FILE" ]; then
  wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/${PROM_FILE}
fi

rm -rf prometheus-${PROM_VERSION}.linux-${ARCH_TYPE}
tar -xvf $PROM_FILE
cd prometheus-${PROM_VERSION}.linux-${ARCH_TYPE}

sudo mkdir -p /etc/prometheus /var/lib/prometheus

sudo cp prometheus /usr/local/bin/
sudo cp promtool /usr/local/bin/

sudo cp prometheus.yml /etc/prometheus/

sudo rm -rf /etc/prometheus/consoles /etc/prometheus/console_libraries
sudo cp -r consoles /etc/prometheus/
sudo cp -r console_libraries /etc/prometheus/

sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool
sudo chown -R prometheus:prometheus /var/lib/prometheus

# -----------------------------
# 🔹 Prometheus Service
# -----------------------------
sudo bash -c 'cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --web.listen-address=:9090

[Install]
WantedBy=multi-user.target
EOF'

# -----------------------------
# 🔹 Install Node Exporter
# -----------------------------
echo "🔹 Installing Node Exporter..."
cd /tmp

NODE_FILE="node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH_TYPE}.tar.gz"

if [ ! -f "$NODE_FILE" ]; then
  wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${NODE_FILE}
fi

rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH_TYPE}
tar -xvf $NODE_FILE
cd node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH_TYPE}

sudo cp node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
sudo chmod +x /usr/local/bin/node_exporter

# -----------------------------
# 🔹 Node Exporter Service
# -----------------------------
sudo bash -c 'cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF'

# -----------------------------
# 🔹 Prometheus Config
# -----------------------------
sudo bash -c 'cat > /etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node_exporter"
    static_configs:
      - targets: ["localhost:9100"]
EOF'

# -----------------------------
# 🔹 Start Services
# -----------------------------
echo "🔹 Starting services..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

sudo systemctl enable prometheus node_exporter
sudo systemctl restart prometheus
sudo systemctl restart node_exporter

# -----------------------------
# 🔹 Status
# -----------------------------
echo "🔹 Checking status..."
sudo systemctl status prometheus --no-pager
sudo systemctl status node_exporter --no-pager

echo ""
echo "✅ Setup Complete!"
echo "👉 Prometheus: http://<VM-IP>:9090"
echo "👉 Node Exporter: http://<VM-IP>:9100/metrics"
