# BloomBox 3.3.3 — IPA Installation & Instant Home Refresh Hotfix

## What's New

- **Immediate app discovery without restarting BloomBox:** The Home screen now reads the live app registry rather than relying on an old snapshot. BloomBox also checks its private and shared app folders for newly installed guest apps while the Home screen is visible, when returning to the foreground, and when a guest session exits.
- **Reliable Files → BloomBox IPA installation:** IPA/TIPA files received from Files or a cloud file provider are copied into BloomBox's private staging area while access is available. The installer uses that private copy instead of a file-provider URL that may become inaccessible when the chooser closes.
- **Safe original IPA handling:** BloomBox no longer removes the original IPA selected in Files. Temporary copies used for an in-BloomBox installation are removed after processing.
- **Immediate gift and icon updates:** Newly discovered guest apps are registered without restarting the app, then sent through the existing animated gift reveal and Home screen icon placement.
- **Existing layout preserved:** The refresh only registers missing app bundles. It does not rebuild installed app objects, overwrite app profiles or data, or reset Home layouts, dock positions, or folders.

## Included from 3.3.2

The 3DS-style animated gifts, MediaBloom shared media labels, optional simultaneous audio behavior, SideStore integration, Husk, RAM+, built-in JIT support, and existing BloomBox modules remain included.

## Validation

GitHub Actions regression checks and the Xcode/IPA packaging workflow verify the source and distribution package. Real-device testing of the installation-to-Home transition, especially when importing an IPA from Files or News, is still recommended.

## Installation

Download **BloomBox-SideStore-unsigned.ipa** from the Assets section and install it using SideStore or a compatible signing method. **Update over the existing BloomBox installation using the same app identifier and signing setup. Do not uninstall BloomBox first** if you want to keep installed apps, settings, profiles, and guest data.

**Version:** BloomBox and widget **3.3.3 (33003)**.
