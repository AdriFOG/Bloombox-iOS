# BloomBox 3.0.1 — LiveContainer compatibility updates 🌸

This maintenance release brings selected improvements from **LiveContainer 3.8.14** into BloomBox 3.0 while preserving our custom Home, GameBox, RAM+, JIT and profile experience.

## What's changed
- **Guest helper processes (experimental):** imported app extensions and helper processes gain new compatibility support. A **Helper Process Support / Permitir procesos auxiliares** toggle appears in individual guest app settings. It is **off by default**, unavailable for 32-bit guests, and may require repatching or reinstalling the guest.
- **Background task compatibility:** optional **Fix Background Processing Tasks / Corregir tareas en segundo plano** for guest apps on **iOS 26 and later**. This improves handling of task identifiers for compatible guest apps, but does not guarantee background execution.
- **Remote source performance:** app sources are loaded when their tab is opened rather than loading automatically at startup.
- **Underlying fixes:** shared preferences initialization, extension isolation, and a Music Haptics capability flag inherited from upstream.
- **BloomBox-specific stability:** adjusted upstream changes for our existing JIT and launcher code, while keeping all third-party licenses and credits.

These changes were selectively adapted from upstream LiveContainer commits [53e83476](https://github.com/LiveContainer/LiveContainer/commit/53e83476f858), [64d75c2d](https://github.com/LiveContainer/LiveContainer/commit/64d75c2d2e88), [7076b961](https://github.com/LiveContainer/LiveContainer/commit/7076b961df49) and [b7cfda60](https://github.com/LiveContainer/LiveContainer/commit/b7cfda60c39933a94d616f2a358ac2e48fd4e5cd).

## Installation
Download **`BloomBox-SideStore-unsigned.ipa`** below and sign it using SideStore or another compatible method. This IPA is **unsigned**. If you already use BloomBox 3.0.0, update over your existing installation with the same signing account, bundle identifier and app groups, and back up your data. Deleting the installed app may remove local app data.

## Compatibility and testing
The new features are optional and **disabled by default**. Testing with the maintainer confirmed that ordinary BloomBox operations worked on their device; broad device and guest-extension compatibility is **not confirmed**. A GitHub Actions build checks the native app, IPA contents, the RAM+/JIT pipeline, and the new backport contracts, but it does not substitute for real device testing of every extension.

RAM+ depends on Apple's entitlements and the final signing profile. JIT depends on the device, OS, guest app and pairing provider. No emulators, games or third-party content are bundled.

## Credits and source
BloomBox is based on [LiveContainer](https://github.com/LiveContainer/LiveContainer) and incorporates [SideStore](https://github.com/LiveContainer/SideStore). Upstream authors retain their licenses and attribution. Consult the [AGPL-3.0 license](https://github.com/AdriFOG/Bloombox-iOS/blob/main/LICENSE), [additional attribution terms](https://github.com/AdriFOG/Bloombox-iOS/blob/main/LICENSE-ADDITIONAL-TERMS.md) and [third-party notices](https://github.com/AdriFOG/Bloombox-iOS/blob/main/THIRD_PARTY_NOTICES.md).
