# BloomBox 3.0 🌸

The first official release under **AdriFOG**, with a new custom launcher and gaming experience. BloomBox is an independent project built on LiveContainer; original credits and licenses remain preserved.

## What's new

- **BloomBox Home:** a customizable iOS-style desktop with themes, a glass dock, widgets, folders and an App Library.
- **GameBox:** a dedicated game launcher with controller features, game artwork and experimental Playnite theme importing.
- **Profiles:** switch between personal workspaces, with profile selection integrated into GameBox.
- **Files & installs:** open compatible `.ipa` and `.tipa` files from iOS Files in BloomBox; a Kirby-themed installer celebrates successful installations.
- **RAM+ & JIT:** installed-entitlement checks, built-in pairing tools, JIT history and per-app controls.
- **Remote services:** App Store, Tweak Store, game profiles, theme downloads, GameBox wallpaper rules and bilingual news now use [BloomBox Remote Systems](https://github.com/AdriFOG/Bloombox-Remote-Systems).
- **Spanish & English:** expanded localization and updated BloomBox screenshots.

## Download & install

Download **`BloomBox-SideStore-unsigned.ipa`** below, then sign and install it using SideStore or a compatible method. **This IPA is unsigned.**

**Updating from an earlier BloomBox?** Install over the existing app with the same signing account, compatible bundle identifier and app groups. Back up your data first; uninstalling the app can erase its local content.

## Compatibility notes

- RAM+ means a requested memory entitlement, **not additional physical RAM**. It depends on the final signing profile and Apple approval; signing can remove the entitlement.
- JIT depends on your iOS version, pairing, provider and guest app. It is experimental, and not all games will work.
- Guest apps and emulators are **not bundled**. Download only content you are allowed to use.
- An automated GitHub Actions build and packaged-IPA checks passed for this release; a passing build is not a guarantee on every physical device.
- Screenshots show the maintainer's personal setup. Third-party characters, wallpaper and game images are not part of the download.

## Open source & credits

BloomBox uses [AGPL-3.0](https://github.com/AdriFOG/Bloombox-iOS/blob/main/LICENSE), with [additional attribution terms for marked original files](https://github.com/AdriFOG/Bloombox-iOS/blob/main/LICENSE-ADDITIONAL-TERMS.md). Upstream projects retain their respective licenses and [third-party credits](https://github.com/AdriFOG/Bloombox-iOS/blob/main/THIRD_PARTY_NOTICES.md).

**Build commit:** ${{ github.sha }}
