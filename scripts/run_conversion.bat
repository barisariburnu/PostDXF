@echo off

:: 1. Scriptin oldugu klasore git (En sade yöntem)
cd /d %~dp0

echo ===================================================
echo   DXF to DGN CONVERTER (DIRECT MODE)
echo ===================================================
echo.

:: 2. Dongu - hicbir tırnak işareti kullanmadan doğrudan manuel formatınızı uyguluyoruz
:: Sadece programı ve dosyayı yan yana koyuyoruz.
for %%F in (..\outputs\*.dxf) do (
    echo [ISLENIYOR] %%~nxF
    
    :: MANUEL OLARAK YAZDIGINIZ FORMAT:
    :: Program_Yolu Dosya_Yolu
    %~dp0converter.exe %%~fF
    
    :: Programın bitmesini (veya kapanmasını) bekleyip kopyalama yapıyoruz
    if exist %%~dpnF.dgn (
        echo   [TAMAM] DGN uretildi, aga kopyalaniyor...
        copy /y %%~dpnF.dgn \\10.5.1.4\Murat\kadastro\ >nul 2>&1
    ) else (
        echo   [HATA] DGN dosyasi bulunamadi.
    )
    echo ------------------------------------------
)

echo.
echo ISLEMLER TAMAMLANDI.
exit