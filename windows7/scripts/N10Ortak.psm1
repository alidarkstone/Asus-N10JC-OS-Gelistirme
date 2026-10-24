# N10JC Windows 7 kiti: ortak yardımcılar (günlük, indirme, Windows Update Kataloğu, 7-Zip).
# Windows PowerShell 5.1 ile çalışır (Windows 10/11'de hazır gelir).

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:LogFile = $null
$script:Ozet = New-Object System.Collections.ArrayList

function Set-N10Log([string]$Yol) {
    $script:LogFile = $Yol
    New-Item -ItemType Directory -Force -Path (Split-Path $Yol) | Out-Null
}

function Write-N10Log {
    param([string]$Mesaj, [ValidateSet('BILGI', 'TAMAM', 'UYARI', 'HATA')][string]$Seviye = 'BILGI')
    $satir = '{0} [{1}] {2}' -f (Get-Date -Format 'HH:mm:ss'), $Seviye, $Mesaj
    $renk = @{ BILGI = 'Gray'; TAMAM = 'Green'; UYARI = 'Yellow'; HATA = 'Red' }[$Seviye]
    Write-Host $satir -ForegroundColor $renk
    if ($script:LogFile) { Add-Content -Path $script:LogFile -Value $satir -Encoding UTF8 }
}

# Rapor dosyasına girecek tek satırlık sonuçlar (ör. "Ses sürücüsü: TAMAM").
function Add-N10Ozet([string]$Konu, [string]$Durum, [string]$Ayrinti = '') {
    [void]$script:Ozet.Add([pscustomobject]@{ Konu = $Konu; Durum = $Durum; Ayrinti = $Ayrinti })
}
function Get-N10Ozet { , $script:Ozet }

function Invoke-N10Web {
    param([string]$Url, [string]$OutFile, [string]$Method = 'GET', $Body = $null, [hashtable]$Headers = @{})
    if ($env:GITHUB_TOKEN -and $Url -like 'https://api.github.com/*') { $Headers['Authorization'] = "Bearer $env:GITHUB_TOKEN" }
    $p = @{ Uri = $Url; UseBasicParsing = $true; Method = $Method; Headers = $Headers; UserAgent = 'Mozilla/5.0 (Windows NT 10.0) N10JC-Win7-Kit' }
    if ($Body) { $p['Body'] = $Body; $p['ContentType'] = 'application/x-www-form-urlencoded' }
    if ($OutFile) { $p['OutFile'] = $OutFile }
    for ($i = 1; $i -le 3; $i++) {
        try { return Invoke-WebRequest @p }
        catch {
            $kod = $null
            if ($_.Exception.Response) { $kod = [int]$_.Exception.Response.StatusCode }
            if ($kod -eq 404 -or $kod -eq 403 -or $i -eq 3) { throw }
            Start-Sleep -Seconds (2 * $i)
        }
    }
}

# Listedeki adresleri sırayla dener, ilk başarılı indirmeyi kullanır. Dosya zaten varsa indirmez.
function Get-N10Dosya {
    param([string[]]$Urls, [string]$Hedef)
    if ((Test-Path $Hedef) -and (Get-Item $Hedef).Length -gt 0) { return $true }
    New-Item -ItemType Directory -Force -Path (Split-Path $Hedef) | Out-Null
    foreach ($u in $Urls) {
        $gecici = "$Hedef.part"
        try {
            Write-N10Log "İndiriliyor: $u"
            Invoke-N10Web -Url $u -OutFile $gecici | Out-Null
            if ((Get-Item $gecici).Length -lt 1024) { throw 'dosya çok küçük' }
            Move-Item -Force $gecici $Hedef
            return $true
        } catch {
            Write-N10Log "Olmadı ($u): $($_.Exception.Message)" 'UYARI'
            Remove-Item -Force -ErrorAction SilentlyContinue $gecici
        }
    }
    return $false
}

