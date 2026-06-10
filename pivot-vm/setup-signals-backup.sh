#!/bin/bash
set -e

# Setup signals backup: scheduled copy of pivot_signals.json and pivotextra_signals.json
# Copies files to /opt/runner/data/dump/oldsignals/ with a YYYY-MM-DD_ date prefix
# Schedule: Sunday to Friday at 21:20 UTC (not Saturday)
# Implemented as a systemd one-shot service + timer

# 

PROJECT_ID="pivot-vm"
ZONE="europe-west1-b"
VM="pivot-trading-vm"
SOURCE_DIR="/opt/runner/data/dump"
DEST_DIR="/opt/runner/data/dump/oldsignals"
SCRIPT_PATH="/opt/runner/backup-signals.sh"
SERVICE_NAME="signals-backup"

echo "🔧 Setting up signals backup on $VM"
echo "====================================="
echo ""
echo "Configuration:"
echo "  - Source directory: $SOURCE_DIR"
echo "  - Destination:      $DEST_DIR"
echo "  - Backup script:    $SCRIPT_PATH"
echo "  - Schedule:         Sun–Fri at 21:20 UTC"
echo ""

# Create destination directory
echo "📁 Creating destination directory..."
gcloud compute ssh $VM --zone=$ZONE --command="
sudo mkdir -p $DEST_DIR
sudo chown -R pivot:pivot /opt/runner/data/dump
echo '✅ Created $DEST_DIR with pivot:pivot ownership'
"

# Write the backup shell script
echo ""
echo "📝 Writing backup script $SCRIPT_PATH..."
gcloud compute ssh $VM --zone=$ZONE --command="
sudo tee $SCRIPT_PATH > /dev/null << 'EOF'
#!/bin/bash
# Backup pivot signal JSON files with a UTC date prefix
# Skips missing source files and logs a warning to stderr (journal)

SOURCE_DIR=\"/opt/runner/data\"
DEST_DIR=\"/opt/runner/data/dump/oldsignals\"
DATE=\$(date -u +%Y-%m-%d)
FILES=(pivot_signals.json pivotextra_signals.json)

for FILE in \"\${FILES[@]}\"; do
    SRC=\"\$SOURCE_DIR/\$FILE\"
    DST=\"\$DEST_DIR/\${DATE}_\${FILE}\"
    if [ -f \"\$SRC\" ]; then
        cp \"\$SRC\" \"\$DST\"
        echo \"Copied \$SRC -> \$DST\"
    else
        echo \"WARNING: source file not found, skipping: \$SRC\" >&2
    fi
done
EOF

sudo chmod 750 $SCRIPT_PATH
sudo chown pivot:pivot $SCRIPT_PATH
echo '✅ Backup script written and made executable'
"

# Write the systemd service unit
echo ""
echo "📝 Creating systemd service $SERVICE_NAME.service..."
gcloud compute ssh $VM --zone=$ZONE --command="
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << 'EOF'
[Unit]
Description=Backup pivot signal JSON files with date prefix
Documentation=https://github.com/bjoelf/WM-management

[Service]
Type=oneshot
User=pivot
Group=pivot
Environment=TZ=UTC
ExecStart=$SCRIPT_PATH

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME
EOF

echo '✅ Service unit created'
"

# Write the systemd timer unit
echo ""
echo "📝 Creating systemd timer $SERVICE_NAME.timer..."
gcloud compute ssh $VM --zone=$ZONE --command="
sudo tee /etc/systemd/system/$SERVICE_NAME.timer > /dev/null << 'EOF'
[Unit]
Description=Run signals backup Sunday to Friday at 21:20 UTC
Documentation=https://github.com/bjoelf/WM-management

[Timer]
OnCalendar=Sun,Mon,Tue,Wed,Thu,Fri *-*-* 21:20:00
Persistent=true
Unit=$SERVICE_NAME.service

[Install]
WantedBy=timers.target
EOF

echo '✅ Timer unit created'
"

# Reload daemon and enable + start the timer
echo ""
echo "🔄 Reloading systemd daemon..."
gcloud compute ssh $VM --zone=$ZONE --command="
sudo systemctl daemon-reload
echo '✅ Daemon reloaded'
"

echo ""
echo "🔌 Enabling and starting $SERVICE_NAME.timer..."
gcloud compute ssh $VM --zone=$ZONE --command="
sudo systemctl enable --now $SERVICE_NAME.timer
echo '✅ Timer enabled and started'
"

# Show next trigger time for confirmation
echo ""
echo "📅 Next scheduled run:"
gcloud compute ssh $VM --zone=$ZONE --command="
systemctl list-timers $SERVICE_NAME.timer --no-pager
"

echo ""
echo "✅ Setup complete!"
echo ""
echo "Useful commands (run via gcloud compute ssh $VM --zone=$ZONE):"
echo "  Check timer:        systemctl list-timers $SERVICE_NAME.timer"
echo "  Manual test run:    sudo systemctl start $SERVICE_NAME.service"
echo "  View logs:          journalctl -u $SERVICE_NAME -n 30"
echo "  List copied files:  ls -la $DEST_DIR"
