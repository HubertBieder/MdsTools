# Einstellungen fuer Invoke-ScriptAnalyzer (Aufruf: Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1)
# 2026-10-31 Hubi/Claude: bewusst ausgeschlossene Regeln
@{
    ExcludeRules = @(
        # Konsolenausgabe ist Zweck von Write-Header/-Info/... und der Install-Skripte
        'PSAvoidUsingWriteHost',
        # $mds*-Variablen sind bewusst global (MdsTools.md, Globale Variablen)
        'PSAvoidGlobalVars',
        # Nur PowerShell 7 (A1): UTF-8 ohne BOM wird korrekt gelesen
        'PSUseBOMForUnicodeEncodedFile'
    )
}
