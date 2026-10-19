import 'package:get/get.dart';
import '../data/repositorio.dart';

class LecturaController extends GetxController {
  final Repositorio repo;
  LecturaController(this.repo);
  final libros = <Libro>[].obs;
  final favoritos = <String>[].obs;
  final usuario = Rxn<Map<String, dynamic>>();
  final cargando = false.obs;
  final ocupado = false.obs;
  final restaurando = true.obs;
  final error = ''.obs;
  final aviso = ''.obs;
  final busqueda = ''.obs;
  final soloFavoritos = false.obs;
  final listaResenas = <Map<String, dynamic>>[].obs;
  final cargandoResenas = false.obs;
  final errorResenas = ''.obs;
  final respuestaIA = ''.obs;
  final errorIA = ''.obs;
  final pensando = false.obs;
  String? libroActual;
  int _resenasVersion = 0;
  int _sesionVersion = 0;
  int get usuarioId => (usuario.value?['id'] as int?) ?? -1;
  bool get autenticado => usuario.value != null;
  List<Libro> get visibles {
    final q = busqueda.value.toLowerCase().trim();
    return libros
        .where(
          (l) =>
              (!soloFavoritos.value || favoritos.contains(l.id)) &&
              (q.isEmpty ||
                  l.titulo.toLowerCase().contains(q) ||
                  l.autor.toLowerCase().contains(q)),
        )
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    iniciar();
  }

  Future<void> iniciar() async {
    libros.assignAll(repo.catalogoGuardado());
    try {
      usuario.value = await repo.restaurar();
      if (autenticado) favoritos.assignAll(repo.favoritos(usuarioId));
    } on Fallo catch (e) {
      if (e.estado == 401) {
        await repo.salir();
      }
      aviso.value = e.mensaje;
    } catch (_) {
      aviso.value = 'No se pudo recuperar la sesión de forma segura.';
    }
    restaurando.value = false;
    await cargar();
    if (repo.sesionSinConexion) {
      aviso.value =
          'Sesión local sin conexión: puedes consultar tus favoritos. Los cambios requieren el servidor. ${aviso.value}';
    }
  }

  Future<void> cargar() async {
    cargando.value = true;
    error.value = '';
    aviso.value = '';
    try {
      libros.assignAll(await repo.catalogo());
    } on Fallo catch (e) {
      if (libros.isNotEmpty) {
        aviso.value = 'Catálogo guardado. ${e.mensaje}';
      } else {
        error.value = e.mensaje;
      }
    } catch (_) {
      error.value = 'No se pudo leer el catálogo.';
    } finally {
      cargando.value = false;
    }
  }

  Future<String?> entrar(
    String correo,
    String password, {
    String? nombre,
  }) async {
    if (ocupado.value) return 'Espera a que termine la operación.';
    ocupado.value = true;
    try {
      usuario.value = await repo.entrar(correo, password, nombre: nombre);
      _sesionVersion++;
      favoritos.assignAll(repo.favoritos(usuarioId));
      aviso.value = '';
      return null;
    } on Fallo catch (e) {
      return e.mensaje;
    } catch (_) {
      return 'No se pudo guardar la sesión. Inténtalo de nuevo.';
    } finally {
      ocupado.value = false;
    }
  }

  Future<void> salir() async {
    await repo.salir();
    _sesionVersion++;
    usuario.value = null;
    favoritos.clear();
    respuestaIA.value = '';
    errorIA.value = '';
    soloFavoritos.value = false;
  }

  Future<String?> alternarFavorito(Libro libro) async {
    if (!autenticado) return 'Inicia sesión para guardar tus favoritos.';
    final id = usuarioId;
    final nuevos = favoritos.toList();
    nuevos.contains(libro.id) ? nuevos.remove(libro.id) : nuevos.add(libro.id);
    try {
      await repo.guardarFavoritos(id, nuevos);
      if (usuarioId == id) {
        favoritos.assignAll(nuevos);
      }
      return null;
    } catch (_) {
      return 'No se pudo guardar el favorito en este dispositivo.';
    }
  }

  Future<void> verResenas(String libro) async {
    final version = ++_resenasVersion;
    libroActual = libro;
    listaResenas.clear();
    errorResenas.value = '';
    cargandoResenas.value = true;
    try {
      final datos = await repo.resenas(libro);
      if (libroActual == libro && version == _resenasVersion) {
        listaResenas.assignAll(datos);
      }
    } on Fallo catch (e) {
      if (libroActual == libro && version == _resenasVersion) {
        errorResenas.value = e.mensaje;
      }
    } catch (_) {
      if (libroActual == libro && version == _resenasVersion) {
        errorResenas.value = 'No se pudieron leer las reseñas.';
      }
    } finally {
      if (libroActual == libro && version == _resenasVersion) {
        cargandoResenas.value = false;
      }
    }
  }

  Future<String?> guardarResena(
    Libro libro,
    int puntuacion,
    String texto, {
    int? id,
  }) async {
    if (ocupado.value) return 'Espera a que termine la operación.';
    ocupado.value = true;
    try {
      await repo.guardarResena(libro.id, puntuacion, texto.trim(), id: id);
      await verResenas(libro.id);
      await cargar();
      return null;
    } on Fallo catch (e) {
      await revisarSesion(e);
      return e.mensaje;
    } catch (_) {
      return 'No se pudo guardar la reseña.';
    } finally {
      ocupado.value = false;
    }
  }

  Future<String?> eliminar(Libro libro, int id) async {
    if (ocupado.value) return 'Espera a que termine la operación.';
    ocupado.value = true;
    try {
      await repo.eliminarResena(id);
      await verResenas(libro.id);
      await cargar();
      return null;
    } on Fallo catch (e) {
      await revisarSesion(e);
      return e.mensaje;
    } catch (_) {
      return 'No se pudo eliminar la reseña.';
    } finally {
      ocupado.value = false;
    }
  }

  Future<void> revisarSesion(Fallo e) async {
    if (e.estado == 401) {
      await salir();
    }
  }

  Future<void> recomendar(String consulta) async {
    if (pensando.value) return;
    errorIA.value = '';
    respuestaIA.value = '';
    if (!autenticado) {
      errorIA.value = 'Inicia sesión para consultar al asistente.';
      return;
    }
    if (consulta.trim().length < 5) {
      errorIA.value = 'Describe tus intereses con al menos 5 caracteres.';
      return;
    }
    final version = _sesionVersion;
    pensando.value = true;
    try {
      final respuesta = await repo.recomendar(
        consulta.trim(),
        favoritos.toList(),
      );
      if (version == _sesionVersion) {
        respuestaIA.value = respuesta;
      }
    } on Fallo catch (e) {
      if (version == _sesionVersion) {
        await revisarSesion(e);
        errorIA.value = e.mensaje;
      }
    } catch (_) {
      if (version == _sesionVersion) {
        errorIA.value = 'El asistente no pudo procesar la respuesta.';
      }
    } finally {
      pensando.value = false;
    }
  }
}
