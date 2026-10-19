# Configurar Gemini localmente

1. Abrir https://aistudio.google.com/apikey en Brave e iniciar sesión personalmente.
2. Crear o elegir una clave de un proyecto propio (por ejemplo, LecturaViva).
3. En Antigravity, abrir backend/.env. Ese archivo ya está excluido de Git.
4. Pegar la clave después de GEMINI_API_KEY=, sin comillas ni espacios. Mantener GEMINI_MODEL=gemini-3.5-flash-lite salvo que la API indique otro modelo disponible.
5. Guardar, cerrar la pestaña del secreto y reiniciar el backend. Nunca enviar la clave por un chat, incluirla en Flutter ni subirla a GitHub.
6. Comprobar /health: ia_configurada debe ser true. Eso solo confirma que existe una clave; la validación real requiere una consulta autenticada a /api/asistente y una respuesta útil.

El código del servidor lee .env mediante python-dotenv; en un despliegue se debe usar la variable de entorno GEMINI_API_KEY. La app solo llama a la API propia. Gemini recibe los metadatos del catálogo, IDs de favoritos y consulta; no recibe el perfil, correo, contraseña ni token de sesión.

Si la API indica cuota agotada, revisar el nivel y los límites en AI Studio. La creación de una clave no garantiza cuota disponible. Este proyecto no activa facturación ni compras automáticamente.

Fuente: https://ai.google.dev/gemini-api/docs/api-key?hl=es-419 (consultada el 17/10/2026).


Validación del 17/10/2026: la clave fue introducida por la persona. La consulta autenticada a /api/asistente devolvió HTTP 200 y recomendaciones de Dracula y Frankenstein con Gemini 3.5 Flash-Lite. Gemini 3.8 Flash era accesible mediante models.get, pero sus solicitudes de generación agotaron el tiempo de espera; por eso se eligió Flash-Lite. No se registraron secretos en esta evidencia.
