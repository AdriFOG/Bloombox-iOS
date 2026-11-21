# BloomBox — Novedades pendientes de lanzamiento (21 de noviembre de 2026)

> **Cambios integrados en código. No son una release ni anuncian una versión nueva.** Se prepararon en la rama `feature/android-port-store-20261121` para su incorporación a `main`.

## Novedades / What's new

### ApkStore — catálogo de ports Android
- **ApkStore** es el nuevo nombre del acceso directo en el escritorio y biblioteca, para distinguir la tienda Android de **App Store**. Se conserva su identificador y posición guardada (`manzana:portstore`).
- Se incorporó un catálogo general de proyectos Android de **OpenPortsGames**: portadas, búsqueda, información de cada juego y filtros por plataforma de origen, APK disponible y verificados.
- Para APKs en releases oficiales de GitHub que coincidan con la fuente declarada, la descarga pasa por validación ZIP y después por el **instalador existente de Husk**, con confirmación. Los demás enlaces se abren en el sitio del autor.
- Las portadas de las tarjetas se limitaron al ancho de la columna para corregir el desbordamiento visto en iPhone; los títulos e insignias permanecen dentro de cada tarjeta.

### App Store — nuevos ports para iPhone
- Nueva sección **iPhone** dentro de la App Store ya existente.
- Solo muestra proyectos de OpenPortsGames cuya plataforma incluya `ios`; no mezcla los que son exclusivos de Android.
- Búsqueda de proyectos, opción **Solo IPA**, portadas, descripción, detalles y enlace a la publicación original.
- Las IPA del catálogo externo **no se instalan automáticamente**: se abren los enlaces oficiales del desarrollador. El instalador de IPA verificada de BloomBox conserva su comprobación de SHA-256.

### BloomBox Remote Systems — insignias
- Nuevo archivo `catalog/android-port-verifications.json` y guía editorial para las etiquetas de compatibilidad de **BloomBox + Husk**.
- **Verificado**, **Con problemas**, **No compatible** y **Sin verificar** dependen de pruebas reales y de la **versión exacta** del port. Ninguna ficha se declara verificada sin probarla.
- La falta de una verificación jamás elimina un port del catálogo general.

## Estado de pruebas y problemas conocidos
- La compilación iOS y las comprobaciones automáticas de la rama aprobaron en GitHub Actions (ejecución [44890415951](https://github.com/AdriFOG/Bloombox-iOS/actions/runs/44890415951)).
- **Pendiente:** confirmar en iPhone físico que el ajuste de portadas de ApkStore resolvió por completo el desbordamiento. Se detectó visualmente antes del cambio.
- **Pendiente:** pruebas individuales de instalación y funcionamiento de los ports en Husk/BloomBox; que exista una APK o IPA no garantiza compatibilidad.
- Se mantienen problemas previamente documentados del instalador SideStore y el inicio intermitente de algunos juegos Android desde BloomBox; estas novedades no los declaran corregidos.

## Créditos y condiciones
- Catálogo: [OpenPortsGames](https://openportsgames.com/), repositorio [Kymie131/openportsgames](https://github.com/Kymie131/openportsgames) y [licencia de datos](https://github.com/Kymie131/openportsgames/blob/main/LICENSE-DATA). Sus datos propios están bajo CC BY 4.0; ciertos registros importados tienen atribución y condiciones distintas.
- Se enlazan las descargas y repositorios de los **autores originales**; BloomBox no redistribuye juegos comerciales ni sus archivos propietarios.
- Compatibilidad Android depende del proyecto externo [Husk](https://github.com/Leviidev/Husk), de JIT y de las condiciones del dispositivo.

**No publicar release por esta integración.** Una ejecución automática de CI en `main` no equivale a lanzar una versión.

---

## English summary
- Added **ApkStore** to the launcher for general Android port discovery, with cell-bounded covers, APK search and sources, and the existing user-confirmed Husk importer.
- Added an **iPhone** category to the existing BloomBox App Store, filtering OpenPortsGames to `ios` entries with an IPA-only toggle and external publisher downloads.
- Added an empty, exact-version compatibility badge feed in Remote Systems. **No games are verified yet.**
- Automated iOS build passed; the Android cover layout fix and individual game compatibility still need real-device verification.
- **Unreleased. No versioned GitHub release has been requested.**
