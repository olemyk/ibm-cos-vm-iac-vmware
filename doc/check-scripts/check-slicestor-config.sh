#!/bin/bash
for i in 1 2 3; do
  ip="10.33.3.11$((i+1))"
  echo "=== Checking Slicestor $i at $ip ==="
  ssh -i ./packer/packer_rsa -o StrictHostKeyChecking=no -o ConnectTimeout=5 localadmin@$ip "show system" 2>/dev/null | grep -E "Hostname|Manager IP" || echo "Failed to connect"
  echo ""
done
