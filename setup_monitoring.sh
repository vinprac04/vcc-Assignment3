#!/bin/bash

# --- CONFIGURATION ---
PROM_VERSION="2.51.0"
NODE_VERSION="1.8.1"
# ---------------------

echo "🚀 Starting Prometheus & Grafana Automation..."

# 1. Install Dependencies
sudo apt update && sudo apt install -y wget curl gpg

# 2. Setup Prometheus User & Directories
sudo useradd --no-create-home --shell /bin/false prometheus
sudo mkdir -p /etc/prometheus /var/lib/prometheus

# 3. Download & Install Prometheus
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz
tar xvf prometheus-${PROM_VERSION}.linux-amd64.tar.gz
sudo cp prometheus-${PROM_VERSION}.linux-amd64/prometheus /usr/local/bin/
sudo cp prometheus-${PROM_VERSION}.linux-amd64/promtool /usr/local/bin/
sudo cp -r prometheus-${PROM_VERSION}.linux-amd64/consoles /etc/prometheus/
sudo cp -r prometheus-${PROM_VERSION}.linux-amd64/console_libraries /etc/prometheus/
sudo cp prometheus-${PROM_VERSION}.linux-amd64/prometheus.yml /etc/prometheus/
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# 4. Install Node Exporter (The Sensor)
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/node_exporter-${NODE_VERSION}.linux-amd64.tar.gz
tar xvf node_exporter-${NODE_VERSION}.linux-amd64.tar.gz
sudo cp node_exporter-${NODE_VERSION}.linux-amd64/node_exporter /usr/local/bin/

# 5. Setup System Services (To run on boot)
cat <<EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus/

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# 6. Install Grafana
sudo mkdir -p /etc/apt/keyrings
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt update && sudo apt install -y grafana

# 7. Start everything
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus node_exporter grafana-server

echo "✅ Setup Complete!"
echo "Prometheus: http://localhost:9090"
echo "Grafana: http://localhost:3000 (admin/admin)"
