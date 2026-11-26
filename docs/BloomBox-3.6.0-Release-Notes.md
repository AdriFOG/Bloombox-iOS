# BloomBox 3.6.0 — Apple Account Onboarding

## English

- **Apple Account in the setup wizard:** after creating a profile, open the bundled SideStore's original sign-in flow, including two-factor authentication and the existing Repair connection button. Sign-in can be deferred.
- **Reuse saved accounts:** detect local account item presence without copying credential values. The wizard skips the account page when the required local session items are present; Apple validates the session when used.
- **Resume setup:** save the profile and checkpoint before entering the signing engine, and return to BloomBox without losing profile information. Completed setup wizards are not forced to repeat.
- **Apple Account settings:** manage the bundled account from BloomBox Settings; advanced SideStore features remain available.
- **RAM+:** correct the release-discovery repository URL while retaining latest stable release selection and existing identity, digest and extension checks.
- **No-PC installer:** prominent README button, bilingual guide and video tutorials at [BloomBox Installer](https://adrifog.github.io/Bloombox-iOS-Installer/). The 3.5.0 pairing handoff, Anisette repair and prior launcher features remain included.

### Validation and limitations

The maintainer confirmed the new login works on their device. The experimental build and account-policy tests passed. The stable release is rebuilt and checked by the release workflow. A saved local account is not proof of an unexpired Apple session. Separate external SideStore accounts are not automatically imported. The original SideStore authentication interface is still used; fully inline login, background installation, real installation progress and the RAM+ automatic reinstall fix are not included. Apple approval alone is not evidence of an installed RAM+ entitlement.

Read the [installer requirements and security notes](BloomBox-3.5.0-Release-Notes.md). Back up important data before updating, preserve the signing identity, bundle identifier and extensions, and do not uninstall first.

## Español

- **Cuenta Apple en el asistente:** después de crear el perfil, abre el login original de SideStore integrado, con verificación en dos pasos y el botón Reparar conexión. Puedes configurar la cuenta más tarde.
- **Reutiliza cuentas guardadas:** detecta la presencia de datos locales de sesión sin copiar credenciales. Si existen los elementos necesarios, omite la página de cuenta; Apple valida la sesión al utilizarla.
- **Continúa la configuración:** guarda el perfil y el avance antes de entrar al motor de firma. No obliga a repetir un asistente ya completado.
- **Cuenta Apple en Ajustes:** acceso a la administración de la cuenta integrada. SideStore sigue disponible para opciones avanzadas.
- **RAM+:** corrige la dirección del repositorio para buscar la última release estable; conserva las comprobaciones de identidad, SHA-256 y extensiones.
- **Instalador sin PC:** botón destacado en el README, guía bilingüe y videotutoriales en [BloomBox Installer](https://adrifog.github.io/Bloombox-iOS-Installer/). Se conservan el pairing automático, reparación de Anisette y las funciones anteriores.

### Pruebas y limitaciones

El mantenedor confirmó que el nuevo login funciona en su dispositivo. La compilación experimental y las pruebas de política de cuenta pasaron correctamente. La release estable se recompila y valida antes de publicarse. Una cuenta guardada no garantiza una sesión vigente. No se importan automáticamente cuentas de un SideStore externo. Se utiliza la interfaz original de autenticación de SideStore; el login completamente integrado, las instalaciones en segundo plano, el porcentaje real y la corrección de reinstalación automática de RAM+ siguen pendientes. La aprobación de Apple no demuestra que RAM+ esté activo en la app instalada.

Consulta los [requisitos y notas de seguridad](BloomBox-3.5.0-Release-Notes.md). Respalda tus datos, conserva la identidad de firma, el identificador y las extensiones, y no desinstales la app antes de actualizar.

**Version / Versión:** 3.6.0 (36000), host and widget.
