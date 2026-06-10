#!/bin/bash
set -e

# Configure nginx for newrunner.pipsnticks.se subdomain
# This script sets up nginx to proxy requests to the newrunner service on port 8081

PROJECT_ID="pivot-vm"
ZONE="europe-west1-b"
VM="pivot-trading-vm"
SUBDOMAIN="newrunner.pipsnticks.se"
PORT=8081

echo "🌐 Configuring nginx for $SUBDOMAIN"
echo "====================================="
echo ""

# Create nginx configuration file (HTTP only, SSL will be added by certbot)
echo "📝 Creating nginx configuration (HTTP only for now)..."
gcloud compute ssh $VM --zone=$ZONE --command="
sudo tee /etc/nginx/sites-available/newrunner << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name newrunner.pipsnticks.se;

    # Logging
    access_log /var/log/nginx/newrunner.access.log;
    error_log /var/log/nginx/newrunner.error.log;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection \"1; mode=block\";

    # Proxy to newrunner service on port 8081
    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        
        # Proxy headers
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \\\$scheme;
        
        # WebSocket support
        proxy_set_header Upgrade \\\$http_upgrade;
        proxy_set_header Connection \"upgrade\";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

echo '✅ Nginx configuration file created (HTTP only)'
"

# Enable the site
echo ""
echo "🔗 Enabling nginx site..."
gcloud compute ssh $VM --zone=$ZONE --command="
sudo ln -sf /etc/nginx/sites-available/newrunner /etc/nginx/sites-enabled/newrunner
echo '✅ Site enabled (symlink created)'
"

# Test nginx configuration
echo ""
echo "🧪 Testing nginx configuration..."
gcloud compute ssh $VM --zone=$ZONE --command="
sudo nginx -t
"

echo ""
echo "🔄 Reloading nginx to apply changes..."
gcloud compute ssh $VM --zone=$ZONE --command="sudo systemctl reload nginx"

echo ""
echo "✅ Nginx configuration created and loaded!"
echo ""
echo "⚠️  IMPORTANT NEXT STEPS:"
echo ""
echo "1. Configure DNS for newrunner.pipsnticks.se:"
echo "   - Add A record: newrunner.pipsnticks.se → 34.79.13.81"
echo "   - Wait for DNS propagation (check: dig newrunner.pipsnticks.se)"
echo ""
echo "2. Test HTTP access (should work immediately if DNS is ready):"
echo "   curl -I http://newrunner.pipsnticks.se"
echo ""
echo "3. Obtain SSL certificate with certbot (after DNS is ready):"
echo "   gcloud compute ssh $VM --zone=$ZONE --command='sudo certbot --nginx -d newrunner.pipsnticks.se'"
echo ""
echo "   Note: Certbot will automatically update the nginx config to add SSL"
echo ""
echo "4. After certbot completes, test HTTPS:"
echo "   curl -I https://newrunner.pipsnticks.se"
echo ""
echo "Current nginx commands:"
echo "  - Test config: sudo nginx -t"
echo "  - Reload:      sudo systemctl reload nginx"
echo "  - Restart:     sudo systemctl restart nginx"
echo "  - Status:      sudo systemctl status nginx"
echo "  - View logs:   sudo tail -f /var/log/nginx/newrunner.error.log"
