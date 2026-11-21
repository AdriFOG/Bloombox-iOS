# BloomBox 3.1.1 🌸

**A maintenance update for the experimental Android APK + Husk integration.** This release retains the iOS guest launcher and all BloomBox 3.1.0 features.

## Changes
- **One-tap APK import from Files:** Adjusted the `.apk` document association so an APK can open the BloomBox installer without repeatedly using **Open With**. Confirmed to work in on-device testing, although the user's iOS default-app choice may still take precedence.
- **More compatible APK checks:** Additional bounded ZIP verification for nonempty APKs when the first ZIP reader cannot enumerate their contents. Husk continues to validate and run the imported package. APK support remains experimental; invalid or unsupported games may still fail.
- **JIT session handoff:** After closing a JIT guest, BloomBox briefly waits for the previous session's container lock to clear before launching another. It **does not bypass live locks** or start two guests against the same data.
- **SideStore IPA sharing:** The installer now prepares and shares an actual IPA file with its appropriate file type, rather than just sharing a file URL. This improves the handoff path but **SideStore installation is not yet confirmed on-device for every signing configuration**. Choose SideStore from the share sheet.

## Known issues
- **Some Husk games may remain on a black `starting` screen** when launched from a BloomBox Home icon, even though the same game can start from Husk directly. This behavior was observed intermittently with Geometry Dash and was not reliably reproducible. It **is not fixed or confirmed to be caused by JIT**. Report: [Issue #8](https://github.com/AdriFOG/Bloombox-iOS/issues/8). If it happens, capture `husk.log` and `husk-native.log` from **Husk > Settings > About > Open Console > Share** without relaunching Husk first.
- **JIT readiness is not guaranteed by a loading indicator or debugger-attachment message.** Actual executable JIT memory depends on Husk, the signing permissions and the debugger sequence. Review **BloomBox > Modules > JIT** and Husk logs for failures.
- **SideStore integration remains under validation**; please report cases where the Share-sheet handoff does not import the IPA. See [Issue #5](https://github.com/AdriFOG/Bloombox-iOS/issues/5).
- APK packages and runtime compatibility depend on the separate Husk installation. Split bundles like `.apkm`, `.apks`, and `.xapk` are not handled by this single-APK installer.

## Installing / Actualización
Download **`BloomBox-SideStore-unsigned.ipa`** and sign with SideStore or a compatible signer. This IPA is **unsigned**, not a direct installation package. To preserve installed apps and data, update over the existing BloomBox installation using the same bundle ID, signing account and app-group entitlements. Back up anything important before replacing or uninstalling the host.

**En español:** Esta versión mejora la apertura de APK desde Archivos, acepta más APK compatibles, reintenta brevemente los cierres de JIT y cambia cómo se entrega una IPA a SideStore. **La pantalla negra ocasional en juegos de Husk sigue siendo un problema conocido.** No se garantiza que todos los juegos Android funcionen.

## Credits
BloomBox builds on [LiveContainer](https://github.com/LiveContainer/LiveContainer) and [SideStore](https://github.com/SideStore/SideStore), and integrates with the separate [Husk](https://github.com/Leviidev/Husk) project. Original projects retain their licenses and notices. See [LICENSE](https://github.com/AdriFOG/Bloombox-iOS/blob/main/LICENSE), [additional terms](https://github.com/AdriFOG/Bloombox-iOS/blob/main/LICENSE-ADDITIONAL-TERMS.md) and [third-party notices](https://github.com/AdriFOG/Bloombox-iOS/blob/main/THIRD_PARTY_NOTICES.md).
