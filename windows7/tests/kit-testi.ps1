# N10JC Windows 7 kiti testi (GitHub Actions, windows-latest). Windows ISO'su gerektirmeyen her şeyi dener:
# betiklerin sözdizimi, tüm indirmeler, sürücü hazırlığı, autounattend.xml ve ISO yazımı.
param([string]$Is = "$env:RUNNER_TEMP\n10w7")
$ErrorActionPreference = 'Stop'
$kit = Split-Path $PSScriptRoot
$hata = 0

# 1) Sözdizimi
foreach ($f in Get-ChildItem $kit -Recurse -Include *.ps1, *.psm1) {
    $tok = $null; $err = $null
    [void][Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tok, [ref]$err)
    if ($err) { $err | ForEach-Object { Write-Host "SÖZDİZİMİ: $($f.Name): $_" }; $hata++ }
}

# 2) İndirme ve sürücü hazırlığı
$onbellek = Join-Path $Is 'onbellek'
& (Join-Path $kit 'scripts\indir.ps1') -Onbellek $onbellek -Gunluk (Join-Path $Is 'indir.log') -TurkceDilPaketi -SP1Gerekli
$ozet = Get-Content -Raw (Join-Path $onbellek 'indirme-ozeti.json') | ConvertFrom-Json
$ozet | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
$zorunlu = 'NVIDIA*', 'KB4490628*', 'KB4474419*', 'KB3125574*', 'KB4536952*', 'KB4534310*', 'DirectX*', 'Supermium*', 'Türkçe arayüz*', 'Service Pack 1'
foreach ($z in $zorunlu) {
    $s = $ozet | Where-Object { $_.Konu -like $z }
    if (-not $s -or $s.Durum -ne 'TAMAM') { Write-Host "EKSİK: $z"; $hata++ }
}
if ($env:N10_KATALOG_DOKUM -and (Test-Path $env:N10_KATALOG_DOKUM)) {
    Write-Host '--- Katalog arama sayfaları (tanı) ---'
    foreach ($h in Get-ChildItem $env:N10_KATALOG_DOKUM -Filter *.html) {
        $t = Get-Content -Raw $h.FullName
        $sonucYok = $t -match 'noResult'
        $i = $t.IndexOf('goToDetails(', $t.IndexOf('goToDetails') + 20)
        Write-Host ("{0}: {1} bayt, goToDetails={2}, sonuç yok işareti={3}" -f $h.Name, $t.Length, ([regex]::Matches($t, 'goToDetails')).Count, $sonucYok)
        if ($i -gt 0 -and $false) { Write-Host ($t.Substring([Math]::Max(0, $i - 900), [Math]::Min(2600, $t.Length - $i + 900)) -replace '\s+', ' ') }
    }
}
Import-Module (Join-Path $kit 'scripts\N10Ortak.psm1') -Force
$lpCab = Join-Path $onbellek 'guncellemeler\dil-tr\lp.cab'
if (Test-Path $lpCab) {
    Write-Host ("Dil paketi: lp.cab {0:N1} MB" -f ((Get-Item $lpCab).Length / 1MB))
    if ((Get-Item $lpCab).Length -lt 20MB) { Write-Host 'DİL PAKETİ ÇOK KÜÇÜK'; $hata++ }
    & expand.exe -D $lpCab | Select-String -Pattern 'update\.(mum|cat)|LanguagePack-Package' | Select-Object -First 4 | ForEach-Object { Write-Host "  $_" }
}
$sp1Mum = Get-ChildItem (Join-Path $onbellek 'guncellemeler\sp1\paket') -Filter 'Windows7SP1-KB976933~*~x86~~6.1.1.17514.mum' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $sp1Mum) { Write-Host 'SP1 PAKETİ HAZIR DEĞİL'; $hata++ } else {
    $t = Get-Content -Raw $sp1Mum.FullName
    Write-Host "SP1 bildirimi: $($sp1Mum.Name), allowedOffline=true: $($t -match 'allowedOffline=""true""'), false kaldı: $($t -match 'allowedOffline=""false""')"
    if ($t -match 'allowedOffline="false"') { $hata++ }
    $ses = Get-Content -Raw (Join-Path $sp1Mum.DirectoryName 'update.ses')
    Write-Host "update.ses: OfflineInstall=$($ses -match 'OfflineInstall'), OnlineInstall kaldı=$($ses -match 'OnlineInstall')"
    if ($ses -match 'operationMode="OnlineInstall"') { $hata++ }
    Write-Host ("SP1 paketi: {0} dosya, {1:N0} MB" -f @(Get-ChildItem $sp1Mum.DirectoryName -Recurse -File).Count, ((Get-ChildItem $sp1Mum.DirectoryName -Recurse -File | Measure-Object Length -Sum).Sum / 1MB))
}
Write-Host '--- Hazırlanan sürücüler ---'
Get-ChildItem (Join-Path $onbellek 'suruculer') -Directory | ForEach-Object {
    $inf = Get-ChildItem $_.FullName -Recurse -Filter *.inf
    $ver = foreach ($i in $inf) { (Select-String -Path $i.FullName -Pattern '^\s*DriverVer\s*=' | Select-Object -First 1).Line }
    Write-Host ("{0,-22} {1} INF  {2}" -f $_.Name, @($inf).Count, (($ver | Select-Object -Unique) -join ' | '))
}
Write-Host '--- NVIDIA: N10JC kimliği ---'
Select-String -Path (Join-Path $onbellek 'suruculer\nvidia-341\*.inf') -Pattern 'DEV_06E9&SUBSYS_19721043' -ErrorAction SilentlyContinue |
    Select-Object -First 4 | ForEach-Object { Write-Host "$($_.Filename): $($_.Line.Trim())" }
