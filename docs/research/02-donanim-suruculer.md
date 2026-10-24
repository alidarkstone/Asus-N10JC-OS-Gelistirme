# Asus N10JC component research (2026-10-24)

Source list: Ubuntu Laptop Testing Team N10JC-HV006 (BIOS 218).

| Component | Driver | Notes |
|---|---|---|
| Atom N270 | acpi-cpufreq, intel_idle, coretemp | P-states 1.60/1.33/1.07/0.80 GHz; schedutil; never p4-clockmod |
| ICH7-M SATA | ata_piix / ahci | AHCI may be absent in BIOS (IDE mode, no NCQ) |
| GMA 950 | i915 KMS + Mesa i915g, modesetting | ~GL 2.1, no VA-API/VDPAU |
| 9300M GS (G98) | nouveau + Mesa nv50 | ~GL 3.3; pstate reclock likely (test); 2026 Tesla fault recovery patches; VDPAU via VP3 firmware extracted from NVIDIA 325.15 (not redistributable, ship extractor) |
| nvidia-340 | — | not viable |
| RTL8111/8168B | r8169 | works |
| Atheros AR928X | ath9k | works, no firmware |
| ICH7 HDA | snd_hda_intel | auto-parser; hda-jack-retask if needed; get codec via alsa-info |
| BT-183 0b05:1712 | btusb | should work |
| Webcam 04f2:b071 | uvcvideo | image upside down -> libv4l flip / quirk |
| Card reader 058f:6366 | usb-storage | works |
| Fingerprint 147e:1000 UPEK TCS4C | libfprint upeksonly (likely) | unreliable |
| Hotkeys/backlight/ALS | asus-laptop (ATK0100) | ALS causes brightness jumps -> disable; pick acpi_backlight per GPU mode |
| Thermal/fan | ACPI + coretemp | EC controls fan |
| Suspend | S3/S4 | mem_sleep_default=deep; hibernate needs >=1 GB swapfile |

Hybrid graphics: physical switch + reboot (no mux). In NVIDIA mode BIOS hides GMA 950. No vga_switcheroo. Plan: detect GPU at boot, Intel = battery profile, nouveau = 3D/VDPAU profile.

Kernel: VMSPLIT_3G_OPT (or 2G_OPT), HIGHMEM=n for 1 GB.

To write/patch ourselves:
1. N10JC kernel config + DMI quirks (webcam flip, ALS off, backlight)
2. GPU-mode boot detection unit
3. First-boot VP3 firmware extractor helper
4. nouveau G98 testing (reclock, suspend), backport Tesla fault patches
5. HDA pin quirk if needed
6. Power tuning (schedutil, ath9k ps, ALPM, powertop defaults)
No new drivers needed.
