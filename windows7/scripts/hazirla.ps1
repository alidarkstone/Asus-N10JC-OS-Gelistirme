# N10JC Windows 7 kiti: sizin orijinal Windows 7 32-bit ISO'nuzdan N10JC'ye özel kurulum ISO'su üretir.
# HAZIRLA.cmd tarafından yönetici olarak çalıştırılır. Komut yazmanız gerekmez.
param([string]$Kok = 'C:\N10-Win7')
Import-Module (Join-Path $PSScriptRoot 'N10Ortak.psm1') -Force
Add-Type -AssemblyName System.Windows.Forms, Microsoft.VisualBasic, System.Drawing

$kit = Split-Path $PSScriptRoot
$is = Join-Path $Kok 'is'
$onbellek = Join-Path $Kok 'onbellek'
$cikti = Join-Path $Kok 'cikti'
$isoKlasor = Join-Path $is 'iso'
$mount = Join-Path $is 'mount'
$zaman = Get-Date -Format 'yyyy-MM-dd_HH-mm'
$gunluk = Join-Path $cikti "derleme_$zaman.log"
Set-N10Log $gunluk

function Dur([string]$Mesaj) {
    Write-N10Log $Mesaj 'HATA'
    [void][Windows.Forms.MessageBox]::Show("$Mesaj`n`nAyrıntılar: $gunluk", 'N10JC Windows 7', 'OK', 'Error')
    exit 1
}
# Kit dosyaları eksik ya da eski kalmışsa (ör. yarım kopyalanmış klasör) hiçbir denetim atlanmadan baştan durulur.
$gerekli = 'Write-N10Log', 'Add-N10Ozet', 'Test-N10MsImza', 'Test-N10Medya', 'Test-N10Imaj', 'Invoke-N10Denetim', 'New-N10Iso', 'Get-N10SevenZip'
$eksik = @($gerekli | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })
if ($eksik) { Dur ("Kit dosyaları eksik veya eski (bulunamayan: $($eksik -join ', ')).`n`nKit klasörünü güncel hâliyle yeniden kopyalayıp tekrar deneyin.") }

function DismCalistir([string[]]$Arg, [int[]]$Kabul = @(0)) {
    $out = & dism.exe /English @Arg 2>&1
    $kod = $LASTEXITCODE
    Add-Content -Path $gunluk -Value ($out | Out-String) -Encoding UTF8
    if ($Kabul -notcontains $kod) { throw "DISM hata kodu $kod ($($Arg -join ' '))" }
    return $kod
}

# ---------------- 1) Ayarlar ----------------
$ayar = @{}
$ini = Join-Path $kit 'ayarlar.ini'
if (-not (Test-Path $ini)) { $ini = Join-Path $kit 'ayarlar.ornek.ini' }
foreach ($s in Get-Content -Encoding UTF8 $ini) {
    if ($s -match '^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$') { $ayar[$Matches[1]] = $Matches[2] }
}
foreach ($k in 'URUN_ANAHTARI', 'SURUM', 'KULLANICI', 'SIFRE', 'BILGISAYAR_ADI', 'NETFX48') { if (-not $ayar.ContainsKey($k)) { $ayar[$k] = '' } }
if (-not $ayar.KULLANICI) { $ayar.KULLANICI = 'darkstone' }
if (-not $ayar.BILGISAYAR_ADI) { $ayar.BILGISAYAR_ADI = 'N10JC' }
Write-N10Log "N10JC Windows 7 kiti başladı. Çalışma klasörü: $Kok"

