#!/bin/bash
set -e

# Check unattended-upgrades log

PROJECT_ID="pivot-vm"
ZONE="europe-west1-b"
VM="pivot-trading-vm"

# Check unattended-upgrades log
gcloud compute ssh $VM --zone=$ZONE --project=$PROJECT_ID --command="
  echo '=== apt/unattended-upgrades log (today) ==='
  grep \"\$(date +%Y-%m-%d)\" /var/log/apt/history.log 2>/dev/null || echo 'No apt history for today'

  echo ''
  echo '=== unattended-upgrades log ==='
  sudo cat /var/log/unattended-upgrades/unattended-upgrades.log 2>/dev/null | tail -30 || echo 'No unattended-upgrades log found'

  echo ''
  echo '=== dpkg log (last 30 lines) ==='
  grep \"\$(date +%Y-%m-%d)\" /var/log/dpkg.log 2>/dev/null | tail -30 || echo 'No dpkg activity today'

  echo ''
  echo '=== Last reboot ==='
  last reboot | head -5

  echo ''
  echo '=== Uptime ==='
  uptime
"

gcloud compute os-config patch-jobs list --project=pivot-vm
