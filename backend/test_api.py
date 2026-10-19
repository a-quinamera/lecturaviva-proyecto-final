"""Pruebas con usuarios sintéticos, base temporal y Gemini simulado."""
import json
import pytest
from fastapi.testclient import TestClient
import main


@pytest.fixture
def cliente(tmp_path, monkeypatch):
    monkeypatch.setattr(main, 'DATOS', tmp_path / 'datos')
    monkeypatch.setattr(main, 'DB', tmp_path / 'datos' / 'pruebas.db')
    monkeypatch.delenv('SESSION_SECRET_KEY', raising=False)
    monkeypatch.delenv('GEMINI_API_KEY', raising=False)
    monkeypatch.delenv('GEMINI_MODEL', raising=False)
    with TestClient(main.app) as cliente:
        yield cliente


def cuenta(cliente, numero=1):
    respuesta = cliente.post('/api/sesion/registro', json={
        'nombre': 'Lector de prueba ' + str(numero),
        'correo': 'lector' + str(numero) + '@example.com',
        'password': 'LecturaPrueba-2026'})
    assert respuesta.status_code == 201
    sesion = respuesta.json()
    return {'Authorization': 'Bearer ' + sesion['token']}, sesion['usuario']


def libro(cliente):
    return cliente.get('/api/catalogo').json()[0]['id']


def entrada():
    return {'puntuacion': 4, 'texto': 'Una lectura muy interesante para conversar.'}


def test_catalogo_real_y_salud(cliente):
    respuesta = cliente.get('/api/catalogo')
    assert respuesta.status_code == 200
    libros = respuesta.json()
    assert len(libros) >= 20
    assert len({l['id'] for l in libros}) == len(libros)
    assert all(l['fuente'].startswith('https://openlibrary.org/works/') for l in libros)
    assert cliente.get('/health').json()['libros'] == len(libros)


def test_registro_no_expone_password_y_deriva_clave(cliente):
    cabecera, usuario = cuenta(cliente)
    assert set(usuario) == {'id', 'nombre', 'correo'}
    assert cliente.get('/api/sesion/yo', headers=cabecera).json() == usuario
    with main.conexion() as db:
        clave = db.execute('SELECT clave FROM usuarios').fetchone()[0]
    assert clave != 'LecturaPrueba-2026' and ':' in clave


def test_login_y_correo_normalizado(cliente):
    cuenta(cliente)
    respuesta = cliente.post('/api/sesion/login', json={
        'correo': ' LECTOR1@EXAMPLE.COM ', 'password': 'LecturaPrueba-2026'})
    assert respuesta.status_code == 200
    assert respuesta.json()['token']


def test_correo_repetido_es_400(cliente):
    cuenta(cliente)
    respuesta = cliente.post('/api/sesion/registro', json={
        'nombre': 'Otro lector', 'correo': 'lector1@example.com', 'password': 'OtraLectura2026'})
    assert respuesta.status_code == 400


def test_password_incorrecta_es_401(cliente):
    cuenta(cliente)
    respuesta = cliente.post('/api/sesion/login', json={
        'correo': 'lector1@example.com', 'password': 'Incorrecta2026'})
    assert respuesta.status_code == 401
    assert 'incorrectos' in respuesta.json()['detail']


@pytest.mark.parametrize('correo,password', [('invalido', 'Lectura2026'), ('a@b.com', 'corta')])
def test_datos_de_registro_invalidos_son_422(cliente, correo, password):
    respuesta = cliente.post('/api/sesion/registro', json={
        'nombre': 'Prueba', 'correo': correo, 'password': password})
    assert respuesta.status_code == 422


def test_rutas_protegidas_sin_token(cliente):
    assert cliente.get('/api/sesion/yo').status_code == 401
    assert cliente.post('/api/libros/' + libro(cliente) + '/resenas', json=entrada()).status_code == 401
    assert cliente.post('/api/asistente', json={'consulta': 'Quiero leer un clásico'}).status_code == 401


def test_token_invalido_es_401(cliente):
    respuesta = cliente.get('/api/sesion/yo', headers={'Authorization': 'Bearer valor-sintetico'})
    assert respuesta.status_code == 401


