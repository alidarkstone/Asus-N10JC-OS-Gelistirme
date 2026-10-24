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
cp "$work/iso"/live/vmlinuz* "$work/vmlinuz"; cp "$work/iso"/live/initrd.img* "$work/initrd"
sudo unsquashfs -q -d "$work/root" "$work/iso/live/filesystem.squashfs" \
  etc/profile.d etc/xdg/openbox usr/local/bin etc/alternatives/x-session-manager >/dev/null
{
  echo "== /etc/profile.d/n10jc.sh"; cat "$work/root/etc/profile.d/n10jc.sh"
  echo "== /usr/local/bin"; ls -l "$work/root/usr/local/bin"
  echo "== x-session-manager -> $(readlink "$work/root/etc/alternatives/x-session-manager")"
  echo "== /etc/xdg/openbox"; ls -l "$work/root/etc/xdg/openbox"
} > "$out/image-files.txt" 2>&1
sudo umount "$work/iso"

accel="-accel tcg -cpu n270"
[ -w /dev/kvm ] && accel="-enable-kvm -cpu host"
qemu-system-i386 $accel -m 1024 -smp 2 -vga std -display none \
  -cdrom "$iso" -kernel "$work/vmlinuz" -initrd "$work/initrd" \
  -append "boot=live components locales=tr_TR.UTF-8 keyboard-layouts=tr timezone=Europe/Istanbul console=ttyS0,115200 console=tty1" \
  -serial file:"$out/serial.log" -monitor unix:"$work/mon",server,nowait &
qemu=$!

shot() { echo "screendump $work/$1.ppm" | socat - unix-connect:"$work/mon" >/dev/null
         sleep 1; convert "$work/$1.ppm" "$out/$1.png" 2>/dev/null; }
t=0
for at in 45 90 150 240; do
  sleep $((at - t)); t=$at
  kill -0 $qemu 2>/dev/null || break
  shot "desktop-${at}s"
done
echo quit | socat - unix-connect:"$work/mon" >/dev/null 2>&1
wait $qemu 2>/dev/null
echo "accel: $accel" >> "$out/image-files.txt"
ls -l "$out"
