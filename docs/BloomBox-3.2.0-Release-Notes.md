# BloomBox 3.2.0 🌸 — Port Stores, RAM+ & Installer

**Release date:** 21 November 2026  
**Previous public release:** 3.1.1

This release combines everything merged into `main` after **v3.1.1**: the previously unreleased Android/iPhone port-store updates and the revamped RAM+ module with its installer integration. All previous v3.1.1 fixes remain included.

## What's new

### ApkStore — Android ports
- Added **ApkStore** to the BloomBox Home desktop and library, with its own name to distinguish it from the existing iOS **App Store**. Saved launcher identity/placement remains compatible.
- General **OpenPortsGames** Android port catalog with game artwork, search, original publisher details, and filters by source platform, available APK and verification state.
- Eligible GitHub-release APK links go through the existing ZIP validation and **user-confirmed Husk APK installer**. Unhandled downloads open the original publisher page; there is no claim that every port runs on Husk.
- Limited cover art to card bounds on narrow iPhone layouts to address the previously observed overflow.

### App Store — iPhone ports
- New **iPhone** section inside BloomBox's existing App Store, showing only OpenPortsGames records that explicitly support **iOS**.
- Search, **Solo IPA** filter, descriptions, cover images, and links to the original port/release.
- Third-party iOS port files are **not automatically installed** by this catalog. Its links open the author's publication. The regular verified BloomBox IPA installer remains separate.

### Compatibility information
- Catalog discovery and **BloomBox Remote Systems** verification records remain separate.
- Version-specific **Verificado / Con problemas / No compatible / Sin verificar** badges are reserved for actual tests. Updating a port can invalidate an earlier verification, and the general catalog is not reduced to verified games.
- **No port is asserted verified without a successful BloomBox/Husk test.** Compatibility depends on the third-party port, Husk, JIT, permissions and device.

### RAM+ — redesigned controls
- Rebuilt RAM+ page with large **green Método BloomBox** and **red Método 2**, glowing particles, and a diagnostic terminal showing genuine installed-entitlement, provisioning-profile, SideStore and installer states.
- Reused the first-run wizard's **animated shapes and the selected profile accent** behind RAM+ and the IPA/APK installer (no separate wallpaper implementation).
- The **green method** retains BloomBox's real SideStore → Apple permission request and verification flow. If RAM+ is already confirmed, **Probar RAM+** performs an authenticated **read-only Apple server recheck**, without modifying entitlements or forcing a reinstallation.
- **Método 2** downloads the official GetMoreRam guest IPA through GitHub, checks the release's SHA-256, file size and app identity, then uses BloomBox's existing guest installer to install and launch it. Fixed an earlier error where the guest IPA was incorrectly required to contain BloomBox's SideStore framework and extensions.
- Método 2 remains available even if RAM+ is already active, to allow repeat testing. **Installing or opening GetMoreRam does not itself enable the host's RAM+ permission.**
- The strict full-BloomBox IPA validation remains in place for host reinstalls. A successful Apple App ID permission check and an installed, signed process entitlement are two distinct conditions.

## Testing & scope
- GitHub Actions' full iOS build, guest IPA regression tests, localization/branding checks, and RAM+ request-planning tests passed before this release preparation.
- Android and iOS catalog records are external discoveries, **not** a list of tested game compatibility results.
- The original Method 2 failure was reported and retested on an iPhone after the validation fix. The already-active green Method 1 server recheck still requires real-device confirmation.
- Unmerged experimental branches and unrelated work in progress are **not** included.

## Known issues
- Some Husk games can still intermittently remain on a black startup screen when launched from a BloomBox icon, although they may open in Husk directly. This has **not** been confirmed fixed: [issue #8](https://github.com/AdriFOG/Bloombox-iOS/issues/8).
- Actual JIT execution depends on Husk, debugger session and device permissions; an indicator is not proof that a guest obtained working JIT.
- SideStore IPA handoff may still depend on signing configuration and has not been confirmed for every case: [issue #5](https://github.com/AdriFOG/Bloombox-iOS/issues/5).
- APK/port compatibility varies; split Android formats (`.apkm`, `.apks`, `.xapk`) are not supported by the single APK installer.
- The ApkStore cover overflow change and individual catalog games need further physical-device checks. No broad compatibility guarantee is made.
- RAM+ does not add physical RAM. It requests a signed iOS memory entitlement, which can be lost on an unsuitable re-sign/install.

## Install / Actualización
Download **`BloomBox-SideStore-unsigned.ipa`** from the assets below. It is **unsigned**: sign and install with SideStore or another compatible method. To preserve existing BloomBox guests, profiles, data, widget/extensions and RAM+ state, install **over** your current app using the same bundle ID, Apple account/team and app-group configuration. Do **not** delete BloomBox first. Back up important guest data before replacing the host.

**En español:** La 3.2.0 incluye ApkStore, ports de iPhone en App Store, la nueva pantalla RAM+ con dos métodos y consola real, el fondo animado reutilizado en el instalador y el fix de GetMoreRam. Los fallos intermitentes de Husk/JIT y ciertos casos de SideStore siguen documentados y no se declaran resueltos.

## Acknowledgements / Créditos
BloomBox incorporates and interoperates with independent projects including [LiveContainer](https://github.com/LiveContainer/LiveContainer), [SideStore](https://github.com/SideStore/SideStore), [Husk](https://github.com/Leviidev/Husk), [GetMoreRam](https://github.com/hugeBlack/GetMoreRam) and the [OpenPortsGames catalog](https://github.com/Kymie131/openportsgames). Credits and licenses belong to their original authors. See [LICENSE](https://github.com/AdriFOG/Bloombox-iOS/blob/main/LICENSE), [additional terms](https://github.com/AdriFOG/Bloombox-iOS/blob/main/LICENSE-ADDITIONAL-TERMS.md) and [third-party notices](https://github.com/AdriFOG/Bloombox-iOS/blob/main/THIRD_PARTY_NOTICES.md).
