# BloomBox · Android Files (Takopi reuse)

**State:** architecture prepared on a feature branch only; no UI/runtime integration yet.
**Base:** `main` as of 2026-11-21. Do not merge or publish release until compiled and tested on device.

## Sources inspected

- Takopi Explorer / old NikaView repository: https://github.com/adri23rep-stack/NikaView
  - `SolidSecViewer/ExplorerFileEngine.swift`: file listing, safe-root checks, coordinated imports, copy/move/rename, symlink exclusion and sorting.
  - `SolidSecViewer/ExplorerPaneState.swift`: independent panel navigation, selection/search, list/grid.
  - `SolidSecViewer/ExplorerOperationQueue.swift`: queued copy/move operations, cancel and progress UI.
  - `SolidSecViewer/ExplorerFolderPicker.swift`: authorized iOS folder picker.
  - `SolidSecViewer/ExplorerArchiveManager.swift`: ZIP / RAR / 7z, but imports additional libraries and must be evaluated separately.
- BloomBox's existing lightweight manager:
  - `LiveContainerSwiftUI/Views/BloomBox/BloomBoxFileStore.swift`
  - `LiveContainerSwiftUI/Views/BloomBox/BloomBoxFilesView.swift`
- Husk (upstream): https://github.com/Leviidev/Husk
  - `src/app/Husk/TranslationLayer.swift`: `Documents/TranslationLayer` (per-app storage), `Documents/Shared Storage` (host storage for translated `/sdcard`).
  - `src/translation-layer-next/husk-tl-bionic-io.c`: `/sdcard` and `/storage/emulated/0` path translation; `Android/data` and `Android/obb` are handled specially.
  - `src/app/Husk/FilesTab.swift`: existing guest-side browser rooted at `/sdcard` in the appropriate Husk runtime.
  - `src/java-framework/src/husk/Documents.java`: file picker bridge for GET_CONTENT / OPEN_DOCUMENT / PICK; no complete directory-picker bridge for Android OPEN_DOCUMENT_TREE.
 
## Integration strategy

1. **Separate interface:** `BloomBox > Files > Android` next to the existing iOS file manager. Do not replace or restructure the existing BloomBox storage or copy Takopi's entire application into BloomBox.
2. **Reuse real Takopi components:** port its pane state, file-operation queue, selection and root-bounded file logic as a self-contained module; preserve original attribution in source comments. Remove Vault, SMB, Face ID, private backup, and app-specific preferences.
3. **Storage abstraction:** do *not* present a manufactured Android filesystem. Detect Husk guest model and permitted container(s), then map only real accessible storage. The root shown to the user is `/sdcard` where supported; expose each game's private data and expansion files only through *verified, separately bounded* mappings. Distinguish native translation storage from the separate guest-VM path, which may be an entirely different model.
4. **Safe import:** choose files and folders via iOS pickers; retain access only during copies or authorized bookmarks; copy selected data into the *correct* container without assuming that the iOS Downloads folder is Android `Download`. Do not write over saves, shared data, APKs or OBB by default. For archives, enforce decompression limits, traversal protection, and conflict resolution before extraction.
5. **Folder operations:** list/search, create/copy/move/rename/preview, multiple selection, optional two-pane navigation and history, clear progress and cancellation. First milestone read-only file exploration and mapping validation; then opt-in writes with backups and explicit confirmation.
6. **Compatibility diagnostics:** detect whether a game requests a file picker or Android directory-tree permission; fixing `ACTION_OPEN_DOCUMENT_TREE` may require a Husk upstream change rather than only a BloomBox file UI.
7. **Device testing:** test native Husk mode and any VM guest mode separately; paths, installs and permissions differ. Confirm UI and mapping on iPhone before any merge.

## Non-goals / safety

- No access to the real iOS or Android root beyond granted containers.
- No synthetic folders presented as existing filesystem paths.
- No automatic `Android/data` or `Android/obb` mass copying.
- No changes to Takopi's own repository, users' existing data, or BloomBox `main`.
- No release, IPA build or claim of a working Android explorer at this preparation stage.

## Visibilidad y orientación — decisión de UX (21 de noviembre de 2026)

El usuario debe descubrir **Archivos Android** inmediatamente, incluso si aún no tiene instalado Husk. Nunca ocultarlo tras ajustes avanzados.

### Entradas visuales

1. **Archivos de BloomBox, primera pantalla:** dos destinos prominentes en el encabezado — **Archivos iOS** y **Archivos Android** — como tarjetas accesibles o control segmentado; no dependen del contenido de la lista. La tarjeta Android lleva el icono de Android/Husk, el texto fijo «Archivos de juegos Android» y una frase de ayuda («Gestiona datos, OBB, descargas y carpetas de juegos usados por Husk»). No se confunden con la App Store o ApkStore.
2. **Escritorio de BloomBox:** ofrecer un acceso directo **Archivos Android** junto a **Archivos**, identificable con icono de carpeta + Android. Si el diseño crea un icono predeterminado, preservar los diseños existentes, migrar sin duplicar ni mover iconos ya colocados y permitir quitarlo/moverlo como los demás. Alternativa si el escritorio necesita reducir ruido: ficha fija «Archivos Android» en la sección Archivos del launcher, visible sin entrar en ajustes.
3. **ApkStore / app Android:** acceso contextual «Administrar datos de este juego» (solo cuando se pueda mapear a una carpeta real); si aún no está disponible, mostrar una explicación clara, nunca crear una carpeta falsa o simular el acceso.

