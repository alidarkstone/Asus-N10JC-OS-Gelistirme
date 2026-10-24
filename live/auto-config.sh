#!/bin/bash
# live-build configuration for N10 OS (Debian bookworm, i386).
# Run from live/: N10_KREL=<kernelrelease> ./auto-config.sh && sudo lb build
# N10_KREL is our kernel's release (e.g. 6.18.5-n10jc); live-build then installs
# the package linux-image-$N10_KREL from config/packages.chroot.
set -euo pipefail
: "${N10_KREL:?set N10_KREL (see build/debs/KERNELRELEASE)}"
lb config noauto \
  --distribution bookworm \
  --architectures i386 \
  --archive-areas "main contrib non-free non-free-firmware" \
  --debian-installer none \
  --linux-packages linux-image \
  --linux-flavours "$N10_KREL" \
  --binary-images iso-hybrid \
  --bootloaders syslinux \
  --memtest none \
  --apt-recommends false \
  --security true \
  --updates true \
  --iso-application "N10 OS" \
  --iso-volume "N10OS" \
  --bootappend-live "boot=live components quiet loglevel=3 splash i915.fastboot=1 zswap.enabled=0 preempt=full mem_sleep_default=deep" \
  "$@"
