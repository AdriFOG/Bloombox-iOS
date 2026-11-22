# BloomBox · Android Files (Takopi reuse)

**State:** first **read-only** Android Files UI milestone implemented on a feature branch; final IPA build and iPhone verification pending. File import, Takopi's dual-pane operations and JIT Recovery remain design-only.
**Base:** `main` as of 2026-11-21. Do not merge or publish release until compiled and tested on device.

## Implementación inicial — 21 de noviembre de 2026

Se añadió en la rama `feature/takopi-husk-files-20261121`:

- Accesos **Archivos** y **Archivos Android** en Home y biblioteca, con IDs propios; sección Android también visible al abrir Archivos iOS.
- Detector del bundle `com.husk.app` y contenedor del perfil activo. Estados «no instalado», «bloqueado», «sin acceso» y «detectado».
- Enlace a la guía y releases oficiales de Husk, con botón para volver a comprobar su presencia.
- Explorador nativo **de solo lectura**, agrupado por APK de Husk en `Documents/TranslationLayer`, con título e identificador de paquete tomados de archivos reales. Incluye lectura de `Documents/Shared Storage` si existe.
- Navegación de archivos limitada a la raíz correspondiente y sin seguir enlaces simbólicos; vistas previas sin escritura.
- Regresiones en `Tests/android-files/test_android_files.py`, conectadas al workflow de build.

**No implementado todavía:** importaciones y movimiento de datos entre aplicaciones, vista del huésped QEMU, extracción, OBB inteligentes, backups, motor de Takopi completo ni **JIT Recovery**. El botón de «Comprobar» reevalúa los contenedores visibles; **no solicita permisos nuevos ni instala Husk por sí solo**.

La validación de compilación no reemplaza pruebas reales de accesibilidad y rutas del contenedor en iPhone. No fusionar ni publicar hasta entonces.

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


## JIT Recovery — recuperación de sesiones cerradas incorrectamente (21-Nov-2026)

**Petición:** al cerrar Husk o un juego JIT de manera incorrecta, la siguiente app con JIT no debe esperar innecesariamente por un estado obsoleto. Un «flush» seguro solo de recursos temporales/propios, sin borrar datos del juego. **Nunca iniciar dos sesiones JIT administradas por BloomBox al mismo tiempo.** Función en estudio, no implementada en esta rama.

### Hechos verificados del código actual de BloomBox

