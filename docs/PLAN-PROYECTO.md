# LecturaViva — Plan del proyecto final

Decisiones de la persona: catálogo de libros, reseñas y favoritos; Gemini con la clave introducida localmente, nunca por el chat. Desarrollo en Windows, edición de código en Antigravity, comprobación web en Brave y entrega Android instalada en emulador.

## Producto

Un catálogo de al menos 20 libros procedentes de metadatos públicos de Open Library, importados al backend. Búsqueda por título y autor; detalle del libro; favoritos locales por usuario; reseñas públicas con puntuación y autorización para editar o eliminar solo las propias; asistente que recomienda libros del catálogo según los intereses indicados. No se enviarán correos, contraseñas ni tokens a Gemini.

## Capas

Flutter (pantallas y widgets) → controladores GetX → repositorio/cliente HTTP y almacenamiento local → API propia FastAPI → SQLite y Gemini. El APK usará almacenamiento seguro para el token; Hive para favoritos y caché del catálogo. La pantalla no hará llamadas HTTP directamente.

## Matriz de evaluación

| Criterio | Peso | Evidencia prevista |
|---|---:|---|
| Persistencia remota | 20 % | Crear, consultar, editar y eliminar reseñas; segundo usuario ve el cambio y no puede modificar reseñas ajenas |
| Autenticación | 15 % | Registro, login, logout, restauración de sesión, rechazo sin token |
| Datos reales | 15 % | 20 o más registros importados al backend, procedencia y fecha documentadas |
| Persistencia local | 10 % | Favoritos sobreviven al cierre completo y quedan separados por usuario |
| GetX | 10 % | Estado de sesión, catálogo, favoritos, reseñas y asistente en controladores |
| IA sin secretos | 10 % | Respuesta real de Gemini a través del servidor, sin clave en Flutter ni Git |
| Errores | 10 % | Carga/vacío/error visibles; probar desconexión, 400, 401, 422 y 5xx |
| Arquitectura | 5 % | Separación observable de interfaz, estado, servicios y datos |
| Documentación y entrega | 5 % | README reproducible, CI verde, Release con APK probado, historial de commits por fases |

## Fases y evidencia

1. Plan, estructura y primer commit real.
2. Modelo de datos, importación del catálogo y backend con pruebas de autorización.
3. App original: catálogo, detalle, sesión, reseñas y favoritos; pruebas de estado y widgets.
4. Integración Gemini y prueba real con clave configurada por la persona.
5. Pruebas en Brave y emulador; auditoría de secretos; instrucciones de instalación limpia.
6. Publicación del repositorio, CI, Release y comprobación del APK; entrega en Moodle del enlace.

## Alcance de la entrega

El documento exige una app propia y distinta de ExploraEC. Se reutilizan los patrones del curso, no su implementación funcional. En Moodle se entrega únicamente el enlace al repositorio; el APK lo genera GitHub Actions y se adjunta al Release. El plazo indicado es el 26 de octubre a las 08:00. Los workflows podrán usar Linux en GitHub; el desarrollo local se hará en Windows.

No se afirmarán como completadas las pruebas contra Gemini, Android ni Actions hasta disponer de sus resultados reales. La clave de Gemini y los datos locales de usuarios se excluyen de Git y de cualquier paquete.