### Estado observable (no suposiciones)

- **Husk no instalado:** tarjeta Android visible, sin carpetas falsas. Indicar «Necesitas Husk para explorar los archivos Android» + qué es Husk + enlace **Ver Husk / Cómo instalarlo** a su repositorio oficial. El usuario aún puede entrar y leer la explicación.
- **Husk instalado y contenedor accesible:** indicar «Husk detectado», nombre del contenedor seleccionado, y botón **Explorar archivos Android**. Solo listar rutas probadas y accesibles; no afirmar que «Conectado» si el contenedor no abre.
- **Husk instalado pero bloqueado / oculto / sin acceso:** indicar «Husk está instalado, pero BloomBox no puede abrir sus archivos todavía», ofrecer **Revisar acceso**, no redirigirlo engañosamente a «instalar».
- **Husk detectado, sin datos importados:** mensaje «Todavía no hay archivos Android. Importa datos de un juego o abre Husk» y guía contextual; no mostrar un listado vacío como si hubiera fallado.
- **Problema de lectura:** explicación concreta (permiso, directorio no disponible, juego en uso), botón **Reintentar**; no alterar datos sin consentimiento.

### Guía de instalación cuando falta Husk (copy definitivo)

La sección **Archivos Android** debe seguir visible y abrir una pantalla breve, no un error ni una página vacía. El usuario pidió palabras cortas, sin tecnicismos y sin explicaciones interminables.

**Texto visible (español):**
- **Husk**
- **Emulador Android** · **Instalador de APK**
- «Abre juegos y apps Android en tu iPhone.»
- «Necesitas instalar Husk para explorar sus archivos.»
- Botón principal: **Instalar Husk** → guía oficial: https://itslevii.dev/docs/install
- Enlace secundario: **Descargar IPA oficial** → https://github.com/Leviidev/Husk/releases
- Acción de comprobación: **Ya instalé Husk · Comprobar** → volver a detectar sin reiniciar BloomBox.
- Texto después de comprobar sin detectar: «Aún no encontramos Husk en BloomBox. Revisa que esté instalado como app compatible y vuelve a comprobar.»
- Texto cuando detecta Husk sin permiso de lectura: «Husk está instalado, pero no podemos abrir sus archivos.» → **Revisar acceso** (nunca ofrecer reinstalar en vez de diagnosticar).

**Texto visible (English):**
- **Husk**
- **Android emulator** · **APK installer**
- "Run Android apps and games on your iPhone."
- "Install Husk to browse Android game files."
- Primary: **Install Husk** → official installation instructions.
- Secondary: **Official IPA download** → official GitHub releases.
- Recheck: **I installed Husk · Check again**.
- Separate state when installed but inaccessible: "Husk is installed, but BloomBox can't access its files." → **Check access**.

**Mini-guía en pantalla (solo si el usuario toca «Instalar Husk»):**
1. «Abre la guía oficial.»
2. «Instala Husk con SideStore, AltStore o TrollStore.»
3. «Vuelve a BloomBox y toca “Comprobar”.»

**Comportamiento obligatorio:** ninguna etiqueta «Instalado» sin detección real del bundle id `com.husk.app`. El botón de instalación abre la **guía oficial** y no debe fingir que BloomBox instaló una IPA; no se promete instalación automática. La vista permanece totalmente navegable sin Husk. No escoger un instalador por el usuario ni pedir que descargue un archivo desde una página desconocida. En caso de tener Husk instalado y detectable, se omite la guía y se muestra la entrada al explorador. Si falta acceso al contenedor, mostrar el estado de acceso en lugar de fingir ausencia de Husk.

Nota técnica: Husk tiene **dos modos**: traducción nativa de código Android y emulación QEMU; el texto «Emulador Android» es una simplificación de producto, no una afirmación de que todo APK se ejecuta en un emulador completo. Los juegos no tienen compatibilidad garantizada, y algunos necesitan JIT.

**Fuente oficial verificada:** README de https://github.com/Leviidev/Husk enlaza `https://itslevii.dev/docs/install`, los firmadores SideStore/AltStore/TrollStore y las releases públicas. No fijar en UI una versión de Husk que se pueda quedar vieja.

### Detección y refresco

- Reutilizar el reconocimiento actual en `BloomBoxHomeScreen.swift`: `sharedModel.apps` y `bundleIdentifier == "com.husk.app"`; la lectura de juegos usa el contenedor seleccionado y `Documents/TranslationLayer`. No usar la presencia de un icono de juego como único indicador de que Husk existe.
- Distinguir «instalado en la lista de apps» de «contenedor disponible»; verificar acceso real antes de activar acciones de escritura. Respetar apps ocultas/bloqueadas.
- Actualizar estado al abrir Archivos, al regresar a primer plano, después de instalar/desinstalar Husk y cuando cambie el contenedor. No dejar el estado «no instalado» cacheado.
- Conservar el estado sin parpadeos mientras se actualiza; accesibilidad VoiceOver, contraste, iPhone vertical, inglés/español.

