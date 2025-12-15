#!/bin/bash

# This script is used to install xahaud in Linux environments. It must be run as root.
# The script is designed not to overwrite existing configuration files. However, all files should be backed up
# prior to running this script.
# It is likely that 'xahaud.cfg' will need to be adjusted manually after running this script.
# Xahaud can be updated by replacing the running binary with the new version, then restarting xahaud.
# If a new binary is specified in BINARY_URL, this script will update xahaud to that version, while leaving
# directory structure, configuration files, and the systemd service file unchanged.

### VARIABLES ###

#### Directory structure ####
XAHAUD_DIR="/opt/xahaud/bin/"	# Path where xahaud binary will be stored
CONF_DIR="/opt/xahaud/etc/"		# Path where the xahaud.cfg and validators-xahau.txt will be stored
DB_DIR="/opt/xahaud/db/"		# Path where xahaud will store databases
LOG_DIR="/var/log/xahaud/"		# Path where logfile(s) will be stored.

#### Ownership ####
XAHAUD_USER="xahaud"			# User that owns the xahaud process.

#### Download links ####
BINARY_URL="https://build.xahau.tech/2025.9.8-HEAD%2B2194"											# URL to the xahaud binary that will be downloaded.
CFG_URL="https://raw.githubusercontent.com/Xahau/xahaud/refs/heads/dev/cfg/xahaud-example.cfg"		# This will be renamed to 'xahaud.cfg'
VAL_URL="https://raw.githubusercontent.com/Xahau/xahaud/refs/heads/dev/cfg/validators-example.txt"	# This will be renamed to 'validators-xahau.txt'



########## SCRIPT BEGINS HERE. DO NOT ADJUST VARIABLES BELOW THIS LINE ##########

### CHECK IF BEING RUN AS ROOT ###
set -euo pipefail
IFS=$'\n\t'
if [[ "$EUID" -ne 0 ]]; then
	echo "Error: this script must be run as root." >&2
	exit 1
fi

### CREATE DIRECTORIES ####
echo "Checking directory structure."
sudo mkdir -p ${XAHAUD_DIR} ${CONF_DIR} ${DB_DIR} ${LOG_DIR}

### CREATE xahaud GROUP AND USER ###
echo "Checking for user and group."
if ! getent group ${XAHAUD_USER} > /dev/null; then
	groupadd --system ${XAHAUD_USER}
fi

if ! getent passwd ${XAHAUD_USER} > /dev/null; then
	sudo useradd --system --gid ${XAHAUD_USER} --no-create-home ${XAHAUD_USER}
fi

### DOWNLOAD CONFIGURATION FILES ###
echo "Downloading files."
if [[ ! -f "${CONF_DIR}xahaud.cfg" ]]; then
	curl -fsSL ${CFG_URL} -o ${CONF_DIR}xahaud.cfg
fi
if [[ ! -f "${CONF_DIR}validators-xahau.txt" ]]; then
	curl -fsSL ${VAL_URL} -o ${CONF_DIR}validators-xahau.txt
fi

### DOWNLOAD XAHAUD ###
if [[ ! -f "${XAHAUD_DIR}xahaud" ]]; then
	curl -fsSL ${BINARY_URL} -o ${XAHAUD_DIR}xahaud
elif [[ -f "${XAHAUD_DIR}xahaud" ]]; then
	echo "Existing xahaud binary found. It will be renamed to 'xahaud.old'."
	mv ${XAHAUD_DIR}xahaud ${XAHAUD_DIR}xahaud.old
	curl -fsSL ${BINARY_URL} -o ${XAHAUD_DIR}xahaud
fi

### CHANGE OWNERSHIP AND PERMISSIONS ###
echo "Checking ownership and permissions."
chown -R ${XAHAUD_USER}:${XAHAUD_USER} ${XAHAUD_DIR} ${CONF_DIR} ${DB_DIR} ${LOG_DIR}
chmod -R 750 ${XAHAUD_DIR} ${CONF_DIR} ${DB_DIR} ${LOG_DIR}

### INSTALL systemd SERVICE FILE ###
if [[ ! -f "/etc/systemd/system/xahaud.service" ]]; then
echo "Installing system service file."
sudo cat > /etc/systemd/system/xahaud.service <<EOF
[Unit]
Description=Xahaud Daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${XAHAUD_DIR}xahaud --silent --conf=${CONF_DIR}xahaud.cfg
Restart=on-failure
User=${XAHAUD_USER}
Group=${XAHAUD_USER}
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
fi

### RUN COMMANDS AS 'xahaud' ###
sudo cat /usr/local/bin/xahaud <<EOF
#!/usr/bin/env bash
set -euo pipefail

exec ${XAHAUD_DIR}xahaud --conf=${CONF_DIR}xahaud.cfg "$@"
EOF
sudo chmod 0755 /usr/local/bin/xahaud

### ENABLE xahaud ###
sudo systemctl daemon-reload
sudo systemctl stop xahaud
sudo systemctl enable --now xahaud
sudo systemctl status xahaud
echo "The install script completed successfully."
