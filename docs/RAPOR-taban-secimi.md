# Asus N10JC OS: araştırma özeti ve taban önerisi

*24 Ekim 2026. Ayrıntılı notlar: `research/01-dagitim-tabanlari.md`, `research/02-donanim-suruculer.md`, `research/03-performans.md`*

## En önemli üç gerçek

1. **Atom N270 yalnızca 32-bit (i686) çalışır.** Çoğu dağıtım i686'yı bıraktı: MX 25, NixOS, Debian 13 kurulum ve çekirdeği. Çekirdeğin kendisi i686'yı uzun süre destekleyecek; Linux 7.1 sadece i486'yı kaldırıyor.
2. **Tarayıcı belirleyici.** Resmi 32-bit Firefox Eylül 2026'da bitti. Güvenlik yaması alan tek güncel i686 tarayıcı Debian'ın derlediği **Chromium**. Yedek tarayıcı olarak NetSurf veya WebKitGTK tabanlı hafif tarayıcılar var.
3. **Hibrit grafik fiziksel anahtarla çalışıyor** (anahtar + yeniden başlatma, canlı geçiş yok). Yeni sürücü yazmaya gerek yok:
   - Intel modu: i915 sürücüsü, pil için.
   - NVIDIA modu: nouveau sürücüsü. OpenGL 3.3 ve H.264 donanım çözme verir (VDPAU, firmware'i makinede çıkarmak gerekiyor). nvidia-340 artık çalışmıyor.

## Taban karşılaştırması (özet)

| Sıra | Taban | Artı | Eksi |
|---|---|---|---|
| **1** | **Debian 12 i386 kullanıcı alanı + kendi çekirdeğimiz** | Güvenlik desteği 30 Haziran 2028'e kadar. Güncel Chromium var. live-build ile ISO üretmek kolay. antiX bu modeli zaten kanıtlıyor. | Açılış RAM'i biraz daha yüksek (runit/sysvinit ile düşürülür). Ufuk 2028–2030. |
| 2 | Alpine x86 | En küçük boyut (40–80 MB), taze çekirdek | Tarayıcısı doğrulanmadı. x86 desteği ilk bırakılacak mimari olabilir. |
| 3 | Gentoo x86 / Buildroot | Her şey `-march=bonnell` ile derlenir, tam kontrol | Derlemeyi güçlü bir PC'de yapmak gerekir. Güvenlik güncellemelerinin hepsi bize kalır. |

Elenenler: MX Linux, NixOS, Arch Linux 32 (durgun), Slackware 15, postmarketOS.

## Önerilen mimari ("N10 OS")

- **Taban:** Debian 12 bookworm i386. Hazır olduğunda kullanıcı alanı trixie'ye taşınır.
- **Çekirdek:** kendimiz derliyoruz, 6.18 LTS.
  - Derleme: `MATOM`, `-march=bonnell`, `PREEMPT_DYNAMIC`, `HZ=300`.
  - Bellek: `HIGHMEM=n` + `VMSPLIT_3G_OPT` (1 GB'ın tamamı doğrudan kullanılır), MGLRU.
  - Gerekli sürücüler çekirdeğe gömülü, initramfs yok.
- **Init:** runit veya sysvinit, systemd yok. tty1'de otomatik giriş, ardından masaüstü.
- **Bellek:** zram (lz4, RAM'in %100'ü), swappiness 180, earlyoom. Pratikte yaklaşık 1,7 GB kullanılabilir bellek.
- **Masaüstü:** Openbox + tint2 + plank + rofi, macOS görünümü (WhiteSur teması, Inter yazı tipi), kompozitör yok. Açılışta yaklaşık 120–150 MB RAM.
- **N10JC'ye özel parçalar** (bunları biz yazacağız):
  - Açılışta hangi GPU'nun açık olduğunu algılayıp uygun profili seçen servis
  - VDPAU firmware'ini ilk açılışta çıkaran yardımcı
  - Webcam ters görüntü düzeltmesi
  - Ortam ışık sensörünü kapatma (parlaklık zıplamasını yapıyor)
  - Güç ayarları
- **SSD:** ext4 (`noatime`) + haftalık `fstrim`, `mq-deadline` zamanlayıcı.
- **Hedefler:**
  - Güç düğmesinden masaüstüne 10 saniyenin altında
  - Video: 480p H.264 akıcı oynar (NVIDIA modunda 720p ve üstü)
