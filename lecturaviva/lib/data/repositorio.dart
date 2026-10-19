import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

class Fallo implements Exception {
  final String mensaje;
  final int? estado;
  const Fallo(this.mensaje, [this.estado]);
  @override
  String toString() => mensaje;
}

class Libro {
  final String id, titulo, autor, fuente;
  final int? anio;
  final int resenas;
  final double promedio;
  const Libro({
    required this.id,
    required this.titulo,
    required this.autor,
    required this.fuente,
    this.anio,
    this.resenas = 0,
    this.promedio = 0,
  });
  factory Libro.deJson(Map<String, dynamic> j) => Libro(
    id: j['id'] as String,
    titulo: j['titulo'] as String,
    autor: j['autor'] as String,
    fuente: j['fuente'] as String,
    anio: j['anio'] as int?,
    resenas: (j['resenas'] as num?)?.toInt() ?? 0,
    promedio: (j['promedio'] as num?)?.toDouble() ?? 0,
  );
  Map<String, dynamic> aJson() => {
    'id': id,
    'titulo': titulo,
    'autor': autor,
    'fuente': fuente,
    'anio': anio,
    'resenas': resenas,
    'promedio': promedio,
  };
}

class Repositorio {
  static const base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb ? 'http://localhost:8001' : 'http://10.0.2.2:8001',
  );
  final http.Client cliente;
  final Box caja;
  final FlutterSecureStorage seguro;
  final Duration espera;
  bool sesionSinConexion = false;
  String? token;
  Repositorio(
    this.caja, {
    http.Client? cliente,
    this.seguro = const FlutterSecureStorage(),
    this.espera = const Duration(seconds: 40),
  }) : cliente = cliente ?? http.Client();

  Future<dynamic> pedir(
    String metodo,
    String ruta, [
    Map<String, dynamic>? datos,
  ]) async {
    final uri = Uri.parse('$base$ruta');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    try {
      final solicitud = http.Request(metodo, uri)..headers.addAll(headers);
      if (datos != null) solicitud.body = jsonEncode(datos);
      final respuesta = await http.Response.fromStream(
        await cliente.send(solicitud).timeout(espera),
      ).timeout(espera);
      dynamic cuerpo;
      try {
        cuerpo = jsonDecode(respuesta.body);
      } on FormatException {
        cuerpo = null;
      }
      if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
        return cuerpo;
      }
      final detalle = cuerpo is Map && cuerpo['detail'] is String
          ? cuerpo['detail'] as String
          : null;
      switch (respuesta.statusCode) {
        case 401:
          throw const Fallo(
            'Tu sesión no es válida. Inicia sesión de nuevo.',
            401,
          );
        case 400:
          throw Fallo(detalle ?? 'Revisa los datos enviados.', 400);
        case 422:
          throw const Fallo(
            'Revisa los campos: alguno no cumple el formato requerido.',
            422,
          );
        case 403:
          throw const Fallo('Solo puedes modificar tus propias reseñas.', 403);
        case 404:
          throw const Fallo('El elemento ya no está disponible.', 404);
        default:
          throw Fallo(
            respuesta.statusCode >= 500
                ? (detalle ??
                      'El servidor no está disponible. Inténtalo después.')
                : 'No se pudo completar la solicitud.',
            respuesta.statusCode,
          );
      }
    } on Fallo {
      rethrow;
    } on TimeoutException {
      throw const Fallo('La conexión tardó demasiado. Vuelve a intentar.');
    } on http.ClientException {
      throw const Fallo(
        'Sin conexión con el servidor. Comprueba la red y la dirección de la API.',
      );
    }
  }

  Future<List<Libro>> catalogo() async {
    final datos = await pedir('GET', '/api/catalogo') as List;
    final libros = datos
        .map((j) => Libro.deJson(Map<String, dynamic>.from(j)))
        .toList();
    await caja.put('catalogo', libros.map((l) => l.aJson()).toList());
    return libros;
  }

  List<Libro> catalogoGuardado() {
    try {
      return (caja.get('catalogo', defaultValue: []) as List)
          .map((j) => Libro.deJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> restaurar() async {
    sesionSinConexion = false;
    Map<String, dynamic>? guardado;
    final texto = await seguro.read(key: 'lecturaviva_sesion');
    if (texto != null) {
      try {
        final sesion = jsonDecode(texto) as Map<String, dynamic>;
        token = sesion['token'] as String;
        guardado = Map<String, dynamic>.from(sesion['usuario']);
        if (token!.isEmpty || guardado['id'] is! int) {
          throw const FormatException();
        }
      } catch (_) {
        throw const Fallo(
          'La sesión guardada no es válida. Inicia sesión de nuevo.',
          401,
        );
      }
    } else {
      token = await seguro.read(key: 'lecturaviva_token');
    }
    if (token == null) return null;
    try {
      final perfil = Map<String, dynamic>.from(
        await pedir('GET', '/api/sesion/yo'),
      );
      await seguro.write(
        key: 'lecturaviva_sesion',
        value: jsonEncode({'token': token, 'usuario': perfil}),
      );
      return perfil;
    } on Fallo catch (e) {
      if (guardado != null && (e.estado == null || e.estado! >= 500)) {
        sesionSinConexion = true;
        return guardado;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> entrar(
    String correo,
    String clave, {
    String? nombre,
  }) async {
    final respuesta = await pedir(
      'POST',
      nombre == null ? '/api/sesion/login' : '/api/sesion/registro',
      {
        'correo': correo.trim(),
        'password': clave,
        if (nombre != null) 'nombre': nombre.trim(),
      },
    );
    final nuevoToken = respuesta['token'] as String;
    final perfil = Map<String, dynamic>.from(respuesta['usuario']);
    await seguro.write(
      key: 'lecturaviva_sesion',
      value: jsonEncode({'token': nuevoToken, 'usuario': perfil}),
    );
    token = nuevoToken;
    sesionSinConexion = false;
    return perfil;
  }

  Future<void> salir() async {
    await seguro.delete(key: 'lecturaviva_sesion');
    await seguro.delete(key: 'lecturaviva_token');
    token = null;
    sesionSinConexion = false;
  }

  List<String> favoritos(int usuario) =>
      List<String>.from(caja.get('favoritos_$usuario', defaultValue: []));
  Future<void> guardarFavoritos(int usuario, List<String> ids) =>
      caja.put('favoritos_$usuario', ids);
  Future<List<Map<String, dynamic>>> resenas(String libro) async =>
      (await pedir('GET', '/api/libros/$libro/resenas') as List)
          .map((j) => Map<String, dynamic>.from(j))
          .toList();
  Future<void> guardarResena(
    String libro,
    int puntuacion,
    String texto, {
    int? id,
  }) async {
    await pedir(
      id == null ? 'POST' : 'PUT',
      id == null ? '/api/libros/$libro/resenas' : '/api/resenas/$id',
      {'puntuacion': puntuacion, 'texto': texto},
    );
  }

  Future<void> eliminarResena(int id) async {
    await pedir('DELETE', '/api/resenas/$id');
  }

  Future<String> recomendar(String consulta, List<String> favoritos) async =>
      (await pedir('POST', '/api/asistente', {
            'consulta': consulta,
            'favoritos': favoritos,
          }))['respuesta']
          as String;
}