Write-Host '--- Uygulamalar ---'
Get-ChildItem (Join-Path $onbellek 'uygulamalar') | ForEach-Object { Write-Host ("{0,-40} {1,8:N1} MB" -f $_.Name, ($_.Length / 1MB)) }

# 3) autounattend.xml
$xml = (Get-Content -Raw -Encoding UTF8 (Join-Path $kit 'scripts\autounattend.sablon.xml')).
    Replace('{{UILANG}}', 'tr-TR').Replace('{{USER}}', 'darkstone').Replace('{{PASSWORD}}', '').Replace('{{COMPUTER}}', 'N10JC').
    Replace('{{KEY_BLOCK}}', '<ProductKey><Key>AAAAA-BBBBB-CCCCC-DDDDD-EEEEE</Key><WillShowUI>OnError</WillShowUI></ProductKey>')
try { [void][xml]$xml; Write-Host 'autounattend.xml: geçerli XML' } catch { Write-Host "autounattend.xml HATALI: $_"; $hata++ }

# 4) ISO yazımı (önyükleme dosyası olmadan)
Import-Module (Join-Path $kit 'scripts\N10Ortak.psm1') -Force
$deneme = Join-Path $Is 'iso-deneme'
New-Item -ItemType Directory -Force "$deneme\sources" | Out-Null
Copy-Item (Join-Path $kit 'oem') "$deneme\sources\oem" -Recurse
New-N10Iso -Kaynak $deneme -Hedef (Join-Path $Is 'deneme.iso') -Etiket 'N10_TEST'
$boy = (Get-Item (Join-Path $Is 'deneme.iso')).Length
Write-Host "Deneme ISO: $boy bayt"
if ($boy -lt 32768) { $hata++ }

