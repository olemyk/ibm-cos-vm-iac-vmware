#!/bin/bash
#
# Copyright 2024- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#
# Configuration script for IBM COS Accesser VM
# This script uses SSH and expect to configure the Accesser node

set -e

# Check required environment variables
: "${VM_NAME:?VM_NAME is required}"
: "${IP_ADDRESS:?IP_ADDRESS is required}"
: "${NETMASK:?NETMASK is required}"
: "${GATEWAY:?GATEWAY is required}"
: "${DNS_SERVERS:?DNS_SERVERS is required}"
: "${HOSTNAME:?HOSTNAME is required}"
: "${MANAGER_IP:?MANAGER_IP is required}"
: "${ORGANIZATION:?ORGANIZATION is required}"
: "${COUNTRY:?COUNTRY is required}"
: "${USERNAME:?USERNAME is required}"
: "${PASSWORD:?PASSWORD is required}"

echo "Configuring IBM COS Accesser: ${VM_NAME} at ${IP_ADDRESS}"

# Remove old SSH host key if exists
ssh-keygen -R "${IP_ADDRESS}" 2>/dev/null || true

# Wait for SSH to be available
echo "Waiting for SSH to be available..."
for i in {1..60}; do
    if ssh-keyscan -H "${IP_ADDRESS}" 2>/dev/null | grep -q ssh; then
        echo "SSH is available"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "ERROR: Timeout waiting for SSH"
        exit 1
    fi
    sleep 5
done

# Use expect to configure the Accesser
expect <<EOF
set timeout 300
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${USERNAME}@${IP_ADDRESS}

expect {
    "password:" {
        send "${PASSWORD}\r"
    }
    timeout {
        puts "ERROR: Timeout waiting for password prompt"
        exit 1
    }
}

expect {
    "# " {
        send "edit\r"
    }
    timeout {
        puts "ERROR: Timeout waiting for shell prompt"
        exit 1
    }
}

expect "# "
send "channel data port eth0 ip ${IP_ADDRESS} netmask ${NETMASK} gateway ${GATEWAY}\r"

expect "# "
send "system hostname ${HOSTNAME}\r"

expect "# "
send "system dns ${DNS_SERVERS}\r"

expect "# "
send "system organization ${ORGANIZATION}\r"

expect "# "
send "system country ${COUNTRY}\r"

expect "# "
send "manager ip ${MANAGER_IP}\r"

expect "available?"
send "y\r"

expect "> "
send "\r"

expect "# "
send "activate\r"

expect "# "
send "exit\r"

expect eof
EOF

if [ $? -eq 0 ]; then
    echo "Accesser configuration completed successfully"
else
    echo "ERROR: Accesser configuration failed"
    exit 1
fi

# Made with Bob