# ---------------- 2) ISO ----------------
# Kaynak: kit klasöründeki ISO, takılı Windows 7 DVD'si/kurulum USB'si ya da seçilen ISO dosyası.
$iso = Get-ChildItem -Path (Join-Path $kit 'iso'), $Kok -Filter *.iso -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notlike "$cikti*" } | Select-Object -First 1
$surucu = $null
if ($iso) { $iso = $iso.FullName } else {
    foreach ($d in Get-WmiObject Win32_LogicalDisk -Filter 'DriveType=5 OR DriveType=2') {
        if ((Test-Path "$($d.DeviceID)\sources\install.wim") -and (Test-Path "$($d.DeviceID)\setup.exe")) {
            $cevap = [Windows.Forms.MessageBox]::Show("$($d.DeviceID) sürücüsünde bir Windows kurulum diski/USB'si bulundu ($($d.VolumeName)).`n`nBundan hazırlansın mı?", 'N10JC Windows 7', 'YesNo', 'Question')
            if ($cevap -eq 'Yes') { $surucu = $d.DeviceID; break }
        }
    }
    if (-not $surucu) {
        $dlg = New-Object Windows.Forms.OpenFileDialog
        $dlg.Title = 'Orijinal Windows 7 32-bit (x86) ISO dosyanızı seçin'
        $dlg.Filter = 'ISO dosyası (*.iso)|*.iso'
        if ($dlg.ShowDialog() -ne 'OK') { Dur 'ISO seçilmedi. Windows 7 DVD''nizi takıp tekrar da deneyebilirsiniz.' }
        $iso = $dlg.FileName
    }
}
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $isoKlasor
New-Item -ItemType Directory -Force $isoKlasor, $mount, $cikti | Out-Null
if ((& dism.exe /English /Get-MountedWimInfo) -match [regex]::Escape($mount)) { DismCalistir @('/Unmount-Wim', "/MountDir:$mount", '/Discard') -Kabul 0, 1 | Out-Null }

function Kopyala([string]$Kaynak) {
    Write-N10Log "Kurulum dosyaları kopyalanıyor ($Kaynak)..."
    & robocopy.exe "$Kaynak\" $isoKlasor /E /NFL /NDL /NJH /NJS /R:1 /W:1 | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy $LASTEXITCODE" }
}
if ($surucu) {
    Write-N10Log "Kaynak: $surucu kurulum diski"
    Kopyala $surucu
} else {
    Write-N10Log "ISO: $iso"
    $disk = Mount-DiskImage -ImagePath $iso -PassThru
    try { Kopyala "$(($disk | Get-Volume).DriveLetter):" }
    finally { Dismount-DiskImage -ImagePath $iso | Out-Null }
}
Get-ChildItem -Recurse $isoKlasor | ForEach-Object { if (-not $_.PSIsContainer) { $_.IsReadOnly = $false } }

$wim = Join-Path $isoKlasor 'sources\install.wim'
if (-not (Test-Path $wim)) { Dur 'Bu ISO''da sources\install.wim yok. Orijinal bir Windows 7 ISO''su gerekiyor.' }

# ---------------- 2b) Kaynak doğrulama ----------------
# Kitin içindeki listede bu ISO'nun SHA-1 değeri varsa karşılaştırılır; her durumda Microsoft imzaları denetlenir.
$dogrulama = @()
if ($iso) {
    Write-N10Log 'ISO''nun SHA-1 özeti hesaplanıyor...'
    $sha1 = (Get-FileHash -Algorithm SHA1 -Path $iso).Hash.ToUpper()
    $liste = Join-Path $kit 'bilinen-iso-ozetleri.txt'
    $eslesen = $null
    if (Test-Path $liste) {
        foreach ($s in Get-Content -Encoding UTF8 $liste) {
            if ($s -match '^\s*([0-9A-Fa-f]{40})\s+(.+)$' -and $Matches[1].ToUpper() -eq $sha1) { $eslesen = $Matches[2].Trim() }
        }
    }
    $dogrulama += "SHA-1: $sha1"
    if ($eslesen) { $dogrulama += "SHA-1 resmi listedeki kayıtla eşleşti: $eslesen" }
    else { $dogrulama += 'SHA-1 kitin listesinde yok; Microsoft imza denetimine göre karar verildi.' }
}
# Denetim hiç çalışamazsa geçmiş sayılmaz: hata da "orijinal değil" gibi durdurur.
$medyaSorun = Invoke-N10Denetim { Test-N10Medya $isoKlasor } 'Medya denetimi'
if ($medyaSorun) {
    Dur ("BU KAYNAK ORİJİNAL GÖRÜNMÜYOR, hazırlık durduruldu:`n`n- " + ($medyaSorun -join "`n- ") +
        "`n`nLütfen kendi orijinal Windows 7 diskinizi veya Microsoft'tan aldığınız ISO'yu kullanın.")
}
$dogrulama += 'Kurulum dosyaları Microsoft imzalı, medyada yabancı dosya yok.'
foreach ($d in $dogrulama) { Write-N10Log "Doğrulama: $d" 'TAMAM' }

