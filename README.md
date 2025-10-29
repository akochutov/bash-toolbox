# bash-toolbox

A collection of Bash scripts for quick installation and configuration of infrastructure and monitoring tools such as **Prometheus**, **Grafana**, **Node Exporter**, and others.

## ⚙️ Before You Start

Before running any script, please make sure to:

1. **Update your system packages:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Make the script executable:**
   ```bash
   chmod +x script-name.sh
   ```

---

## 📦 Available Scripts

### 🟢 Prometheus Installation

**Script:** [`install-prometheus.sh`](./install-prometheus.sh)  
This script installs **Prometheus** on Ubuntu, creates a dedicated system user, sets up necessary directories, downloads the latest Prometheus binary, and configures it as a systemd service.

**Run the script:**
```bash
sudo ./install-prometheus.sh
```

---

## 💡 Notes

- All scripts are intended for **Ubuntu/Debian-based systems**.
- You can freely modify and adapt them for your infrastructure needs.

---