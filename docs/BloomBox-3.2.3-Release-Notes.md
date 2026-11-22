# BloomBox v3.2.3 — Unified Files, iOS App Icons, Transparent Profiles

## Cambios / What's new
- **Archivos / Files:** el acceso verde ahora permite elegir entre **Archivos iOS** y **Archivos Android**. The Home / News shortcut leads to the same two-choice hub.
- **Archivos iOS:** view installed BloomBox guests, browse the *existing* active-profile data container, and manage files with import, export/share, preview, folder creation, rename, and delete. Security-scoped importing uses the existing bounded file editor. Containers outside BloomBox, other apps and uninitialized profiles are not accessed.
- **Íconos arreglados:** the iOS app list uses the same real icon renderer as BloomBox's Home screen, including customized icons and light/dark variants rather than generic blue squares.
- **Perfiles:** translucent Profiles widget matches the rest of the News glass surfaces; user wallpaper remains visible.
- **Husk:** retains the current scoped APK game container and detected `-data` folder access. There is no made-up OBB storage path.
- **Version / versión:** host and widget 3.2.3 (32003). Full unsigned SideStore bundle with JIT helper and extensions.

## Notas / Notes
- iOS sandbox still prevents access to other iPhone apps not installed inside BloomBox. Close running guests before modifying saves or app databases, and keep backups.
- The Files manager is part of the 3.2.3 build but runtime compatibility depends on how a guest stores its data. Some games can lock files while running.
- Previous known issues in SideStore/JIT and individual guests are not claimed fixed by this update.

## Install
Get **`BloomBox-SideStore-unsigned.ipa`**, sign with your usual SideStore-compatible method, and install over the existing BloomBox using the **same bundle ID, signing team and App Groups** to preserve profiles and files. Do not uninstall the prior copy.
