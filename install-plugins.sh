#!/bin/bash
set -e

: "${PLUGIN_DIR?}" 

if [ "${INSTALL_PLUGINS,,}" != "true" ]; then
    echo "Plugin installation disabled via INSTALL_PLUGINS=false. Skipping."
    exit 0
fi

PLUGIN_SOURCE="L4D2-Competitive-Rework"

if [ ! -d "${PLUGIN_DIR}/addons/sourcemod" ]; then
    echo "Plugins not found. Installing L4D2 Competitive Rework plugins..."

    mkdir -p \
    "${PLUGIN_DIR}/addons" \
    "${PLUGIN_DIR}/cfg" \
    "${PLUGIN_DIR}/scripts"
    
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT
    
    cd "$TEMP_DIR"
    git clone https://github.com/SirPlease/L4D2-Competitive-Rework.git
    
    cp -r "${PLUGIN_SOURCE}/addons/" "${PLUGIN_DIR}"
    cp -r "${PLUGIN_SOURCE}/cfg/" "${PLUGIN_DIR}"
    cp -r "${PLUGIN_SOURCE}/scripts/" "${PLUGIN_DIR}"
    
    echo "Plugins installed successfully."
else
    echo "Plugins already present, skipping installation."
fi