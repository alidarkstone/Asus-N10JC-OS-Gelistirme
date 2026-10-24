# N10JC Windows 7 kiti: sürücüleri, güncellemeleri ve uygulamaları indirip hazırlar.
# Tek başına da çalışır (GitHub Actions testi böyle kullanır):
#   powershell -ExecutionPolicy Bypass -File indir.ps1 -Onbellek C:\yol\onbellek
param(
    [Parameter(Mandatory)][string]$Onbellek,
    [switch]$SP1Gerekli,
    [switch]$TurkceDilPaketi,
    [switch]$NetFx48,
    [string]$Gunluk
)
Import-Module (Join-Path $PSScriptRoot 'N10Ortak.psm1') -Force
if ($Gunluk) { Set-N10Log $Gunluk }

$suruculer = Join-Path $Onbellek 'suruculer'
$guncel = Join-Path $Onbellek 'guncellemeler'
$uyg = Join-Path $Onbellek 'uygulamalar'
$ham = Join-Path $Onbellek 'ham'
$arac = Join-Path $Onbellek 'arac'
foreach ($k in $suruculer, $guncel, $uyg, $ham, $arac) { New-Item -ItemType Directory -Force -Path $k | Out-Null }

# ------------------------------------------------------------------
# 1) NVIDIA GeForce 9300M GS: resmi 341.x (Windows 7 32-bit dizüstü) sürücüsü
# ------------------------------------------------------------------
# N10JC'deki kart: PCI\VEN_10DE&DEV_06E9&SUBSYS_19721043 (ASUS alt kimliği).
$nvHwId = 'PCI\VEN_10DE&DEV_06E9&SUBSYS_19721043'
$nvHedef = Join-Path $suruculer 'nvidia-341'
$nvTamam = $false

function Add-NvidiaSubsys([string]$Klasor) {
    # Paket N10JC'nin alt kimliğini listelemiyorsa, aynı GPU'nun (06E9) bir satırını kopyalayıp
    # bizim kimliği ekler. 32-bit Windows 7 imzası değişmiş sürücüyü kabul eder (DISM /ForceUnsigned).
    foreach ($inf in Get-ChildItem $Klasor -Filter 'nv*.inf') {
        $bayt = [IO.File]::ReadAllBytes($inf.FullName)
        $kod = if ($bayt.Length -gt 1 -and $bayt[0] -eq 0xFF -and $bayt[1] -eq 0xFE) { [Text.Encoding]::Unicode } else { [Text.Encoding]::Default }
        $satirlar = $kod.GetString($bayt).TrimStart([char]0xFEFF) -split "`r`n"
        if (-not ($satirlar -match 'DEV_06E9')) { continue }
        $yeni = New-Object System.Collections.Generic.List[string]
        $bolum = ''; $eklenen = @{}
        foreach ($s in $satirlar) {
            $yeni.Add($s)
            if ($s -match '^\s*\[(.+)\]') { $bolum = $Matches[1] }
            if ($bolum -match 'NTx86' -and -not $eklenen[$bolum] -and $s -match '^\s*%[^%]+%\s*=\s*([^,]+),\s*PCI\\VEN_10DE&DEV_06E9') {
                $yeni.Add("%NVIDIA_DEV.06E9.1972.1043% = $($Matches[1].Trim()), PCI\VEN_10DE&DEV_06E9&SUBSYS_19721043")
                $eklenen[$bolum] = $true
            }
            if ($s -match '^\s*\[Strings\]\s*$') { $yeni.Add('NVIDIA_DEV.06E9.1972.1043 = "NVIDIA GeForce 9300M GS"') }
        }
        if ($eklenen.Count -gt 0) {
            [IO.File]::WriteAllText($inf.FullName, ($yeni -join "`r`n"), $kod)
            Write-N10Log "NVIDIA: N10JC kimliği $($inf.Name) dosyasına eklendi ($($eklenen.Count) bölüm)." 'TAMAM'
            return $true
        }
    }
    return $false
}