# ---------------- 3) Sürüm seçimi ----------------
$imajlar = @(Get-WindowsImage -ImagePath $wim | ForEach-Object { Get-WindowsImage -ImagePath $wim -Index $_.ImageIndex })
$imajlar = @($imajlar | Where-Object { $_.Architecture -eq 0 })   # 0 = x86
if (-not $imajlar) { Dur 'ISO''da 32-bit (x86) Windows yok. Atom N270 yalnızca 32-bit çalıştırır; x86 ISO gerekiyor.' }
$secim = $null
if ($ayar.SURUM) { $secim = $imajlar | Where-Object { $_.ImageName -match [regex]::Escape($ayar.SURUM) } | Select-Object -First 1 }
if (-not $secim -and $imajlar.Count -eq 1) { $secim = $imajlar[0] }
if (-not $secim) {
    $secim = $imajlar | Select-Object ImageIndex, ImageName, @{ n = 'Dil'; e = { $_.Languages -join ',' } } |
        Out-GridView -Title 'Kurulacak Windows 7 sürümünü seçin (ürün anahtarınız hangi sürüme aitse)' -OutputMode Single
    if (-not $secim) { Dur 'Sürüm seçilmedi.' }
    $secim = $imajlar | Where-Object { $_.ImageIndex -eq $secim.ImageIndex }
}
$dil = @($secim.Languages)[0]
$yapi = [int]($secim.Version -split '\.')[2]
Write-N10Log "Seçilen: $($secim.ImageName) (dizin $($secim.ImageIndex), dil $dil, yapı $($secim.Version))"
if ($secim.Version -notmatch '^6\.1\.') { Dur 'Bu bir Windows 7 imajı değil.' }

# ---------------- 4) Ürün anahtarı ----------------
$anahtar = ($ayar.URUN_ANAHTARI -replace '\s', '').ToUpper()
if (-not $anahtar) {
    $anahtar = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Kendi orijinal Windows 7 ürün anahtarınızı yazın (ör. bilgisayarın altındaki COA etiketi).`n`n" +
        "Boş bırakırsanız kurulum sırasında sorulur, sonra da girebilirsiniz.`n`nSeçilen sürüm: $($secim.ImageName)",
        'N10JC Windows 7: ürün anahtarı', '').Trim().ToUpper()
}
if ($anahtar -and $anahtar -notmatch '^[A-Z0-9]{5}(-[A-Z0-9]{5}){4}$') { Dur "Ürün anahtarı biçimi hatalı: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX olmalı." }

# ---------------- 5) İndirmeler ----------------
$indirArg = @{ Onbellek = $onbellek; Gunluk = $gunluk }
if ($yapi -lt 7601) { $indirArg['SP1Gerekli'] = $true }
# Türkçe menüler yalnızca Ultimate/Enterprise'ta dil paketiyle mümkün; diğer sürümlerde bölge/klavye/saat Türkçe olur.
$turkceArayuz = ($dil -ne 'tr-TR') -and ($secim.ImageName -match 'Ultimate|Enterprise')
if ($turkceArayuz) { $indirArg['TurkceDilPaketi'] = $true }
if ($ayar.NETFX48 -eq '1') { $indirArg['NetFx48'] = $true }
& (Join-Path $PSScriptRoot 'indir.ps1') @indirArg
Import-Module (Join-Path $PSScriptRoot 'N10Ortak.psm1') -Force
Set-N10Log $gunluk

