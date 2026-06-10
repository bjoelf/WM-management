#!/bin/bash
set -e

# Check SSL certificate status on VM
# Quick script to view all SSL certificates and their expiration dates

PROJECT_ID="pivot-vm"
ZONE="europe-west1-b"
VM="pivot-trading-vm"

echo "🔐 SSL Certificate Status Check"
echo "================================="
echo ""

echo "📜 Checking certificates on $VM..."
echo ""

gcloud compute ssh $VM --zone=$ZONE --command="sudo certbot certificates"

echo ""
echo "🌐 Testing HTTPS endpoints..."
echo ""

# Test main domains
for domain in "pipsnticks.se" "runner.pipsnticks.se" "www.pipsnticks.se" "newrunner.pipsnticks.se"; do
    echo -n "  $domain: "
    if curl -s -I -m 5 "https://$domain" > /dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
    fi
done

echo ""
echo "✅ SSL status check complete!"
echo ""
echo "To renew certificates manually:"
echo "  gcloud compute ssh $VM --zone=$ZONE --command='sudo certbot renew --non-interactive'"
echo ""
echo "To check nginx logs:"
echo "  gcloud compute ssh $VM --zone=$ZONE --command='sudo tail -f /var/log/nginx/error.log'"
