# PowerShell script to convert all DXF files in outputs folder to DGN format
# Uses converter.exe to process each DXF file

# Get the script directory and project root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

# Paths
$converterExe = Join-Path $scriptDir "converter.exe"
$outputsFolder = Join-Path $projectRoot "outputs"
$networkPath = "\\10.5.1.4\Murat\kadastro"

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
    $dxfFileName = $dxfFile.Name
    $dgnFileName = [System.IO.Path]::ChangeExtension($dxfFileName, ".dgn")
    $dgnPath = Join-Path $outputsFolder $dgnFileName
    
    # Start timing
    $startTime = Get-Date
    
    Write-Host "[$currentFile/$($dxfFiles.Count)] Isleniyor: $dxfFileName" -ForegroundColor Cyan
    Write-Host "  Baslangic zamani: $($startTime.ToString('HH:mm:ss'))" -ForegroundColor Gray
    Write-Host "  Komut: $converterExe $dxfPath" -ForegroundColor Gray
    
    # Delete existing DGN file if exists to ensure fresh conversion
    if (Test-Path $dgnPath) {
        Remove-Item $dgnPath -Force
        Write-Host "  Eski DGN dosyasi silindi" -ForegroundColor Yellow
    }
    
    try {
        # Run converter.exe directly using & operator
        # This is exactly like: C:\CBS\PostDXF\scripts\converter.exe C:\CBS\PostDXF\outputs\FILE.dxf
        & $converterExe $dxfPath
        
        Write-Host "  Converter calistirildi" -ForegroundColor Gray
        
        # Wait for DGN file to be created (with timeout of 1 hour)
        $maxWaitSeconds = 3600  # 1 hour = 3600 seconds
        $waitedSeconds = 0
        $checkIntervalMs = 500
        
        Write-Host "  DGN dosyasi olusturulmasi bekleniyor..." -ForegroundColor Gray
        
        while (-not (Test-Path $dgnPath) -and $waitedSeconds -lt $maxWaitSeconds) {
            Start-Sleep -Milliseconds $checkIntervalMs
            $waitedSeconds += ($checkIntervalMs / 1000)
        }
        
        # Check if DGN file was created
        if (Test-Path $dgnPath) {
            $endTime = Get-Date
            $duration = $endTime - $startTime
            $dgnSize = (Get-Item $dgnPath).Length
            
            Write-Host "  Bitis zamani: $($endTime.ToString('HH:mm:ss'))" -ForegroundColor Gray
            Write-Host "  Sure: $([math]::Floor($duration.TotalMinutes)) dakika $($duration.Seconds) saniye" -ForegroundColor Gray
            Write-Host "  BASARILI: $dgnFileName ($([math]::Round($dgnSize/1KB, 2)) KB)" -ForegroundColor Green
            $successCount++
        }
        else {
            $endTime = Get-Date
            $duration = $endTime - $startTime
            
            Write-Host "  Bitis zamani: $($endTime.ToString('HH:mm:ss'))" -ForegroundColor Gray
            Write-Host "  Sure: $([math]::Floor($duration.TotalMinutes)) dakika $($duration.Seconds) saniye" -ForegroundColor Gray
            Write-Host "  HATA: DGN dosyasi $maxWaitSeconds saniye icinde olusturulamadi" -ForegroundColor Red
            Write-Host "  Beklenen konum: $dgnPath" -ForegroundColor Red
            
            # List all files in outputs folder for debugging
            Write-Host "  Outputs klasorundeki dosyalar:" -ForegroundColor Yellow
            Get-ChildItem -Path $outputsFolder | ForEach-Object { Write-Host "    - $($_.Name)" -ForegroundColor Yellow }
            
            $errorCount++
        }
    }
    catch {
        Write-Host "  HATA: $dxfFileName - $_" -ForegroundColor Red
        $errorCount++
    }
    
    # Wait 30 seconds between files (except for the last file)
    if ($currentFile -lt $dxfFiles.Count) {
        Write-Host "  Sonraki dosya icin 30 saniye bekleniyor..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
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

# Copy all DGN files to network share (as a backup/alternative method)
Write-Host ""
Write-Host "Ag paylasimina tum DGN dosyalari kopyalaniyor..." -ForegroundColor Cyan

$dgnFiles = Get-ChildItem -Path $outputsFolder -Filter "*.dgn" -File
$copiedCount = 0

foreach ($dgnFile in $dgnFiles) {
    try {
        Copy-Item -Path $dgnFile.FullName -Destination $networkPath -Force -ErrorAction Stop
        Write-Host "  Kopyalandi: $($dgnFile.Name) -> $networkPath" -ForegroundColor Green
        $copiedCount++
    }
    catch {
        Write-Host "  Kopyalanamadi: $($dgnFile.Name) - $_" -ForegroundColor Red
    }
}

Write-Host "Ag paylasimina kopyalanan dosya sayisi: $copiedCount/$($dgnFiles.Count)" -ForegroundColor $(if ($copiedCount -eq $dgnFiles.Count) { "Green" } else { "Yellow" })

# List all DGN files in the outputs folder
Write-Host ""
Write-Host "Outputs klasorundeki DGN dosyalari:" -ForegroundColor Cyan
$dgnFiles | ForEach-Object { 
    $sizeKB = [math]::Round($_.Length / 1KB, 2)
    Write-Host "  - $($_.Name) ($sizeKB KB)" -ForegroundColor White 
}

Write-Host ""

# Exit with error code if any conversions failed
if ($errorCount -gt 0) {
    exit 1
}
