#!/bin/bash
# Filename: config_nf_conntrack.sh
# Description: Auto configure nf_conntrack persistence on Debian 12

set -e

CONF_FILE="/etc/modules-load.d/nf_conntrack.conf"
MODULE_LIST=("nf_conntrack" "nf_conntrack_ipv4" "nf_conntrack_ipv6")

# Check root privilege
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root" 
   exit 1
fi

# Function: Check module availability
check_module() {
    local module=$1
    if ! modinfo "$module" &>/dev/null; then
        echo "FATAL: Kernel module $module not found"
        echo "Possible reasons:"
        echo " - Host is running non-standard kernel"
        echo " - Required kernel config not enabled"
        exit 2
    fi
}

# Check all required modules
for mod in "${MODULE_LIST[@]}"; do
    check_module "$mod"
done

# Create config file if not exists
if [[ ! -f "$CONF_FILE" ]]; then
    echo "# Auto-configured by $0" > "$CONF_FILE"
    chmod 644 "$CONF_FILE"
    echo "Created config file: $CONF_FILE"
fi

# Add modules to config file
for mod in "${MODULE_LIST[@]}"; do
    if ! grep -q "^$mod" "$CONF_FILE"; then
        echo "$mod" >> "$CONF_FILE"
        echo "Added module: $mod"
    else
        echo "Module $mod already in config, skipping..."
    fi
done

# Load modules immediately
for mod in "${MODULE_LIST[@]}"; do
    if ! lsmod | grep -q "^${mod} "; then
        modprobe "$mod"
        echo "Loaded module: $mod"
    else
        echo "Module $mod already loaded"
    fi
done

# Restart systemd-modules-load
systemctl restart systemd-modules-load.service
echo "Reloaded systemd modules service"

# Verify post-config
echo -e "\nVerification:"
lsmod | grep -E "^nf_conntrack|^nf_conntrack_ipv"
systemctl status systemd-modules-load.service --no-pager
