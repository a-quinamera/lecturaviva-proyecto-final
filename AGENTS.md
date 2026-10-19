# Guía de trabajo

Proyecto Flutter original LecturaViva con backend FastAPI propio. Respetar las instrucciones directas de la persona. Mantener las capas UI → GetX → repositorio → datos. No leer ni imprimir .env o claves. No incluir bases de datos, sesiones, APK ni cachés en Git. Los tests usan usuarios sintéticos y un doble de Gemini.

Validación desde lecturaviva: flutter analyze, flutter test, flutter build web --release. Desde backend: python -m pytest test_api.py -q. La CI compila el APK y publica Release solo en tags v* con pruebas aprobadas. Registrar únicamente comprobaciones realizadas; no presentar CI o instalación como exitosas sin evidencia.
