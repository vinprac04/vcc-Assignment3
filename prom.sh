#!/bin/bash

set -e

echo "🔹 Updating system..."
sudo apt update -y
sudo apt install -y wget curl tar

echo "🔹 Creating Prometheus user..."
sudo useradd --no-create-home --shell /bin/false prometheus || true

echo "🔹 Downloading latest Prometheus..."
cd /tmp
PROM_VERSION="2.52.0"

wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz

echo "🔹 Extracting files..."
tar -xvf prometheus-${PROM_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROM_VERSION}.linux-amd64

echo "🔹 Creating directories..."
sudo mkdir -p /etc/prometheus
sudo mkdir -p /var/lib/prometheus

echo "🔹 Moving binaries..."
sudo mv prometheus /usr/local/bin/
sudo mv promtool /usr/local/bin/

echo "🔹 Moving config files..."
sudo mv prometheus.yml /etc/prometheus/
sudo mv consoles /etc/prometheus/
sudo mv console_libraries /etc/prometheus/

echo "🔹 Setting permissions..."
sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool
sudo chown -R prometheus:prometheus /var/lib/prometheus

echo "🔹 Creating systemd service..."
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

echo "🔹 Starting Prometheus..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus

echo "🔹 Checking status..."
sudo systemctl status prometheus --no-pager

echo "✅ Prometheus installed successfully!"
echo "👉 Access UI: http://<YOUR_VM_IP>:9090"