if (Test-N10Inf $nvHedef $nvHwId) {
    $nvTamam = $true
    Write-N10Log 'NVIDIA 341.x hazır (önbellekte).' 'TAMAM'
} else {
    $nvExe = Join-Path $ham 'nvidia-341-notebook-win7-32.exe'
    $urls = foreach ($v in '341.95', '341.92', '341.44') {
        foreach ($ek in '-whql', '') {
            foreach ($h in 'us.download.nvidia.com', 'international.download.nvidia.com') {
                "https://$h/Windows/$v/$v-notebook-win8-win7-32bit-international$ek.exe"
            }
        }
    }
    if (Get-N10Dosya -Urls $urls -Hedef $nvExe) {
        try {
            $7z = Get-N10SevenZip $arac
            $acik = Join-Path $ham 'nvidia-acik'
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $acik
            & $7z x -y "-o$acik" $nvExe | Out-Null
            $dd = Join-Path $acik 'Display.Driver'
            if (-not (Test-Path $dd)) { throw 'Display.Driver klasörü yok' }
            if (-not (Test-N10Inf $dd $nvHwId)) {
                if (-not (Add-NvidiaSubsys $dd)) { throw 'pakette 9300M GS (06E9) satırı yok' }
            }
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $nvHedef
            Copy-Item -Recurse $dd $nvHedef
            # NVIDIA Denetim Masası ve PhysX kurulumdan sonra kurulur (bkz. oem\Scripts).
            $physx = Get-ChildItem $acik -Recurse -Filter 'PhysX*.msi' | Select-Object -First 1
            if ($physx) { Copy-Item -Force $physx.FullName (Join-Path $uyg 'PhysX.msi') }
            $nvTamam = $true
        } catch { Write-N10Log "NVIDIA paketi hazırlanamadı: $($_.Exception.Message)" 'HATA' }
    }
}
Add-N10Ozet 'NVIDIA 9300M GS sürücüsü (341.x)' $(if ($nvTamam) { 'TAMAM' } else { 'YOK' })

