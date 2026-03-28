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

echo "✅ Architecture detected: $ARCH_TYPE"

echo "🔹 Cleaning old files (VERY IMPORTANT)..."
sudo systemctl stop prometheus node_exporter 2>/dev/null || true

sudo rm -f /usr/local/bin/prometheus
sudo rm -f /usr/local/bin/promtool
sudo rm -f /usr/local/bin/node_exporter

sudo rm -rf /etc/prometheus
sudo rm -rf /var/lib/prometheus

rm -rf /tmp/prometheus*
rm -rf /tmp/node_exporter*

echo "🔹 Updating system..."
sudo apt update -y
sudo apt install -y wget curl tar

echo "🔹 Creating users..."
sudo useradd --no-create-home --shell /bin/false prometheus 2>/dev/null || true
sudo useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true

# -----------------------------
# 🔹 Install Prometheus
# -----------------------------
echo "🔹 Installing Prometheus..."
cd /tmp

PROM_FILE="prometheus-${PROM_VERSION}.linux-${ARCH_TYPE}.tar.gz"

wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/${PROM_FILE}

tar -xvf $PROM_FILE
cd prometheus-${PROM_VERSION}.linux-${ARCH_TYPE}

sudo mkdir -p /etc/prometheus /var/lib/prometheus

sudo cp prometheus /usr/local/bin/
sudo cp promtool /usr/local/bin/

sudo cp prometheus.yml /etc/prometheus/
sudo cp -r consoles /etc/prometheus/
sudo cp -r console_libraries /etc/prometheus/

sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool
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

NODE_FILE="node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH_TYPE}.tar.gz"

wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${NODE_FILE}

tar -xvf $NODE_FILE
cd node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH_TYPE}

sudo cp node_exporter /usr/local/bin/
sudo chmod +x /usr/local/bin/node_exporter
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
# 🔹 Prometheus Config
# -----------------------------
echo "🔹 Setting Prometheus config..."
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

#  Install Grafana
sudo mkdir -p /etc/apt/keyrings
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt update && sudo apt install -y grafana



# -----------------------------
# 🔹 Start Services
# -----------------------------
echo "🔹 Starting services..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

sudo systemctl enable prometheus node_exporter
sudo systemctl start prometheus
sudo systemctl start node_exporter

echo "🔹 Final status..."
sudo systemctl status prometheus --no-pager
sudo systemctl status node_exporter --no-pager

echo ""
echo "🎉 SUCCESS!"
echo "👉 Prometheus: http://<VM-IP>:9090"
echo "👉 Node Exporter: http://<VM-IP>:9100/metrics"
