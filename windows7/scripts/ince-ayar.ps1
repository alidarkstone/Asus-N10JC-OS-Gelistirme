# N10JC Windows 7 kiti: bağlanmış (mount) imaja çevrimdışı kayıt defteri ayarları.
# Hedef: 2 GB RAM, mSATA SSD, Atom N270. Görünüm sade: şeffaflık ve animasyon yok.
param([Parameter(Mandatory)][string]$Mount, [string]$DuvarKagidi, [string]$Logo)
Import-Module (Join-Path $PSScriptRoot 'N10Ortak.psm1')

$kovanlar = [ordered]@{
    N10_SYS = "$Mount\Windows\System32\config\SYSTEM"
    N10_SW  = "$Mount\Windows\System32\config\SOFTWARE"
    N10_DEF = "$Mount\Users\Default\NTUSER.DAT"
}

function R([string]$Anahtar, [string]$Ad, [string]$Tur, $Deger) {
    $arg = @('add', "HKLM\$Anahtar", '/f')
    if ($Ad) { $arg += @('/v', $Ad) } else { $arg += '/ve' }
    if ($Tur) { $arg += @('/t', $Tur, '/d', "$Deger") }
    & reg.exe @arg | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-N10Log "Kayıt yazılamadı: $Anahtar\$Ad" 'UYARI' }
}

