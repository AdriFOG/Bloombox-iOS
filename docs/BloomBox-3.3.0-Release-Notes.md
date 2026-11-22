# BloomBox 3.3.0 — Stability & Polish

## Novedades / What's new

- **GameBox + Husk:** detecta automáticamente las APK ya instaladas en el perfil activo de Husk, muestra sus iconos y nombres, y las abre con el flujo existente de orientación y JIT de BloomBox. No reinstala los APK.
- **Organización de GameBox:** permite ocultar juegos de la lista y restaurarlos desde **Mostrar apps ocultas**. Ocultar no desinstala juegos ni cambia su visibilidad en iOS.
- **Instalación desde el inicio:** acceso al instalador combinado IPA, TIPA y APK al lado del botón de personalización.
- **Instalar con SideStore:** el botón entrega el archivo IPA local preparado al **SideStore integrado** mediante el enlace de instalación, sin mostrar la hoja de Compartir de iOS. No se borra el archivo mientras SideStore lo necesita.
- **Dock:** Liquid Glass más claro y transparente, con un comportamiento alternativo para dispositivos y ajustes de accesibilidad sin el mismo efecto.
- **Archivos:** estilo coherente con los símbolos del asistente inicial y el fondo del perfil; ajustes de compatibilidad con iOS 15.
- **Carpetas:** fondo difuminado del wallpaper tanto en carpetas del escritorio como en categorías de la Biblioteca de apps (incluida «Añadidas recientemente»), en lugar de paneles grises opacos.
- **Limpieza segura:** al superar **1 GB** de temporales elegibles, retira archivos antiguos y no utilizados que pertenecen a BloomBox. Protege las instalaciones, documentos, datos de usuario, partidas, OBB y archivos ajenos; excluye archivos recientes y enlaces simbólicos.
- **Compatibilidad:** conserva las correcciones anteriores de Husk/JIT de BloomBox 3.2.4.

## Verificación / Validation

- Las pruebas automáticas de la rama 3.3 y la compilación completa con las extensiones de SideStore pasaron antes de la fusión.
- El flujo directo de instalación con SideStore y los cambios de estabilidad fueron probados en un iPhone por el usuario.
- Esta release valida la estructura IPA, las versiones de BloomBox y del widget (3.3.0 / 33000), las extensiones LiveProcess/JIT Helper y la integración SideStore.

## Instalación / Install

Descarga **BloomBox-SideStore-unsigned.ipa** de esta release. Es un archivo **sin firmar**: deberás firmarlo con SideStore u otro método compatible e instalarlo **encima de tu BloomBox actual**, con el mismo identificador y configuración de firma. **No desinstales primero** si quieres conservar tus perfiles, datos y configuraciones.

La disponibilidad de RAM+ y de JIT depende de las autorizaciones, permisos, firma, dispositivo y versión de iOS.
