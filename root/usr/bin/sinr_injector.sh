#!/bin/sh
# sinr_injector.sh - SINR data injector for AIQoS
# Reads 5G signal quality via uqmi, writes to /tmp/aiqos_sinr_coeff
# Part of luci-app-aiqos

SINR_FILE="/tmp/aiqos_sinr_coeff"
LOG_TAG="sinr_injector"
INTERVAL=2
MAX_TIMEOUTS=5
LOCK_FILE="/var/run/sinr_injector.lock"
QUEUE_FIFO="/tmp/uqmi_queue.fifo"

log_msg() {
    logger -t "$LOG_TAG" "$1"
}

# Check if another instance is running
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# Ensure FIFO exists
[ -p "$QUEUE_FIFO" ] || mkfifo "$QUEUE_FIFO"

timeout_count=0
while true; do
    # Read SINR via uqmi with timeout and retry
    result=$(timeout 3 uqmi -d /dev/cdc-wdm0 --get-signal-info 2>/dev/null)
    
    if [ -n "$result" ]; then
        # Parse signal info
        rsrp=$(echo "$result" | grep -o '"rssi":-[0-9]*' | head -1 | cut -d: -f2)
        rsrq=$(echo "$result" | grep -o '"rsrq":-[0-9]*' | head -1 | cut -d: -f2)
        sinr=$(echo "$result" | grep -o '"sinr":[0-9]*' | head -1 | cut -d: -f2)
        
        if [ -n "$rsrp" ] && [ -n "$rsrq" ] && [ -n "$sinr" ]; then
            # Calculate quality coefficient (0-100 scale)
            # Higher is better: RSRP normalized + SINR bonus
            rsrp_norm=$(( (-${rsrp#-} + 44) * 2 ))  # -44dBm=100, -95dBm=0
            sinr_norm=$(( ${sinr} * 2 ))             # 0-50
            coeff=$(( rsrp_norm + sinr_norm ))
            [ $coeff -gt 100 ] && coeff=100
            [ $coeff -lt 0 ] && coeff=0
            
            echo "$coeff" > "$SINR_FILE"
            timeout_count=0
        fi
    else
        timeout_count=$((timeout_count + 1))
        if [ $timeout_count -ge $MAX_TIMEOUTS ]; then
            log_msg "uqmi timeout $timeout_count times, backing off"
            sleep 15
            timeout_count=$(( $timeout_count > 3 ? $timeout_count - 2 : 0 ))
        fi
    fi
    
    # Random jitter to avoid uqmi contention
    sleep_jitter=$(( RANDOM % 5 ))
    sleep $(( INTERVAL + sleep_jitter - 2 ))
done
