#======================================================================
# Modul:        MdsTools.psm1 (Root-Modul)
# Beschreibung: Laedt alle Funktionsdateien aus SkriptModule in den Modulbereich.
#               Dadurch sehen sich alle Funktionen gegenseitig; exportiert wird nur,
#               was in MdsTools.psd1 (FunctionsToExport) steht.
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Erstellt (Nachfolger von mdsPackage)
#======================================================================

foreach ($datei in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'SkriptModule') -Filter '*.ps1' -File) {
    . $datei.FullName
}
Remove-Variable datei
