#
# Modulmanifest fuer das Modul "MdsTools" (Nachfolger von mdsPackage)
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Erstellt, Version 8.0.0 (E1)
#
@{
    RootModule        = 'MdsTools.psm1'

    # Einzige Stelle fuer die Modulversion (A2); $mdsVersion liest sie aus.
    ModuleVersion     = '8.0.0'

    GUID              = '2c35decb-09fa-485a-b287-a1f1f2774b39'
    Author            = 'Hubert Bieder'
    Copyright         = '(c) 2015..2026 H.Bieder. Alle Rechte vorbehalten.'
    Description       = 'MDS (Multi Development System): Bauen und Veroeffentlichen von C#-Projekten, Datei-, ZIP- und Freigabe-Hilfen, Werkzeug-Updates sowie go/mk fuer macOS und Windows.'

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
        'Update-DotNet', 'Update-PowerShell', 'Show-PowerShell',                       # Tools.ps1
        'go', 'mk'                                                                     # Navigation.ps1
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
