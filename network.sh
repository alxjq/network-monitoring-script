#!/bin/bash

# ==========================
# Network Monitoring Script
# ==========================
TARGET="8.8.8.8"
PORTS=(22 80 443)
LOGFILE="/var/log/network.log"
PING_COUNT=4
SLEEP_TIME=30

#Root check (ping -c & permission may be required for some operations)
if [[ $EUID -ne 0 ]]; then
    echo "Please run script as root (sudo bash $0)"
    exit 1
fi

# Log file provide permissions and entity if available
touch "$LOGFILE" || { echo "Cannot create log file $LOGFILE"; exit 1; }
chmod 644 "$LOGFILE"

echo "=== network monitoring started ==="
echo "Target: $TARGET | Log: $LOGFILE"
echo "=================================="

while true; do
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    # --- PING ---
    PING_OUTPUT=$(ping -c "$PING_COUNT" "$TARGET" 2>/dev/null)
    # Paket loss (from ping output)
    PACKET_LOSS=$(echo "$PING_OUTPUT" | grep -oP '\d+(?=% packet loss)' || echo "100")
    # Average RTT: center time= values on each line of ping
    AVG_TIME=$(echo "$PING_OUTPUT" | grep -oP 'time=[0-9.]+' | sed 's/time=//' | awk '{sum+=$1; n++} END {if (n>0) printf("%.2f", sum/n); else print "0.00"}')

    # --- PORT CONTROL ---
    PORT_RESULTS=""
    for PORT in "${PORTS[@]}"; do
        # nc (netcat) kullan; -z sadece port kontrolü, -w2 timeout 2s
        if command -v nc >/dev/null 2>&1; then
            nc -z -w2 "$TARGET" "$PORT" &>/dev/null
            if [[ $? -eq 0 ]]; then
                PORT_RESULTS+="Port $PORT: OPEN | "
            else
                PORT_RESULTS+="Port $PORT: CLOSED | "
            fi
        else
            # nc yoksa socket ile kontrol (bash + /dev/tcp)
            (echo > /dev/tcp/"$TARGET"/"$PORT") &>/dev/null
            if [[ $? -eq 0 ]]; then
                PORT_RESULTS+="Port $PORT: OPEN | "
            else
                PORT_RESULTS+="Port $PORT: CLOSED | "
            fi
        fi
    done

    # --- Write Log ---
    echo "$TIMESTAMP | Ping: ${AVG_TIME} ms | Packet loss: ${PACKET_LOSS}% | $PORT_RESULTS" >> "$LOGFILE"

    # --- ALERT LİNE ---
    if [[ "$PACKET_LOSS" -ge 50 ]]; then
        echo "[!] $TIMESTAMP - High Packet Loss: ${PACKET_LOSS}%" >> "$LOGFILE"
    fi

    # write console too
    echo "$TIMESTAMP | Ping: ${AVG_TIME} ms | Loss: ${PACKET_LOSS}% | $PORT_RESULTS"

    # wait
    sleep "$SLEEP_TIME"
done
