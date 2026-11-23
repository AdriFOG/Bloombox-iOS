# BloomBox 3.3.2 — Media Tags & Gifts Hotfix

## What's New

- **3DS-style animated gifts:** Restores the animated gift-box reveal for newly installed iOS apps (IPA/TIPA) and Android APKs imported directly through BloomBox. Gift boxes shake periodically and reveal the app when tapped.
- **Instant Home screen updates:** Newly installed iOS apps appear without restarting BloomBox. Husk's Android app library also refreshes after direct APK imports or when returning from a guest session.
- **Shared media tags:** Mark apps as **Music**, **Video**, **Automatic**, or **Not Media**. Tags are stored in shared preferences for compatible MediaBloom installations.
- **Simultaneous audio option:** Adds an opt-in setting, **off by default**, that attempts to keep one app's audio playing while another app is running. Actual behavior depends on iOS and individual apps; simultaneous playback is not guaranteed.
- **No external volume HUD:** The experimental external volume overlay is intentionally excluded. System volume buttons and controls are unchanged.

## Scope

This hotfix combines the shared media tags/audio settings work with the Home screen and animated-gift fixes. It does **not** include the experimental second LiveContainer instance from PR #22. MediaBloom remains a separate app.

## Validation

The combined changes passed GitHub Actions checks, the Xcode archive, and packaged IPA checks for SideStore integration, JIT/LiveProcess extensions, RAM+ entitlements, and branding. Final interaction testing of gifts, labels, and audio on a physical iPhone is still recommended.

## Installation

Download **BloomBox-SideStore-unsigned.ipa** from the Assets section below and sign it with SideStore or another compatible signing method. Install it **over your existing BloomBox installation**, using the same bundle identifier, signing team, and signing configuration. **Do not uninstall BloomBox first** if you want to preserve your installed apps, data, and settings.

The IPA includes SideStore, LiveProcess, and JIT Helper components. Available RAM+ and JIT permissions may depend on your final signing configuration.

**Version:** BloomBox and widget **3.3.2 (33002)**.
