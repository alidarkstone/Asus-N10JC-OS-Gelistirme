#!/bin/bash
# live-build configuration for N10 OS (Debian bookworm, i386).
# Run from live/: ./auto-config.sh && sudo lb build
set -euo pipefail
lb config noauto \
  --distribution bookworm \
  --architectures i386 \
  --archive-areas "main contrib non-free non-free-firmware" \
  --debian-installer none \
  --linux-packages none \
  --binary-images iso-hybrid \
  --bootloaders "syslinux,grub-efi" \
  --memtest none \
  --apt-recommends false \
  --security true \
  --updates true \
  --iso-application "N10 OS" \
  --iso-volume "N10OS" \
  --bootappend-live "boot=live components quiet loglevel=3 splash i915.fastboot=1 zswap.enabled=0 preempt=full mem_sleep_default=deep" \
  "$@"
