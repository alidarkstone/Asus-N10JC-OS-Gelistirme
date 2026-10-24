#!/bin/bash
# Build the N10JC kernel as Debian packages (linux-image-*-n10jc_*.deb).
# Usage: kernel/build-kernel.sh [series]   (default series: 6.18)
# Runs on an x86_64 Debian/Ubuntu host; the kernel is built for ARCH=i386.
set -euo pipefail

SERIES="${1:-6.18}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-$HERE/../build/kernel}"
OUT="${OUT:-$HERE/../build/debs}"
mkdir -p "$WORK" "$OUT"
cd "$WORK"
# Debian's deb packaging rules call the i686 cross compiler, so use it for every step.
export ARCH=i386 CROSS_COMPILE=i686-linux-gnu-
# Only the image package: the headers package would rebuild host tools against i386 libc.
export DEB_BUILD_PROFILES="pkg.linux-upstream.nokernelheaders pkg.linux-upstream.nokerneldbg"

# Latest stable release in the series, from kernel.org.
VER="$(curl -fsSL https://www.kernel.org/releases.json \
  | python3 -c "import json,sys; s='$SERIES'; print(next(r['version'] for r in json.load(sys.stdin)['releases'] if r['version']==s or r['version'].startswith(s+'.')))")"
echo ">> Kernel $VER"

if [ ! -d "linux-$VER" ]; then
  curl -fsSLO "https://cdn.kernel.org/pub/linux/kernel/v${SERIES%%.*}.x/linux-$VER.tar.xz"
  tar xf "linux-$VER.tar.xz"
fi
cd "linux-$VER"

# Base: Debian bookworm's 686-pae config (full hardware coverage), then our fragment.
if [ ! -f "$WORK/debian-686-pae.config" ]; then
  tmp="$(mktemp -d)"
  ( cd "$tmp"
    # Download first: awk exits early, which would SIGPIPE a streaming xz under pipefail.
    curl -fsSLo Packages.xz https://deb.debian.org/debian/dists/bookworm/main/binary-i386/Packages.xz
    xz -d Packages.xz
    pkg="$(awk '/^Package: linux-image-[0-9.-]+-686-pae-unsigned$/{p=1} p&&/^Filename:/{print $2; exit}' Packages)"
    curl -fsSLo k.deb "https://deb.debian.org/debian/$pkg"
    dpkg-deb -x k.deb x
    cp x/boot/config-* "$WORK/debian-686-pae.config" )
  rm -rf "$tmp"
fi
cp "$WORK/debian-686-pae.config" .config
scripts/kconfig/merge_config.sh -m .config "$HERE/n10jc.config"
make olddefconfig
"$HERE/check-config.sh" .config
grep -E "^CONFIG_MODULE_SIG" .config || true

make -j"$(nproc)" KCFLAGS="-march=bonnell -mtune=bonnell -O2" \
  KDEB_PKGVERSION="$VER-1n10" KDEB_CHANGELOG_DIST=bookworm \
  DPKG_FLAGS=-d bindeb-pkg  # -d: skip i386 lib build-deps (libssl-dev:i386 etc.), not needed for the kernel
make -s kernelrelease > "$OUT/KERNELRELEASE"
mv ../linux-image-*n10jc*.deb "$OUT/"
rm -f "$OUT"/linux-image-*-dbg_*.deb
ls -l "$OUT"
