@echo off
cd /d E:\Workspaces\PostDXF\scripts

E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\BUYUKORHAN.DXF
E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\GEMLIK.DXF
E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\GURSU.DXF
E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\HARMANCIK.DXF
E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\INEGOL.DXF
E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\IZNIK.DXF
E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\KARACABEY.DXF
E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\KELES.DXF
E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\KESTEL.DXF
E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\MUDANYA.DXF
E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\MUSTAFAKEMALPASA.DXF
E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\NILUFER.DXF
E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\ORHANELI.DXF
E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\ORHANGAZI.DXF
E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\OSMANGAZI.DXF
E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\YENISEHIR.DXF
E:\Workspaces\PostDXF\scripts\converter.exe E:\Workspaces\PostDXF\outputs\YILDIRIM.DXF

:: DGN dosyalarini aga kopyala
copy /y E:\Workspaces\PostDXF\outputs\*.DGN \\10.5.1.4\Murat\kadastro\ >nul 2>&1