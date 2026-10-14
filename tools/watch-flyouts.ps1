# Investigation helper: logs every top-level window that becomes visible/uncloaked
# or moves while you open the system flyouts. Run it, then open each panel
# (by mouse and by keyboard shortcut), then wait for it to finish.
param([int]$Seconds = 60, [string]$Out = "$PSScriptRoot\flyout-log.txt")
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class FW {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("kernel32.dll")] public static extern IntPtr OpenThread(uint a, bool i, uint id);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern int GetThreadDescription(IntPtr h, out IntPtr d);
  [DllImport("kernel32.dll")] public static extern IntPtr LocalFree(IntPtr p);
  public static string ThreadDesc(uint tid) { var h = OpenThread(0x800, false, tid); if (h == IntPtr.Zero) return "?"; IntPtr d; string s = "?"; if (GetThreadDescription(h, out d) >= 0) { s = Marshal.PtrToStringUni(d); LocalFree(d); } CloseHandle(h); return s; }
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out int v, int s);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string t);
  // EnumWindows skips immersive/banded windows (e.g. ShellHost flyouts); FindWindowEx walks all of them.
  public static List<IntPtr> Top() { var l = new List<IntPtr>(); IntPtr h = IntPtr.Zero; while ((h = FindWindowEx(IntPtr.Zero, h, null, null)) != IntPtr.Zero) l.Add(h); return l; }
  public static int EnumCount() { int n = 0; EnumWindows((h,x)=>{n++;return true;}, IntPtr.Zero); return n; }
  public static string Cls(IntPtr h){var s=new StringBuilder(256);GetClassName(h,s,256);return s.ToString();}
  public static string Txt(IntPtr h){var s=new StringBuilder(256);GetWindowText(h,s,256);return s.ToString();}
}
"@
$names = @{}; Get-Process | % { $names[[uint32]$_.Id] = $_.Name }
function Log($line) { Write-Host $line; Add-Content -Path $Out -Value $line -Encoding UTF8 }
Set-Content -Path $Out -Value "" -Encoding UTF8
$prev = @{}; $first = $true
Log "Watching for $Seconds s. Open the hidden-icons flyout, Quick Settings and Notification Center now..."
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) {
  foreach ($h in [FW]::Top()) {
    $vis = [FW]::IsWindowVisible($h); $cloak = 0; [void][FW]::DwmGetWindowAttribute($h, 14, [ref]$cloak, 4)
    $r = New-Object FW+RECT; [void][FW]::GetWindowRect($h, [ref]$r)
    $state = "vis=$([int]$vis) cloak=$cloak [$($r.L),$($r.T),$($r.R),$($r.B)]"
    $key = [int64]$h
    # Log windows that are new (created after the baseline) or whose state changed,
    # as long as they are visible; cloak transitions are logged too.
    $changed = if ($prev.ContainsKey($key)) { $prev[$key] -ne $state } else { -not $first }
    if ($changed -and $vis) {
      $p = 0; $tid = [FW]::GetWindowThreadProcessId($h, [ref]$p)
      if (-not $names.ContainsKey($p)) { $names[$p] = (Get-Process -Id $p -ErrorAction SilentlyContinue).Name }
      $ex = [FW]::GetWindowLong($h, -20)
      $tag = if ($prev.ContainsKey($key)) { 'CHG' } else { 'NEW' }
      Log ("{0:HH:mm:ss.fff} {1} {2,-22} 0x{3:X8} {4} dpi={5} exstyle=0x{6:X8} thread='{7}' cls='{8}' title='{9}'" -f (Get-Date), $tag, $names[$p], $key, $state, [FW]::GetDpiForWindow($h), $ex, [FW]::ThreadDesc($tid), [FW]::Cls($h), [FW]::Txt($h))
    }
    $prev[$key] = $state
  }
  $first = $false
  Start-Sleep -Milliseconds 50
}
Log "Done. Log saved to $Out"
