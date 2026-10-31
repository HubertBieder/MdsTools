#======================================================================
# Datei:        InitMDS.ps1  (wird von Skripte/InitModule.ps1 nur unter Windows
#               dot-gesourct, Bereich des Aufrufers - beim Profil also global)
# Beschreibung: Laedt alle woy-/Auftrags-Skripte dieses Ordners. Die Funktionen
#               stammen aus dem alten mdsProfile.ps1 (Aufteilung: Umsetzung Schritt 3).
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Erstellt
#======================================================================

# WoyEnv.ps1 zuerst: die uebrigen Skripte brauchen Get-WoyValue/Get-WoyCredential.
$mdsSkripte = @(Get-Item -LiteralPath (Join-Path $PSScriptRoot 'WoyEnv.ps1')) +
    @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File |
        Where-Object { $_.Name -notin 'InitMDS.ps1', 'WoyEnv.ps1' } | Sort-Object Name)
foreach ($mdsSkript in $mdsSkripte) {
    . $mdsSkript.FullName
}
Remove-Variable mdsSkripte, mdsSkript -ErrorAction SilentlyContinue
