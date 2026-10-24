# N270 / 1 GB / GMA 950 — performance research (2026-10-24)

Key facts:
- Linux 7.1 removes i486/Elan; i686 (Atom) not slated for removal (highmem shrinking 2026-27). 
- Firefox 144 was last official 32-bit Linux build; ESR 140 i686 updates ended ~2026-09-29. Only distro/community builds remain.
- Pale Moon Linux now 64-bit+AVX only.
- sched_ext not usable on i686.

Priorities (impact order): zram + MGLRU + earlyoom > X11 WM without compositor > runit/no-initramfs > browser choice > kernel tuning.

## P1 Memory
- zram 100% RAM, lz4, prio 100 (optional zstd recompression)
- sysctl: vm.swappiness=180, vm.page-cluster=0, vm.watermark_boost_factor=0, vm.watermark_scale_factor=125, vm.vfs_cache_pressure=50
- zswap.enabled=0
- MGLRU: CONFIG_LRU_GEN=y, LRU_GEN_ENABLED=y, min_ttl_ms=1000
- earlyoom -m 4 -s 10 --prefer '(firefox|Web Content)' --avoid '(Xorg|labwc|openbox)'
- HIGHMEM4G=n + VMSPLIT_3G_OPT for 1 GB (HIGHMEM4G=y if upgraded to 2 GB)
- /tmp tmpfs size=128M, volatile journal

## P2 Kernel
- CONFIG_MATOM=y, KCFLAGS -march=bonnell -mtune=bonnell -O2
- PREEMPT_DYNAMIC + preempt=full, HZ=300, NO_HZ_IDLE
- EEVDF mainline; BORE untested on i686
- Bonnell in NO_SPECULATION list: mitigations=off gains nothing
- localmodconfig; built-in ahci, ext4/f2fs, i915, snd_hda_intel, wifi, zram
- no initramfs: root=PARTUUID=… rootwait quiet loglevel=3 i915.fastboot=1
- 9300M GS: nvidia-340 dead; disable in BIOS or nouveau/vga_switcheroo power-off

## P3 Boot
- runit (Void) or OpenRC (Alpine); autologin tty1 -> startx/labwc; target <10 s total

## P4 Desktop
- GMA 950: GL2.1/GLES2, no HW vertex shaders
- A: Openbox+tint2 or JWM, modesetting (no glamor) or intel SNA, picom xrender optional; ~110-150 MB idle
- B: labwc + sfwbar/waybar, WLR_RENDERER=pixman fallback; ~130-170 MB
- macOS look: WhiteSur/MacTahoe light, WhiteSur/Papirus icons, Inter 10pt, plank dock, rofi as Spotlight

## P5 Apps
- Firefox ESR from distro (verify), processCount=2, uBlock Origin; NetSurf as 2nd browser
- mpv --hwdec=no, profile=fast; H.264 480p smooth, 720p borderline; yt-dlp ≤480p avc1

## P6 SSD
- ext4 noatime,commit=60 + weekly fstrim (test TRIM first); avoid btrfs
- mq-deadline/none, no BFQ
- vm.dirty_bytes=33554432, vm.dirty_background_bytes=8388608