# ---------------- 6) İmajı tek sürüme indir ve bağla ----------------
$tekWim = Join-Path $is 'install.wim'
Remove-Item -Force -ErrorAction SilentlyContinue $tekWim
# SP1 ve dil paketi eklenmiş imaj önbellekte saklanır; sonraki denemelerde bu uzun adım atlanır.
$noktaKlasor = Join-Path $onbellek 'imaj'
$noktaAd = ('{0}_{1}_{2}' -f $secim.ImageIndex, $secim.Version, $secim.ImageSize) -replace '[^\w\.-]', ''
$noktaTr = Join-Path $noktaKlasor "$noktaAd-tr.wim"
$noktaEn = Join-Path $noktaKlasor "$noktaAd-en.wim"
$nokta = $null
if ($turkceArayuz -and (Test-Path $noktaTr)) { $nokta = $noktaTr } elseif (-not $turkceArayuz -and (Test-Path $noktaEn)) { $nokta = $noktaEn }
$tabanHazir = [bool]$nokta
if ($tabanHazir) {
    Write-N10Log "Önceki denemeden kalan SP1'li imaj kullanılıyor: $(Split-Path -Leaf $nokta)" 'TAMAM'
    Copy-Item -Force $nokta $tekWim
    if ($nokta -eq $noktaTr) { $dil = 'tr-TR' }
} else {
    Write-N10Log 'Seçilen sürüm ayrı bir imaja aktarılıyor...'
    DismCalistir @('/Export-Image', "/SourceImageFile:$wim", "/SourceIndex:$($secim.ImageIndex)", "/DestinationImageFile:$tekWim", '/Compress:max') | Out-Null
}
Write-N10Log 'İmaj bağlanıyor...'
DismCalistir @('/Mount-Wim', "/WimFile:$tekWim", '/Index:1', "/MountDir:$mount") | Out-Null
$imajSorun = Invoke-N10Denetim { Test-N10Imaj $mount } 'İmaj denetimi'
if ($imajSorun) {
    & dism.exe /English /Unmount-Wim "/MountDir:$mount" /Discard | Out-Null
    Dur ("WINDOWS İMAJI DEĞİŞTİRİLMİŞ, hazırlık durduruldu:`n`n- " + ($imajSorun -join "`n- ") +
        "`n`nÖnyükleme veya lisans dosyaları Microsoft'un orijinali değil. Bu tür kopyalar zararlı yazılım taşıyabilir.")
}
Write-N10Log 'Doğrulama: önyükleme ve lisans dosyaları Microsoft imzalı.' 'TAMAM'
$dogrulama += 'Önyükleme ve lisans dosyaları (winload, ntoskrnl, sppsvc...) Microsoft imzalı.'

