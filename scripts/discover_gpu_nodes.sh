#!/bin/bash
# Discover Linux GPU nodes in the network

SUBNET="${1:-192.168.10}"
OUTPUT_FILE="${2:-./gpu_nodes_discovered.txt}"

echo "[*] Scanning subnet: $SUBNET.0/24 for Linux GPU machines..."
echo "" > "$OUTPUT_FILE"

# Get your own IP and MAC
LOCAL_IP=$(ifconfig en0 | grep "inet " | awk '{print $2}')
echo "[*] Local machine IP: $LOCAL_IP"

# Extract active IPs from ARP table
echo "[*] Found active network nodes:"
arp -a | grep "$SUBNET" | grep -v "broadcast\|multicast" | while read line; do
    IP=$(echo $line | grep -oE "192\.168\.10\.[0-9]+")
    if [ ! -z "$IP" ] && [ "$IP" != "$LOCAL_IP" ]; then
        echo "  Checking $IP..."
        
        # SSH into remote machine and check for GPU
        timeout 3 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 "root@$IP" \
            "uname -a | grep -i linux > /dev/null && nvidia-smi > /dev/null 2>&1 && echo 'GPU_MACHINE' || echo 'NO_GPU'" 2>/dev/null | {
            read result
            if [ "$result" = "GPU_MACHINE" ]; then
                echo "[✓] GPU detected on $IP"
                # Get GPU info
                GPU_INFO=$(timeout 3 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 "root@$IP" \
                    "nvidia-smi --query-gpu=name,driver_version,compute_cap --format=csv,noheader" 2>/dev/null)
                echo "$IP|$GPU_INFO" >> "$OUTPUT_FILE"
            fi
        }
    fi
done

echo ""
echo "[*] Discovery complete. Results saved to: $OUTPUT_FILE"
echo "[*] GPU Nodes found:"
cat "$OUTPUT_FILE" 2>/dev/null || echo "  (none found)"