# ------------------------------------------------------------------
# 2) Diğer N10JC aygıtları: Microsoft Windows Update Kataloğu (resmi, imzalı)
# ------------------------------------------------------------------
# Kimlikler N10JC'nin kendi donanım raporundan (lspci/lsusb) alındı.
$aygitlar = @(
    @{ Ad = 'Realtek ALC662 ses'; Klasor = 'ses-alc662'; HwId = 'HDAUDIO\FUNC_01&VEN_10EC&DEV_0662'
       Sorgu = @('HDAUDIO\FUNC_01&VEN_10EC&DEV_0662&SUBSYS_10431813', 'HDAUDIO\FUNC_01&VEN_10EC&DEV_0662', 'Realtek High Definition Audio Windows 7') }
    @{ Ad = 'Intel GMA 950 ekran'; Klasor = 'intel-gma950'; HwId = 'PCI\VEN_8086&DEV_27AE'
       Sorgu = @('PCI\VEN_8086&DEV_27AE&SUBSYS_1AB71043', 'PCI\VEN_8086&DEV_27AE') }
    @{ Ad = 'Atheros AR9281 Wi-Fi'; Klasor = 'wifi-ar9281'; HwId = 'PCI\VEN_168C&DEV_002A'
       Sorgu = @('PCI\VEN_168C&DEV_002A&SUBSYS_10671A3B', 'PCI\VEN_168C&DEV_002A') }
    @{ Ad = 'Realtek RTL8111 Ethernet'; Klasor = 'ethernet-rtl8111'; HwId = 'PCI\VEN_10EC&DEV_8168'
       Sorgu = @('PCI\VEN_10EC&DEV_8168&SUBSYS_16D51043', 'PCI\VEN_10EC&DEV_8168') }
    @{ Ad = 'ASUS BT-183 Bluetooth'; Klasor = 'bluetooth-bt183'; HwId = 'USB\VID_0B05&PID_1712'
       Sorgu = @('USB\VID_0B05&PID_1712') }
    @{ Ad = 'ASUS ATK0100 (Fn tuşları)'; Klasor = 'asus-atk0100'; HwId = 'ATK0100'
       Sorgu = @('ACPI\ATK0100', 'ATK0100') }
    @{ Ad = 'Chicony web kamerası'; Klasor = 'kamera-chicony'; HwId = 'USB\VID_04F2&PID_B071'
       Sorgu = @('USB\VID_04F2&PID_B071') }
    @{ Ad = 'UPEK parmak izi okuyucu'; Klasor = 'parmakizi-upek'; HwId = 'USB\VID_147E&PID_1000'
       Sorgu = @('USB\VID_147E&PID_1000') }
)
if (-not $nvTamam) {
    # Yedek: Windows Update'in kendi NVIDIA sürücüsü.
    $aygitlar += @{ Ad = 'NVIDIA 9300M GS (Windows Update yedeği)'; Klasor = 'nvidia-wu'; HwId = 'PCI\VEN_10DE&DEV_06E9'
                    Sorgu = @($nvHwId, 'PCI\VEN_10DE&DEV_06E9') }
}
foreach ($a in $aygitlar) {
    $ok = $false
    try { $ok = Get-N10KatalogSurucu -Ad $a.Ad -Sorgular $a.Sorgu -HwId $a.HwId -Hedef (Join-Path $suruculer $a.Klasor) -Onbellek $ham }
    catch { Write-N10Log "$($a.Ad): $($_.Exception.Message)" 'HATA' }
    if (-not $ok) { Write-N10Log "$($a.Ad) katalogda bulunamadı; Windows 7'nin kendi sürücüsü kullanılacak." 'UYARI' }
    Add-N10Ozet $a.Ad $(if ($ok) { 'TAMAM' } else { 'Windows içi sürücü' })
}

# ------------------------------------------------------------------
# 3) Güncellemeler (sırası önemli: önce servis yığını ve SHA-2)
# ------------------------------------------------------------------
$kbListesi = @(
    @{ KB = 'KB3020369'; Not = 'Servis yığını (Nisan 2015)' }
    @{ KB = 'KB4490628'; Not = 'Servis yığını (Mart 2019)' }
    @{ KB = 'KB4474419'; Not = 'SHA-2 imza desteği' }
    @{ KB = 'KB3125574'; Not = 'SP1 sonrası toplu güncelleme (2016)'
       Yedek = @('http://download.windowsupdate.com/d/msdownload/update/software/updt/2016/05/windows6.1-kb3125574-v4-x86_ba1ff5537312561795cc04db0b02fbb0a74b2cbd.msu') }
    @{ KB = 'KB4536952'; Not = 'Servis yığını (Ocak 2020)' }
    @{ KB = 'KB4534310'; Not = 'Son aylık toplu güncelleme (Ocak 2020)' }
)
$sira = New-Object System.Collections.ArrayList
$i = 0
foreach ($k in $kbListesi) {
    $i++
    $yedek = @(); if ($k.ContainsKey('Yedek')) { $yedek = $k.Yedek }
    $dosya = $null
    try { $dosya = Get-N10Guncelleme -KB $k.KB -Klasor $guncel -YedekUrl $yedek } catch { Write-N10Log "$($k.KB): $($_.Exception.Message)" 'HATA' }
    if ($dosya) { [void]$sira.Add([pscustomobject]@{ Sira = $i; KB = $k.KB; Dosya = [IO.Path]::GetFileName($dosya); Not = $k.Not }) ; Write-N10Log "$($k.KB) hazır: $($k.Not)" 'TAMAM' }
    else { Write-N10Log "$($k.KB) indirilemedi ($($k.Not))." 'HATA' }
    Add-N10Ozet "$($k.KB) $($k.Not)" $(if ($dosya) { 'TAMAM' } else { 'YOK' })
}
$sira | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $guncel 'sira.json')

