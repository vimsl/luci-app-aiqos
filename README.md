# luci-app-aiqos

AI-powered QoS management for 5G CPE routers running ImmortalWrt on MediaTek MT798x platforms.

## Features

- **SINR-aware Bandwidth Adjustment**: Reads 5G signal quality every 2 seconds, adjusts QoS parameters in real-time
- **Night Cell Locking**: Automatically locks to the strongest 5G cell during off-peak hours with three-tier fallback (uqmi → AT serial → mmcli)
- **Platform Auto-Detection**: Detects WiFi chipset, eBPF support, eqos-mtk, ModemManager, HNAT status
- **7-Toggle LuCI Interface**: SimpleForm CBI with one-click preset scenarios (Gaming / Streaming / Office / Download)
- **HNAT Compatible**: Designed to work with MediaTek hardware acceleration (HNAT) after DTS WWAN whitelist patch

## Supported Hardware

| Device | SoC | 5G Module | Status |
|--------|-----|-----------|--------|
| Hiveton H5000M | MT7987 (Filogic 660) | Fibocom FM170-EAU (USB 3.0) | Active |
| Cetron CT3003 | MT7986 (Filogic 830) | Fibocom FM170 (QMI) | Planned |

## Requirements

- ImmortalWrt 24.10+ (padavanonly/immortalwrt-mt798x)
- Linux kernel 6.6+
- `kmod-sched-cake` (CAKE qdisc)
- `cake-autorate` (auto rate adjustment)
- `uqmi` (5G modem management)
- `CONFIG_KPROBES=y` (optional, for `qmi_fix_skb.ko` fallback)

## Quick Install

```bash
# Add to feeds.conf
echo "src-git aiqos https://github.com/vimsl/luci-app-aiqos.git" >> feeds.conf.default

# Update and install
./scripts/feeds update aiqos
./scripts/feeds install luci-app-aiqos

# Enable in menuconfig
make menuconfig
# LuCI → Applications → luci-app-aiqos

# Build
make package/luci-app-aiqos/compile
```

## File Structure

```
luci-app-aiqos/
├── Makefile                          # OpenWrt package definition
├── root/
│   ├── etc/
│   │   ├── config/aiqos              # UCI default config
│   │   └── init.d/aiqosd             # Procd init script
│   └── usr/bin/
│       ├── sinr_injector.sh          # SINR data injector (~80 lines)
│       ├── night_lock.sh             # Night cell locking (~100 lines)
│       └── condition_detect.sh       # Capability detection (~60 lines)
├── luasrc/
│   ├── controller/aiqos.lua          # LuCI route + JSON API (~80 lines)
│   ├── model/cbi/aiqos.lua           # SimpleForm CBI config (~150 lines)
│   └── view/aiqos/status.htm         # Status dashboard (~100 lines)
├── patches/
│   └── 0001-mt7987-h5000m-hnat-add-wwan-ext-devices.patch
├── docs/
│   └── H5000M-HNAT-AIQoS-白皮书-v2.1.md
└── README.md
```

## Architecture

```
FM170-EAU (USB 3.0)
    │
    ▼
qmodem-next + uqmi
    │
    ▼
wwan0 → HNAT (DTS whitelist: ext-devices-prefix="wwan")
    │
    ▼
CAKE qdisc → cake-autorate → aiqosd
    │                            ├── sinr_injector.sh
    │                            ├── night_lock.sh
    │                            └── condition_detect.sh
    │
    ▼
LuCI Dashboard (SimpleForm + Status)
```

## Verification

After installation and DTS patch:

```bash
# 1. Tailroom cleared
dmesg | grep tailroom                    # → 0

# 2. HNAT forwarding active
cat /sys/kernel/debug/hnat/hnat_stats    # → BIND entries bytes > 0

# 3. CAKE on wwan0
tc -s qdisc show dev wwan0              # → cake qdisc visible

# 4. SINR data updating
cat /tmp/aiqos_sinr_coeff                # → value updating every ~2s

# 5. Capability detection
cat /tmp/aiqos_capability.json           # → valid JSON

# 6. LuCI
# → No garbled text, presets work, toggles grey out correctly
```

## Key Design Decisions

| Original Design | H5000M Reality | Adaptation |
|----------------|----------------|------------|
| ModemManager + mmcli | qmodem-next + uqmi | All scripts use uqmi |
| cake-autorate | eqos-mtk (MTK HW QoS) | condition_detect adapts |
| mmcli SINR | uqmi --get-signal-info | timeout 3 + backoff |
| Standalone | Multi-process uqmi contention | FIFO serial queue |

## License

GPL-2.0-only

## Credits

- Inspired by `padavanonly/immortalwrt-mt798x` community
- HNAT WWAN support concept from MTK official feed + 237176253 (恩山)
- `cake-autorate` by lynxthecat
