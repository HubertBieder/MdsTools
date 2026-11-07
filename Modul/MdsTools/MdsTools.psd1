#
# Modulmanifest fuer das Modul "MdsTools" (Nachfolger von mdsPackage)
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Erstellt, Version 8.0.0 (E1)
#   2026-11-03  Hubi/Claude  run und Show-Mds exportiert
#   2026-11-03  Hubi/Claude  8.2.0: Anpassen an Windows (Keep fuer Clear-BinFolder/Invoke-Make),
#                            JSON-Verfahren (*.mds) wird nicht mehr unterstuetzt
#   2026-11-04  Hubi/Claude  8.2.1: Show-Mds -Full, globale Skripte unter Modul/Skripte
#   2026-11-04  Hubi/Claude  8.2.2: Show-Repos
#   2026-11-04  Hubi/Claude  8.2.3: Update-PowerShell unter Windows nur Anzeige (Update-PowerShell7.cmd)
#   2026-11-05  Hubi/Claude  8.3.0: Repos und Root unabhaengig; $mdsDev, DEV_HOME und go dev entfallen
#   2026-11-05  Hubi/Claude  8.3.1: Offene Punkte MDS-Development (C# auf 8.3, mdsPackage), Umzugsrezept LUNA
#   2026-11-05  Hubi/Claude  8.3.2: Prompt ~, .env.example, Install/Uninstall ohne mdsPackage; Doku nur aktueller Stand
#   2026-11-05  Hubi/Claude  8.3.3: push, clone (Invoke-PushAll/-CloneAll), Show-Alias
#   2026-11-06  Hubi/Claude  8.3.4: go dev/go home = go repos; CloneAll: Mds geaendert -> Install.ps1
#
@{
    RootModule        = 'MdsTools.psm1'

    # Einzige Stelle fuer die Modulversion (A2); $mdsVersion liest sie aus.
    ModuleVersion     = '8.3.4'

    GUID              = '2c35decb-09fa-485a-b287-a1f1f2774b39'
    Author            = 'Hubert Bieder'
    Copyright         = '(c) 2015..2026 H.Bieder. Alle Rechte vorbehalten.'
    Description       = 'MDS (Multi Development System): Bauen und Veroeffentlichen von C#-Projekten, Datei-, ZIP- und Freigabe-Hilfen, Werkzeug-Updates sowie go/mk/run fuer macOS und Windows.'

    # Nur PowerShell 7, mindestens 7.6 (A1)
    PowerShellVersion = '7.6'
    CompatiblePSEditions = @('Core')

    # Setzt die globalen mds-Variablen im Bereich des Aufrufers (siehe Skripte/InitModule.ps1).
    ScriptsToProcess  = @('Skripte/InitModule.ps1')

    FunctionsToExport = @(
        'Write-Header', 'Write-Start', 'Write-Info', 'Write-Success', 'Write-Fail',   # Output.ps1
        'Publish-DotNet', 'Build-Project', 'Clear-BinFolder', 'Invoke-Make',           # Build.ps1
        'Clear-CodeFolder', 'Clear-Target', 'Remove-Folder',                           # FileIO.ps1
        'Backup-Develop', 'Get-OneDriveRoot',                                          # FileIO.ps1
        'Copy-FileWithCredential', 'Copy-FolderWithCredential',                        # Share.ps1
        'Copy-ToZip', 'Copy-FileToZip', 'Export-FromZip', 'Get-ZipEntry',              # Zip.ps1
        'Update-DotNet', 'Update-PowerShell', 'Show-PowerShell', 'Show-Mds',           # Tools.ps1
        'go', 'mk', 'run', 'Show-Repos', 'Show-Alias',                                 # Navigation.ps1
        'Invoke-PushAll', 'Invoke-CloneAll'                                            # Navigation.ps1
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('push', 'clone')
}
