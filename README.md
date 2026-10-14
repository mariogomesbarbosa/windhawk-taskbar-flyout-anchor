# Taskbar Flyout Anchor

A [Windhawk](https://windhawk.net/) mod for Windows 11 that makes the system
tray flyouts open right above the taskbar button that opened them, instead of
at a fixed position.

It's meant for custom taskbar layouts, such as a centered dock made with
[Windows 11 Taskbar Styler](https://windhawk.net/mods/windows-11-taskbar-styler),
where the system tray is no longer at the right edge of the screen. By default,
Windows keeps opening these flyouts at the screen corner, far away from their
buttons.

## Covered flyouts

| Flyout | Opened by | Anchored to |
|---|---|---|
| Hidden icons (tray overflow) | Chevron | Chevron button |
| Quick Settings | Network/volume buttons, Win+A | Network/volume button group |
| Notification Center and calendar | Clock, Win+N | Clock/notifications button group |
| Input switcher | Input indicator, Win+Space | Input indicator |

The button positions are read every time a flyout opens, so the flyouts follow
the taskbar when its width changes (for example when apps are pinned or
unpinned). If a button position isn't available, the flyout keeps the default
Windows position.

## Settings

Each flyout has its own group of settings:

| Setting | Default | Description |
|---|---|---|
| Anchor this flyout | On | Enables anchoring for the flyout. |
| Alignment | Centered (hidden icons, input switcher), right-aligned (Quick Settings, Notification Center) | Centered on the button, or the right edge of the flyout aligned with the right edge of the system tray. |
| Vertical spacing | 8 px | Distance between the top of the taskbar buttons and the bottom of the visible flyout panel. Negative values make the flyout overlap the taskbar. |
| Minimum screen margin | 8 px | Minimum distance between the flyout and the edges of the monitor work area. |

Pixel values are at 100% scaling and are scaled with the monitor DPI.

## Installation

The mod is submitted to the official Windhawk mod list. Until it's available
there:

1. In Windhawk, click **Create a new mod**.
2. Replace the editor content with
   [`taskbar-flyout-anchor.wh.cpp`](taskbar-flyout-anchor.wh.cpp).
3. Click **Compile Mod**, then **Exit editing mode**.

## How it works

* **explorer.exe**: the hidden icons flyout and the input switcher are
  explorer windows, repositioned when explorer positions them
  (`SetWindowPos`/`MoveWindow`). The Notification Center is a
  ShellExperienceHost window that explorer shows by uncloaking it
  (`DwmSetWindowAttribute`), and it's moved right before that.
* **ShellHost.exe**: Quick Settings is a ShellHost window
  (`ControlCenterWindow`), repositioned when ShellHost positions it.
* The button positions are read from the taskbar XAML tree on the taskbar
  thread, using the same `taskbar.dll` objects as other taskbar mods (no XAML
  diagnostics, so it doesn't conflict with Windows 11 Taskbar Styler).
  ShellHost asks explorer for them with a window message, and the answer is
  passed through a shared memory section.

## Limitations

* Only Windows 11 with the taskbar at the bottom of the screen is supported.
  With a vertical, top or auto-hidden taskbar, the flyouts keep their default
  position.
* Tested on Windows 11 25H2 (build 26200).
* Flyouts open on the monitor of the taskbar that opened them. Secondary
  taskbars usually don't have these buttons, in which case the default
  position is kept.
* If the input indicator can't be identified on your Windows build, the input
  switcher is anchored after the indicator is clicked once; until then,
  Win+Space opens it at the default position.
* Mods that also move these flyouts (such as Shell Flyout Positions) shouldn't
  be enabled at the same time.

## Development tools

The [`tools`](tools) folder has the PowerShell scripts used to investigate the
flyout windows:

* `watch-flyouts.ps1` logs every top-level window that appears or moves while
  the flyouts are opened (process, thread, class, rect, DPI).
* `capture-flyout.ps1` captures the open flyouts with enlarged corner crops, to
  measure the transparent shadow area around the visible panels.