function Get-N10GitHubAsset {
    # En son sürümün eklerinden, desene uyan ilkinin indirme adresini verir.
    param([string]$Repo, [string]$Desen, [string]$Haric = '^$')
    $r = Invoke-N10Web -Url "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ Accept = 'application/vnd.github+json' }
    $rel = $r.Content | ConvertFrom-Json
    foreach ($a in $rel.assets) {
        if ($a.name -match $Desen -and $a.name -notmatch $Haric) {
            return [pscustomobject]@{ Ad = $a.name; Url = $a.browser_download_url; Surum = $rel.tag_name }
        }
    }
    return $null
}

# ---------------- Windows Update Kataloğu ----------------
# catalog.update.microsoft.com arama sayfasını okur. Her satır: Id, Baslik, Urunler, Sinif, Tarih, Surum.
function Find-N10Katalog([string]$Sorgu) {
    $url = 'https://www.catalog.update.microsoft.com/Search.aspx?q=' + [uri]::EscapeDataString($Sorgu)
    $html = (Invoke-N10Web -Url $url).Content
    if ($env:N10_KATALOG_DOKUM) {
        New-Item -ItemType Directory -Force $env:N10_KATALOG_DOKUM | Out-Null
        Set-Content -Encoding UTF8 -Path (Join-Path $env:N10_KATALOG_DOKUM (($Sorgu -replace '[^A-Za-z0-9]+', '_') + '.html')) -Value $html
    }
    $satirlar = @{}
    $re = [regex]'(?s)id="([0-9a-fA-F-]{36})_C(\d)_R\d+"[^>]*>(.*?)</td>'
    foreach ($m in $re.Matches($html)) {
        $id = $m.Groups[1].Value
        if (-not $satirlar.ContainsKey($id)) { $satirlar[$id] = @{} }
        $metin = [regex]::Replace($m.Groups[3].Value, '<[^>]+>', ' ')
        $satirlar[$id][[int]$m.Groups[2].Value] = [Net.WebUtility]::HtmlDecode(($metin -replace '\s+', ' ').Trim())
    }
    $sonuc = @(foreach ($id in $satirlar.Keys) {
        $s = $satirlar[$id]
        $tarih = [datetime]::MinValue
        if ($s.ContainsKey(4)) { [void][datetime]::TryParseExact($s[4], 'M/d/yyyy', [Globalization.CultureInfo]::InvariantCulture, 'None', [ref]$tarih) }
        [pscustomobject]@{
            Id = $id; Baslik = $s[1]; Urunler = $s[2]; Sinif = $s[3]; Tarih = $tarih
            Surum = $(if ($s.ContainsKey(5)) { $s[5] } else { '' })
        }
    })
    if ($sonuc.Count -eq 0) { return }
    , @($sonuc | Sort-Object Tarih -Descending)
}

