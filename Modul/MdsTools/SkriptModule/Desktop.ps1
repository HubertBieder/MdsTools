#======================================================================
# Datei:        Desktop.ps1  (wird von MdsTools.psm1 dot-gesourct)
# Beschreibung: Positionen der Desktop-Symbole (Verknuepfungen, Dateien, Ordner) je
#               Bildschirm speichern und wiederherstellen.
#               Windows: Shell-COM (IFolderView des Desktops), macOS: Finder ueber osascript.
#               Speicherdatei: $mdsConfig/Desktop/<rechner>.json (luna.json, mars.json).
#
# Versionshistorie:
#   2026-11-12  Hubi/Claude  Erstellt (8.4.0): Desktop-Symbole statt offener Fenster
#
# Oeffentlich: Save-Desktop, Restore-Desktop
#======================================================================

# [intern] Shell-Zugriff (nur Windows), wird beim ersten Aufruf uebersetzt.
# Koordinaten sind physische Pixel in Bildschirmkoordinaten (Per-Monitor-DPI-V2).
$script:DesktopApiSource = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace MdsTools
{
    public class DesktopScreen
    {
        public string Name; public bool Primary;
        public int X, Y, Width, Height;
    }

    public class DesktopIcon
    {
        public string Name; public string Path;
        public int X, Y;
    }

    public class DesktopIconList
    {
        public bool AutoArrange; public int SpacingX, SpacingY;
        public List<DesktopIcon> Icons = new List<DesktopIcon>();
    }

    [StructLayout(LayoutKind.Sequential)] public struct DPOINT { public int X, Y; }

    [ComImport, Guid("85CB6900-4D95-11CF-960C-0080C7F4EE85"), InterfaceType(ComInterfaceType.InterfaceIsDual)]
    interface IShellWindows
    {
        void _1(); void _2(); void _3(); void _4(); void _5(); void _6(); void _7(); void _8();
        [return: MarshalAs(UnmanagedType.IDispatch)]
        object FindWindowSW([In, MarshalAs(UnmanagedType.Struct)] ref object loc,
            [In, MarshalAs(UnmanagedType.Struct)] ref object locRoot, int swClass, out int hwnd, int options);
    }

    [ComImport, Guid("6D5140C1-7436-11CE-8034-00AA006009FA"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IComServiceProvider
    {
        [return: MarshalAs(UnmanagedType.IUnknown)] object QueryService(ref Guid sid, ref Guid iid);
    }

    [ComImport, Guid("000214E2-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellBrowser
    {
        void _1(); void _2(); void _3(); void _4(); void _5(); void _6();
        void _7(); void _8(); void _9(); void _10(); void _11(); void _12();
        [return: MarshalAs(UnmanagedType.IUnknown)] object QueryActiveShellView();
    }

    [ComImport, Guid("000214E3-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellView
    {
        IntPtr GetWindow();
    }

    [ComImport, Guid("000214E6-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellFolder
    {
        void _1(); void _2(); void _3(); void _4(); void _5(); void _6(); void _7(); void _8();
        void GetDisplayNameOf(IntPtr pidl, uint flags, IntPtr strret);
    }

    [ComImport, Guid("CDE725B0-CCC9-4519-917E-325D72FAB4CE"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IFolderView
    {
        uint GetCurrentViewMode();
        void SetCurrentViewMode(uint mode);
        [return: MarshalAs(UnmanagedType.IUnknown)] object GetFolder(ref Guid riid);
        IntPtr Item(int index);
        int ItemCount(uint flags);
        [return: MarshalAs(UnmanagedType.IUnknown)] object Items(uint flags, ref Guid riid);
        int GetSelectionMarkedItem();
        int GetFocusedItem();
        void GetItemPosition(IntPtr pidl, out DPOINT pt);
        void GetSpacing(ref DPOINT pt);
        void GetDefaultSpacing(out DPOINT pt);
        [PreserveSig] int GetAutoArrange();
        void SelectItem(int index, uint flags);
        void SelectAndPositionItems(uint count, [MarshalAs(UnmanagedType.LPArray)] IntPtr[] pidls,
            [MarshalAs(UnmanagedType.LPArray)] DPOINT[] points, uint flags);
    }

    public static class DesktopApi
    {
        [StructLayout(LayoutKind.Sequential)] struct RECT { public int Left, Top, Right, Bottom; }
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct MONITORINFOEX
        {
            public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string szDevice;
        }
        delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdc, IntPtr rect, IntPtr lParam);

        [DllImport("user32.dll")] static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonitorEnumProc cb, IntPtr lParam);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFOEX mi);
        [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr hWnd, ref DPOINT pt);
        [DllImport("user32.dll")] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
        [DllImport("shlwapi.dll", CharSet = CharSet.Unicode)] static extern int StrRetToBufW(IntPtr strret, IntPtr pidl, StringBuilder buf, uint size);

        static readonly IntPtr DPI_PER_MONITOR_V2 = new IntPtr(-4);
        const int SWC_DESKTOP = 8, SWFO_NEEDDISPATCH = 1;
        const uint SVGIO_ALLVIEW = 2, SVSI_POSITIONITEM = 0x80;
        const uint SHGDN_NORMAL = 0, SHGDN_FORPARSING = 0x8000;

        // Shell-COM braucht ein STA; pwsh laeuft meist schon darin, sonst eigener Thread.
        static T RunSta<T>(Func<T> f)
        {
            Func<T> mitDpi = () =>
            {
                IntPtr old = SetThreadDpiAwarenessContext(DPI_PER_MONITOR_V2);
                try { return f(); } finally { SetThreadDpiAwarenessContext(old); }
            };
            if (Thread.CurrentThread.GetApartmentState() == ApartmentState.STA) return mitDpi();
            T result = default(T); Exception fehler = null;
            var t = new Thread(() => { try { result = mitDpi(); } catch (Exception e) { fehler = e; } });
            t.SetApartmentState(ApartmentState.STA);
            t.Start(); t.Join();
            if (fehler != null) throw fehler;
            return result;
        }

        // IFolderView des Desktops (Raymond Chen: "Manipulating the positions of desktop icons").
        static IFolderView DesktopView(out DPOINT origin)
        {
            var sw = (IShellWindows)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("9BA05972-F6A8-11CF-A442-00A0C90A8F39")));
            object loc = 0, root = null; int hwnd;
            object disp = sw.FindWindowSW(ref loc, ref root, SWC_DESKTOP, out hwnd, SWFO_NEEDDISPATCH);
            Guid sid = new Guid("4C96BE40-915C-11CF-99D3-00AA004AE837"), iid = typeof(IShellBrowser).GUID;
            var browser = (IShellBrowser)((IComServiceProvider)disp).QueryService(ref sid, ref iid);
            object view = browser.QueryActiveShellView();
            origin = new DPOINT();
            ClientToScreen(((IShellView)view).GetWindow(), ref origin);
            return (IFolderView)view;
        }

        static string DisplayName(IShellFolder folder, IntPtr pidl, uint flags)
        {
            IntPtr strret = Marshal.AllocCoTaskMem(1024);
            try
            {
                folder.GetDisplayNameOf(pidl, flags, strret);
                var sb = new StringBuilder(1024);
                return StrRetToBufW(strret, pidl, sb, (uint)sb.Capacity) == 0 ? sb.ToString() : "";
            }
            catch { return ""; }
            finally { Marshal.FreeCoTaskMem(strret); }
        }

        public static List<DesktopScreen> GetScreens()
        {
            return RunSta(() =>
            {
                var list = new List<DesktopScreen>();
                EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (h, dc, r, l) =>
                {
                    var mi = new MONITORINFOEX();
                    mi.cbSize = Marshal.SizeOf(typeof(MONITORINFOEX));
                    if (GetMonitorInfo(h, ref mi))
                    {
                        list.Add(new DesktopScreen
                        {
                            Name = mi.szDevice.Replace("\\\\.\\", ""), Primary = (mi.dwFlags & 1) != 0,
                            X = mi.rcMonitor.Left, Y = mi.rcMonitor.Top,
                            Width = mi.rcMonitor.Right - mi.rcMonitor.Left, Height = mi.rcMonitor.Bottom - mi.rcMonitor.Top
                        });
                    }
                    return true;
                }, IntPtr.Zero);
                return list;
            });
        }

        public static DesktopIconList GetIcons()
        {
            return RunSta(() =>
            {
                DPOINT origin;
                var view = DesktopView(out origin);
                Guid iidFolder = typeof(IShellFolder).GUID;
                var folder = (IShellFolder)view.GetFolder(ref iidFolder);
                var result = new DesktopIconList { AutoArrange = view.GetAutoArrange() == 0 };
                var spacing = new DPOINT();
                view.GetSpacing(ref spacing);
                result.SpacingX = spacing.X; result.SpacingY = spacing.Y;
                int count = view.ItemCount(SVGIO_ALLVIEW);
                for (int i = 0; i < count; i++)
                {
                    IntPtr pidl = view.Item(i);
                    try
                    {
                        DPOINT pt;
                        view.GetItemPosition(pidl, out pt);
                        result.Icons.Add(new DesktopIcon
                        {
                            Name = DisplayName(folder, pidl, SHGDN_NORMAL), Path = DisplayName(folder, pidl, SHGDN_FORPARSING),
                            X = pt.X + origin.X, Y = pt.Y + origin.Y
                        });
                    }
                    finally { Marshal.FreeCoTaskMem(pidl); }
                }
                return result;
            });
        }

        // Setzt die Symbole mit dem Pfad paths[i] auf (xs[i], ys[i]) in Bildschirmkoordinaten.
        // Rueckgabewert: je Eintrag true, wenn das Symbol gefunden wurde.
        public static bool[] SetIcons(string[] paths, int[] xs, int[] ys)
        {
            return RunSta(() =>
            {
                DPOINT origin;
                var view = DesktopView(out origin);
                Guid iidFolder = typeof(IShellFolder).GUID;
                var folder = (IShellFolder)view.GetFolder(ref iidFolder);
                var found = new bool[paths.Length];
                var pidls = new List<IntPtr>();
                var points = new List<DPOINT>();
                var all = new List<IntPtr>();
                try
                {
                    int count = view.ItemCount(SVGIO_ALLVIEW);
                    for (int i = 0; i < count; i++)
                    {
                        IntPtr pidl = view.Item(i);
                        all.Add(pidl);
                        string path = DisplayName(folder, pidl, SHGDN_FORPARSING);
                        int k = Array.FindIndex(paths, p => string.Equals(p, path, StringComparison.OrdinalIgnoreCase));
                        if (k < 0 || found[k]) continue;
                        found[k] = true;
                        pidls.Add(pidl);
                        points.Add(new DPOINT { X = xs[k] - origin.X, Y = ys[k] - origin.Y });
                    }
                    if (pidls.Count > 0)
                        view.SelectAndPositionItems((uint)pidls.Count, pidls.ToArray(), points.ToArray(), SVSI_POSITIONITEM);
                }
                finally { foreach (var p in all) Marshal.FreeCoTaskMem(p); }
                return found;
            });
        }
    }
}
'@

# [intern] JXA-Skripte fuer macOS (Finder). Koordinaten in Punkten, Ursprung oben links am
# Hauptbildschirm; NSScreen liefert unten links und wird umgerechnet.
$script:DesktopMacGet = @'
ObjC.import('AppKit');
function run() {
    const all = $.NSScreen.screens, screens = [];
    const mainH = all.objectAtIndex(0).frame.size.height;
    for (let i = 0; i < all.count; i++) {
        const s = all.objectAtIndex(i), f = s.frame;
        let name = 'Screen' + (i + 1);
        try { name = ObjC.unwrap(s.localizedName) || name; } catch (e) { }
        screens.push({ Name: name, Primary: i === 0, X: f.origin.x, Y: mainH - (f.origin.y + f.size.height),
                       Width: f.size.width, Height: f.size.height });
    }
    const finder = Application('Finder'), icons = [];
    let arranged = false;
    try { arranged = finder.desktop.containerWindow.iconViewOptions.arrangement() !== 'not arranged'; } catch (e) { }
    for (const it of finder.desktop.items()) {
        try {
            const p = it.desktopPosition();
            let path = '';
            try { path = decodeURI(it.url()).replace(/^file:\/\//, ''); } catch (e) { }
            icons.push({ Name: it.name(), Path: path, X: p[0], Y: p[1] });
        } catch (e) { }
    }
    return JSON.stringify({ Screens: screens, AutoArrange: arranged, SpacingX: 100, SpacingY: 100, Icons: icons });
}
'@

$script:DesktopMacSet = @'
function run(argv) {
    const finder = Application('Finder'), byName = {}, result = [];
    for (const it of finder.desktop.items()) { try { byName[it.name()] = it; } catch (e) { } }
    for (const m of JSON.parse(argv[0])) {
        const it = byName[m.Name];
        if (!it) { result.push(false); continue; }
        try { it.desktopPosition = [m.X, m.Y]; result.push(true); } catch (e) { result.push(false); }
    }
    return JSON.stringify(result);
}
'@

# [intern] Fuehrt ein JXA-Skript aus; Fehler (meist fehlende Automation-Freigabe fuer den Finder) werfen.
function Invoke-DesktopJxa([string] $Script, [string[]] $Argument = @()) {
    $ausgabe = & osascript -l JavaScript -e $Script @Argument 2>&1
    if ($LASTEXITCODE -ne 0) {
        $text = ($ausgabe | Out-String).Trim()
        if ($text -match '-1743|-1744|not authorized|nicht berechtigt') {
            $text += "`nDas Terminal (bzw. VS Code) braucht die Freigabe unter Systemeinstellungen > Datenschutz & Sicherheit > Automation > Finder."
        }
        throw "osascript fehlgeschlagen: $text"
    }
    ($ausgabe | Out-String).Trim()
}

# [intern] Liest Bildschirme und Desktop-Symbole des aktuellen Systems.
# Rueckgabewert: [pscustomobject] Screens, Icons (Name, Path, X, Y), AutoArrange, SpacingX, SpacingY
function Get-DesktopState {
    if ($IsWindows) {
        if (-not ('MdsTools.DesktopApi' -as [type])) {
            Add-Type -TypeDefinition $script:DesktopApiSource -Language CSharp
        }
        $liste = [MdsTools.DesktopApi]::GetIcons()
        $screens = foreach ($s in [MdsTools.DesktopApi]::GetScreens()) {
            [pscustomobject]@{ Name = $s.Name; Primary = $s.Primary; X = $s.X; Y = $s.Y; Width = $s.Width; Height = $s.Height }
        }
        $icons = foreach ($i in $liste.Icons) {
            [pscustomobject]@{ Name = $i.Name; Path = $i.Path; X = $i.X; Y = $i.Y }
        }
        return [pscustomobject]@{
            Screens = @($screens); Icons = @($icons); AutoArrange = $liste.AutoArrange
            SpacingX = $liste.SpacingX; SpacingY = $liste.SpacingY
        }
    }
    if ($IsMacOS) {
        $d = Invoke-DesktopJxa $script:DesktopMacGet | ConvertFrom-Json
        return [pscustomobject]@{
            Screens = @($d.Screens); Icons = @($d.Icons); AutoArrange = [bool]$d.AutoArrange
            SpacingX = $d.SpacingX; SpacingY = $d.SpacingY
        }
    }
    throw 'Save-Desktop/Restore-Desktop gibt es nur unter Windows und macOS.'
}

# [intern] Setzt Symbole. $Placement: Name, Path, X, Y (Bildschirmkoordinaten).
# Rueckgabewert: je Eintrag $true (gesetzt) oder $false (nicht gefunden)
function Set-DesktopIcon([object[]] $Placement) {
    if (-not $Placement) { return }
    if ($IsWindows) {
        [string[]] $pfade = $Placement.Path
        [int[]] $xs = $Placement.X
        [int[]] $ys = $Placement.Y
        return [MdsTools.DesktopApi]::SetIcons($pfade, $xs, $ys)
    }
    $json = ConvertTo-Json -InputObject @($Placement | Select-Object Name, X, Y) -Depth 3 -Compress
    @(Invoke-DesktopJxa $script:DesktopMacSet @($json) | ConvertFrom-Json -NoEnumerate) | ForEach-Object { $_ }
}

# [intern] Standardname der Speicherdatei: Rechnername ohne Domain, klein (luna, mars).
function Get-DesktopDefaultName {
    ([Environment]::MachineName -split '\.')[0].ToLowerInvariant()
}

# [intern] Pfad der Speicherdatei: Name ohne Pfad -> $mdsConfig/Desktop/<Name>.json, sonst Pfad selbst.
function Get-DesktopFile([string] $Name) {
    if ($Name -match '[\\/]' -or $Name.EndsWith('.json', [StringComparison]::OrdinalIgnoreCase)) {
        return $Name
    }
    Join-Path (Join-Path $mdsConfig 'Desktop') "$Name.json"
}

# [intern] Bildschirm, in dem die Mitte von X/Y/Width/Height liegt; sonst der naechste.
function Get-DesktopScreenOf([object] $Item, [object[]] $Screens) {
    $mx = $Item.X + $Item.Width / 2
    $my = $Item.Y + $Item.Height / 2
    $treffer = $Screens | Where-Object { $mx -ge $_.X -and $mx -lt $_.X + $_.Width -and $my -ge $_.Y -and $my -lt $_.Y + $_.Height } |
        Select-Object -First 1
    if ($treffer) { return $treffer }
    $Screens | Sort-Object {
        $dx = [math]::Max(0, [math]::Max($_.X - $mx, $mx - ($_.X + $_.Width)))
        $dy = [math]::Max(0, [math]::Max($_.Y - $my, $my - ($_.Y + $_.Height)))
        $dx * $dx + $dy * $dy
    } | Select-Object -First 1
}

# [intern] Ordnet gespeicherte Symbole vorhandenen zu: zuerst ueber den Pfad, dann ueber den Namen.
# Rueckgabewert: [pscustomobject] Saved, Current (Current = $null, wenn das Symbol fehlt)
function Find-DesktopMatch([object[]] $Saved, [object[]] $Current) {
    # Ueber Indizes, denn [pscustomobject] gelten untereinander als gleich.
    $vergeben = [System.Collections.Generic.HashSet[int]]::new()
    $zuordnung = @{}
    foreach ($feld in 'Path', 'Name') {
        for ($i = 0; $i -lt $Saved.Count; $i++) {
            if ($zuordnung.ContainsKey($i) -or -not $Saved[$i].$feld) { continue }
            for ($j = 0; $j -lt $Current.Count; $j++) {
                if ($vergeben.Contains($j) -or $Current[$j].$feld -ne $Saved[$i].$feld) { continue }
                $zuordnung[$i] = $Current[$j]
                $null = $vergeben.Add($j)
                break
            }
        }
    }
    for ($i = 0; $i -lt $Saved.Count; $i++) {
        [pscustomobject]@{ Saved = $Saved[$i]; Current = $zuordnung[$i] }
    }
}

# [intern] Zielrechteck auf den aktuellen Bildschirmen.
# Gleicher Bildschirm (Name) mit gleicher Lage: unveraendert. Sonst relativ zum Bildschirm
# (fehlt er: Hauptbildschirm) und innerhalb des Bildschirms gehalten.
function Resolve-DesktopRect([object] $Item, [object[]] $SavedScreens, [object[]] $Screens) {
    $alt = $SavedScreens | Where-Object Name -eq $Item.Screen | Select-Object -First 1
    $neu = $Screens | Where-Object Name -eq $Item.Screen | Select-Object -First 1
    if (-not $neu) { $neu = $Screens | Where-Object Primary | Select-Object -First 1 }
    if (-not $neu) { $neu = $Screens | Select-Object -First 1 }
    if (-not $alt -or -not $neu -or
        ($alt.X -eq $neu.X -and $alt.Y -eq $neu.Y -and $alt.Width -eq $neu.Width -and $alt.Height -eq $neu.Height)) {
        return [pscustomobject]@{ X = $Item.X; Y = $Item.Y; Width = $Item.Width; Height = $Item.Height }
    }
    $w = [math]::Min($Item.Width, $neu.Width)
    $h = [math]::Min($Item.Height, $neu.Height)
    $x = $neu.X + [math]::Min([math]::Max(0, $Item.X - $alt.X), $neu.Width - $w)
    $y = $neu.Y + [math]::Min([math]::Max(0, $Item.Y - $alt.Y), $neu.Height - $h)
    [pscustomobject]@{ X = $x; Y = $y; Width = $w; Height = $h }
}

<#
.SYNOPSIS
    Speichert die Positionen der Desktop-Symbole je Bildschirm in $mdsConfig/Desktop/<rechner>.json.
.DESCRIPTION
    Windows: alle Symbole des Desktops (eigener und oeffentlicher Desktop, Papierkorb, ...).
    macOS: alle Objekte auf dem Finder-Schreibtisch; das Terminal braucht beim ersten Aufruf
    die Freigabe Automation > Finder.
.PARAMETER Name
    Name der Anordnung (Standard: Rechnername klein, z. B. luna, mars) oder Pfad einer *.json-Datei.
.EXAMPLE
    Save-Desktop
    Save-Desktop vortrag
#>
function Save-Desktop {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0)] [string] $Name = (Get-DesktopDefaultName),
        [switch] $PassThru
    )
    $state = Get-DesktopState
    $symbole = foreach ($i in $state.Icons) {
        $screen = Get-DesktopScreenOf ([pscustomobject]@{ X = $i.X; Y = $i.Y; Width = $state.SpacingX; Height = $state.SpacingY }) $state.Screens
        [ordered]@{ Name = $i.Name; Screen = $screen.Name; X = [int]$i.X; Y = [int]$i.Y; Path = $i.Path }
    }
    $daten = [ordered]@{
        Version  = 2
        Computer = [Environment]::MachineName
        System   = $(if ($IsWindows) { 'Windows' } else { 'macOS' })
        Saved    = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Spacing  = [ordered]@{ X = [int]$state.SpacingX; Y = [int]$state.SpacingY }
        Screens  = @($state.Screens | ForEach-Object {
                [ordered]@{ Name = $_.Name; Primary = [bool]$_.Primary; X = [int]$_.X; Y = [int]$_.Y; Width = [int]$_.Width; Height = [int]$_.Height }
            })
        Icons    = @($symbole | Sort-Object { $_.Screen }, { $_.X }, { $_.Y })
    }
    $datei = Get-DesktopFile $Name
    if ($PSCmdlet.ShouldProcess($datei, "$($daten.Icons.Count) Symbole speichern")) {
        $ordner = Split-Path -Parent $datei
        if ($ordner -and -not (Test-Path -LiteralPath $ordner -PathType Container)) {
            $null = New-Item -Path $ordner -ItemType Directory -Force
        }
        $daten | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $datei -Encoding utf8
        Write-Success "$($daten.Icons.Count) Symbole auf $($daten.Screens.Count) Bildschirm(en) gespeichert: $datei"
    }
    if ($state.AutoArrange) {
        Write-Warning 'Automatisch anordnen ist eingeschaltet; Restore-Desktop kann die Symbole so nicht setzen.'
    }
    if ($PassThru) { [pscustomobject]$daten }
}

<#
.SYNOPSIS
    Setzt die Desktop-Symbole auf die mit Save-Desktop gespeicherten Positionen zurueck.
.DESCRIPTION
    Zuordnung ueber den Pfad, sonst den Namen. Fehlt ein Bildschirm, landen dessen Symbole an der
    entsprechenden Stelle des Hauptbildschirms. Voraussetzung: Automatisch anordnen ist aus
    (Windows: Desktop > Ansicht; macOS: Darstellungsoptionen, Sortieren nach: Ohne).
.PARAMETER Name
    Name der Anordnung (Standard: Rechnername klein, z. B. luna, mars) oder Pfad einer *.json-Datei.
.EXAMPLE
    Restore-Desktop
    Restore-Desktop -WhatIf
#>
function Restore-Desktop {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0)] [string] $Name = (Get-DesktopDefaultName)
    )
    $datei = Get-DesktopFile $Name
    if (-not (Test-Path -LiteralPath $datei -PathType Leaf)) {
        Write-Error "Keine gespeicherte Anordnung: $datei (zuerst Save-Desktop)."
        return
    }
    $daten = Get-Content -LiteralPath $datei -Raw | ConvertFrom-Json
    if (-not $daten.PSObject.Properties['Icons']) {
        Write-Error "$datei enthaelt keine Desktop-Symbole (alte Fenster-Datei?). Bitte neu mit Save-Desktop speichern."
        return
    }
    $state = Get-DesktopState
    if ($state.AutoArrange) {
        Write-Error 'Automatisch anordnen ist eingeschaltet. Windows: Rechtsklick auf den Desktop > Ansicht > Symbole automatisch anordnen ausschalten; macOS: Darstellungsoptionen > Sortieren nach: Ohne.'
        return
    }
    $gespeichert = @($daten.Icons)
    $plan = [System.Collections.Generic.List[object]]::new()
    $fehlt = [System.Collections.Generic.List[object]]::new()
    foreach ($m in Find-DesktopMatch $gespeichert $state.Icons) {
        if (-not $m.Current) { $fehlt.Add($m.Saved); continue }
        $s = $m.Saved
        $r = Resolve-DesktopRect ([pscustomobject]@{ Screen = $s.Screen; X = $s.X; Y = $s.Y; Width = $daten.Spacing.X; Height = $daten.Spacing.Y }) @($daten.Screens) $state.Screens
        if ($r.X -eq $m.Current.X -and $r.Y -eq $m.Current.Y) { continue }
        if ($PSCmdlet.ShouldProcess("$($s.Name) -> $($s.Screen) $($r.X),$($r.Y)", 'Symbol setzen')) {
            $plan.Add([pscustomobject]@{ Name = $m.Current.Name; Path = $m.Current.Path; X = [int]$r.X; Y = [int]$r.Y })
        }
    }
    $ok = @(Set-DesktopIcon $plan.ToArray())
    for ($i = 0; $i -lt $ok.Count; $i++) {
        if (-not $ok[$i]) { Write-Warning "$($plan[$i].Name) nicht gesetzt." }
    }
    foreach ($f in $fehlt) { Write-Warning "$($f.Name) liegt nicht mehr auf dem Desktop." }
    $gesetzt = @($ok | Where-Object { $_ }).Count
    if (-not $WhatIfPreference) {
        Write-Success "$gesetzt Symbole verschoben, $($gespeichert.Count - $fehlt.Count - $gesetzt) standen schon richtig, $($fehlt.Count) fehlen"
    }
}
