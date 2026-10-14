# Investigation helper: waits a few seconds (open a flyout meanwhile), then
# finds the open flyout windows and saves screenshots of them with a small
# padding, plus 4x enlarged crops of their bottom-left corner, so the
# transparent shadow area around the visible panel can be measured.
param([int]$Delay = 5, [string]$OutDir = "$PSScriptRoot\captures")
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class CF {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string t);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out int v, int s);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
  public static List<IntPtr> Top() { var l = new List<IntPtr>(); IntPtr h = IntPtr.Zero; while ((h = FindWindowEx(IntPtr.Zero, h, null, null)) != IntPtr.Zero) l.Add(h); return l; }
  public static string Cls(IntPtr h){var s=new StringBuilder(256);GetClassName(h,s,256);return s.ToString();}
  public static string Txt(IntPtr h){var s=new StringBuilder(256);GetWindowText(h,s,256);return s.ToString();}
}
"@
[void][CF]::SetProcessDPIAware()
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Write-Host "Open a flyout now, capturing in $Delay s..."
Start-Sleep -Seconds $Delay

$classes = 'TopLevelWindowForOverflowXamlIsland', 'ControlCenterWindow', 'Shell_InputSwitchTopLevelWindow', 'Windows.UI.Core.CoreWindow'
$pad = 16
$found = 0
foreach ($h in [CF]::Top()) {
  $cls = [CF]::Cls($h)
  if ($classes -notcontains $cls -or -not [CF]::IsWindowVisible($h)) { continue }
  $cloak = 0; [void][CF]::DwmGetWindowAttribute($h, 14, [ref]$cloak, 4)
  if ($cloak -ne 0) { continue }
  $title = [CF]::Txt($h)
  if ($cls -eq 'Windows.UI.Core.CoreWindow' -and $title -notmatch 'Notifica') { continue }
  $r = New-Object CF+RECT; [void][CF]::GetWindowRect($h, [ref]$r)
  $w = $r.R - $r.L; $hgt = $r.B - $r.T
  if ($w -le 0 -or $hgt -le 0) { continue }

  $name = ($cls -replace '[^A-Za-z]', '')
  $bmp = New-Object System.Drawing.Bitmap ($w + 2 * $pad), ($hgt + 2 * $pad)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.L - $pad, $r.T - $pad, 0, 0, $bmp.Size)
  $bmp.Save("$OutDir\$name.png")

  # 4x enlarged 64x64 crop around the bottom-left corner of the window.
  $crop = New-Object System.Drawing.Bitmap 256, 256
  $cg = [System.Drawing.Graphics]::FromImage($crop)
  $cg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $cg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $src = New-Object System.Drawing.Rectangle ($pad - 8), ($pad + $hgt - 56), 64, 64
  $cg.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0, 0, 256, 256), $src, [System.Drawing.GraphicsUnit]::Pixel)
  # Mark the window edges (red) on the enlarged crop: x=8 and y=56 in source pixels.
  $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::Red), 1
  $cg.DrawLine($pen, 32, 0, 32, 255); $cg.DrawLine($pen, 0, 224, 255, 224)
  $crop.Save("$OutDir\$name-corner4x.png")

  "{0} title='{1}' window=[{2},{3},{4},{5}] size={6}x{7}" -f $cls, $title, $r.L, $r.T, $r.R, $r.B, $w, $hgt | Tee-Object -FilePath "$OutDir\$name.txt"
  $g.Dispose(); $cg.Dispose(); $bmp.Dispose(); $crop.Dispose(); $found++
}
if ($found -eq 0) { Write-Host "No open flyout found." } else { Write-Host "Saved to $OutDir" }
