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
& (Join-Path $kit 'scripts\indir.ps1') -Onbellek $onbellek -Gunluk (Join-Path $Is 'indir.log')
$ozet = Get-Content -Raw (Join-Path $onbellek 'indirme-ozeti.json') | ConvertFrom-Json
$ozet | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
$zorunlu = 'NVIDIA*', 'KB4490628*', 'KB4474419*', 'KB3125574*', 'KB4536952*', 'KB4534310*', 'DirectX*', 'Supermium*'
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
Find-N10Katalog 'PCI\VEN_168C&DEV_002A Windows 7' | Select-Object -First 8 | Format-Table Baslik, Urunler, Sinif, Tarih -AutoSize | Out-String -Width 250 | Write-Host
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

Copy-Item (Join-Path $onbellek 'indirme-ozeti.json') $Is
if ($hata) { Write-Host "$hata sorun var."; exit 1 }
Write-Host 'Tüm testler geçti.'