### Flujo previsto

```text
BloomBox > Archivos
   ├─ Archivos iOS     → gestor actual sin cambios
   └─ Archivos Android → ¿Husk detectado?
                          ├─ No → explicación + enlace oficial de Husk
                          ├─ Sí, inaccesible → estado preciso + revisar/reintentar
                          └─ Sí, accesible → carpetas reales + gestor adaptado de Takopi
```

**Criterios de aceptación:** una persona nueva debe encontrar Archivos Android en un toque desde Archivos o su acceso del escritorio, comprender para qué sirve sin saber qué es OBB, y recibir una acción útil tanto si Husk está instalado como si no. El explorador iOS permanece idéntico y nunca se expone un directorio ficticio como real. El diseño debe validarse con capturas de pantalla en un iPhone antes de integrarlo a main.

## Next implementation milestone

Build a mount/provider protocol for (a) native Husk Shared Storage, (b) per-app scoped directories, and (c) any supported guest file bridge, then integrate Takopi's isolated navigation components. Require a failing/passing test for traversal and symlink protection before enabling writes.

## Exploración por juego versus almacenamiento compartido

La interfaz principal tendrá dos vistas visibles:
- **Por juego** (predeterminada): tarjeta por APK instalada con icono, título real, nombre de paquete, ruta del contenedor y acciones «Ver datos», «Ver OBB» y «Importar archivos» cuando la ruta exista y sea accesible.
- **Almacenamiento**: explorar únicamente el almacenamiento Android compartido comprobado (`/sdcard`, `/storage/emulated/0`) y sus carpetas reales (Download, DCIM, Documents, Games, etc. solo si existen).

### Lo que confirma la implementación actual de Husk
- **Capa nativa / translation layer**: `Documents/TranslationLayer/<app-uuid>` contiene un directorio por app. `label.txt`, `package.txt`, `icon.png`, `report.json` y los APK ayudan a identificarla. `Documents/Shared Storage` funciona como `/sdcard` compartido.
- **Rutas privadas**: `/data/data/<package>`, `/data/user/0/<package>`, `/sdcard/Android/data/<package>` y `/sdcard/Android/obb/<package>` pueden redirigirse al directorio privado de ejecución de esa app. Los OBB importados pueden permanecer junto al APK en `obb/` y la traducción redirige lecturas cuando corresponda.
- **Emulador / guest**: Husk tiene también una vista de archivos del huésped desde `/sdcard` (`FilesTab.swift`). No asumir que esa vista comparte ubicación física o reglas de permisos con la capa nativa.
- BloomBox ya detecta `com.husk.app` y utiliza el contenedor seleccionado de Husk bajo `Documents/TranslationLayer`, de modo que se puede reutilizar la identificación existente. Debe validarse si existe permiso real para leer/editar cada contenedor antes de listar.

### Atribución exacta, sin confundir al usuario
1. Vincular un directorio a una app **solo con una referencia inequívoca** a su directorio de Husk y/o su `package.txt`. Mostrar el título de `label.txt`, el icono real si existe y el paquete completo.
2. Si hay dos juegos con el mismo paquete o diferentes contenedores/perfiles, **no mezclar sus datos**: la identidad incluye contenedor y directorio interno.
3. Los archivos de `Shared Storage` pueden pertenecer a varios juegos o haber sido importados manualmente. **No adjudicarlos automáticamente por cercanía o nombre**. Si una ruta coincide con un paquete identificado, mostrar «Posible carpeta de este juego» hasta confirmación; si no, dejarla en «Compartidos / Sin identificar».
4. Mostrar secciones **Datos privados**, **Archivos del juego**, **OBB** y **Almacenamiento compartido** solamente cuando la ruta real correspondiente esté disponible. No crear `Android/data`, `Android/obb` o `DCIM` ficticios para llenar la lista.
5. Para importar, ofrecer destino recomendado **con vista previa de ruta real**, espacio libre, posibles duplicados y confirmación. Nunca sobrescribir guardados automáticamente.
6. El modo navegador de APKs y carpetas de usuario debe mantenerse funcional aunque el acceso a datos privados esté restringido. Explicar «Esta carpeta no se puede abrir desde BloomBox» en lugar de «vacío».
7. No enumerar o exponer datos de otras apps de iOS; limitar todo al contenedor autorizado de Husk.

**Criterio de prueba:** instalar al menos dos apps en Husk con diferente package ID; comprobar que sus archivos privados y sus OBB no se intercambian, que los compartidos quedan en el explorador general y que la vista sigue siendo útil sin tener un juego instalado.

**Archivos de referencia:** `Leviidev/Husk/src/app/Husk/TranslationLayer.swift`, `Leviidev/Husk/src/translation-layer-next/husk-tl-bionic-io.c`, `Leviidev/Husk/src/app/Husk/FilesTab.swift`, `AdriFOG/Bloombox-iOS/LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeScreen.swift`.
