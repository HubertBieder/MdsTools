@echo off
rem ======================================================================
rem Update-PowerShell7.cmd  (Teil von MdsTools, liegt neben Update-PowerShell7.ps1)
rem Startet Update-PowerShell7.ps1 in Windows PowerShell 5.1 als Administrator (UAC)
rem und umgeht die Execution Policy nur fuer diesen Prozess. Argumente werden durchgereicht:
rem   Update-PowerShell7.cmd                 pruefen; ohne PowerShell 7 neueste installieren
rem   Update-PowerShell7.cmd -Last           neueste Version der Linie 7.6 installieren
rem   Update-PowerShell7.cmd -Version 7.6.4  diese Version installieren
rem 2026-11-04 Hubi/Claude: erstellt
rem 2026-11-04 Hubi/Claude: umbenannt von Install-PowerShell7.cmd
rem 2026-11-11 Hubi/Claude: -Last bleibt in der Linie 7.6
rem ======================================================================
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -NoExit -File \"%~dp0Update-PowerShell7.ps1\" %*')"
