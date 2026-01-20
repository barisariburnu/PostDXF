@echo off
cd /d E:\Workspaces\CadastralFlow\scripts

E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\BUYUKORHAN.DXF
E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\GEMLIK.DXF
E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\GURSU.DXF
E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\HARMANCIK.DXF
E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\INEGOL.DXF
E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\IZNIK.DXF
E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\KARACABEY.DXF
E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\KELES.DXF
E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\KESTEL.DXF
E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\MUDANYA.DXF
E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\MUSTAFAKEMALPASA.DXF
E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\NILUFER.DXF
E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\ORHANELI.DXF
E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\ORHANGAZI.DXF
E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\OSMANGAZI.DXF
E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\YENISEHIR.DXF
E:\Workspaces\CadastralFlow\scripts\converter.exe E:\Workspaces\CadastralFlow\outputs\YILDIRIM.DXF

:: DGN dosyalarini aga kopyala
copy /y E:\Workspaces\CadastralFlow\outputs\*.DGN \\10.5.1.4\Murat\kadastro\ >nul 2>&1