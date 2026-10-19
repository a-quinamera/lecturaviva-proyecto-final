# Fuentes del catálogo

25 registros importados de Open Library mediante su API Search. Consulta: language:spa AND subject:fiction; campos key, title, author_name, first_publish_year. Obtención: 16 de octubre de 2026. Cada libro conserva la URL de su ficha original. Solo se utilizan metadatos bibliográficos; no se incluyen textos ni portadas de los libros. Las fechas corresponden al metadato recibido y pueden contener discrepancias de edición.

API y atribución: https://openlibrary.org/dev/docs/api/search

El archivo backend/catalogo.json es una instantánea de datos de entrada; se importará a la base del servidor, no a constantes dentro del código Flutter.