$guncellemeSonuc = @()
try {
    $img = "/Image:$mount"
    # SP1 (gerekirse)
    # indir.ps1 SP1'i çevrimdışı entegrasyon için açar; DISM'e KB976933 bildirimi verilir.
    $sp1 = Get-ChildItem (Join-Path $onbellek 'guncellemeler\sp1\paket') -Filter 'Windows7SP1-KB976933~31bf3856ad364e35~x86~~6.1.1.17514.mum' -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $tabanHazir -and $yapi -lt 7601) {
        if (-not $sp1) { throw 'ISO SP1 içermiyor ve SP1 paketi hazırlanamadı.' }
        Write-N10Log 'Service Pack 1 ekleniyor (uzun sürer)...'
        DismCalistir @($img, '/Add-Package', "/PackagePath:$sp1") -Kabul 0, 3010 | Out-Null
    }
    # Türkçe dil paketi (güncellemelerden önce eklenir ki güncellemelerin Türkçe dosyaları da gelsin)
    $lp = Join-Path $onbellek 'guncellemeler\dil-tr\lp.cab'
    if ($tabanHazir) { }
    elseif ($turkceArayuz -and (Test-Path $lp)) {
        Write-N10Log 'Türkçe dil paketi ekleniyor...'
        $eklendi = $false
        try { DismCalistir @($img, '/Add-Package', "/PackagePath:$lp") -Kabul 0, 3010 | Out-Null; $eklendi = $true }
        catch { Write-N10Log "  dil paketi eklenemedi: $($_.Exception.Message)" 'UYARI' }
        if ($eklendi) {
            DismCalistir @($img, '/Set-AllIntl:tr-TR') | Out-Null
            DismCalistir @($img, '/Set-SKUIntlDefaults:tr-TR') -Kabul 0, 87 | Out-Null
            $dil = 'tr-TR'
            Write-N10Log 'Türkçe arayüz eklendi.' 'TAMAM'
        } else { Write-N10Log 'Türkçe dil paketi eklenemedi; menüler İngilizce kalacak (ayrıntı günlükte).' 'UYARI' }
    } elseif ($turkceArayuz) { Write-N10Log 'Türkçe dil paketi bulunamadı; menüler İngilizce kalacak.' 'UYARI' }
    if (-not $tabanHazir -and ($yapi -lt 7601 -or $dil -eq 'tr-TR')) {
        # Ara kayıt: imaj kaydedilip önbelleğe kopyalanır, sonra yeniden bağlanır.
        Write-N10Log 'SP1/dil paketi eklenmiş imaj önbelleğe kaydediliyor...'
        DismCalistir @('/Unmount-Wim', "/MountDir:$mount", '/Commit') | Out-Null
        New-Item -ItemType Directory -Force $noktaKlasor | Out-Null
        Get-ChildItem $noktaKlasor -Filter "$noktaAd-*.wim" | Remove-Item -Force
        Copy-Item -Force $tekWim $(if ($dil -eq 'tr-TR') { $noktaTr } else { $noktaEn })
        DismCalistir @('/Mount-Wim', "/WimFile:$tekWim", '/Index:1', "/MountDir:$mount") | Out-Null
        Write-N10Log 'Ara kayıt tamam; bir sonraki denemede SP1 ve dil paketi adımı atlanır.' 'TAMAM'
    }
    # Güncellemeler
    $siraDosya = Join-Path $onbellek 'guncellemeler\sira.json'
    # ConvertFrom-Json (PowerShell 5) diziyi tek nesne olarak verir; boru hattı onu tek tek güncellemelere açar.
    $sira = @(Get-Content -Raw $siraDosya | ConvertFrom-Json | ForEach-Object { $_ }) | Sort-Object Sira
    foreach ($g in $sira) {
        Write-N10Log "Güncelleme ekleniyor: $($g.KB) - $($g.Not)"
        $kod = & dism.exe /English $img /Add-Package "/PackagePath:$(Join-Path $onbellek "guncellemeler\$($g.Dosya)")" 2>&1
        $c = $LASTEXITCODE
        Add-Content -Path $gunluk -Value ($kod | Out-String) -Encoding UTF8
        $dr = switch ($c) { 0 { 'TAMAM' } 3010 { 'TAMAM' } -2146498530 { 'Gerekmedi' } default { "HATA ($c)" } }
        Write-N10Log "  $($g.KB): $dr" $(if ($dr -like 'HATA*') { 'UYARI' } else { 'TAMAM' })
        $guncellemeSonuc += [pscustomobject]@{ Konu = "Entegre: $($g.KB)"; Durum = $dr; Ayrinti = $g.Not }
    }
    # Sürücüler
    $surDizin = Join-Path $onbellek 'suruculer'
    $sonraKurulacak = @()
    foreach ($k in Get-ChildItem $surDizin -Directory -ErrorAction SilentlyContinue) {
        if (-not (Get-ChildItem $k.FullName -Recurse -Filter *.inf)) { continue }
        Write-N10Log "Sürücü ekleniyor: $($k.Name)"
        try {
            DismCalistir @($img, '/Add-Driver', "/Driver:$($k.FullName)", '/Recurse', '/ForceUnsigned') | Out-Null
            Write-N10Log "  $($k.Name): TAMAM" 'TAMAM'
            $guncellemeSonuc += [pscustomobject]@{ Konu = "Sürücü: $($k.Name)"; Durum = 'TAMAM'; Ayrinti = 'imaja eklendi' }
        } catch {
            # Bir sürücünün eklenememesi hazırlığı durdurmaz; sürücü kurulumdan sonra (ilk açılışta) yüklenir.
            Write-N10Log "  $($k.Name) imaja eklenemedi ($($_.Exception.Message)); Windows kurulduktan sonra yüklenecek." 'UYARI'
            $sonraKurulacak += $k
            $guncellemeSonuc += [pscustomobject]@{ Konu = "Sürücü: $($k.Name)"; Durum = 'Kurulumdan sonra'; Ayrinti = 'imaja eklenemedi' }
            $sapi = Join-Path $mount 'Windows\inf\setupapi.offline.log'
            if (Test-Path $sapi) { Copy-Item -Force $sapi (Join-Path $cikti "setupapi.offline_$zaman.log") }
        }
    }
    # Gereksiz özellikler (yer ve bellek)
    foreach ($f in 'MediaCenter', 'TabletPCOC', 'FaxServicesClientPackage', 'Xps-Foundation-Xps-Viewer', 'Printing-XPSServices-Features',
        'WindowsGadgetPlatform', 'Internet Games', 'OpticalMediaDisc', 'MSRDC-Infrastructure') {
        $null = & dism.exe /English $img /Disable-Feature "/FeatureName:$f" 2>&1
        Write-N10Log "  Özellik kapatıldı: $f ($LASTEXITCODE)"
    }
    # Kayıt defteri ayarları, duvar kağıdı, logo
    $duvar = Join-Path $kit 'assets\duvar.jpg'
    $logoPng = Join-Path $kit 'assets\rog-logo.png'
    $logoBmp = $null
    if (Test-Path $logoPng) {
        $logoBmp = Join-Path $is 'n10-logo.bmp'
        $kaynak = [Drawing.Image]::FromFile($logoPng)
        $bmp = New-Object Drawing.Bitmap 120, 120
        $gr = [Drawing.Graphics]::FromImage($bmp)
        $gr.Clear([Drawing.Color]::White); $gr.InterpolationMode = 'HighQualityBicubic'
        $gr.DrawImage($kaynak, 4, 4, 112, 112)
        $bmp.Save($logoBmp, [Drawing.Imaging.ImageFormat]::Bmp)
        $gr.Dispose(); $bmp.Dispose(); $kaynak.Dispose()
    }
    $p = @{ Mount = $mount }
    if (Test-Path $duvar) { $p['DuvarKagidi'] = $duvar }
    if ($logoBmp) { $p['Logo'] = $logoBmp }
    & (Join-Path $PSScriptRoot 'ince-ayar.ps1') @p
    Set-N10Log $gunluk

    Write-N10Log 'İmaj kaydediliyor...'
    DismCalistir @('/Unmount-Wim', "/MountDir:$mount", '/Commit') | Out-Null
} catch {
    Write-N10Log "Hata: $($_.Exception.Message). Değişiklikler geri alınıyor." 'HATA'
    & dism.exe /English /Unmount-Wim "/MountDir:$mount" /Discard | Out-Null
    Dur "İmaj hazırlanamadı: $($_.Exception.Message)"
}

