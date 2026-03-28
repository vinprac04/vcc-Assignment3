#!/bin/bash

set -e

PROM_VERSION="2.52.0"
NODE_EXPORTER_VERSION="1.8.1"

echo "🔹 Updating system..."
sudo apt update -y
sudo apt install -y wget curl tar

# -----------------------------
# 🔹 Create Users (safe)
# -----------------------------
echo "🔹 Creating users..."
sudo useradd --no-create-home --shell /bin/false prometheus 2>/dev/null || true
sudo useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true

# -----------------------------
# 🔹 Install Prometheus
# -----------------------------
echo "🔹 Installing Prometheus..."
cd /tmp

if [ ! -f prometheus-${PROM_VERSION}.linux-amd64.tar.gz ]; then
  wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz
fi

rm -rf prometheus-${PROM_VERSION}.linux-amd64
tar -xvf prometheus-${PROM_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROM_VERSION}.linux-amd64

# Directories
sudo mkdir -p /etc/prometheus
sudo mkdir -p /var/lib/prometheus

# Binaries
sudo cp prometheus /usr/local/bin/
sudo cp promtool /usr/local/bin/

# Config (safe copy)
sudo cp prometheus.yml /etc/prometheus/

# Clean old consoles safely
sudo rm -rf /etc/prometheus/consoles
sudo rm -rf /etc/prometheus/console_libraries

sudo cp -r consoles /etc/prometheus/
sudo cp -r console_libraries /etc/prometheus/

# Permissions
sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool
sudo chown -R prometheus:prometheus /var/lib/prometheus

# -----------------------------
# 🔹 Prometheus Service
# -----------------------------
echo "🔹 Configuring Prometheus service..."
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

if [ ! -f node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz ]; then
  wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
fi

rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64
tar -xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
cd node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64

sudo cp node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

# -----------------------------
# 🔹 Node Exporter Service
# -----------------------------
echo "🔹 Configuring Node Exporter service..."
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
# 🔹 Update Prometheus Config
# -----------------------------
echo "🔹 Updating Prometheus config..."
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
# 🔹 Status Check
# -----------------------------
echo "🔹 Service Status:"
sudo systemctl status prometheus --no-pager
sudo systemctl status node_exporter --no-pager

echo ""
echo "✅ Setup Complete!"
echo "👉 Prometheus UI: http://<VM-IP>:9090"
echo "👉 Node Exporter: http://<VM-IP>:9100/metrics"
