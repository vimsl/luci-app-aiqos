#!/bin/sh
# condition_detect.sh - Platform capability detection
# Detects: WiFi chipset, eBPF support, eqos-mtk, ModemManager
# Outputs: /tmp/aiqos_capability.json
# Part of luci-app-aiqos

OUTPUT_FILE="/tmp/aiqos_capability.json"
LOG_TAG="condition_detect"

log_msg() {
    logger -t "$LOG_TAG" "$1"
}

detect_wifi() {
    # Check MT7992 (Filogic 660) BE7200
    if dmesg | grep -qi "mt7992"; then
        echo '"wifi": {"chipset": "MT7992", "standard": "BE7200", "supported": true}'
    elif lsmod | grep -qi "mt7915"; then
        echo '"wifi": {"chipset": "MT7915", "standard": "AX3000", "supported": true}'
    elif lsmod | grep -qi "mt7916"; then
        echo '"wifi": {"chipset": "MT7916", "standard": "AX6000", "supported": true}'
    else
        echo '"wifi": {"chipset": "unknown", "supported": false}'
    fi
}

detect_ebpf() {
    if zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_BPF=y"; then
        echo '"ebpf": {"supported": true}'
    else
        echo '"ebpf": {"supported": false}'
    fi
}

detect_eqos_mtk() {
    if which eqos-mtk >/dev/null 2>&1; then
        echo '"eqos_mtk": {"installed": true}'
    elif lsmod | grep -qi "eqos"; then
        echo '"eqos_mtk": {"installed": true, "module_loaded": true}'
    else
        echo '"eqos_mtk": {"installed": false}'
    fi
}

detect_modem() {
    if uqmi -d /dev/cdc-wdm0 --get-capabilities >/dev/null 2>&1; then
        local model=$(uqmi -d /dev/cdc-wdm0 --get-model 2>/dev/null)
        local fw=$(uqmi -d /dev/cdc-wdm0 --get-firmware-version 2>/dev/null)
        echo "\"modem\": {\"detected\": true, \"model\": \"${model:-unknown}\", \"firmware\": \"${fw:-unknown}\", \"interface\": \"uqmi\"}"
    elif lsusb | grep -qi "2cb7"; then
        echo '"modem": {"detected": true, "vendor": "Fibocom", "interface": "detected_but_not_ready"}'
    else
        echo '"modem": {"detected": false}'
    fi
}

detect_hnat() {
    if [ -f /sys/kernel/debug/hnat/hnat_stats ]; then
        local bind_entries=$(grep -c "BIND" /sys/kernel/debug/hnat/hnat_stats 2>/dev/null || echo 0)
        echo "\"hnat\": {\"available\": true, \"bind_entries\": $bind_entries}"
    else
        echo '"hnat": {"available": false}'
    fi
}

detect_cake() {
    if tc qdisc show 2>/dev/null | grep -q "cake"; then
        echo '"cake": {"active": true}'
    elif which tc >/dev/null 2>&1; then
        echo '"cake": {"active": false, "available": true}'
    else
        echo '"cake": {"active": false, "available": false}'
    fi
}

# Build JSON output
cat > "$OUTPUT_FILE" <<EOF
{
$(detect_wifi),
$(detect_ebpf),
$(detect_eqos_mtk),
$(detect_modem),
$(detect_hnat),
$(detect_cake)
}
EOF

log_msg "Capability detection complete, output: $OUTPUT_FILE"