foreach ($k in $kovanlar.Keys) {
    & reg.exe load "HKLM\$k" $kovanlar[$k] | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Kovan yüklenemedi: $($kovanlar[$k])" }
}
try {
    $cs = 'N10_SYS\ControlSet001'
    # --- Bellek ve disk (2 GB RAM + SSD) ---
    R "$cs\Control\Session Manager\Memory Management" DisablePagingExecutive REG_DWORD 1
    R "$cs\Control\Session Manager\Memory Management\PrefetchParameters" EnableSuperfetch REG_DWORD 0
    R "$cs\Control\Session Manager\Memory Management\PrefetchParameters" EnablePrefetcher REG_DWORD 2
    R "$cs\Control\FileSystem" NtfsDisableLastAccessUpdate REG_DWORD 1
    R "$cs\Control\FileSystem" NtfsDisable8dot3NameCreation REG_DWORD 1
    R "$cs\Control\Power" HibernateEnabled REG_DWORD 0
    R "$cs\Control\CrashControl" CrashDumpEnabled REG_DWORD 3
    # Yanıt vermeyen uygulama/hizmet kapanışını hızlandır
    R "$cs\Control" WaitToKillServiceTimeout REG_SZ 5000
    # --- Güncel siteler ve oyun başlatıcıları için TLS 1.1/1.2 ---
    foreach ($tls in 'TLS 1.1', 'TLS 1.2') {
        foreach ($taraf in 'Client', 'Server') {
            R "$cs\Control\SecurityProviders\SCHANNEL\Protocols\$tls\$taraf" Enabled REG_DWORD 1
            R "$cs\Control\SecurityProviders\SCHANNEL\Protocols\$tls\$taraf" DisabledByDefault REG_DWORD 0
        }
    }
    R 'N10_SW\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp' DefaultSecureProtocols REG_DWORD 2560
    foreach ($nf in 'v2.0.50727', 'v4.0.30319') {
        R "N10_SW\Microsoft\.NETFramework\$nf" SchUseStrongCrypto REG_DWORD 1
        R "N10_SW\Microsoft\.NETFramework\$nf" SystemDefaultTlsVersions REG_DWORD 1
    }
    # --- Arka plan yükü: Windows Update (artık güncelleme yok, tarama Atom'u saatlerce %100 tutar), telemetri, hata raporu ---
    R 'N10_SW\Policies\Microsoft\Windows\WindowsUpdate\AU' NoAutoUpdate REG_DWORD 1
    R 'N10_SW\Policies\Microsoft\Windows\WindowsUpdate' DisableOSUpgrade REG_DWORD 1
    R 'N10_SW\Policies\Microsoft\Windows\DataCollection' AllowTelemetry REG_DWORD 0
    R 'N10_SW\Policies\Microsoft\SQMClient\Windows' CEIPEnable REG_DWORD 0
    R 'N10_SW\Policies\Microsoft\Windows\AppCompat' AITEnable REG_DWORD 0
    R 'N10_SW\Policies\Microsoft\Windows\AppCompat' DisableInventory REG_DWORD 1
    R 'N10_SW\Microsoft\Windows\Windows Error Reporting' Disabled REG_DWORD 1
    R 'N10_SW\Policies\Microsoft\Windows NT\SystemRestore' DisableSR REG_DWORD 1
    R 'N10_SW\Policies\Microsoft\Windows\Gwx' DisableGwx REG_DWORD 1
    # --- Sistem bilgisi ---
    R 'N10_SW\Microsoft\Windows\CurrentVersion\OEMInformation' Manufacturer REG_SZ 'ASUS'
    R 'N10_SW\Microsoft\Windows\CurrentVersion\OEMInformation' Model REG_SZ 'Eee PC N10JC (N10 Windows 7)'
    if ($Logo) { R 'N10_SW\Microsoft\Windows\CurrentVersion\OEMInformation' Logo REG_SZ 'C:\Windows\System32\oobe\info\n10-logo.bmp' }

    # --- Varsayılan kullanıcı: sade görünüm, efekt yok ---
    $u = 'N10_DEF'
    R "$u\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" VisualFXSetting REG_DWORD 3
    R "$u\Control Panel\Desktop" UserPreferencesMask REG_BINARY 9012038010000000
    R "$u\Control Panel\Desktop" DragFullWindows REG_SZ 1
    R "$u\Control Panel\Desktop" FontSmoothing REG_SZ 2
    R "$u\Control Panel\Desktop" FontSmoothingType REG_DWORD 2
    R "$u\Control Panel\Desktop" MenuShowDelay REG_SZ 100
    R "$u\Control Panel\Desktop\WindowMetrics" MinAnimate REG_SZ 0
    R "$u\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" TaskbarAnimations REG_DWORD 0
    R "$u\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" ListviewShadow REG_DWORD 0
    R "$u\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" ListviewAlphaSelect REG_DWORD 1
    R "$u\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" HideFileExt REG_DWORD 0
    R "$u\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" Start_ShowRun REG_DWORD 1
    R "$u\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" DisablePreviewDesktop REG_DWORD 1
    # Opak, koyu gri pencere çerçeveleri (şeffaflık ve Aero Peek kapalı)
    R "$u\Software\Microsoft\Windows\DWM" ColorizationOpaqueBlend REG_DWORD 1
    R "$u\Software\Microsoft\Windows\DWM" ColorizationColor REG_DWORD '0xC42B2B2B'
    R "$u\Software\Microsoft\Windows\DWM" ColorizationAfterglow REG_DWORD '0xC42B2B2B'
    R "$u\Software\Microsoft\Windows\DWM" ColorizationColorBalance REG_DWORD 8
    R "$u\Software\Microsoft\Windows\DWM" EnableAeroPeek REG_DWORD 0
    R "$u\Software\Microsoft\Windows\DWM" AlwaysHibernateThumbnails REG_DWORD 0
    # Türkçe Q klavye
    R "$u\Keyboard Layout\Preload" 1 REG_SZ 0000041f
    if ($DuvarKagidi) {
        R "$u\Control Panel\Desktop" Wallpaper REG_SZ 'C:\Windows\Web\Wallpaper\N10\n10.jpg'
        R "$u\Control Panel\Desktop" WallpaperStyle REG_SZ 10
        R "$u\Control Panel\Desktop" TileWallpaper REG_SZ 0
    }
    # Oyunlar: Oyun Gezgini'nin internetten bilgi çekmesini kapat
    R "$u\Software\Microsoft\Windows\CurrentVersion\GameUX" DownloadGameInfo REG_DWORD 0
    R "$u\Software\Microsoft\Windows\CurrentVersion\GameUX" GameUpdateOptions REG_DWORD 0
    Write-N10Log 'Çevrimdışı ayarlar yazıldı.' 'TAMAM'
} finally {
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    foreach ($k in $kovanlar.Keys) {
        for ($i = 0; $i -lt 5; $i++) {
            & reg.exe unload "HKLM\$k" 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { break }
            Start-Sleep -Seconds 2
        }
    }
}

if ($DuvarKagidi) {
    New-Item -ItemType Directory -Force "$Mount\Windows\Web\Wallpaper\N10" | Out-Null
    Copy-Item -Force $DuvarKagidi "$Mount\Windows\Web\Wallpaper\N10\n10.jpg"
}
if ($Logo) {
    New-Item -ItemType Directory -Force "$Mount\Windows\System32\oobe\info" | Out-Null
    Copy-Item -Force $Logo "$Mount\Windows\System32\oobe\info\n10-logo.bmp"
}
