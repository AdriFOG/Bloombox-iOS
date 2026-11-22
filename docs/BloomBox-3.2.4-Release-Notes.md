# BloomBox v3.2.4 — Husk JIT Ready Hotfix

## Cambios / What's new
- **JIT de Husk / Husk JIT:** la pantalla de inicio permanece hasta recibir la confirmación real de memoria JIT preparada y reconocida por el depurador del invitado. El contador de inicio ya no se usa como señal de éxito.
- **Nuevo estado de verificación:** el JIT integrado recibe una confirmación separada del final de la sesión del depurador; se evita confundir una desconexión posterior con la ausencia de preparación de memoria.
- **Arranque sin bloqueo:** BloomBox envía el juego a Husk para que pueda generar las señales requeridas, manteniendo visible la pantalla de carga hasta recibir la confirmación JIT.
- **Errores reales:** si el JIT no se confirma, se conserva el error y el registro para reintentar; no se muestra una confirmación falsa.
- **Sin pérdida de cambios:** conserva todas las mejoras de v3.2.3 (Archivos iOS/Android, iconos y Perfiles).
- **Version / Versión:** aplicación y widget 3.2.4 (32004), IPA SideStore sin firmar y con las extensiones completas.

## Verificación / Validation
La compilación Xcode y las pruebas automáticas de integración JIT de la rama del fix pasaron. El funcionamiento del JIT también depende de los permisos de la instalación firmada, la versión de iOS y el proveedor.

## Instalación / Install
Descarga **BloomBox-SideStore-unsigned.ipa**, fírmala con SideStore o un método compatible e instálala **sobre tu BloomBox existente**, usando el mismo identificador, equipo de firma y App Groups. No desinstales la versión anterior: respalda tus datos y conserva las extensiones, incluidos LiveProcess y JIT Helper.