# Son aktarım imajı küçültür (güncellemelerden kalan boşluklar atılır)
Write-N10Log 'İmaj sıkıştırılıyor...'
Remove-Item -Force $wim
DismCalistir @('/Export-Image', "/SourceImageFile:$tekWim", '/SourceIndex:1', "/DestinationImageFile:$wim", '/Compress:max') | Out-Null
Remove-Item -Force $tekWim

# ---------------- 7) Otomatik kurulum ve kurulum sonrası dosyalar ----------------
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $isoKlasor 'sources\ei.cfg')
$kesBlok = ''
if ($anahtar) { $kesBlok = "        <ProductKey>`r`n          <Key>$anahtar</Key>`r`n          <WillShowUI>OnError</WillShowUI>`r`n        </ProductKey>" }
function Xml([string]$s) { [Security.SecurityElement]::Escape($s) }
$xml = (Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'autounattend.sablon.xml')).
    Replace('{{UILANG}}', $dil).Replace('{{USER}}', (Xml $ayar.KULLANICI)).Replace('{{PASSWORD}}', (Xml $ayar.SIFRE)).
    Replace('{{COMPUTER}}', (Xml $ayar.BILGISAYAR_ADI)).Replace('{{KEY_BLOCK}}', $kesBlok)
[IO.File]::WriteAllText((Join-Path $isoKlasor 'autounattend.xml'), $xml, (New-Object Text.UTF8Encoding $false))

