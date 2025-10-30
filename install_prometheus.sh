#!/bin/bash

set -e

# === Settings ===
TMP_DIR="/tmp/prometheus_install"
INSTALL_DIR="/usr/local/bin"
DATA_DIR="/var/lib/prometheus"
CONFIG_DIR="/etc/prometheus"
PROM_USER="prometheus"
PROM_GROUP="prometheus"
SERVICE_FILE="/etc/systemd/system/prometheus.service"

# === Detect architecture ===
echo "Detecting system architecture..."
ARCH=$(uname -m)

case "$ARCH" in
    x86_64)
        ARCH_TYPE="amd64"
        ;;
    aarch64 | arm64)
        ARCH_TYPE="arm64"
        ;;
    armv7l | armv6l)
        ARCH_TYPE="armv7"
        ;;
    *)
        echo -e "\e[31m❌ Unsupported architecture: $ARCH\e[0m"
        exit 1
        ;;
esac

echo "Detected architecture: $ARCH_TYPE"

# === Determine the latest version ===
echo "Fetching the latest Prometheus version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep tag_name | cut -d '"' -f 4)

if [ -z "$LATEST_VERSION" ]; then
    echo "\e[31m❌ Failed to determine the latest version!\e[0m"
    exit 1
fi

echo "Latest version: $LATEST_VERSION"

# === Create system group ===
if ! getent group "$PROM_GROUP" > /dev/null; then
    echo "Creating system group $PROM_GROUP..."
    groupadd --system "$PROM_GROUP"
else
    echo "Group $PROM_GROUP already exists."
fi

# === Create system user ===

if ! id "$PROM_USER" > /dev/null; then
    echo "Creating system user $PROM_USER..."
    useradd --system --no-create-home --shell /usr/sbin/nologin -g "$PROM_GROUP" "$PROM_USER"
else
    echo "User $PROM_USER already exists."
fi

# === Create temporary directory ===
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# === Download and install Prometheus ===
FILENAME="prometheus-${LATEST_VERSION#v}.linux-${ARCH_TYPE}.tar.gz"
URL="https://github.com/prometheus/prometheus/releases/download/${LATEST_VERSION}/${FILENAME}"

echo "Downloading $URL..."
curl -sL -o "$FILENAME" "$URL"

echo "Extracting..."
tar -xzf "$FILENAME"

cd "prometheus-${LATEST_VERSION#v}.linux-${ARCH_TYPE}"

echo "Installing binaries..."
cp prometheus promtool "$INSTALL_DIR/"

echo "Installing configuration and data directories..."
mkdir -p "$CONFIG_DIR" "$DATA_DIR"

# === Copy consoles and libraries if they exist ===
if [ -d "consoles" ] && [ -d "console_libraries" ]; then
    echo -e "\e[34mCopying console templates...\e[0m"
    cp -r consoles/ console_libraries/ "$CONFIG_DIR/"
else
    echo -e "\e[33m⚠️  No console templates found in this release. Skipping...\e[0m"
fi

# === Create config file ===
cat > "$CONFIG_DIR/prometheus.yml" << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF

echo "Setting ownership and permissions..."
chown -R "$PROM_USER:$PROM_GROUP" "$CONFIG_DIR" "$DATA_DIR"
chmod -R 755 "$CONFIG_DIR" "$DATA_DIR"

# === Create systemd unit ===
echo "Creating systemd service unit..."
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Prometheus Monitoring System
After=network.target

[Service]
User=${PROM_USER}
Group=${PROM_GROUP}
Type=simple
Restart=on-failure
ExecStart=${INSTALL_DIR}/prometheus \\
  --config.file=${CONFIG_DIR}/prometheus.yml \\
  --storage.tsdb.path=${DATA_DIR} \\
  --web.console.templates=${CONFIG_DIR}/consoles \\
  --web.console.libraries=${CONFIG_DIR}/console_libraries \\
  --web.listen-address=0.0.0.0:9090

[Install]
WantedBy=multi-user.target
EOF

# === Start and enable service ===
echo "Reloading systemd and starting Prometheus..."
systemctl daemon-reload
systemctl enable prometheus
systemctl restart prometheus

# === Check if Prometheus is running ===
if systemctl is-active --quiet prometheus; then
    echo -e "\e[32m✅ Prometheus installed and running successfully!\e[0m"
    echo "Available at: http://$(hostname -I | awk '{print $1}'):9090"
else
    echo -e "\e[31m❌ Error: Prometheus failed to start!\e[0m"
    journalctl -u prometheus --no-pager | tail -n 10
    exit 1
fi

# === Clean up ===
echo "Cleaning up temporary files..."
rm -rf "$TMP_DIR"

echo -e "\e[32m✅ Installation completed!\e[0m"