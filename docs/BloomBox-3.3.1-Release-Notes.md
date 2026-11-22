# BloomBox 3.3.1 — App Language Selection

## Cambios / What's new

- **Idioma por app / Per-app language:** el selector permite elegir manualmente español, español de México, inglés y otros idiomas aunque la lista automática esté vacía.
- **Detección ampliada:** además de carpetas `.lproj` principales, detecta idiomas declarados en `CFBundleLocalizations` y carpetas de idioma en recursos y frameworks del IPA.
- **Preferencia individual:** el cambio se guarda por app y no modifica el idioma de BloomBox ni de otras aplicaciones.
- **Compatibilidad JIT/LiveProcess:** aplica la preferencia durante el inicio de la app con las rutas existentes de lanzamiento, incluidas las que usan JIT. Los idiomas regionales tienen opciones de respaldo (por ejemplo, `es-MX` → `es`).
- **Compatibilidad y seguridad:** evita rastrear archivos privados del juego, no sigue enlaces simbólicos durante la detección y tolera que iOS no exponga determinadas funciones internas.
- **Sin regresiones intencionales:** conserva los cambios de BloomBox 3.3.0 (SideStore, Husk/GameBox, interfaz y limpieza segura).

## Verificación / Validation

- La rama de prueba pasó la batería de comprobaciones del repositorio y la compilación completa de Xcode con integración SideStore.
- **Red Dead Redemption (RDR):** el usuario probó la selección de idioma en su iPhone y confirmó que el menú del juego cambió a español.
- El resultado final puede variar según las traducciones incluidas en cada IPA. Una app que use su propio selector de idioma puede ignorar esta preferencia.

## Instalación / Install

Descarga **BloomBox-SideStore-unsigned.ipa** y fírmala mediante SideStore u otro método compatible. Instálala **sobre la versión existente**, con el mismo identificador de app, equipo y configuración de firma. No desinstales BloomBox antes si deseas conservar datos y configuraciones. Comprueba que las extensiones LiveProcess/JIT Helper se conservan.

La firma final puede afectar permisos de RAM+ y JIT. Revisa los permisos y certificados de tu instalación.

**Versión:** BloomBox y widget **3.3.1 (33001)**.