def test_resena_crud_visible_a_otro_usuario_y_autorizacion(cliente):
    autor, _ = cuenta(cliente, 1)
    otro, _ = cuenta(cliente, 2)
    ruta = '/api/libros/' + libro(cliente) + '/resenas'
    creada = cliente.post(ruta, headers=autor, json=entrada())
    assert creada.status_code == 201
    rid = creada.json()['id']
    visibles = cliente.get(ruta, headers=otro).json()
    assert visibles[0]['texto'] == entrada()['texto']
    assert 'correo' not in visibles[0]
    individual = '/api/resenas/' + str(rid)
    assert cliente.put(individual, headers=otro, json=entrada()).status_code == 403
    assert cliente.delete(individual, headers=otro).status_code == 403
    cambios = {'puntuacion': 5, 'texto': 'Actualicé mi opinión después de terminar el libro.'}
    assert cliente.put(individual, headers=autor, json=cambios).status_code == 200
    assert cliente.get(ruta, headers=otro).json()[0]['texto'] == cambios['texto']
    assert cliente.delete(individual, headers=autor).status_code == 204
    assert cliente.get(ruta).json() == []


def test_resena_duplicada_es_400(cliente):
    autor, _ = cuenta(cliente)
    ruta = '/api/libros/' + libro(cliente) + '/resenas'
    assert cliente.post(ruta, headers=autor, json=entrada()).status_code == 201
    assert cliente.post(ruta, headers=autor, json=entrada()).status_code == 400


def test_puntuacion_invalida_es_422(cliente):
    autor, _ = cuenta(cliente)
    respuesta = cliente.post('/api/libros/' + libro(cliente) + '/resenas', headers=autor,
                             json={'puntuacion': 9, 'texto': 'Opinión para comprobar la validación.'})
    assert respuesta.status_code == 422


def test_libro_ausente_es_404(cliente):
    assert cliente.get('/api/libros/NO_EXISTE/resenas').status_code == 404


def test_resena_ausente_es_404(cliente):
    autor, _ = cuenta(cliente)
    assert cliente.delete('/api/resenas/9999', headers=autor).status_code == 404


def test_ia_sin_configurar_es_503(cliente):
    autor, _ = cuenta(cliente)
    respuesta = cliente.post('/api/asistente', headers=autor, json={'consulta': 'Recomiéndame un clásico'})
    assert respuesta.status_code == 503
    assert 'configurado' in respuesta.json()['detail']


def test_gemini_solo_recibe_consulta_y_metadatos(cliente, monkeypatch):
    autor, usuario = cuenta(cliente)
    llamadas = []
    class Respuesta:
        status_code = 200
        def json(self):
            return {'candidates': [{'content': {'parts': [{'text': 'Respuesta sintética de prueba.'}]}}]}
    class ClienteSimulado:
        def __init__(self, **kwargs):
            pass
        async def __aenter__(self):
            return self
        async def __aexit__(self, *args):
            pass
        async def post(self, url, **kwargs):
            llamadas.append((url, kwargs))
            return Respuesta()
    monkeypatch.setenv('GEMINI_API_KEY', 'valor-falso-solo-para-pruebas')
    monkeypatch.setattr(main.httpx, 'AsyncClient', ClienteSimulado)
    respuesta = cliente.post('/api/asistente', headers=autor, json={
        'consulta': 'Recomiéndame un clásico', 'favoritos': [libro(cliente), 'NO_EXISTE']})
    assert respuesta.status_code == 200
    assert respuesta.json()['proveedor'] == 'Gemini'
    url, parametros = llamadas[0]
    assert url.startswith('https://generativelanguage.googleapis.com/')
    assert 'key=' not in url
    assert set(parametros['headers']) == {'x-goog-api-key'}
    cuerpo = json.dumps(parametros['json'])
    assert usuario['correo'] not in cuerpo
    assert autor['Authorization'] not in cuerpo
    contexto = json.loads(parametros['json']['contents'][0]['parts'][0]['text'])
    assert set(contexto) == {'consulta', 'catalogo', 'favoritos'}
    assert 'NO_EXISTE' not in contexto['favoritos']
