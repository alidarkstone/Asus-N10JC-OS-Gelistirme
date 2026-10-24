# i686 base distro comparison (checked 2026-10-24)

N270 flags: pae, nx, sse3 (pni), ssse3; no lm. Target -march=bonnell.

Browser is decisive: Firefox 32-bit EOL (144 last, ESR 140 i686 updates to ~Sep 2026).
Debian still builds i386 Chromium (sid 156.x; bookworm/trixie security 150.x).

| Base | i686 status | Kernel | Browser | Init | Idle RAM | ISO tooling |
|---|---|---|---|---|---|---|
| Debian 12 bookworm i386 | full arch, LTS to 2028-06-30 | 6.1 | Chromium 150 | systemd/sysvinit | 150-250 MB | live-build, mmdebstrap |
| Debian 13 trixie i386 | userland only, no installer, no i386 kernel | own | Chromium 150 | systemd/sysvinit | 150-250 MB | mmdebstrap + own kernel |
| Devuan 6 i386 | no kernel, no ISO | own | Debian | sysvinit/runit/OpenRC | 100-180 MB | live-sdk |
| antiX 26 | 32-bit ISO kept | 5.10.240 | Debian Chromium | runit etc. | 80-120 MB | iso-snapshot |
| MX 25 | 32-bit ISO dropped | - | - | - | - | - |
| Alpine 3.24.3 | x86 ISOs shipped | 6.18 | unverified | OpenRC | 40-80 MB | mkimage.sh |
| Void i686 | glibc only, 2026 builds unconfirmed | 6.12 | unverified | runit | 70-100 MB | void-mklive |
| Arch Linux 32 | stagnant (May 2025) | lagging | ? | systemd | 120 MB | archiso32 |
| Gentoo x86 | daily i686 stage3; x86 may go ~arch | any | build from source | OpenRC | 50-100 MB | catalyst |
| Slackware 15 | 2022 stable | 5.15 | ? | sysv | 100 MB | manual |
| Tiny Core 17 | 32-bit | 6.18.2 | very limited | busybox | 46 MB | remaster |
| NixOS | i686 cache removed | - | - | - | - | not viable |
| Buildroot/Yocto/LFS | supported | any | WebKitGTK (Buildroot) | any | 20-60 MB | native, all security on us |

## Ranked
1. Debian i386 userland (bookworm -> trixie) + own tuned LTS kernel, live-build/mmdebstrap, sysvinit/runit (antiX model). Horizon ~2028-2030.
2. Alpine x86 — smallest, fresh kernel; browser unconfirmed, x86 likely dropped next.
3. Gentoo x86 / Buildroot — max tuning, needs cross-compile/binhost.

Unverified: browsers on Alpine x86 / Void i686; Void i686 builds in 2026.

Sources: debian.org/News/2025/20250809, debian.org/News/2026/20260712, devuan excalibur release notes, alpinelinux.org/downloads, gentoo x86 autobuilds, mozilla blog 2025-09-05, debian pool chromium.