function Get-N10KatalogUrl([string]$Id) {
    $govde = 'updateIDs=' + [uri]::EscapeDataString("[{`"size`":0,`"languages`":`"`",`"uidInfo`":`"$Id`",`"updateID`":`"$Id`"}]")
    $html = (Invoke-N10Web -Url 'https://www.catalog.update.microsoft.com/DownloadDialog.aspx' -Method POST -Body $govde).Content
    , @([regex]::Matches($html, "downloadInformation\[\d+\]\.files\[\d+\]\.url\s*=\s*'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
}

# KB numarasıyla Windows 7 x86 güncellemesini bulur ve indirir. İndirilen .msu yolunu verir.
function Get-N10Guncelleme {
    param([string]$KB, [string]$Klasor, [string[]]$YedekUrl = @())
    $mevcut = Get-ChildItem -Path $Klasor -Filter "*$($KB.ToLower())*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($mevcut) { return $mevcut.FullName }
    $adaylar = @()
    try {
        $adaylar = @((Find-N10Katalog $KB) | Where-Object {
                $_.Baslik -match 'Windows 7' -and $_.Baslik -notmatch 'x64|Itanium|Embedded|Server|ARM64'
            })
    } catch { Write-N10Log "Katalog araması olmadı ($KB): $($_.Exception.Message)" 'UYARI' }
    $urls = @()
    foreach ($a in $adaylar) {
        try { $urls += (Get-N10KatalogUrl $a.Id) | Where-Object { $_ -match '\.msu$' -and $_ -notmatch 'x64' } } catch {}
        if ($urls) { break }
    }
    $urls += $YedekUrl
    foreach ($u in $urls) {
        $hedef = Join-Path $Klasor ([IO.Path]::GetFileName(([uri]$u).AbsolutePath))
        if (Get-N10Dosya -Urls @($u) -Hedef $hedef) { return $hedef }
    }
    return $null
}

# ---------------- Sürücüler ----------------
function Expand-N10Cab([string]$Cab, [string]$Hedef) {
    New-Item -ItemType Directory -Force -Path $Hedef | Out-Null
    & expand.exe -F:* "$Cab" "$Hedef" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "expand.exe hata kodu $LASTEXITCODE" }
}

# Bir INF, verilen donanım kimliğini 32-bit (x86) için içeriyor mu?
function Test-N10Inf([string]$Klasor, [string]$HwId) {
    foreach ($inf in Get-ChildItem -Path $Klasor -Filter *.inf -Recurse -ErrorAction SilentlyContinue) {
        $metin = Get-Content -Raw -Path $inf.FullName
        if ($metin -notmatch [regex]::Escape($HwId)) { continue }
        if ($metin -match '(?i)NTx86' -or $metin -notmatch '(?i)NTamd64|NTia64') { return $true }
    }
    return $false
}

# Donanım kimliğiyle katalogda Windows 7 (yoksa Vista) 32-bit sürücüsü arar, ilk uygun olanı $Hedef'e açar.
function Get-N10KatalogSurucu {
    param([string]$Ad, [string[]]$Sorgular, [string]$HwId, [string]$Hedef, [string]$Onbellek)
    if (Test-N10Inf $Hedef $HwId) { Write-N10Log "$Ad hazır (önbellekte)." 'TAMAM'; return $true }
    $denenen = @{}
    # Katalog yalnızca en yeni 25 sonucu gösterir (çoğu Windows 10 sürücüsü); bu yüzden önce "Windows 7" ile daraltılır.
    $tumSorgular = @(foreach ($ek in ' Windows 7', ' Vista', '') { foreach ($q in $Sorgular) { "$q$ek" } })
    foreach ($q in $tumSorgular) {
        $liste = @()
        try { $liste = @(Find-N10Katalog $q) } catch { Write-N10Log "Katalog araması olmadı ($q): $($_.Exception.Message)" 'UYARI'; continue }
        $sirali = @($liste | Where-Object { $_.Urunler -match 'Windows 7' } | Where-Object { $_.Baslik -notmatch 'x64|amd64|64-bit' }) +
                  @($liste | Where-Object { $_.Urunler -match 'Windows 7' -and $_.Baslik -match 'x64|amd64|64-bit' }) +
                  @($liste | Where-Object { $_.Urunler -notmatch 'Windows 7' -and $_.Urunler -match 'Vista' })
        foreach ($aday in ($sirali | Select-Object -First 6)) {
            if ($denenen.ContainsKey($aday.Id)) { continue }
            $denenen[$aday.Id] = $true
            try {
                foreach ($u in (Get-N10KatalogUrl $aday.Id)) {
                    $cab = Join-Path $Onbellek ([IO.Path]::GetFileName(([uri]$u).AbsolutePath))
                    if (-not (Get-N10Dosya -Urls @($u) -Hedef $cab)) { continue }
                    $gecici = Join-Path $Onbellek ('acilan_' + [IO.Path]::GetFileNameWithoutExtension($cab))
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $gecici
                    Expand-N10Cab $cab $gecici
                    if (Test-N10Inf $gecici $HwId) {
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $Hedef
                        Move-Item $gecici $Hedef
                        Write-N10Log "${Ad}: '$($aday.Baslik)' ($($aday.Tarih.ToString('yyyy-MM-dd')))" 'TAMAM'
                        return $true
                    }
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $gecici
                }
            } catch { Write-N10Log "$Ad adayı olmadı ($($aday.Baslik)): $($_.Exception.Message)" 'UYARI' }
        }
    }
    return $false
}

# ---------------- 7-Zip (yalnızca derleme bilgisayarında, kurulum yapmadan) ----------------
function Get-N10SevenZip([string]$AracKlasoru) {
    $exe = Join-Path $AracKlasoru '7zip\Files\7-Zip\7z.exe'
    if (Test-Path $exe) { return $exe }
    foreach ($p in @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe")) { if (Test-Path $p) { return $p } }
    $msi = Join-Path $AracKlasoru '7z-x64.msi'
    $urls = @()
    try { $a = Get-N10GitHubAsset -Repo 'ip7z/7zip' -Desen '-x64\.msi$'; if ($a) { $urls += $a.Url } } catch {}
    $urls += 'https://www.7-zip.org/a/7z2409-x64.msi'
    if (-not (Get-N10Dosya -Urls $urls -Hedef $msi)) { throw '7-Zip indirilemedi' }
    # "msiexec /a" kurulum yapmaz, yalnızca dosyaları klasöre çıkarır.
    $p = Start-Process msiexec.exe -ArgumentList "/a `"$msi`" /qn TARGETDIR=`"$AracKlasoru\7zip`"" -Wait -PassThru
    if ($p.ExitCode -ne 0 -or -not (Test-Path $exe)) { throw "7-Zip açılamadı (msiexec $($p.ExitCode))" }
    return $exe
}

# ---------------- ISO (Windows'un kendi IMAPI2 bileşeniyle, ek program gerekmez) ----------------
function New-N10Iso {
    param([string]$Kaynak, [string]$Hedef, [string]$Etiket, [string]$BootDosyasi)
    if (-not ('N10IsoYaz' -as [type])) {
        $cp = New-Object CodeDom.Compiler.CompilerParameters
        $cp.CompilerOptions = '/unsafe'
        Add-Type -CompilerParameters $cp -TypeDefinition @'
public class N10IsoYaz {
    public unsafe static void Yaz(string yol, object akis, int blok, int toplam) {
        int okunan = 0; byte[] tampon = new byte[blok]; var p = (System.IntPtr)(&okunan);
        var cik = System.IO.File.OpenWrite(yol); var gir = akis as System.Runtime.InteropServices.ComTypes.IStream;
        while (toplam-- > 0) { gir.Read(tampon, blok, p); cik.Write(tampon, 0, okunan); }
        cik.Flush(); cik.Close();
    }
}
'@
    }
    $fs = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
    $fs.ChooseImageDefaultsForMediaType(13)   # çift katmanlı DVD boyutu
    $fs.FileSystemsToCreate = 4               # yalnız UDF: 4 GB'tan büyük install.wim de sığar
    $fs.VolumeName = $Etiket
    $bootAkis = $null
    if ($BootDosyasi) {
        # El Torito, BIOS önyüklemesi (N10JC'de UEFI yok)
        $bootAkis = New-Object -ComObject ADODB.Stream
        $bootAkis.Type = 1; $bootAkis.Open(); $bootAkis.LoadFromFile($BootDosyasi)
        $boot = New-Object -ComObject IMAPI2FS.BootOptions
        $boot.AssignBootImage($bootAkis)
        $fs.BootImageOptions = $boot
    }
    $fs.Root.AddTree($Kaynak, $false)
    $sonuc = $fs.CreateResultImage()
    Remove-Item -Force -ErrorAction SilentlyContinue $Hedef
    [N10IsoYaz]::Yaz($Hedef, $sonuc.ImageStream, $sonuc.BlockSize, $sonuc.TotalBlocks)
    if ($bootAkis) { $bootAkis.Close() }
}

Export-ModuleMember -Function *-N10*
