#!/bin/bash
set -e

# Check Both Services Status
# Quick diagnostic script to verify runner and stagefx health

PROJECT_ID="pivot-vm"
ZONE="europe-west1-b"
VM="pivot-trading-vm"

echo "🔍 Checking service status on $VM..."
echo ""

gcloud compute ssh $VM --zone=$ZONE --project=$PROJECT_ID --command="
echo '═══════════════════════════════════════════'
echo 'RUNNER SERVICE (legacy pivot-web)'
echo '═══════════════════════════════════════════'
sudo systemctl status runner --no-pager | head -15

echo ''
echo '📜 Last 10 runner log messages:'
sudo journalctl -u runner -n 10 --no-pager

echo ''
echo '═══════════════════════════════════════════'
echo 'NEWRUNNER SERVICE (pivot-web2)'
echo '═══════════════════════════════════════════'
sudo systemctl status newrunner --no-pager | head -15

echo ''
echo '📜 Last 10 newrunner log messages:'
sudo journalctl -u newrunner -n 10 --no-pager

echo ''
echo '═══════════════════════════════════════════'
echo 'SYSTEM RESOURCES'
echo '═══════════════════════════════════════════'
echo 'Memory usage:'
free -h

echo ''
echo 'Disk usage:'
df -h | grep -E '(Filesystem|/opt|/$)'

echo ''
echo 'Process count by service:'
ps aux | grep -E '(runner|newrunner)' | grep -v grep | wc -l | xargs echo 'Active processes:'

echo ''
echo '═══════════════════════════════════════════'
echo 'LISTENING PORTS'
echo '═══════════════════════════════════════════'
sudo netstat -tlnp | grep -E '(8080|8081)' || echo 'No services listening on 8080/8081'
"

echo ""
echo "✅ Status check complete"
