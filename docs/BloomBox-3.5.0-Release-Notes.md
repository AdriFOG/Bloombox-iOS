# BloomBox 3.5.0 — No-PC Installer & SideStore Repair

## English

- **Install without a computer:** the [BloomBox Installer](https://adrifog.github.io/Bloombox-iOS-Installer/) provides a bilingual guide and video tutorials for Open Minis / siboot on supported devices.
- **Pairing handoff:** import the installer-provided remote pairing record into integrated SideStore and BloomBox JIT, with validation, conflict protection, one-time migration and local diagnostic export.
- **SideStore connection:** prepare remote Anisette for installer handoffs, synchronize public server metadata on eligible first sign-in, and offer **Repair connection** on the login screen. Existing customized configurations are preserved by automatic migration; explicit repair can change the selected Anisette server. The synchronization does not copy Apple credentials, certificates, device identifiers or tokens.
- **Keep the existing launcher:** Nova, Bloom icons, guest apps, Husk, GameBox, media labels and previous features remain included.

### Tested and known limitations

The maintainer verified no-PC installation, pairing/JIT, SideStore sign-in and the Preview 4 login repair flow on an iPhone. This does not guarantee compatibility on all devices. If authentication still fails, SideStore's **Reset adi.pb** with **Keep Headers** remains a manual recovery option; it signs out the account while preserving the signing certificate. Apple server outages may prevent authentication.

**RAM+:** Apple confirmed the capability request, but the automatic reinstall handoff did not complete in the latest device test. Approval is not proof of an installed entitlement. Automatic reinstall is not fixed by this release; do not uninstall BloomBox to retry. Native account onboarding and integrated installation progress are planned, not included.

**Security:** Open Minis / siboot is a separate third-party tool. Its current signing backend can store private signing keys and developer session data locally without additional encryption. Only run trusted scripts, avoid exposing pairing files or credentials, and review the installer requirements. BloomBox does not import those private signing keys. Back up important data before updating. Use the same signing identity and app identifier, and preserve extensions.

Download **BloomBox-SideStore-unsigned.ipa** from Assets, or use the installation guide above. The IPA must be signed before installation.

## Español

- **Instalación sin computadora:** [BloomBox Installer](https://adrifog.github.io/Bloombox-iOS-Installer/) incluye una guía bilingüe y videotutoriales para Open Minis / siboot en dispositivos compatibles.
- **Pairing automático:** entrega del registro remoto a SideStore integrado y a JIT de BloomBox, con validación, protección contra conflictos, migración única y exportación local de diagnóstico.
- **Conexión de SideStore:** preparación de Anisette remoto, sincronización de parámetros públicos en el primer inicio de sesión elegible y botón **Reparar conexión** en el login. La migración automática respeta configuraciones personalizadas existentes; la reparación explícita puede cambiar el servidor seleccionado. No se copian credenciales, certificados, identificadores ni tokens de Apple.
- **Se conservan las funciones anteriores:** Nova, iconos Bloom, apps invitadas, Husk, GameBox y etiquetas multimedia.

### Pruebas y limitaciones

El mantenedor comprobó la instalación sin PC, pairing/JIT, inicio de sesión y reparación del login en Preview 4 en un iPhone. No garantiza compatibilidad universal. Si falla la autenticación, **Reset adi.pb** con **Keep Headers** sigue disponible manualmente en SideStore: cierra la sesión y conserva el certificado de firma. Las caídas de Apple pueden impedir iniciar sesión.

**RAM+:** Apple confirmó el permiso, pero la reinstalación automática no terminó en la última prueba. La aprobación no demuestra que el permiso esté presente en la firma instalada. Esta versión no corrige la reinstalación automática. No desinstales BloomBox para reintentar. El login en el asistente y el progreso integrado de instalación todavía no están incluidos.

**Seguridad:** Open Minis / siboot es una herramienta externa. Su sistema de firma actual puede guardar claves privadas y datos de sesión de desarrollador localmente sin cifrado adicional. Ejecuta únicamente scripts de confianza, no compartas archivos de pairing ni credenciales y revisa los requisitos de instalación. BloomBox no importa esas claves privadas. Respalda tus datos antes de actualizar, conserva la identidad de firma, el identificador de la app y las extensiones.

Descarga **BloomBox-SideStore-unsigned.ipa** de Assets o utiliza la guía anterior. La IPA requiere firma antes de instalarse.

**Version / Versión:** 3.5.0 (35000), host and widget.
