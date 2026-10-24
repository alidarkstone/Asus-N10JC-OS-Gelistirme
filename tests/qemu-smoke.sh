#!/bin/bash
# Boot the built ISO in QEMU (i386) and take screenshots of the live desktop, so a
# broken session is caught in CI instead of on the netbook.
# Usage: tests/qemu-smoke.sh build/n10os-*.iso out-dir
set -uo pipefail
iso=$1; out=$2
mkdir -p "$out"; out=$(realpath "$out")
work=$(mktemp -d)

# What actually landed in the image
mkdir -p "$work/iso"
sudo mount -o loop,ro "$iso" "$work/iso"
ls -l "$work/iso/live"
cp "$(ls "$work/iso"/live/vmlinuz* | head -1)" "$work/vmlinuz"
cp "$(ls "$work/iso"/live/initrd* | head -1)" "$work/initrd"
sudo unsquashfs -q -d "$work/root" "$work/iso/live/filesystem.squashfs" \
  etc/profile.d etc/xdg/openbox usr/local/bin etc/alternatives/x-session-manager usr/bin/calamares >/dev/null
{
  echo "== /etc/profile.d/n10jc.sh"; cat "$work/root/etc/profile.d/n10jc.sh"
  echo "== /usr/local/bin"; ls -l "$work/root/usr/local/bin"
  echo "== x-session-manager -> $(readlink "$work/root/etc/alternatives/x-session-manager")"
  echo "== installer: $(ls "$work/root/usr/bin/calamares" 2>/dev/null || echo MISSING)"
  echo "== /etc/xdg/openbox"; ls -l "$work/root/etc/xdg/openbox"
} > "$out/image-files.txt" 2>&1
sudo umount "$work/iso"

# Boot from a USB stick like the real netbook: ISO + free space for the Output partition
cp "$iso" "$work/usb.img"; truncate -s +256M "$work/usb.img"

accel="-accel tcg -cpu n270"
[ -w /dev/kvm ] && accel="-enable-kvm -cpu host"
qemu-system-i386 $accel -m 1024 -smp 2 -vga std -display none -device intel-hda -device hda-duplex,audiodev=snd0 -audiodev none,id=snd0 \
  -drive file="$work/usb.img",if=none,id=usb,format=raw -device qemu-xhci -device usb-storage,drive=usb,removable=on \
  -kernel "$work/vmlinuz" -initrd "$work/initrd" \
  -append "boot=live components timezone=Europe/Istanbul console=ttyS0,115200 console=tty1" \
  -serial file:"$out/serial.log" -monitor unix:"$work/mon",server,nowait &
qemu=$!

shot() { echo "screendump $work/$1.ppm" | socat - unix-connect:"$work/mon" >/dev/null
         sleep 1; convert "$work/$1.ppm" "$out/$1.png" 2>/dev/null; }
t=0
for at in 45 90 150 300; do  # n10-rapor runs at ~100 s
  sleep $((at - t)); t=$at
  kill -0 $qemu 2>/dev/null || break
  shot "desktop-${at}s"
done
# App menu via Alt+Space (same rofi menu as the ROG button)
echo "sendkey alt-spc" | socat - unix-connect:"$work/mon" >/dev/null; sleep 4; shot menu
echo quit | socat - unix-connect:"$work/mon" >/dev/null 2>&1
wait $qemu 2>/dev/null
echo "accel: $accel" >> "$out/image-files.txt"

# The diagnostics n10-rapor wrote to the stick's N10-OUTPUT partition
{ sfdisk -l "$work/usb.img"; } >> "$out/image-files.txt" 2>&1
start=$(sfdisk -J "$work/usb.img" | python3 -c 'import json,sys; p=json.load(sys.stdin)["partitiontable"]["partitions"]; print(p[1]["start"] if len(p)>1 else "")')
if [ -n "$start" ]; then
  mcopy -s -n -i "$work/usb.img@@$((start*512))" ::Output "$out/" && echo "Output partition: OK" >> "$out/image-files.txt"
else
  echo "Output partition: MISSING" >> "$out/image-files.txt"
fi
ls -l "$out"
