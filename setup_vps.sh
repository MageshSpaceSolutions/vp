#!/bin/bash
# One-click shell script to configure a new Linux VPS for the Vendor Portal with CloudPanel
# Run with: sudo bash setup_vps.sh

echo "======================================================="
echo " Chandra Group Vendor Portal VPS Auto-Configuration"
echo "======================================================="

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run this script as root (using sudo)."
  exit 1
fi

# Detect Package Manager
if [ -x "$(command -v apt-get)" ]; then
    PM="apt"
elif [ -x "$(command -v dnf)" ]; then
    PM="dnf"
else
    echo "ERROR: Unsupported package manager. This script supports Debian/Ubuntu (apt) and AlmaLinux/Rocky Linux (dnf)."
    exit 1
fi

echo "Step 1: Installing system dependencies (Python3, PIP, unzip)..."
if [ "$PM" = "apt" ]; then
    apt-get update -y
    apt-get install -y python3 python3-pip python3-venv unzip curl
elif [ "$PM" = "dnf" ]; then
    dnf clean all
    dnf makecache
    dnf install -y python3 python3-pip unzip curl
fi

# Define site path (CloudPanel default structure)
SITE_DIR="/home/cloudpanel/htdocs/portal.chandragroup.co"
BACKEND_DIR="$SITE_DIR/backend"

if [ ! -d "$SITE_DIR" ]; then
    echo "WARNING: Site folder '$SITE_DIR' not found."
    echo "Please make sure you have added the site in CloudPanel first."
    read -p "Enter path to site directory manually [/home/cloudpanel/htdocs/portal.chandragroup.co]: " USER_PATH
    SITE_DIR=${USER_PATH:-$SITE_DIR}
    BACKEND_DIR="$SITE_DIR/backend"
fi

echo "Step 2: Installing Python packages..."
if [ -f "$SITE_DIR/requirements.txt" ]; then
    pip3 install -r "$SITE_DIR/requirements.txt"
else
    echo "No requirements.txt found in $SITE_DIR. Skipping package installation."
fi

echo "Step 3: Creating Systemd Service for Python API..."
cat > /etc/systemd/system/vendor-portal.service <<EOF
[Unit]
Description=Chandra Group Vendor Portal Backend
After=network.target

[Service]
User=root
WorkingDirectory=$BACKEND_DIR
ExecStart=/usr/bin/python3 $BACKEND_DIR/CG_Server.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Step 4: Starting and Enabling Backend service..."
systemctl daemon-reload
systemctl enable vendor-portal
systemctl restart vendor-portal

if systemctl is-active --quiet vendor-portal; then
    echo "SUCCESS: Python backend service is running!"
else
    echo "ERROR: Backend failed to start. Check status via: journalctl -u vendor-portal -n 50"
fi

echo "======================================================="
echo " VPS configuration completed successfully!"
echo "-------------------------------------------------------"
echo "Next Steps:"
echo "1. Log into your CloudPanel."
echo "2. Edit the Vhost config for the site and add the proxy & security rules:"
echo "   (See CloudPanel_Deployment_Guide.md in the cp folder for the Nginx snippet)"
echo "3. Run 'journalctl -u vendor-portal -f' to monitor live logs."
echo "======================================================="
