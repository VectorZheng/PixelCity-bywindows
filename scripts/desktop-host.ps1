param([switch]$Probe, [switch]$Test)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DesktopHostNative {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    public delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lparam);
    [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lparam);
    [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint msg, IntPtr wparam, IntPtr lparam, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SetParent(IntPtr child, IntPtr parent);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr hwnd);
    [DllImport("user32.dll", SetLastError=true)] public static extern int GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll", SetLastError=true)] public static extern int SetWindowLong(IntPtr hwnd, int index, int value);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool SetLayeredWindowAttributes(IntPtr hwnd, uint key, byte alpha, uint flags);
    public static IntPtr IconLayer = IntPtr.Zero;
    public static bool Modern = false;
    public static IntPtr FindWallpaperLayer() {
        IntPtr progman = FindWindow("Progman", null);
        if (progman == IntPtr.Zero) return IntPtr.Zero;
        IntPtr ignored;
        SendMessageTimeout(progman, 0x052C, IntPtr.Zero, IntPtr.Zero, 2, 1000, out ignored);
        IntPtr shellView = FindWindowEx(progman, IntPtr.Zero, "SHELLDLL_DefView", null);
        IntPtr childWorker = FindWindowEx(progman, IntPtr.Zero, "WorkerW", null);
        if (shellView != IntPtr.Zero && childWorker != IntPtr.Zero) {
            IconLayer = shellView;
            Modern = true;
            return progman;
        }
        IntPtr result = IntPtr.Zero;
        EnumWindows((window, arg) => {
            if (FindWindowEx(window, IntPtr.Zero, "SHELLDLL_DefView", null) == IntPtr.Zero) return true;
            IntPtr next = FindWindowEx(IntPtr.Zero, window, "WorkerW", null);
            if (next != IntPtr.Zero) { result = next; return false; }
            return true;
        }, IntPtr.Zero);
        return result;
    }
}
'@
[void][DesktopHostNative]::SetProcessDPIAware()
$layer = [DesktopHostNative]::FindWallpaperLayer()
if ($Probe) {
    if ($layer -eq [IntPtr]::Zero) { Write-Output 'WALLPAPER_LAYER_NOT_FOUND'; exit 2 }
    if ([DesktopHostNative]::Modern) { Write-Output 'WALLPAPER_LAYER_MODERN_FOUND' } else { Write-Output 'WALLPAPER_LAYER_CLASSIC_FOUND' }
    exit 0
}
if ($layer -eq [IntPtr]::Zero) {
    [System.Windows.Forms.MessageBox]::Show('Desktop wallpaper layer was not found. Use the preview launcher instead.','Shenzhen Pixel City') | Out-Null
    exit 2
}
$projectDir = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $projectDir '.tools\godot\Godot_v4.6-stable_win64.exe'
if (-not (Test-Path -LiteralPath $enginePath)) { throw 'Godot 4.6 executable not found.' }
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$resolution = '{0}x{1}' -f $screen.Width,$screen.Height
$arguments = @('--path', ('"' + $projectDir + '"'), '--resolution', $resolution, '--borderless', '--', '--wallpaper')
$process = Start-Process -FilePath $enginePath -ArgumentList $arguments -WorkingDirectory $projectDir -PassThru
$attached = $false
try {
    for ($attempt = 0; $attempt -lt 100; $attempt++) {
        Start-Sleep -Milliseconds 100
        $process.Refresh()
        if ($process.HasExited) { throw 'Wallpaper process exited before attaching.' }
        if ($process.MainWindowHandle -ne [IntPtr]::Zero) { break }
    }
    $window = $process.MainWindowHandle
    if ($window -eq [IntPtr]::Zero) { throw 'Wallpaper window did not appear.' }
    $style = [DesktopHostNative]::GetWindowLong($window, -16)
    $childStyle = ($style -band (-bnot [int]0x80000000)) -bor 0x40000000
    [void][DesktopHostNative]::SetWindowLong($window, -16, $childStyle)
    if ([DesktopHostNative]::Modern) {
        $extendedStyle = [DesktopHostNative]::GetWindowLong($window, -20)
        # Layered, transparent to mouse, and no activation.
        [void][DesktopHostNative]::SetWindowLong($window, -20, ($extendedStyle -bor 0x00080000 -bor 0x00000020 -bor 0x08000000))
        if (-not [DesktopHostNative]::SetLayeredWindowAttributes($window, 0, 255, 2)) { throw 'Failed to initialize the desktop layer.' }
    }
    [void][DesktopHostNative]::SetParent($window, $layer)
    if ([DesktopHostNative]::GetParent($window) -ne $layer) { throw 'Failed to attach wallpaper to desktop layer.' }
    $insertAfter = if ([DesktopHostNative]::Modern) { [DesktopHostNative]::IconLayer } else { [IntPtr]::Zero }
    if (-not [DesktopHostNative]::SetWindowPos($window, $insertAfter, 0, 0, $screen.Width, $screen.Height, 0x0050)) { throw 'Failed to size wallpaper window.' }
    $attached = $true
    $tray = [System.Windows.Forms.NotifyIcon]::new()
    $tray.Icon = [System.Drawing.SystemIcons]::Application
    $tray.Text = 'Shenzhen Pixel City'
    $menu = [System.Windows.Forms.ContextMenuStrip]::new()
    $displayDirectory = Join-Path $env:APPDATA 'PixelCity'
    $displayFile = Join-Path $displayDirectory 'display.cfg'
    if ($Test) {
        $displayDirectory = [System.IO.Path]::GetTempPath()
        $displayFile = Join-Path $displayDirectory ('PixelCity-test-' + [Guid]::NewGuid().ToString('N') + '.cfg')
    }
    $displayMenu = [System.Windows.Forms.ToolStripMenuItem]::new('Display mode')
    [void]$menu.Items.Add($displayMenu)
    foreach ($choice in @(@('Fill (crop)', 'fill'), @('Fit (letterbox)', 'fit'), @('Stretch', 'stretch'), @('Enlarged scene (slight crop)', 'sky'))) {
        $item = [System.Windows.Forms.ToolStripMenuItem]::new($choice[0])
        $item.Tag = $choice[1]
        $item.add_Click({
            param($sender, $eventArgs)
            try {
                [void][System.IO.Directory]::CreateDirectory($displayDirectory)
                $content = '[display]' + [Environment]::NewLine + 'mode="' + $sender.Tag + '"' + [Environment]::NewLine
                [System.IO.File]::WriteAllText($displayFile, $content, [System.Text.Encoding]::UTF8)
            } catch {
                [System.Windows.Forms.MessageBox]::Show('Unable to save display mode.', 'Shenzhen Pixel City') | Out-Null
            }
        })
        [void]$displayMenu.DropDownItems.Add($item)
    }
    $exitItem = $menu.Items.Add('Exit wallpaper')
    $exitItem.add_Click({ [System.Windows.Forms.Application]::Exit() })
    $tray.ContextMenuStrip = $menu
    $tray.Visible = $true
    if ($Test) {
        $displayMenu.DropDownItems[1].PerformClick()
        if (-not [System.IO.File]::Exists($displayFile) -or -not ([System.IO.File]::ReadAllText($displayFile).Contains('mode="fit"'))) {
            throw 'Display mode menu did not save the chosen setting.'
        }
        [System.IO.File]::Delete($displayFile)
        Start-Sleep -Seconds 3
        $process.Refresh()
        if ($process.HasExited -or [DesktopHostNative]::GetParent($window) -ne $layer) { throw 'Wallpaper did not remain attached.' }
        Write-Output 'WALLPAPER_ATTACH_AND_MENU_TEST_PASSED'
        return
    }
    $timer = [System.Windows.Forms.Timer]::new()
    $timer.Interval = 3000
    $timer.add_Tick({
        $process.Refresh()
        if ($process.HasExited -or [DesktopHostNative]::GetParent($window) -ne $layer) { [System.Windows.Forms.Application]::Exit() }
    })
    $timer.Start()
    [System.Windows.Forms.Application]::Run()
} catch {
    if ($Test) { Write-Error $_.Exception.Message } else { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Shenzhen Pixel City') | Out-Null }
} finally {
    if ($timer) { $timer.Stop(); $timer.Dispose() }
    if ($tray) { $tray.Visible = $false; $tray.Dispose() }
    $process.Refresh()
    if (-not $process.HasExited) { Stop-Process -Id $process.Id }
}
