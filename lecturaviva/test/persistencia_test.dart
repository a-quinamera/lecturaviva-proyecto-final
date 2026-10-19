import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lecturaviva/controllers/lectura_controller.dart';
import 'package:lecturaviva/data/repositorio.dart';
import 'package:lecturaviva/main.dart';

const libro = Libro(
  id: 'OL450063W',
  titulo: 'Frankenstein',
  autor: 'Mary Shelley',
  fuente: 'https://openlibrary.org/works/OL450063W',
  anio: 1818,
);
const otro = Libro(
  id: 'OL2W',
  titulo: 'Otra historia',
  autor: 'Otro autor',
  fuente: 'https://openlibrary.org/works/OL2W',
);
Map<String, dynamic> perfil(int id) => {
  'id': id,
  'nombre': 'Lector $id',
  'correo': 'lector$id@example.test',
};
http.Response jsonRespuesta(Object dato, [int estado = 200]) => http.Response(
  jsonEncode(dato),
  estado,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory carpeta;
  late Box caja;
  setUp(() async {
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    carpeta = await Directory.systemTemp.createTemp('lecturaviva-pruebas-');
    Hive.init(carpeta.path);
    caja = await Hive.openBox('pruebas');
  });
  tearDown(() async {
    Get.reset();
    await Hive.close();
    await carpeta.delete(recursive: true);
  });

  for (final estado in [400, 401, 403, 404, 422, 500, 503]) {
    test(
      'HTTP $estado conserva el código y ofrece un mensaje legible',
      () async {
        final repo = Repositorio(
          caja,
          cliente: MockClient(
            (_) async => estado == 500
                ? http.Response(
                    '<html>error interno sin detalle público</html>',
                    estado,
                  )
                : jsonRespuesta({
                    'detail': estado == 422
                        ? [
                            {'msg': 'validación'},
                          ]
                        : 'Mensaje controlado',
                  }, estado),
          ),
        );
        await expectLater(
          repo.pedir('GET', '/prueba'),
          throwsA(
            isA<Fallo>()
                .having((e) => e.estado, 'código', estado)
                .having(
                  (e) => e.mensaje.isNotEmpty && !e.mensaje.contains('<html>'),
                  'mensaje seguro',
                  true,
                ),
          ),
        );
      },
    );
  }
  test('DELETE 204 se acepta sin intentar exigir un JSON', () async {
    final repo = Repositorio(
      caja,
      cliente: MockClient((r) async {
        expect(r.method, 'DELETE');
        return http.Response('', 204);
      }),
    );
    await repo.eliminarResena(1);
  });
  test('fallo de red se transforma en un error recuperable', () async {
    final repo = Repositorio(
      caja,
      cliente: MockClient((_) async => throw http.ClientException('sin red')),
    );
    await expectLater(
      repo.catalogo(),
      throwsA(
        isA<Fallo>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('Sin conexión'),
        ),
      ),
    );
  });
  test('timeout termina la espera y muestra un mensaje propio', () async {
    final repo = Repositorio(
      caja,
      espera: const Duration(milliseconds: 5),
      cliente: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return jsonRespuesta([]);
      }),
    );
    await expectLater(
      repo.catalogo(),
      throwsA(
        isA<Fallo>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('tardó demasiado'),
        ),
      ),
    );
  });
  test('catálogo y favoritos sobreviven a cerrar y reabrir Hive', () async {
    var repo = Repositorio(
      caja,
      cliente: MockClient((_) async => jsonRespuesta([libro.aJson()])),
    );
    await repo.catalogo();
    await repo.guardarFavoritos(1, [libro.id]);
    await repo.guardarFavoritos(2, [otro.id]);
    await caja.close();
    caja = await Hive.openBox('pruebas');
    repo = Repositorio(caja);
    expect(repo.catalogoGuardado().single.titulo, libro.titulo);
    expect(repo.favoritos(1), [libro.id]);
    expect(repo.favoritos(2), [otro.id]);
    expect(repo.favoritos(3), isEmpty);
  });
  test('caché corrupta no impide arrancar y permite recargar', () async {
    await caja.put('catalogo', 'datos no válidos');
    expect(Repositorio(caja).catalogoGuardado(), isEmpty);
  });
  test(
    'registro envía password y la sesión se restaura en otra instancia',
    () async {
      final cliente = MockClient((r) async {
        if (r.method == 'POST') {
          final datos = jsonDecode(r.body) as Map;
          expect(datos['password'], 'clave-sintetica');
          expect(datos.containsKey('clave'), isFalse);
          return jsonRespuesta({
            'token': 'token-sintetico',
            'usuario': perfil(1),
          }, 201);
        }
        expect(r.headers['Authorization'], 'Bearer token-sintetico');
        return jsonRespuesta(perfil(1));
      });
      final repo = Repositorio(caja, cliente: cliente);
      await repo.entrar(
        'lector1@example.test',
        'clave-sintetica',
        nombre: 'Lector 1',
      );
      final nueva = Repositorio(caja, cliente: cliente);
      expect((await nueva.restaurar())?['id'], 1);
      expect(nueva.token, 'token-sintetico');
      expect(nueva.sesionSinConexion, isFalse);
    },
  );
  test('sin red se recupera perfil seguro y favoritos locales', () async {
    final repo = Repositorio(
      caja,
      cliente: MockClient(
        (_) async =>
            jsonRespuesta({'token': 'token-sintetico', 'usuario': perfil(1)}),
      ),
    );
    await repo.entrar('lector1@example.test', 'clave-sintetica');
    await repo.guardarFavoritos(1, [libro.id]);
    repo.catalogoGuardado();
    final sinRed = Repositorio(
      caja,
      cliente: MockClient((_) async => throw http.ClientException('sin red')),
    );
    final c = LecturaController(sinRed);
    await c.iniciar();
    expect(c.usuarioId, 1);
    expect(c.favoritos, [libro.id]);
    expect(sinRed.sesionSinConexion, isTrue);
    expect(c.aviso.value, contains('sin conexión'));
  });
  test(
    '401 al restaurar borra la sesión y evita conservar el usuario',
    () async {
      final repo = Repositorio(
        caja,
        cliente: MockClient(
          (_) async =>
              jsonRespuesta({'token': 'token-expirado', 'usuario': perfil(1)}),
        ),
      );
      await repo.entrar('lector1@example.test', 'clave-sintetica');
      final nueva = Repositorio(
        caja,
        cliente: MockClient(
          (r) async => r.url.path.endsWith('/yo')
              ? jsonRespuesta({'detail': 'Caducada'}, 401)
              : jsonRespuesta([]),
        ),
      );
      final c = LecturaController(nueva);
      await c.iniciar();
      expect(c.autenticado, isFalse);
      expect(nueva.token, isNull);
      expect(await nueva.seguro.read(key: 'lecturaviva_sesion'), isNull);
    },
  );
  test(
    'logout separa favoritos y respuesta IA de la siguiente cuenta',
    () async {
      final repo = Repositorio(
        caja,
        cliente: MockClient((r) async {
          final correo = (jsonDecode(r.body) as Map)['correo'] as String;
          final id = correo.startsWith('lector2') ? 2 : 1;
          return jsonRespuesta({'token': 'token-$id', 'usuario': perfil(id)});
        }),
      );
      final c = LecturaController(repo);
      await c.entrar('lector1@example.test', 'clave-sintetica');
      await c.alternarFavorito(libro);
      c.respuestaIA.value = 'Respuesta de la cuenta 1';
      await c.salir();
      expect(c.favoritos, isEmpty);
      expect(c.respuestaIA.value, isEmpty);
      await c.entrar('lector2@example.test', 'clave-sintetica');
      expect(c.favoritos, isEmpty);
      await c.salir();
      await c.entrar('lector1@example.test', 'clave-sintetica');
      expect(c.favoritos, [libro.id]);
    },
  );
  test(
    'una respuesta vieja de reseñas no sustituye a la más reciente',
    () async {
      final pendiente = Completer<http.Response>();
      int veces = 0;
      final repo = Repositorio(
        caja,
        cliente: MockClient((_) {
          veces++;
          return veces == 1
              ? pendiente.future
              : Future.value(
                  jsonRespuesta([
                    {'id': 2, 'texto': 'Reciente'},
                  ]),
                );
        }),
      );
      final c = LecturaController(repo);
      final antigua = c.verResenas(libro.id);
      await c.verResenas(libro.id);
      pendiente.complete(
        jsonRespuesta([
          {'id': 1, 'texto': 'Antigua'},
        ]),
      );
      await antigua;
      expect(c.listaResenas.single['id'], 2);
      expect(c.cargandoResenas.value, isFalse);
    },
  );
  test(
    'la respuesta IA pendiente no se muestra después de cerrar sesión',
    () async {
      final pendiente = Completer<http.Response>();
      final c = LecturaController(
        Repositorio(caja, cliente: MockClient((_) => pendiente.future)),
      );
      c.usuario.value = perfil(1);
      final llamada = c.recomendar('Quiero leer misterio');
      await c.salir();
      pendiente.complete(
        jsonRespuesta({'respuesta': 'Solo de la sesión anterior'}),
      );
      await llamada;
      expect(c.respuestaIA.value, isEmpty);
      expect(c.autenticado, isFalse);
    },
  );
  testWidgets('catálogo y búsqueda funcionan a 360 px sin desbordamientos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = Repositorio(
      caja,
      cliente: MockClient(
        (_) async => jsonRespuesta([libro.aJson(), otro.aJson()]),
      ),
    );
    final c = LecturaController(repo);
    await tester.runAsync(() async {
      Get.put(c);
      final limite = DateTime.now().add(const Duration(seconds: 3));
      while (c.restaurando.value || c.cargando.value) {
        if (DateTime.now().isAfter(limite)) {
          throw StateError('El catálogo no terminó de cargar');
        }
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    await tester.pumpWidget(const LecturaViva());
    await tester.pumpAndSettle();
    expect(find.text('Frankenstein'), findsOneWidget);
    expect(find.text('Otra historia'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'mary');
    await tester.pumpAndSettle();
    expect(find.text('Frankenstein'), findsOneWidget);
    expect(find.text('Otra historia'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
