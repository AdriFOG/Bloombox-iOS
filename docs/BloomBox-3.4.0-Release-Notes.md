# BloomBox 3.4.0 — Nova Launcher & Bloom

A new way to make BloomBox yours.

## Nova: a new launcher style

- **An Android-inspired experience inside BloomBox.** Choose Nova as a per-profile launcher alongside the existing iOS, GameBox and hybrid options. Nova does not replace the system Home Screen or require installing Android.
- **Your own desktop.** Arrange apps, folders and pages, use a five-app dock, and customize icon shapes, labels and wallpapers.
- **Customizable app drawer.** Swipe upward to browse or search apps, adjust columns, colors and transparency, and access recent apps and the installer.
- **Personal search bar.** Change its shape, colors, width, icons and optional app shortcut.
- **Widgets.** Add minimal, flip, analog or pixel clocks, notes, and photo or GIF widgets. Adjust their size, position and background transparency; icons can overlap widgets.
- **News.** Swipe right from the first desktop page to access the existing BloomBox News, profiles, GameBox, shortcuts and installer.
- **Interaction and layout improvements.** Revised app and widget long-press handling, drag and drop, profile-scoped layout persistence, and recovery of transient touch state after returning from the background.

## Meet Bloom

The new green mascot replaces the default flower-and-box icon. The layered native iOS icon supports default, dark and tinted appearances, with generated fallback artwork for older configurations.

## Other improvements

- Updated README with the new mascot and real Nova desktop and app-drawer screenshots.
- Existing guest installation, SideStore, Husk, GameBox, RAM+, JIT and media-label features from 3.3.3 remain included.

## Validation and known limitations

The release workflow validates the Xcode build, IPA integrity, host and widget versions, branding, English localization and required SideStore/JIT components before publication. Nova is a new launcher: physical-device feedback on long-press menus, layout restoration, widget overlap, background recovery and animations is welcome. Guest compatibility still depends on the app, device, iOS version and signing configuration.

## Installation

Download **BloomBox-SideStore-unsigned.ipa** from Assets and sign/install it with SideStore or a compatible signing method. Update over your existing installation with the same signing identity and app identifier; do not uninstall first if you want to retain guest data. Back up important data before updating.

**Version:** BloomBox and widget **3.4.0 (34000)**.
