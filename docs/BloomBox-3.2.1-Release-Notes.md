# BloomBox 3.2.1 🌸 — Compact Home & Store Icons

**Release date:** 21 November 2026  
**Previous public release:** 3.2.0

This update includes the approved **Novedades y escritorio** redesign and fixes blank Store icons seen on iPhone. All 3.2.0 improvements remain included.

## What's new
- **Two-row quick-access panel:** APK Store, App Store, Temas, Módulos, SideStore, Archivos, RAM+ and Ajustes. Buttons use the already existing real destinations.
- **Personalizar:** Reorder, hide and restore quick-access icons independently of the main iOS-style desktop.
- **Compact profiles:** Matte dark card with smaller avatars and less empty space, without Liquid Glass or excessive reflections.
- **Recognizable store icons:** The multicolor Google Play logo for APK Store, Apple's App Store icon for App Store and the actual icon from the embedded SideStore framework. Other icons keep simple colors and soft shadows.
- **Blank-icon fix:** PNGs previously stored as loose resources were referenced as asset-catalog names, leaving empty tiles. The logos are now bundled directly as offline PNG data, decoded once and checked by an automated regression test, with graceful fallback visuals.
- **Less wasted space:** Smaller GameBox and news sections; navigate between news posts and open each full article.

## Testing and scope
- The iOS PR build and the logo decode regression test passed before version preparation.
- No changes to the Husk, JIT, signing, APK installer or RAM+ entitlement engines.
- Real-device testing of the final 3.2.1 package is still recommended; compilation alone does not establish every UI interaction.
- Known issues from 3.2.0 remain open, including intermittent Husk launching and SideStore signing/handoff cases. This release does not claim to resolve those issues.

## Install / Actualización
Download **`BloomBox-SideStore-unsigned.ipa`** from the assets below. It is **unsigned** and requires signing with SideStore or a compatible method. Install **over your existing BloomBox** using the same bundle ID, Apple team and App Groups to preserve guests, profiles and data. Back up important data and don't uninstall first. Re-signing may alter RAM+ entitlements.

**En español:** BloomBox **3.2.1** trae accesos rápidos en dos filas, perfiles compactos sin Liquid Glass, noticias y GameBox más pequeños, y corrige los iconos vacíos de APK Store y App Store con logos reconocibles y sin efectos exagerados. Conserva todo lo de la versión 3.2.0; Husk y JIT no se modificaron. Instala encima de tu BloomBox actual.

## Acknowledgements
Google Play and App Store marks identify their respective shortcuts; no affiliation or endorsement is implied. SideStore's icon comes from the embedded framework. See the [third-party notices](https://github.com/AdriFOG/Bloombox-iOS/blob/main/THIRD_PARTY_NOTICES.md).
