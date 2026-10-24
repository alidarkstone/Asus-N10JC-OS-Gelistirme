#!/bin/bash
# Build the N10 OS live ISO: kernel .deb -> live-build -> build/n10os-*.iso
# Needs a Debian (bookworm or newer) x86_64 host, root, and network.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SERIES="${KERNEL_SERIES:-6.18}"

apt-get update
apt-get install -y --no-install-recommends live-build debootstrap \
  build-essential bc bison flex libssl-dev libelf-dev cpio kmod rsync \
  python3 curl xz-utils dpkg-dev debhelper ca-certificates gcc-multilib

"$ROOT/kernel/build-kernel.sh" "$SERIES"

cd "$ROOT/live"
mkdir -p config/packages.chroot
cp "$ROOT"/build/debs/linux-image-*n10jc*.deb config/packages.chroot/
lb clean --purge || true
N10_KREL="$(cat "$ROOT/build/debs/KERNELRELEASE")" ./auto-config.sh
lb build
mkdir -p "$ROOT/build"
iso="$ROOT/build/n10os-$(date +%Y%m%d).iso"
mv live-image-i386.hybrid.iso "$iso"
sha256sum "$iso" > "$iso.sha256"
echo ">> $iso"
