# BloomBox 3.3.2 — Media Tags & Gifts Hotfix

## Cambios / What's new

- **Regalitos 3DS / Animated gifts:** recupera la presentación de caja de regalo animada para nuevas apps IPA y APK importadas directamente en BloomBox.
- **Apps visibles al instalar / Instant Home updates:** el escritorio lee la lista activa de apps iOS, sin necesitar reiniciar BloomBox para ver la nueva instalación; las apps Android de Husk se actualizan al importar y al volver de una sesión.
- **Etiquetas compartidas / Shared media labels:** Música, Video, Automático y No es multimedia; se comparten con MediaBloom mediante preferencias del App Group compatible.
- **Audio simultáneo / Audio mixing:** añade una opción apagada por defecto para intentar que una app no interrumpa el audio de otra. El resultado depende de las apps y de iOS; no garantiza mezcla de audio en todos los casos.
- **Sin HUD de volumen externo:** el experimento de HUD externo no se incluye; iOS mantiene sus controles físicos y de volumen general.

## Alcance / Scope

Incluye el PR de etiquetas y audio y el arreglo de regalos/actualización de Home. **No** integra el segundo LiveContainer experimental del PR #22 ni convierte BloomBox en un reproductor multimedia. MediaBloom sigue separado.

## Verificación / Validation

Las pruebas de GitHub Actions y la compilación de la versión combinada deben completarse antes de publicar. La prueba final de interacción de regalos, etiquetas y audio debe realizarse en un iPhone.

## Instalación / Install

Descarga **BloomBox-SideStore-unsigned.ipa** desde los archivos de esta versión y fírmala con SideStore o un método compatible. Actualiza sobre la instalación existente utilizando el mismo identificador de app y equipo de firma. **No desinstales BloomBox**, para conservar tus apps, datos y configuraciones. Comprueba que LiveProcess, SideStore y JIT Helper siguen incluidos.

**Versión:** BloomBox y widget **3.3.2 (33002)**.
