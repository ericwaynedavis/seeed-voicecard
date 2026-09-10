#!/bin/bash
# Install the original WM8960 2-mic HAT on Raspberry Pi 5 / Linux 6.18.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
mode=${1:---check}
case "$mode" in
    --check|--install) ;;
    *) echo "Usage: $0 [--check|--install]" >&2; exit 2 ;;
esac
kernel=$(uname -r)
[[ $(uname -m) == aarch64 ]] || { echo "Requires ARM64" >&2; exit 1; }
grep -q 'Raspberry Pi 5' /proc/device-tree/model || { echo "Requires Raspberry Pi 5" >&2; exit 1; }
[[ $kernel == 6.18.* ]] || { echo "This port is validated for Linux 6.18 only" >&2; exit 1; }
for tool in make gcc dtc; do
    command -v "$tool" >/dev/null || { echo "Missing build tool: $tool" >&2; exit 1; }
done
[[ -f /lib/modules/$kernel/build/Makefile ]] || {
    echo "Install matching headers: sudo apt install linux-headers-$kernel" >&2
    exit 1
}
make -j"$(nproc)"
mkdir -p build
dtc -@ -Wno-unit_address_vs_reg -I dts -O dtb     -o build/seeed-2mic-voicecard-pi5.dtbo seeed-2mic-voicecard-pi5-overlay.dts
if [[ $mode == --check ]]; then
    echo "Build passed. Installation requires the original WM8960 2-mic HAT."
    echo "Install with: sudo ./install_arm64.sh --install"
    exit 0
fi
[[ $EUID == 0 ]] || { echo "Run --install with sudo" >&2; exit 1; }
config=/boot/firmware/config.txt
[[ -f $config && -d /boot/firmware/overlays ]] || { echo "Boot firmware directory missing" >&2; exit 1; }
# A boot-time overlay replaces the old hardware-detection service.
if systemctl is-enabled --quiet seeed-voicecard.service 2>/dev/null; then
    echo "Disable the legacy seeed-voicecard service before installing." >&2
    exit 1
fi
if grep -Eq '^dtoverlay=(seeed-|wm8960)' "$config" && ! grep -qx 'dtoverlay=seeed-2mic-voicecard-pi5' "$config"; then
    echo "Existing audio overlay found; resolve it in $config first." >&2
    exit 1
fi
install -D -m 644 snd-soc-wm8960.ko "/lib/modules/$kernel/updates/seeed-voicecard/snd-soc-wm8960.ko"
depmod -a "$kernel"
install -m 644 build/seeed-2mic-voicecard-pi5.dtbo /boot/firmware/overlays/
install -D -m 644 wm8960_asound.state /etc/voicecard/wm8960_asound.state
if ! grep -qx 'dtoverlay=seeed-2mic-voicecard-pi5' "$config"; then
    cp -a "$config" "$config.seeed-backup-$(date +%Y%m%d%H%M%S)"
    printf '\n[all]\n# Original ReSpeaker 2-mic HAT (WM8960)\ndtparam=i2c_arm=on\ndtoverlay=seeed-2mic-voicecard-pi5\n' >> "$config"
fi
echo "Installed for $kernel. Reboot, then restore the mixer as described in PORTING.md."
echo "Rerun after kernel upgrades; this installer does not configure DKMS."
