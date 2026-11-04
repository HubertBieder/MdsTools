@echo off
rem ======================================================================
rem Install-PowerShell7.cmd  (Teil von MdsTools, liegt neben Install-PowerShell7.ps1)
rem Startet Install-PowerShell7.ps1 in Windows PowerShell 5.1 als Administrator (UAC)
rem und umgeht die Execution Policy nur fuer diesen Prozess. Argumente werden durchgereicht:
rem   Install-PowerShell7.cmd                 pruefen; ohne PowerShell 7 neueste installieren
rem   Install-PowerShell7.cmd -Last           neueste Version installieren
rem   Install-PowerShell7.cmd -Version 7.6.4  diese Version installieren
rem 2026-11-04 Hubi/Claude: erstellt
rem ======================================================================
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -NoExit -File \"%~dp0Install-PowerShell7.ps1\" %*')"