$oem = Join-Path $isoKlasor 'sources\$OEM$'
New-Item -ItemType Directory -Force "$oem\`$`$\Setup\Scripts", "$oem\`$1\N10\uygulamalar" | Out-Null
Copy-Item -Force (Join-Path $kit 'oem\Setup-Scripts\*') "$oem\`$`$\Setup\Scripts"
Copy-Item -Force (Join-Path $kit 'oem\N10\*') "$oem\`$1\N10"
Copy-Item -Force (Join-Path $onbellek 'uygulamalar\*') "$oem\`$1\N10\uygulamalar"
foreach ($k in $sonraKurulacak) {
    $hedef = "$oem\`$1\N10\suruculer\$($k.Name)"
    New-Item -ItemType Directory -Force $hedef | Out-Null
    Copy-Item -Recurse -Force (Join-Path $k.FullName '*') $hedef
}

# ---------------- 8) ISO ----------------
$cikIso = Join-Path $cikti "N10JC-Win7-$zaman.iso"
Write-N10Log "ISO oluşturuluyor: $cikIso"
New-N10Iso -Kaynak $isoKlasor -Hedef $cikIso -Etiket 'N10JC_WIN7' -BootDosyasi (Join-Path $isoKlasor 'boot\etfsboot.com')

# ---------------- 9) Rapor ----------------
$ozet = @()
$ozetDosya = Join-Path $onbellek 'indirme-ozeti.json'
if (Test-Path $ozetDosya) { $ozet += @(Get-Content -Raw $ozetDosya | ConvertFrom-Json) }
$ozet += $guncellemeSonuc
$rapor = Join-Path $cikti "RAPOR_$zaman.txt"
@(
    'N10JC Windows 7 kurulum ISO''su hazır.'
    "ISO      : $cikIso ($([math]::Round((Get-Item $cikIso).Length / 1GB, 2)) GB)"
    "Sürüm    : $($secim.ImageName) ($dil)"
    "Anahtar  : $(if ($anahtar) { 'otomatik kurulum dosyasına eklendi (' + $anahtar.Substring(24) + ' ile biten)' } else { 'yok, kurulumda sorulacak' })"
    "Kullanıcı: $($ayar.KULLANICI)"
    ''
    'Kaynak doğrulama: GEÇTİ'
    ($dogrulama | ForEach-Object { "  - $_" })
    ''
    ($ozet | Format-Table Konu, Durum, Ayrinti -AutoSize | Out-String -Width 200)
    'USB''ye yazmak için Rufus kullanın: Bölüm düzeni MBR, hedef sistem BIOS. Ayrıntılar README.md''de.'
) | Set-Content -Encoding UTF8 $rapor
Write-N10Log "Bitti. Rapor: $rapor" 'TAMAM'
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $isoKlasor
Start-Process explorer.exe $cikti
[void][Windows.Forms.MessageBox]::Show("ISO hazır:`n$cikIso`n`nÖzet: $rapor", 'N10JC Windows 7', 'OK', 'Information')
