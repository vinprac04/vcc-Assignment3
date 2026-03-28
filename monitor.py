import psutil
import os
import time

# ==========================================================
# CONFIGURATION - Set these to match your GCP Console
# ==========================================================
PROJECT_ID = "assignment-3-local-to-gcp"  # Double check this ID!
TEMPLATE_NAME = "gcp-worker-template"    # The template you created
INSTANCE_NAME = "scaled-worker-01"        # Name for the new VM
ZONE = "us-central1-a"

UP_THRESHOLD = 75.0    # CPU % to Scale Up
DOWN_THRESHOLD = 25.0  # CPU % to Scale Down
CHECK_INTERVAL = 5     # Seconds between checks
# ==========================================================

active = False

def scale_up():
    print(f"\n[!] ALERT: CPU at {psutil.cpu_percent()}%")
    print(f"    Action: Provisioning {INSTANCE_NAME} from template...")
    
    # Command to create VM from your template
    cmd = (f"gcloud compute instances create {INSTANCE_NAME} "
           f"--source-instance-template={TEMPLATE_NAME} "
           f"--zone={ZONE} --project={PROJECT_ID} --quiet")
    
    exit_code = os.system(cmd)
    return exit_code == 0

def scale_down():
    print(f"\n[i] INFO: Load has normalized.")
    print(f"    Action: Deleting {INSTANCE_NAME} to save costs...")
    
    # Command to delete the VM automatically
    cmd = (f"gcloud compute instances delete {INSTANCE_NAME} "
           f"--zone={ZONE} --project={PROJECT_ID} --quiet")
    
    exit_code = os.system(cmd)
    return exit_code == 0

print("--- Hybrid Cloud Monitor Started ---")
print(f"Target Project: {PROJECT_ID}")

try:
    while True:
        # Get current CPU usage over 1 second
        cpu = psutil.cpu_percent(interval=1)
        status = "CLOUD ACTIVE" if active else "LOCAL ONLY"
        print(f"Current Load: {cpu}% | Mode: {status}")

        # LOGIC: Scale Up
        if cpu > UP_THRESHOLD and not active:
            if scale_up():
                active = True
                print("[SUCCESS] Cloud resources online.")
            else:
                print("[ERROR] Could not scale up. Check API/Template.")

        # LOGIC: Scale Down
        elif cpu < DOWN_THRESHOLD and active:
            if scale_down():
                active = False
                print("[SUCCESS] Cloud resources decommissioned.")
            else:
                print("[ERROR] Deletion failed. Check GCP Console.")

        time.sleep(CHECK_INTERVAL)

except KeyboardInterrupt:
    print("\n[!] Monitoring stopped by user. Cleaning up...")
