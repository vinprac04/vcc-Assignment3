import psutil
import os
import time
import subprocess

# ==========================================
# CONFIGURATION
# ==========================================
UP_THRESHOLD = 75.0          # Trigger Cloud VM at 75%
DOWN_THRESHOLD = 25.0        # Delete Cloud VM at 25%
CHECK_INTERVAL = 5           
PROJECT_ID = "YOUR_PROJECT_ID_HERE"
ZONE = "us-central1-a"
INSTANCE_NAME = "gcp-autoscale-worker"

cloud_is_active = False # Track if we have a VM running

def scale_up():
    global cloud_is_active
    print(f"\n[!] HIGH LOAD: Creating Cloud VM...")
    cmd = ["gcloud", "compute", "instances", "create", INSTANCE_NAME, 
           "--project", PROJECT_ID, "--zone", ZONE, "--machine-type", "e2-micro"]
    try:
        subprocess.run(cmd, check=True)
        cloud_is_active = True
        print("[SUCCESS] Cloud VM is UP.")
    except:
        print("[ERROR] Failed to scale up.")

def scale_down():
    global cloud_is_active
    print(f"\n[i] LOW LOAD: Deleting Cloud VM to save costs...")
    # --quiet prevents gcloud from asking "Are you sure? (Y/n)"
    cmd = ["gcloud", "compute", "instances", "delete", INSTANCE_NAME, 
           "--project", PROJECT_ID, "--zone", ZONE, "--quiet"]
    try:
        subprocess.run(cmd, check=True)
        cloud_is_active = False
        print("[SUCCESS] Cloud VM is DOWN.")
    except:
        print("[ERROR] Failed to scale down.")

print("--- Hybrid Monitor Started ---")

try:
    while True:
        cpu = psutil.cpu_percent(interval=1)
        print(f"Local CPU: {cpu}% | Cloud Active: {cloud_is_active}")

        # Logic: If high load and no cloud VM, Scale Up
        if cpu > UP_THRESHOLD and not cloud_is_active:
            scale_up()
        
        # Logic: If low load and cloud VM is running, Scale Down
        elif cpu < DOWN_THRESHOLD and cloud_is_active:
            scale_down()

        time.sleep(CHECK_INTERVAL)
except KeyboardInterrupt:
    print("\nMonitor Stopped.")
