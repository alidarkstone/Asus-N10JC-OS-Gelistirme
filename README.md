# N10 OS

Asus N10JC netbook'u (Atom N270, 1 GB DDR2, GMA 950 + GeForce 9300M GS, SSD) için hazırlanmış, Debian 12 i386 tabanlı hafif bir Linux.

## Neden böyle?
- **N270 yalnızca 32-bit** çalışır. Debian 12 i386'nın güvenlik desteği 30 Haziran 2028'e kadar sürüyor ve güncel bir i686 Chromium sunuyor.
- **Çekirdeği kendimiz derliyoruz** (6.18 LTS):
  - İşlemci: `MATOM`, `-march=bonnell`
  - Bellek: highmem kapalı. `VMSPLIT_2G` ile 1 GB'ın tamamı doğrudan adreslenir, PAE/NX de korunur. MGLRU açık, zram (lz4) kullanılıyor.
  - Gecikme: `PREEMPT_DYNAMIC`, `HZ=300`
- **systemd yok:** sysvinit + elogind. Bir sonraki adım runit.
- **Masaüstü:** Openbox + tint2 + plank + rofi. Görünüm WhiteSur teması ve Inter yazı tipi. Yalnızca gölge yapan hafif bir kompozitör (xrender) var.

## Hibrit grafik
N10JC'nin yanındaki fiziksel anahtarla GPU seçilir, değişiklik yeniden başlatınca geçerli olur. `n10-gpu-profile` açılışta hangi GPU'nun açık olduğunu algılar:
- **Intel modu (GMA 950, i915):** pil profili. CPU `schedutil`, SATA ve ses güç tasarrufu açık.
- **NVIDIA modu (9300M GS, nouveau):** performans profili. H.264 donanım çözme için bir kez `sudo n10-nouveau-firmware` çalıştırın.

## N10JC'ye özel düzeltmeler
- Webcam ters takılı olduğu için görüntü libv4l ile çevriliyor (`LIBV4LCONTROL_FLAGS=3`).
- Ortam ışık sensörü kapatılıyor (parlaklık zıplamasının sebebi).
- `p4_clockmod` engelli. N270'te gerçek EIST frekans adımları var.
- SSD için `mq-deadline` zamanlayıcı, /tmp RAM'de (128 MB), yazmalar küçük parçalar halinde yapılıyor.

## Derleme
```sh
# Debian bookworm x86_64 üzerinde, root olarak:
./build.sh                 # build/n10os-YYYYMMDD.iso
KERNEL_SERIES=6.18 ./build.sh
```
GitHub'da **Actions → Build N10 OS ISO → Run workflow** ile de derlenir. ISO, artifact olarak indirilir.

## USB'ye yazma
```sh
sudo dd if=n10os-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## Yol haritası
- [x] v0.1: canlı ISO, özel çekirdek, bellek/IO ayarları, GPU profili
- [ ] Gerçek donanımda test: ses kodeği, arka ışık arayüzü, uyku/uyanma, nouveau reclock
- [ ] Kurulum aracı (initramfs'siz kurulu sistem, hedef: 10 saniyenin altında açılış)
- [ ] runit'e geçiş
- [ ] Ayarlar paneli (GPU modu, pil, parlaklık)
