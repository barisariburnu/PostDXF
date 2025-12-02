# PowerShell script to convert all DXF files in outputs folder to DGN format
# Uses converter.exe to process each DXF file

# Get the script directory and project root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

# Paths
$converterExe = Join-Path $scriptDir "converter.exe"
$outputsFolder = Join-Path $projectRoot "outputs"

# Check if converter.exe exists
if (-Not (Test-Path $converterExe)) {
    Write-Host "HATA: converter.exe bulunamadi: $converterExe" -ForegroundColor Red
    exit 1
}

# Check if outputs folder exists
if (-Not (Test-Path $outputsFolder)) {
    Write-Host "HATA: outputs klasoru bulunamadi: $outputsFolder" -ForegroundColor Red
    exit 1
}

# Get all DXF files in the outputs folder
$dxfFiles = Get-ChildItem -Path $outputsFolder -Filter "*.dxf" -File

# Check if any DXF files were found
if ($dxfFiles.Count -eq 0) {
    Write-Host "UYARI: outputs klasorunde DXF dosyasi bulunamadi." -ForegroundColor Yellow
    exit 0
}

Write-Host "Toplam $($dxfFiles.Count) adet DXF dosyasi bulundu." -ForegroundColor Green
Write-Host "Donusturme islemi basliyor..." -ForegroundColor Cyan
Write-Host ""

# Counter for tracking progress
$currentFile = 0
$successCount = 0
$errorCount = 0

# Process each DXF file
foreach ($dxfFile in $dxfFiles) {
    $currentFile++
    $dxfPath = $dxfFile.FullName
    
    Write-Host "[$currentFile/$($dxfFiles.Count)] Isleniyor: $($dxfFile.Name)" -ForegroundColor Cyan
    
    try {
        # Run converter.exe with the full path of the DXF file
        & $converterExe $dxfPath
        
        # Check the exit code
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  BASARILI: $($dxfFile.Name)" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "  HATA: $($dxfFile.Name) - Cikis kodu: $LASTEXITCODE" -ForegroundColor Red
            $errorCount++
        }
    }
    catch {
        Write-Host "  HATA: $($dxfFile.Name) - $_" -ForegroundColor Red
        $errorCount++
    }
    
    Write-Host ""
}

# Summary
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Donusturme islemi tamamlandi!" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Toplam dosya: $($dxfFiles.Count)" -ForegroundColor White
Write-Host "Basarili: $successCount" -ForegroundColor Green
Write-Host "Hata: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "White" })
Write-Host ""

# Exit with error code if any conversions failed
if ($errorCount -gt 0) {
    exit 1
}
