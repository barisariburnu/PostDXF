$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$ConverterExe = Join-Path $ScriptDir "converter.exe"
$OutputsFolder = Join-Path $ProjectRoot "outputs"
$LogFile = Join-Path $ScriptDir "task_log.txt"

# Log fonksiyonu
function Write-Log($Message) {
    $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Stamp - $Message" | Out-File -FilePath $LogFile -Append
}

Write-Log "--- Islem Basladi ---"

# Klasör kontrolü
if (-not (Test-Path $OutputsFolder)) {
    Write-Log "HATA: Outputs klasoru bulunamadi: $OutputsFolder"
    exit 1
}

# Tum DXF dosyalarini bul
$DxfFiles = Get-ChildItem -Path $OutputsFolder -Filter "*.dxf"

Write-Log "Toplam $($DxfFiles.Count) dosya bulundu."

foreach ($DxfFile in $DxfFiles) {
    $DxfPath = $DxfFile.FullName
    $DgnPath = [System.IO.Path]::ChangeExtension($DxfPath, ".dgn")
    
    Write-Log "Isleniyor: $($DxfFile.Name)"
    
    # Eski DGN varsa temizle
    if (Test-Path $DgnPath) { Remove-Item $DgnPath -Force }

    # Converter'ı başlat (Hidden modunda başlatmayı dener)
    $Proc = Start-Process -FilePath $ConverterExe -ArgumentList "`"$DxfPath`"" -WindowStyle Hidden -PassThru
    
    # Bekleme döngüsü (Maksimum 2 dakika)
    $TimeoutSec = 120 
    $Elapsed = 0
    $FileCreated = $false

    while ($Elapsed -lt $TimeoutSec) {
        if (Test-Path $DgnPath) {
            # Dosya oluştu, ancak yazmanın bitmesi için kısa bir süre bekle
            Start-Sleep -Seconds 2
            $FileCreated = $true
            break
        }
        Start-Sleep -Seconds 2
        $Elapsed += 2
        
        # İşlem beklenmedik şekilde kapandıysa çık
        if ($Proc.HasExited) { break }
    }
    
    # GUI'yi zorla kapat (Bu sayede Task Scheduler takılmaz)
    if (-not $Proc.HasExited) {
        $Proc | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Log "  GUI otomatik kapatildi."
    }
    
    if ($FileCreated) {
        Write-Log "  BASARILI: $($DxfFile.Name)"
    }
    else {
        Write-Log "  HATA: $($DxfFile.Name) donusturulemedi (Zaman asimi)."
    }
}

Write-Log "--- Islem Tamamlandi ---"