if ($TurkceDilPaketi) {
    # Türkçe arayüz dil paketi (KB2483139, SP1 için). Microsoft yalnızca Ultimate/Enterprise'ta dil paketine izin verir.
    $lpCab = Join-Path $guncel 'dil-tr\lp.cab'
    if (-not (Test-Path $lpCab)) {
        try {
            # Dil paketleri katalogda yok; Microsoft'un Windows Update sunucusundaki asıl dosya kullanılır.
            # Dosya adındaki 40 haneli değer dosyanın SHA-1 özetidir; indirilen dosya buna göre doğrulanır.
            $ad = 'windows6.1-kb2483139-x86-tr-tr_228dfa5fbaa4606b17f93d6fcd51c8c85c0f1fd3.exe'
            $dosya = Join-Path $ham $ad
            $ok = Get-N10Dosya -Hedef $dosya -Urls @(
                "https://download.windowsupdate.com/msdownload/update/software/updt/2011/02/$ad",
                "http://download.windowsupdate.com/msdownload/update/software/updt/2011/02/$ad")
            if ($ok) {
                $sha = (Get-FileHash -Algorithm SHA1 $dosya).Hash.ToLower()
                if ($sha -ne '228dfa5fbaa4606b17f93d6fcd51c8c85c0f1fd3') { Remove-Item -Force $dosya; throw "SHA-1 uyuşmadı ($sha)" }
                $imzaSorun = Test-N10MsImza $dosya
                if ($imzaSorun) { throw $imzaSorun }
                New-Item -ItemType Directory -Force (Split-Path $lpCab) | Out-Null
                $acik = Join-Path $ham 'dil-tr-acik'
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $acik
                & (Get-N10SevenZip $arac) x -y "-o$acik" $dosya | Out-Null
                $c = Get-ChildItem $acik -Recurse -Filter *.cab | Sort-Object Length -Descending | Select-Object -First 1
                if ($c) { Copy-Item -Force $c.FullName $lpCab; Write-N10Log "Türkçe dil paketi hazır ($($c.Name), SHA-1 ve Microsoft imzası doğrulandı)." 'TAMAM' }
                else { throw 'paketten lp.cab çıkmadı' }
            }
        } catch { Write-N10Log "Türkçe dil paketi alınamadı: $($_.Exception.Message)" 'HATA' }
    }
    Add-N10Ozet 'Türkçe arayüz dil paketi (KB2483139)' $(if (Test-Path $lpCab) { 'TAMAM' } else { 'YOK' })
}