# 5) İmza denetimi: gerçek Windows 7 x86 dosyaları (Ocak 2020 toplu güncellemesinin içinden) geçmeli,
#    bir baytı değiştirilmiş kopya da yakalanmalı.
$msu = Get-ChildItem (Join-Path $onbellek 'guncellemeler') -Filter '*kb4534310*.msu' | Select-Object -First 1
$imza = Join-Path $Is 'imza'
New-Item -ItemType Directory -Force $imza | Out-Null
& expand.exe -F:*.cab $msu.FullName $imza | Out-Null
$cab = Get-ChildItem $imza -Filter 'Windows6.1-KB4534310*.cab' | Select-Object -First 1
& expand.exe -F:ntoskrnl.exe $cab.FullName $imza | Out-Null
# Karşılaştırma: bilinen sağlam bir Windows 7 paketini bu sunucudaki DISM nasıl okuyor? (yalnızca tanı)
Write-Host '--- DISM karşılaştırma (KB4534310 cab, çalışan sisteme göre) ---'
& dism.exe /English /Online /Get-PackageInfo "/PackagePath:$($cab.FullName)" 2>&1 | Where-Object { $_ -match 'Error|error|Package Identity|Applicable|State' } | Select-Object -First 8 | ForEach-Object { Write-Host "  $_" }
$nt = Get-ChildItem $imza -Recurse -Filter ntoskrnl.exe | Select-Object -First 1
if (-not $nt) { Write-Host 'İMZA TESTİ: ntoskrnl.exe çıkarılamadı'; $hata++ } else {
    $r = Test-N10MsImza $nt.FullName
    Write-Host "İmza (orijinal ntoskrnl.exe): $(if ($r) { $r } else { 'geçerli, Microsoft' })"
    if ($r) { $hata++ }
    $bozuk = Join-Path $imza 'bozuk-ntoskrnl.exe'
    $b = [IO.File]::ReadAllBytes($nt.FullName); $b[4096] = $b[4096] -bxor 0xFF; [IO.File]::WriteAllBytes($bozuk, $b)
    $r2 = Test-N10MsImza $bozuk
    Write-Host "İmza (değiştirilmiş kopya): $r2"
    if (-not $r2) { Write-Host 'İMZA TESTİ: değiştirilmiş dosya yakalanmadı'; $hata++ }
}
$sahte = Join-Path $Is 'sahte-medya'
New-Item -ItemType Directory -Force "$sahte\sources\`$OEM`$" | Out-Null
# HAZIRLA'nın kullandığı yolla: temiz medya boş liste, $OEM$'li medya bulgu, hata veren denetim de bulgu vermeli.
$temiz = Join-Path $Is 'temiz-medya'
New-Item -ItemType Directory -Force "$temiz\sources", "$temiz\boot" | Out-Null
Copy-Item "$env:windir\explorer.exe" (Join-Path $temiz 'setup.exe')
# Orijinal Windows 7 medyasındaki gibi: bu iki dosya gömülü imzasız (katalog imzalı)
foreach ($f in 'sources\setup.exe', 'boot\bootsect.exe') { [IO.File]::WriteAllBytes((Join-Path $temiz $f), [byte[]](0x4D, 0x5A, 0, 0)) }
$r = Invoke-N10Denetim { Test-N10Medya $temiz } 'Medya denetimi'
if ($r.Count) { Write-Host "MEDYA TESTİ: temiz medya reddedildi: $($r -join ' | ')"; $hata++ } else { Write-Host 'Medya testi: temiz medya geçti.' }
$r = Invoke-N10Denetim { Test-N10Medya $sahte } 'Medya denetimi'
if (-not $r.Count -or ($r -join '') -notmatch 'OEM') { Write-Host "MEDYA TESTİ: Invoke-N10Denetim `$OEM`$ bulgusunu vermedi: $($r -join ' | ')"; $hata++ }
$ErrorActionPreference = 'Continue'   # HAZIRLA'daki gibi
$r = Invoke-N10Denetim { Test-YokBoyleBirKomut 'x' } 'Medya denetimi'
$ErrorActionPreference = 'Stop'
if (-not $r.Count) { Write-Host 'MEDYA TESTİ: çalışamayan denetim geçti sayıldı'; $hata++ } else { Write-Host "Çalışamayan denetim: $($r -join ' | ')" }
if (-not (Test-N10Medya $sahte)) { Write-Host 'MEDYA TESTİ: $OEM$ içeren medya yakalanmadı'; $hata++ } else { Write-Host 'Medya testi: değiştirilmiş medya yakalandı.' }

Copy-Item (Join-Path $onbellek 'indirme-ozeti.json') $Is
if ($hata) { Write-Host "$hata sorun var."; exit 1 }
Write-Host 'Tüm testler geçti.'