- \`LiveContainerSwiftUI/Models/LCAppModel.swift\`: \`runApp\` ya consulta \`LCSharedUtils.getContainerUsingLCScheme(withFolderName:)\`, espera hasta 16 × 250 ms si el JIT previo aún libera su contenedor y **rechaza** abrir otro huésped JIT si sigue en uso. \`MultitaskManager.isUsing(container:)\` refleja ventanas registradas en el proceso actual, pero no es por sí solo un indicador universal de toda sesión JIT.
- \`MultitaskSupport/AppSceneViewController.m\`: \`isAppRunning\` verifica \`getpgid(pid)\`, y \`appTerminationCleanUp\` destruye la escena, quita la entrada del mapa de invitados, emite \`BloomBoxGuestSceneDidExit\` y desregistra el contenedor. **No llamar manualmente a la limpieza de una escena cuyo proceso aún está vivo.**
- \`LiveContainerSwiftUI/Views/BloomBox/BloomBoxJITCoordinator.swift\`: el helper interno rechaza una segunda operación concurrente con \`busy\`, usa un token para los mensajes, y en \`defer\` detiene su propio helper y borra únicamente su archivo de estado. Al reabrir BloomBox marca los intentos JIT antiguos incompletos como \`interrupted\`; **esto solo arregla historial visual, no mata ni desbloquea procesos**.
- \`LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeScreen.swift\`: al reencontrar una escena activa de Husk entrega un deep link a esa escena en lugar de crear un proceso JIT adicional; de lo contrario inicia el huésped antes del enlace del juego. El indicador de depurador conectado **no demuestra** que JIT esté listo.

### Propuesta de comportamiento

**Nombre en UI:** «JIT Recovery». Descripción: «Recupera sesiones cerradas inesperadamente antes de abrir otro juego». Visible en Módulos > JIT y accesible en el error de inicio de juegos. Modo automático al solicitar otro inicio; botón manual **Revisar y recuperar JIT** para diagnosticar, sin promesa de un reset forzoso.

1. **Cola única / protección global BloomBox**: serializar **toda nueva sesión JIT administrada por BloomBox**, no solo lanzamientos de Husk, usando un coordinador en el host y una exclusión compartida verificable entre sus procesos/instancias. No suponer que un booleano Swift en un proceso cubre varios procesos LiveProcess. Cada intento posee ID, app, contenedor, PID/tipo de proceso cuando se conoce, generación y hora de inicio. Solo registrar identificadores y resultados no sensibles.
2. **Reconciliación antes del lanzamiento**: revisar escena y contenedor seleccionados, estado del LiveProcess anterior, señal explícita de salida (\`BloomBoxGuestSceneDidExit\`), bloqueo real de datos y estado del helper. Distinguir **activo**, **cerrándose**, **terminado confirmado**, **bloqueo aparentemente obsoleto pero sin confirmar**, y **desconocido**. No basarse solo en que pasaron N segundos ni solo en el estado del historial de JIT.
3. **Proceso activo o sin certeza**: NO ejecutar flush destructivo ni reutilizar/liberar bloqueo. Si Husk sigue activo, ofrecer volver al juego o cerrarlo normalmente; si está incierto, explicar «No se puede confirmar que Husk terminó» y permitir reintento / ver diagnóstico. Otros huéspedes JIT activos impiden iniciar un segundo, aunque sea otro juego.
4. **Cierre confirmado**: si se puede demostrar que el proceso anterior terminó, cancelar únicamente tareas previas **del mismo intento y cuyo estado siga bajo control del host**, retirar marcadores/overlays temporales propios con identificador coincidente, y esperar la liberación **real** del bloqueo por el dueño. Reconsultar los bloqueos antes de lanzar; si no se liberan, permanecer en espera/error seguro. Los tokens/archivos temporales nunca son el criterio exclusivo para declarar libre el contenedor.
5. **Lanzamiento nuevo**: reservar la exclusión antes de preparar el helper, comprobar nuevamente los estados, iniciar JIT, recibir evidencia real de preparación/uso del huésped, y mantener la reserva mientras el proceso JIT permanezca activo. Quitarla solo después de la salida verificada y el desbloqueo efectivo; en crash/reinicio reconciliar la reserva persistida sin borrar la marca por antigüedad.
6. **UI sencilla**: estados «Revisando sesión anterior», «Cerrando recursos pendientes», «Listo para abrir», «Husk sigue abierto», «No se pudo confirmar el cierre». Mostrar el motivo real si el bloqueo persiste, no un spinner infinito. Un botón **Ver detalles** enseña nombre del juego, estado de la escena y resultado de la comprobación.
7. **Ámbito preciso**: **una sola sesión JIT simultánea iniciada y controlada por BloomBox**. Las sesiones de SideStore, Husk instalado por separado u otras apps pueden no exponer estado/controles a BloomBox: detectar hasta donde permitan permisos y APIs, y **no prometer coordinación global con procesos ajenos ni un desbloqueo universal de iOS**.
8. **Compatibilidad:** preservar el proceso normal de JIT, sus permisos y el estado del emparejamiento, así como el acceso a datos privados. No interferir con sesiones sin JIT ni borrar los datos de la capa Android.

### Prohibiciones

- No borrar \`Documents/TranslationLayer\`, \`Shared Storage\`, \`Android/data\`, \`Android/obb\`, partidas, APK, configuración del usuario, emparejamientos ni credenciales.
- No modificar/desactivar Secure Boot, permisos de firma, entitlements ni configuración de depuración como parte del «flush».
- No falsificar éxito de JIT por una simple ventana abierta, una alerta, token viejo o debugger attachment.
- No eliminar bloqueos activos, no matar procesos arbitrarios y no intentar manipular procesos externos de iOS sin autorización real.
- No iniciar un segundo huésped JIT mientras la existencia del anterior sea desconocida; priorizar la seguridad ante un estado inconcluso.

### Matriz mínima de pruebas antes de habilitar

1. Cierre normal de Husk → juego B inicia una vez confirmada la salida; sin esperas artificiales.
2. Cierre forzado / crash de Husk → reconciliar estado, esperar cierre confirmado, y abrir B cuando sea seguro.
3. Husk activo → solicitud de B bloqueada / volver a la escena existente; **jamás** dos sesiones.
4. Dos toques rápidos o dos solicitudes simultáneas → solo una adquisición JIT.
5. Pérdida del host y reapertura → no marcar contenedor libre solo porque el historial de JIT aparece \`interrupted\`.
6. Bloqueo retenido por otro LiveContainer → no modificar ni robar; mostrar aviso y acciones seguras.
7. Fallo del helper, cancelación, ausencia de permisos, sesión externa JIT → evitar false-success y proteger el juego anterior.
8. Alternar Husk en capa nativa y emulación QEMU → verificar separación de contenedores y cierre, sin mezclar estados.
9. Tras recuperación → partidas y APK intactos, ningún marcador temporal ajeno eliminado.
10. Confirmar en iPhone real con logs y timestamps; no asumir que un test en CI representa comportamiento de cierre forzado del sistema.

**Pendientes técnicos para implementación:** determinar qué identidad de proceso se puede verificar de forma fiable en cada ruta de LiveProcess/SideStore, qué APIs de cierre seguro están realmente disponibles, qué marca de bloqueo persiste y su dueño, y si Husk ofrece una señal de salida completa. Si faltan esas garantías, presentar «Reintentar» y «Cerrar Husk manualmente» en lugar de ofrecer un «flush» falso.


## Engine-aware Husk files and unrestricted editing within the selected game (2026-11-21)

**Device findings:** user confirmed \`BloomBoxTest\` (package \`com.bloombox.testapp\`) stores its working files under \`java-data/sdcard/Android/data/<package>\`, while Minecraft Dungeons uses \`ue4-data\`. The previous importer created \`obb/\` and \`sdcard/\` directly under the game root, which were not the verified data paths for the Java test. An OBB in \`Android/data\` is app-specific; do not assume every game looks for expansions there. Husk also has a separate root-level \`obb/\` fallback beside APKs.

**Implementation on feature branch, not yet device-verified:**
- Parse each game’s \`report.json\` and discover actual existing engine folders, according to Husk \`TLApp.dataDirectory\`: \`java-data\`, \`ue4-data\`, \`unity-data\`, \`cocos-data\`, \`minecraft-data\`, \`sdl-data\`, \`gta-data\`, \`godot-data\`, \`na-data\`, \`gm-data\`, \`flutter-data\`, \`classic-data\`, and \`web\`. Selection follows Husk’s nuanced decisions such as Unity 6 → Java, Flutter → Java, and ordinary SDL/Python → Java.
- For each existing runtime, discover \`sdcard/Android/data/<package>/files\`, \`sdcard/Android/data/<package>\`, \`sdcard/Android/obb/<package>\`, private \`files\`, \`sdcard\`, engine root, any existing APK-root \`obb\` fallback, and \`Shared Storage\`. Case-insensitive lookup retains the directory’s **actual** spelling. Show all existing choices; prefer the report's runtime when present, but never invent missing directories.
- **Remove hardcoded category imports that silently wrote to the game root.** Import directly into a specific existing folder chosen in the UI; selected raw \`.obb\`/\`.dat\`, ZIP, or directory are copied there. This also handles apps that use nonstandard OBB paths.
- Turn on manual browsing and editing of game data, including hidden files: **import, create folder, rename, delete, optional replace existing on import**. A clear on-screen warning explains that users can break installations or saves, but it does not artificially prevent deliberate edits. No writes outside the authorized Husk game container or specifically discovered shared storage, and no symlink/traversal escapes.
- Do not copy, move or delete anything automatically to clean up folders created by past builds. Users can inspect and remove them manually if they choose.
- Test Java and Unreal Engine layouts with pre-existing folders; assert that a scan creates no fictitious \`sdcard\` or \`obb\` directories.

**Next QA:** verify the build compiles on Xcode; manually import the two BloomBoxTest fixtures to the user's verified existing Java folder, then launch BloomBoxTest and check both files. Repeat with an Unreal Engine game. JIT Recovery remains a separate pending feature.
