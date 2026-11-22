# BloomBox 3.2.2 — Android Files & Home Cleanup

**Release date:** 21 November 2026  
**Previous public release:** 3.2.1

## What's new
- **Android Files for Husk:** opens the actual APK container or the detected engine-specific `-data` folder. If the folder is missing or ambiguous, no path is invented.
- **Game file management:** create folders, import, rename and delete inside the chosen real directory. Symlink/traversal checks guard against crossing the container boundary; overwriting requires explicit choice.
- **One green shortcut:** removes the duplicate orange Files app from Home and app library, preserves the internal iOS Files utility elsewhere, and adds a minimal Android robot + folder icon.
- **Compatibility:** based on the newest merged 3.2.1 Home, Port Store, RAM+ and SideStore code, with dedicated Python and Swift regression tests.

## Testing and limitations
- CI checks the Swift path logic and complete iOS build. Successful compilation does not guarantee every Husk title exposes a usable data folder.
- Back up game saves before deleting or overwriting; close the guest before sensitive edits.
- Separately developed News installer/removable built-ins work remains pending until independently merged. Known SideStore, JIT and guest-startup issues may still happen.

## Install / Instalación
Download **`BloomBox-SideStore-unsigned.ipa`** and sign with SideStore or a compatible method. Install **over the existing BloomBox** with the same signing identity, bundle ID and App Groups to keep your data. Do not uninstall first.

**En español:** se elimina el ícono naranja duplicado y se conserva **Archivos Android** en verde, con un robot Android y carpeta minimalistas. El navegador permite abrir el contenedor del APK y la carpeta real `-data`, sin inventar directorios. Conserva las mejoras de 3.2.1.
