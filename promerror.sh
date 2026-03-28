#!/bin/bash

echo "🔍 Starting Prometheus Validation..."
echo "---------------------------------------"

# 1. Check if Binary exists
if command -v prometheus >/dev/null 2>&1; then
    echo "✅ [Binary] Prometheus is installed at $(which prometheus)"
else
    echo "❌ [Binary] Prometheus NOT found in PATH"
fi

# 2. Check Configuration Syntax
if [ -f /etc/prometheus/prometheus.yml ]; then
    check_conf=$(promtool check config /etc/prometheus/prometheus.yml 2>&1)
    if [[ $check_conf == *"SUCCESS"* ]]; then
        echo "✅ [Config] /etc/prometheus/prometheus.yml is valid"
    else
        echo "❌ [Config] Syntax Error: $check_conf"
    fi
else
    echo "❌ [Config] Configuration file NOT found at /etc/prometheus/prometheus.yml"
fi

# 3. Check Service Status
service_status=$(systemctl is-active prometheus)
if [ "$service_status" == "active" ]; then
    echo "✅ [Service] Prometheus service is RUNNING"
else
    echo "❌ [Service] Prometheus service is $service_status (Not Running)"
fi

# 4. Check Network Port (9090)
if sudo ss -tulpn | grep -q ":9090"; then
    echo "✅ [Network] Port 9090 is listening"
else
    echo "❌ [Network] Nothing is listening on Port 9090"
fi

# 5. Check Live API Response
api_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy)
if [ "$api_response" == "200" ]; then
    echo "✅ [API] Web UI is responding (HTTP 200)"
else
    echo "❌ [API] No response from Web UI (Code: $api_response)"
fi

echo "---------------------------------------"
echo "Done."