if ($SP1Gerekli) {
    # SP1 içermeyen (7600) ISO için Service Pack 1 paketini çıkarır.
    $sp1Exe = Join-Path $ham 'windows6.1-KB976932-X86.exe'
    $sp1Cab = Join-Path $guncel 'sp1\windows6.1-KB976932-X86.cab'
    if (-not (Test-Path $sp1Cab)) {
        if (Get-N10Dosya -Urls @('https://download.microsoft.com/download/0/A/F/0AFB5316-3062-494A-AB78-7FB0D4461357/windows6.1-KB976932-X86.exe') -Hedef $sp1Exe) {
            $p = Start-Process $sp1Exe -ArgumentList "/x:`"$(Split-Path $sp1Cab)`"" -Wait -PassThru
            Write-N10Log "SP1 paketi açıldı (kod $($p.ExitCode))."
        }
    }
    Add-N10Ozet 'Service Pack 1' $(if (Test-Path $sp1Cab) { 'TAMAM' } else { 'YOK' })
}

# ------------------------------------------------------------------
# 4) Uygulamalar ve oyun bileşenleri (kurulumdan sonra sessizce kurulur)
# ------------------------------------------------------------------
$uygulamalar = @(
    @{ Ad = 'DirectX 9.0c (Haziran 2010)'; Dosya = 'directx_Jun2010_redist.exe'
       Url = @('https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe') }
    @{ Ad = 'Visual C++ 2005'; Dosya = 'vcredist2005_x86.exe'
       Url = @('https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x86.EXE') }
    @{ Ad = 'Visual C++ 2008'; Dosya = 'vcredist2008_x86.exe'
       Url = @('https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe') }
    @{ Ad = 'Visual C++ 2010'; Dosya = 'vcredist2010_x86.exe'
       Url = @('https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x86.exe') }
    @{ Ad = 'Visual C++ 2012'; Dosya = 'vcredist2012_x86.exe'
       Url = @('https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe') }
    @{ Ad = 'Visual C++ 2013'; Dosya = 'vcredist2013_x86.exe'
       Url = @('https://aka.ms/highdpimfc2013x86enu') }
    @{ Ad = 'Visual C++ 2015-2019'; Dosya = 'vcredist2019_x86.exe'
       Url = @('https://aka.ms/vs/16/release/vc_redist.x86.exe') }
    @{ Ad = 'Visual C++ 2015-2022'; Dosya = 'vcredist2022_x86.exe'
       Url = @('https://aka.ms/vs/17/release/vc_redist.x86.exe') }
    @{ Ad = 'OpenAL'; Dosya = 'oalinst.zip'; Url = @('https://www.openal.org/downloads/oalinst.zip') }
)
if ($NetFx48) {
    $uygulamalar += @{ Ad = '.NET Framework 4.8'; Dosya = 'ndp48-x86-x64-allos-enu.exe'
        Url = @('https://download.visualstudio.microsoft.com/download/pr/2d6bb6b2-226a-4baa-bdec-798822606ff1/8494001c276a4b96804cde7829c04d7f/ndp48-x86-x64-allos-enu.exe') }
}
$github = @(
    @{ Ad = 'Supermium (tarayıcı)'; Dosya = 'supermium_setup_32.exe'; Repo = 'win32ss/supermium'; Desen = '(?i)32.*setup.*\.exe$|setup.*32.*\.exe$'; Haric = '(?i)x64|arm|64_' }
    @{ Ad = '7-Zip'; Dosya = '7zip_x86.exe'; Repo = 'ip7z/7zip'; Desen = '^7z\d+\.exe$'; Haric = '^$' }
    @{ Ad = 'MPC-HC (video oynatıcı)'; Dosya = 'mpc-hc_x86.exe'; Repo = 'clsid2/mpc-hc'; Desen = '(?i)\.x86\.exe$'; Haric = '(?i)x64' }
)
foreach ($g in $github) {
    $u = @()
    try { $a = Get-N10GitHubAsset -Repo $g.Repo -Desen $g.Desen -Haric $g.Haric; if ($a) { $u = @($a.Url); Write-N10Log "$($g.Ad): $($a.Ad) ($($a.Surum))" } }
    catch { Write-N10Log "$($g.Ad) sürüm bilgisi alınamadı: $($_.Exception.Message)" 'UYARI' }
    $uygulamalar += @{ Ad = $g.Ad; Dosya = $g.Dosya; Url = $u }
}
foreach ($a in $uygulamalar) {
    $ok = $false
    if ($a.Url) { $ok = Get-N10Dosya -Urls $a.Url -Hedef (Join-Path $uyg $a.Dosya) }
    Add-N10Ozet $a.Ad $(if ($ok) { 'TAMAM' } else { 'YOK' })
    if (-not $ok) { Write-N10Log "$($a.Ad) indirilemedi." 'UYARI' }
}
$oal = Join-Path $uyg 'oalinst.zip'
if (Test-Path $oal) { Expand-Archive -Force $oal $uyg; Remove-Item $oal }

Get-N10Ozet | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $Onbellek 'indirme-ozeti.json')
Write-N10Log 'İndirme ve hazırlık bitti.' 'TAMAM'
