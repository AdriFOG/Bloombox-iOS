# BloomBox 3.1.0 — Android APK launcher and Husk integration 🌸

This release introduces **experimental Android APK support through Husk**, integrated into BloomBox's existing iOS-style Home screen. It also improves guest JIT launch sequencing and APK management.

## What's new
- **Import APK files:** Open `.apk` files from Files or BloomBox's installer and import them into an installed copy of [Husk](https://github.com/Leviidev/Husk). Husk is a separate dependency and is **not bundled**.
- **Android games on Home:** APKs imported into Husk appear alongside iOS guest apps, with support for the Home launcher, folders and icon dragging.
- **Per-game orientation:** Choose portrait, landscape, or hybrid (ask each launch). BloomBox saves each game's choice and synchronizes its own scene orientation with Husk.
- **Safer APK uninstall:** Long-press an Android game's icon and choose **Uninstall app**. A confirmation explains that the APK, settings and local game data will be permanently deleted. Uninstallation is blocked while Husk is running or the game is launching, and folder safety checks prevent removing files outside the selected app.
- **Husk JIT startup:** An in-app startup overlay coordinates Husk's launch and game deep link while the built-in debugger attempts to attach. The launcher waits briefly before forwarding the game link, and keeps the JIT helper's actual status separate from a visual loading screen.
- **APK validation:** Imports verify ZIP structure without requiring the manifest to appear at the ZIP root, improving compatibility with APK archives that Husk accepts.

## Installation
Download **`BloomBox-SideStore-unsigned.ipa`** and sign it with SideStore or another compatible signer. It is **unsigned**.

**Update over your existing BloomBox installation** using the same bundle identifier, signing account and app groups to preserve data. Back up important apps and data first; uninstalling BloomBox itself can erase local content.

To import or run Android games, install a compatible copy of Husk separately. Installing an APK into Husk does **not** mean every Android app will run correctly on iOS.

## Important compatibility notes
- **Experimental:** Android translation and compatibility depend on Husk, the APK, iOS, the device, JIT and signing permissions. Not all games, activities or APK packages are supported. Split APK bundles (`.xapk`, `.apks`, `.apkm`) are not part of this new BloomBox `.apk` importer.
- **JIT is not guaranteed.** The startup overlay and debugger-attach markers are not proof that executable JIT memory is available. If activation fails, inspect the JIT log and the signed app's permissions. Pairing/LocalDevVPN requirements remain.
- **Uninstalling an Android app deletes its Husk-local data.** This is different from simply removing an icon from Home.
- **Tests:** GitHub Actions checks the source contracts, archives the iOS application and validates the IPA. Individual APK launch/orientation behavior still needs testing on real iPhones.

## Credits and source
BloomBox is based on [LiveContainer](https://github.com/LiveContainer/LiveContainer) and incorporates [SideStore](https://github.com/LiveContainer/SideStore). Android support is built around the separate open-source [Husk](https://github.com/Leviidev/Husk) project. Original authors retain their notices and licenses. See the [AGPL-3.0 license](https://github.com/AdriFOG/Bloombox-iOS/blob/main/LICENSE), [additional terms](https://github.com/AdriFOG/Bloombox-iOS/blob/main/LICENSE-ADDITIONAL-TERMS.md) and [third-party notices](https://github.com/AdriFOG/Bloombox-iOS/blob/main/THIRD_PARTY_NOTICES.md).
