# Raspberry Pi 5 / Linux 6.18 port

This branch targets the **original ReSpeaker 2-Mics Pi HAT (WM8960)** on
ARM64 Raspberry Pi 5, Debian 13. It does not support the V2/TLV320AIC3104
board. Five-second 48 kHz stereo recording and playback completed on the development
host. Both channels contain varying samples; audible quality remains unverified.

## Findings

The original ARM64 installer assumes obsolete Raspberry Pi/Ubuntu kernel
packages, extracts a kernel version from an old boot image path, and writes
an obsolete boot configuration path. The driver also uses removed ASoC and
I2C APIs. Matching headers are already installed on the development host.

## Build and install

Install `build-essential`, `device-tree-compiler`, `alsa-utils`, and headers
matching `uname -r` if missing. Run from this directory:

```sh
./install_arm64.sh --check
sudo ./install_arm64.sh --install
```

The default invocation only builds. Explicit installation installs the WM8960
module under the running kernel's `updates/seeed-voicecard` directory, copies
the Pi 5 overlay and mixer state, and appends a boot configuration block after
backing up `/boot/firmware/config.txt`. It does not reboot automatically.
The legacy autodetection service must be disabled if previously installed.
The Pi 5 overlay selects `i2s_clk_producer` for the CPU clock provider.
The 2-mic overlay uses the kernel's simple-audio-card driver, so only the
WM8960 module is installed, though all three repository modules are built.

After reboot:

```sh
arecord -l
aplay -l
sudo alsactl -f /etc/voicecard/wm8960_asound.state restore seeed2micvoicec
arecord -D plughw:CARD=seeed2micvoicec,DEV=0 -f S16_LE -r 48000 -c 2 -d 5 /tmp/2mic.wav
aplay -D plughw:CARD=seeed2micvoicec,DEV=0 /tmp/2mic.wav
sudo alsactl store seeed2micvoicec
```

Recording must be checked for actual audio on both channels; device enumeration
alone is insufficient. Existing default ALSA routing is preserved.
Reinstall after kernel upgrades: this installer does not configure DKMS.
The old `install.sh`, `uninstall.sh`, and `dkms.conf` remain legacy paths and
must not be used for this port. To undo this installation, remove the appended
Seeed boot block and the installed overlay and WM8960 module, run `depmod -a`,
and reboot. Preserve unrelated boot configuration changes.

## Validation

- All three modules built and passed modpost on `6.18.34+rpt-rpi-2712`.
- WM8960 module vermagic matches the running ARM64 kernel.
- Pi 5 overlay compiled and applied offline to the installed
  `bcm2712-rpi-5-b.dtb` using `fdtoverlay`.
- Installer shell syntax and `git diff --check` passed.
- AC101/AC108 retain existing missing-prototype warnings; their hardware
  and the 4/6/8-mic paths are not validated.
- Installed WM8960 module and Pi 5 overlay on the development host; boot
  configuration backed up and updated. Module lookup resolves to the installed
  custom driver. After reboot, the card enumerated for capture and playback.
- Five-second S16_LE / 48 kHz stereo capture and playback completed successfully.
  Both channels contain varying samples (RMS approximately 2287 and 2281).
  Mixer restore reported a missing UCM configuration warning but stream tests
  completed. Audible quality and mixer persistence across reboot remain pending.

## Attribution

The four driver C files incorporate compatibility changes from
[HinTak/seeed-voicecard v6.14](https://github.com/HinTak/seeed-voicecard/tree/v6.14),
commit `1a07cfa0e17d27b29a9af0c40a3bfb0d364d8c48`, preserving their copyright
and license headers. Further changes adapt clock-provider constants, mixer
control initialization, and card/link naming for 6.18. Naming behavior was
checked against the Raspberry Pi Linux `rpi-6.18.y` simple-card utilities.
The original project GPL license remains in LICENSE.
