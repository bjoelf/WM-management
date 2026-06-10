#!/bin/bash
set -e

# Setup newrunner systemd service on VM
# This creates the systemd service file for pivot-web2 as "newrunner"
# Service will run on port 8081 and serve newrunner.pipsnticks.se

PROJECT_ID="pivot-vm"
ZONE="europe-west1-b"
VM="pivot-trading-vm"
DEPLOY_DIR="/opt/newrunner"
SERVICE_NAME="newrunner"
BINARY_NAME="newrunner"
PORT=8081

echo "🔧 Setting up newrunner systemd service on $VM"
echo "==============================================="
echo ""
echo "Configuration:"
echo "  - Service name: $SERVICE_NAME"
echo "  - Deploy directory: $DEPLOY_DIR"
echo "  - Binary name: $BINARY_NAME"
echo "  - Port: $PORT"
echo "  - Subdomain: newrunner.pipsnticks.se"
echo ""

# Create deploy directory on VM
echo "📁 Creating deployment directory..."
gcloud compute ssh $VM --zone=$ZONE --command="
sudo mkdir -p $DEPLOY_DIR
sudo mkdir -p $DEPLOY_DIR/data
sudo chown -R bjorn:bjorn $DEPLOY_DIR
echo '✅ Created $DEPLOY_DIR with proper ownership'
"

# Create systemd service file
echo ""
echo "📝 Creating systemd service file..."
gcloud compute ssh $VM --zone=$ZONE --command="
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << 'EOF'
[Unit]
Description=NewRunner Trading Platform (pivot-web2)
Wants=network-online.target
After=network-online.target
AssertFileIsExecutable=$DEPLOY_DIR/$BINARY_NAME

[Service]
Type=simple
User=pivot
Group=pivot
WorkingDirectory=$DEPLOY_DIR

# Create data directories before starting
ExecStartPre=/bin/mkdir -p $DEPLOY_DIR/data
ExecStartPre=/bin/mkdir -p $DEPLOY_DIR/data/spreads
ExecStartPre=/bin/chown -R pivot:pivot $DEPLOY_DIR/data

ExecStart=$DEPLOY_DIR/$BINARY_NAME
Restart=always
RestartSec=10
EnvironmentFile=$DEPLOY_DIR/.env

# Restart limits (prevent infinite restart loops)
StartLimitBurst=5

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DEPLOY_DIR/data
PrivateTmp=true

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
EOF

echo '✅ Systemd service file created'
"

# Reload systemd daemon
echo ""
echo "🔄 Reloading systemd daemon..."
gcloud compute ssh $VM --zone=$ZONE --command="
sudo systemctl daemon-reload
echo '✅ Systemd daemon reloaded'
"

# Enable service (but don't start yet)
echo ""
echo "🔌 Enabling $SERVICE_NAME service..."
gcloud compute ssh $VM --zone=$ZONE --command="
sudo systemctl enable $SERVICE_NAME
echo '✅ Service enabled (will start on boot)'
"

echo ""
echo "✅ newrunner service setup complete!"
echo ""
echo "Next steps:"
echo "  1. Deploy application code: ./scripts/deploy-service.sh"
echo "  2. Deploy .env configuration: ./scripts/deploy-env-only.sh"
echo "  3. Start the service: gcloud compute ssh $VM --zone=$ZONE --command='sudo systemctl start $SERVICE_NAME'"
echo "  4. Check service status: ./scripts/check-services-health.sh"
echo "  5. Configure nginx for newrunner.pipsnticks.se subdomain"
echo ""
echo "Service commands:"
echo "  - Start:   sudo systemctl start $SERVICE_NAME"
echo "  - Stop:    sudo systemctl stop $SERVICE_NAME"
echo "  - Restart: sudo systemctl restart $SERVICE_NAME"
echo "  - Status:  sudo systemctl status $SERVICE_NAME"
echo "  - Logs:    sudo journalctl -u $SERVICE_NAME -f"
