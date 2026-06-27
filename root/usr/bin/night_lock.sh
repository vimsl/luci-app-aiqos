#!/bin/sh
# night_lock.sh - Night-time cell locking for optimal 5G cell
# Locks to strongest cell during off-peak hours
# Three-tier fallback: uqmi → AT serial → mmcli
# Part of luci-app-aiqos

LOG_TAG="night_lock"
WATCHDOG_INTERVAL=30
UQMI_DEVICE="/dev/cdc-wdm0"
AT_PORT="/dev/ttyUSB1"
QMODE_PID_FILE="/var/run/qmodem.pid"

log_msg() {
    logger -t "$LOG_TAG" "$1"
}

# Resume qmodem with health check
resume_qmodem() {
    local pid=$(cat "$QMODE_PID_FILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill -CONT "$pid" 2>/dev/null
        sleep 2
        # Health check after resume
        if ! timeout 5 uqmi -d "$UQMI_DEVICE" --get-signal-info >/dev/null 2>&1; then
            log_msg "qmodem health check failed after resume, restarting"
            /etc/init.d/qmodem restart
        fi
    fi
}

# Suspend qmodem to free AT port
suspend_qmodem() {
    local pid=$(cat "$QMODE_PID_FILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill -STOP "$pid" 2>/dev/null
        sleep 1
        # Verify suspended
        if grep -q "T (stopped)" "/proc/$pid/status" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Tier 1: Lock via uqmi
lock_via_uqmi() {
    local pci="$1"
    timeout 5 uqmi -d "$UQMI_DEVICE" --set-network-cells --cells "$pci" 2>/dev/null && return 0
    return 1
}

# Tier 2: Lock via AT serial port
lock_via_at() {
    local pci="$1"
    if [ -e "$AT_PORT" ]; then
        suspend_qmodem
        echo -ne "AT+GTCELLLOCK=$pci\r\n" > "$AT_PORT"
        sleep 2
        resume_qmodem
        return 0
    fi
    return 1
}

# Tier 3: Lock via mmcli (fallback)
lock_via_mmcli() {
    local pci="$1"
    which mmcli >/dev/null 2>&1 || return 1
    local modem_id=$(mmcli -L 2>/dev/null | grep -o '/org/freedesktop/ModemManager1/Modem/[0-9]*' | head -1)
    [ -n "$modem_id" ] && mmcli -m "$modem_id" --3gpp-lock-cell="$pci" 2>/dev/null && return 0
    return 1
}

# Main: try all three tiers
lock_cell() {
    local pci="$1"
    
    if lock_via_uqmi "$pci"; then
        log_msg "Cell $pci locked via uqmi (Tier 1)"
        return 0
    fi
    
    log_msg "Tier 1 (uqmi) failed, trying AT serial (Tier 2)"
    if lock_via_at "$pci"; then
        log_msg "Cell $pci locked via AT serial (Tier 2)"
        return 0
    fi
    
    log_msg "Tier 2 (AT) failed, trying mmcli (Tier 3)"
    if lock_via_mmcli "$pci"; then
        log_msg "Cell $pci locked via mmcli (Tier 3)"
        return 0
    fi
    
    log_msg "All three tiers failed to lock cell $pci"
    return 1
}

# Get strongest cell PCI
get_best_cell() {
    local cells=$(timeout 5 uqmi -d "$UQMI_DEVICE" --get-cell-info 2>/dev/null)
    if [ -n "$cells" ]; then
        echo "$cells" | grep -o '"physical_cell_id":[0-9]*' | sort -t: -k2 -nr | head -1 | cut -d: -f2
        return 0
    fi
    return 1
}

# Watchdog: ensure lock is held
watchdog_loop() {
    local locked_pci="$1"
    while true; do
        sleep "$WATCHDOG_INTERVAL"
        current_cell=$(get_best_cell)
        if [ "$current_cell" != "$locked_pci" ]; then
            log_msg "Watchdog: lock lost (current=$current_cell, locked=$locked_pci), re-locking"
            lock_cell "$locked_pci" || {
                log_msg "Watchdog: re-lock failed, best available cell is $current_cell"
            }
        fi
    done
}

# Main entry
main() {
    log_msg "Starting night_lock, finding best cell..."
    
    best_pci=$(get_best_cell)
    if [ -z "$best_pci" ]; then
        log_msg "Failed to get cell info, aborting"
        exit 1
    fi
    
    log_msg "Best cell PCI=$best_pci, locking..."
    lock_cell "$best_pci"
    
    # Start watchdog
    watchdog_loop "$best_pci" &
    watchdog_pid=$!
    
    # Trap EXIT
    trap "kill \$watchdog_pid 2>/dev/null; resume_qmodem; log_msg 'night_lock stopped'" EXIT
    
    wait "$watchdog_pid"
}

main "$@"
