# N10JC Windows 7 (32-bit), cihaza özel kurulum

Kendi orijinal Windows 7 ISO'nuzdan, Asus N10JC için hazırlanmış bir kurulum ISO'su üretir. Komut yazmanız gerekmez.

## Ne yapar?
- **Sürücüleri kuruluma gömer.** Kimlikler N10JC'nin kendi donanım raporundan alındı.
  - NVIDIA GeForce 9300M GS: NVIDIA'nın resmi 341.x dizüstü sürücüsü. Paket N10JC'nin ASUS alt kimliğini (`SUBSYS_19721043`) listelemiyorsa kit bu kimliği kendisi ekler.
  - Intel GMA 950, Realtek ALC662 ses, Atheros AR9281 Wi-Fi, RTL8111 Ethernet, ASUS BT-183 Bluetooth, ATK0100 (Fn tuşları), Chicony kamera, UPEK parmak izi: Microsoft'un resmi Windows Update Kataloğu'ndan, imzalı sürücüler.
  - Katalogda bulunamayan bir aygıt Windows 7'nin kendi sürücüsünü kullanır. Rapor hangisinin hangisi olduğunu söyler.
- **Güncellemeleri gömer:** SHA-2 desteği, servis yığınları, 2016 toplu güncellemesi (KB3125574) ve son ücretsiz aylık toplu güncelleme (Ocak 2020, KB4534310). ISO'nuz SP1 içermiyorsa SP1'i de ekler.
- **Türkçe menüler:** Ultimate sürümünü seçerseniz Microsoft'un resmi Türkçe dil paketi (KB2483139) kuruluma eklenir. Paket SHA-1 özeti ve Microsoft imzasıyla doğrulanır. Diğer sürümlerde Microsoft dil paketine izin vermediği için menüler İngilizce kalır; bölge, klavye ve saat yine Türkçe olur.
- **Hafifletir:** Media Center, Tablet PC, Faks, XPS, Araçlar (gadget) ve internet oyunları kapatılır. Superfetch, Windows Search, telemetri, Defender ve otomatik Windows Update taraması kapalıdır. Windows 7 artık güncelleme almadığı için bu tarama Atom işlemciyi saatlerce %100'de tutuyordu.
- **SSD ve 2 GB RAM ayarları:** TRIM açık, birleştirme görevi kapalı, hazırda bekletme kapalı (2 GB yer açılır), sayfa dosyası sabit 1-3 GB, sistem geri yükleme kapalı.
- **Görünüm:** Aero açık ama şeffaflık, animasyonlar, gölgeler ve Aero Peek kapalı. Opak koyu gri çerçeveler, ClearType, N10 OS duvar kağıdı, Türkçe Q klavye ve Türkiye saati kullanılır.
- **Oyun için:** DirectX 9.0c (Haziran 2010), Visual C++ 2005-2022, PhysX ve OpenAL. Crysis dönemi oyunların istediği bileşenler bunlar.
- **Uygulamalar:** Supermium (Windows 7'de çalışan güncel Chromium tarayıcı), 7-Zip ve MPC-HC (9300M ile donanım hızlandırmalı video).
- **Otomatik rapor:** Her açılıştan 2 dakika sonra donanım, sürücü ve etkinleştirme raporu `C:\N10\Output` klasörüne ve takılı USB belleğin **Output** klasörüne yazılır.

## Kaynak doğrulama
HAZIRLA, işe başlamadan önce kaynağı denetler ve şüpheli bir kopyada durur:
- ISO'nun SHA-1 özetini hesaplar ve `bilinen-iso-ozetleri.txt` listesiyle karşılaştırır. Listeye yalnızca doğrulanmış resmi değerler eklenir.
- Kurulum dosyalarının (setup, bootsect) Microsoft imzalı olup olmadığına bakar. Medyada önceden eklenmiş `$OEM$` klasörü veya hazır yanıt dosyası olup olmadığını da kontrol eder. Bunlar "hazır etkinleştirilmiş" kopyaların izleridir.
- Windows imajının içinde önyükleme ve lisans dosyalarının (winload, ntoskrnl, ci, hal, sppsvc) değiştirilmemiş Microsoft imzalı dosyalar olduğunu doğrular.

## Etkinleştirme
Windows yalnızca **sizin kendi orijinal ürün anahtarınızla** etkinleştirilir (örneğin bir bilgisayarın altındaki COA etiketi veya satın aldığınız lisans). Kit anahtarınızı otomatik kurulum dosyasına yazar. İnternete bağlanınca etkinleştirmeyi de kendisi dener ve sonucu rapora yazar. Çevrimiçi etkinleştirme olmazsa `slui 4` ile telefonla etkinleştirme yapılabilir. Kırma araçları, KMS taklitçileri veya "loader"lar kullanılmaz.

Anahtar sürümle eşleşmeli. Örneğin Home Premium anahtarı yalnızca Home Premium'u etkinleştirir.

## Kullanım (Windows 10/11 bilgisayarda)
1. Kaynak olarak üç seçenek var: orijinal **Windows 7 32-bit (x86)** ISO'nuzu `iso` alt klasörüne koyun, Windows 7 DVD'nizi ya da kurulum USB'nizi takın, ya da hiçbirini yapmayın, program ISO dosyasını size sorar. Microsoft Windows 7 ISO indirmesini kapattığı için kit ISO'yu kendisi indirmez.
2. **`HAZIRLA.cmd`** dosyasına çift tıklayıp yönetici iznini verin.
3. Açılan pencerelerde ISO'yu, sürümü ve ürün anahtarınızı seçin. Anahtarı boş bırakabilirsiniz.
4. İndirme ve hazırlık 30-60 dakika sürer. Bittiğinde `C:\N10-Win7\cikti` klasörü açılır. Orada ISO ve `RAPOR_*.txt` bulunur.
5. ISO'yu [Rufus](https://rufus.ie) ile USB'ye yazın: **Bölüm düzeni: MBR**, **Hedef sistem: BIOS**.
6. N10JC'de USB'den açın (açılışta **Esc** tuşuyla önyükleme menüsü gelir). Kurulum yalnızca hangi diske ya da bölüme kurulacağını sorar, gerisini kendisi yapar.

Değiştirmek isterseniz `ayarlar.ornek.ini` dosyasını `ayarlar.ini` adıyla kopyalayıp düzenleyin. Bu dosyada kullanıcı adı, şifre, sürüm, ürün anahtarı ve .NET 4.8 seçeneği vardır. `ayarlar.ini` depoya gönderilmez.

## Hibrit grafik
Yandaki fiziksel anahtar Linux'taki gibi çalışır. Konumunu değiştirip yeniden başlatın. Her iki GPU'nun sürücüsü de sistemde hazır bekler. Oyunlar için **NVIDIA** konumunu, pil ömrü için **Intel** konumunu seçin.

## Bilinen sınırlar
- 9300M GS DirectX 10 kartıdır. Crysis düşük ayarlarda, 800x600 civarında oynanabilir. DLSS ve benzeri teknolojiler bu kartta yoktur.
- BIOS'ta SATA IDE modundaysa Windows 7'nin IDE sürücüsü TRIM komutunu SSD'ye iletmez. Bu durum SSD'ye zarar vermez, yalnızca uzun vadede yazma hızı biraz düşebilir.
- Windows 7'nin güvenlik güncellemeleri 2020'de bitti. İnternette yalnızca Supermium'la gezin ve bilinmeyen dosyaları açmayın.

## Dosyalar
| Dosya | Görev |
|---|---|
| `HAZIRLA.cmd` | Başlatıcı (yönetici izni ister) |
| `scripts/hazirla.ps1` | ISO açma, DISM ile güncelleme, sürücü ve ayar entegrasyonu, ISO üretimi |
| `scripts/indir.ps1` | Sürücü, güncelleme ve uygulama indirme (NVIDIA INF düzeltmesi dahil) |
| `scripts/ince-ayar.ps1` | Çevrimdışı kayıt defteri ayarları |
| `scripts/autounattend.sablon.xml` | Otomatik kurulum şablonu |
| `oem/` | Kurulum sonrası betikler (`SetupComplete.cmd`, ilk giriş, açılış raporu) |
| `tests/kit-testi.ps1` | GitHub Actions testi (Windows ISO'su olmadan her şeyi dener) |
