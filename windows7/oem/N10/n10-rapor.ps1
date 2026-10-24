# N10JC Windows 7: her açılıştan 2 dakika sonra çalışır (SYSTEM).
# Donanım/sürücü/etkinleştirme raporunu C:\N10\Output'a ve takılı USB belleklerin Output klasörüne yazar.
# Windows 7'nin PowerShell 2.0 sürümüyle uyumludur.
$ErrorActionPreference = 'Continue'
$zaman = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$yerel = "C:\N10\Output\win7_$zaman"
New-Item -ItemType Directory -Force -Path $yerel | Out-Null

function Yaz($dosya, $baslik, $icerik) {
    $yol = Join-Path $yerel $dosya
    Add-Content -Path $yol -Value "== $baslik =="
    Add-Content -Path $yol -Value ($icerik | Out-String -Width 220)
}

# ---- Etkinleştirme (yalnızca kullanıcının kendi ürün anahtarıyla) ----
$winApp = '55c92734-d682-4d71-983e-d6ec3f16059f'
$lis = Get-WmiObject SoftwareLicensingProduct -Filter "ApplicationID='$winApp' AND PartialProductKey IS NOT NULL" | Select-Object -First 1
$durum = @{ 0 = 'Lisanssız'; 1 = 'ETKİN'; 2 = 'Deneme süresi'; 3 = 'Ek süre'; 4 = 'Orijinal değil'; 5 = 'Bildirim modu'; 6 = 'Uzatılmış ek süre' }
$etkin = 'Ürün anahtarı girilmemiş'
if ($lis) {
    $etkin = $durum[[int]$lis.LicenseStatus]
    if ($lis.LicenseStatus -ne 1) {
        $ag = Test-Connection -ComputerName 'www.microsoft.com' -Count 1 -Quiet
        if ($ag) {
            $sonuc = & cscript.exe //nologo "$env:windir\System32\slmgr.vbs" /ato 2>&1
            Yaz 'etkinlestirme.txt' 'Çevrimiçi etkinleştirme denemesi' $sonuc
            $lis = Get-WmiObject SoftwareLicensingProduct -Filter "ApplicationID='$winApp' AND PartialProductKey IS NOT NULL" | Select-Object -First 1
            $etkin = $durum[[int]$lis.LicenseStatus]
        } else { $etkin += ' (internet yok, bağlanınca tekrar denenecek)' }
    }
}
Yaz 'etkinlestirme.txt' 'Durum' (& cscript.exe //nologo "$env:windir\System32\slmgr.vbs" /dli 2>&1)

# ---- Özet ----
$os = Get-WmiObject Win32_OperatingSystem
$cs = Get-WmiObject Win32_ComputerSystem
$sorunlu = @(Get-WmiObject Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 })
$gpu = Get-WmiObject Win32_VideoController
$c = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
$ozet = @(
    "N10JC Windows 7 raporu  $zaman"
    "Windows        : $($os.Caption) $($os.CSDVersion) (yapı $($os.BuildNumber))"
    "Etkinleştirme  : $etkin"
    "Bellek         : toplam $([math]::Round($cs.TotalPhysicalMemory/1MB)) MB, boş $([math]::Round($os.FreePhysicalMemory/1KB)) MB"
    "Açılıştan beri : $([math]::Round(((Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime)).TotalSeconds)) sn"
    "C: diski       : boş $([math]::Round($c.FreeSpace/1GB,1)) / $([math]::Round($c.Size/1GB,1)) GB"
    "Ekran kartı    : " + (($gpu | ForEach-Object { "$($_.Name) [$($_.DriverVersion)]" }) -join ', ')
    "Sürücüsü eksik/sorunlu aygıt: $($sorunlu.Count)"
)
foreach ($d in $sorunlu) { $ozet += "   - $($d.Name)  [$($d.DeviceID)]  hata $($d.ConfigManagerErrorCode)" }
Set-Content -Path (Join-Path $yerel 'OZET.txt') -Value $ozet

Yaz 'suruculer.txt' 'Yüklü sürücüler' (Get-WmiObject Win32_PnPSignedDriver | Where-Object { $_.DeviceName } |
    Sort-Object DeviceClass, DeviceName | Format-Table DeviceClass, DeviceName, DriverVersion, DriverProviderName, HardWareID -AutoSize)
Yaz 'suruculer.txt' 'Sorunlu aygıtlar' ($sorunlu | Format-List Name, DeviceID, ConfigManagerErrorCode)
Yaz 'sistem.txt' 'İşlemci' (Get-WmiObject Win32_Processor | Format-List Name, CurrentClockSpeed, MaxClockSpeed, LoadPercentage)
Yaz 'sistem.txt' 'Ekran' ($gpu | Format-List Name, DriverVersion, DriverDate, CurrentHorizontalResolution, CurrentVerticalResolution, AdapterRAM, PNPDeviceID)
Yaz 'sistem.txt' 'Ses' (Get-WmiObject Win32_SoundDevice | Format-Table Name, Status, PNPDeviceID -AutoSize)
Yaz 'sistem.txt' 'Ağ' (Get-WmiObject Win32_NetworkAdapter -Filter 'PhysicalAdapter=True' | Format-Table Name, NetConnectionStatus, MACAddress -AutoSize)
Yaz 'sistem.txt' 'Diskler' (Get-WmiObject Win32_DiskDrive | Format-List Model, InterfaceType, Size, PNPDeviceID)
Yaz 'sistem.txt' 'Güncellemeler' (Get-WmiObject Win32_QuickFixEngineering | Sort-Object HotFixID | Format-Table HotFixID, Description -AutoSize)
Yaz 'sistem.txt' 'Bellek kullanan ilk 15 işlem' (Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 15 |
    Format-Table Name, @{ n = 'MB'; e = { [math]::Round($_.WorkingSet / 1MB) } } -AutoSize)
Yaz 'sistem.txt' 'Çalışan hizmetler' (Get-Service | Where-Object { $_.Status -eq 'Running' } | Format-Table Name, DisplayName -AutoSize)
Yaz 'olaylar.txt' 'Son 60 hata/uyarı (Sistem)' (Get-EventLog -LogName System -EntryType Error, Warning -Newest 60 |
    Format-Table TimeGenerated, Source, EventID, Message -AutoSize -Wrap)
if (Test-Path 'C:\N10\kurulum.log') { Copy-Item 'C:\N10\kurulum.log' $yerel }
if (Test-Path "$env:windir\Panther\setupact.log") { Copy-Item "$env:windir\Panther\setupact.log" $yerel }

# ---- Takılı USB belleklere kopyala ----
foreach ($usb in Get-WmiObject Win32_LogicalDisk -Filter 'DriveType=2') {
    try {
        $hedef = "$($usb.DeviceID)\Output\win7_$zaman"
        New-Item -ItemType Directory -Force -Path $hedef -ErrorAction Stop | Out-Null
        Copy-Item -Path "$yerel\*" -Destination $hedef -Recurse -Force -ErrorAction Stop
    } catch {}
}
# Bilgisayarda en son 10 rapor kalsın
Get-ChildItem 'C:\N10\Output' | Where-Object { $_.PSIsContainer } | Sort-Object Name -Descending | Select-Object -Skip 10 |
    ForEach-Object { Remove-Item -Recurse -Force $_.FullName }
