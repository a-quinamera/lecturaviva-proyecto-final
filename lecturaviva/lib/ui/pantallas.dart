import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/lectura_controller.dart';
import '../data/repositorio.dart';

void informar(BuildContext context, String? mensaje) {
  if (mensaje != null && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }
}

class Estado extends StatelessWidget {
  final String mensaje;
  final VoidCallback? accion;
  const Estado(this.mensaje, {super.key, this.accion});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book, size: 40),
          const SizedBox(height: 16),
          Text(mensaje, textAlign: TextAlign.center),
          if (accion != null)
            TextButton(
              onPressed: accion,
              child: const Text('Volver a intentar'),
            ),
        ],
      ),
    ),
  );
}

class Inicio extends GetView<LecturaController> {
  const Inicio({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('LecturaViva'),
      actions: [
        IconButton(
          tooltip: 'Asistente',
          icon: const Icon(Icons.auto_awesome_outlined),
          onPressed: () => Get.to(() => const Asistente()),
        ),
        Obx(
          () => TextButton.icon(
            onPressed: controller.restaurando.value
                ? null
                : () => Get.to(() => const Acceso()),
            icon: const Icon(Icons.person_outline),
            label: Text(controller.autenticado ? 'Mi cuenta' : 'Entrar'),
          ),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu próxima historia empieza aquí',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Explora libros, comparte reseñas y construye tu biblioteca.',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (v) => controller.busqueda.value = v,
                    decoration: const InputDecoration(
                      labelText: 'Buscar título o autor',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Obx(
                    () => Row(
                      children: [
                        FilterChip(
                          label: const Text('Mis favoritos'),
                          selected: controller.soloFavoritos.value,
                          onSelected: (v) => controller.soloFavoritos.value = v,
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Actualizar',
                          onPressed: controller.cargando.value
                              ? null
                              : controller.cargar,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Obx(
              () => controller.cargando.value
                  ? const LinearProgressIndicator()
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: Obx(() {
                if (controller.error.value.isNotEmpty) {
                  return Estado(
                    controller.error.value,
                    accion: controller.cargar,
                  );
                }
                final libros = controller.visibles;
                return Column(
                  children: [
                    if (controller.aviso.value.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(controller.aviso.value),
                      ),
                    Expanded(
                      child: libros.isEmpty
                          ? const Estado(
                              'No hay libros para esta selección. Cambia la búsqueda o guarda favoritos.',
                            )
                          : LayoutBuilder(
                              builder: (context, espacio) => GridView.builder(
                                padding: const EdgeInsets.all(20),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: espacio.maxWidth > 850
                                          ? 4
                                          : espacio.maxWidth > 560
                                          ? 3
                                          : 2,
                                      mainAxisExtent: 290,
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                    ),
                                itemCount: libros.length,
                                itemBuilder: (context, i) {
                                  final libro = libros[i];
                                  return Card(
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () {
                                        controller.verResenas(libro.id);
                                        Get.to(() => Detalle(libro));
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(16),
                                              color: [
                                                const Color(0xffe7d8c0),
                                                const Color(0xffd8e5dd),
                                                const Color(0xffe6dce8),
                                              ][i % 3],
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Icon(
                                                    Icons.menu_book_outlined,
                                                  ),
                                                  Text(
                                                    libro.titulo,
                                                    maxLines: 4,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.titleMedium,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              12,
                                              12,
                                              12,
                                              0,
                                            ),
                                            child: Text(
                                              libro.autor,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              const SizedBox(width: 12),
                                              const Icon(
                                                Icons.star_outline,
                                                size: 18,
                                              ),
                                              Expanded(
                                                child: Text(
                                                  ' ${libro.promedio} · ${libro.resenas}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Obx(
                                                () => IconButton(
                                                  tooltip: 'Favorito',
                                                  icon: Icon(
                                                    controller.favoritos
                                                            .contains(libro.id)
                                                        ? Icons.favorite
                                                        : Icons.favorite_border,
                                                  ),
                                                  onPressed: () async {
                                                    final mensaje =
                                                        await controller
                                                            .alternarFavorito(
                                                              libro,
                                                            );
                                                    if (context.mounted) {
                                                      informar(
                                                        context,
                                                        mensaje,
                                                      );
                                                    }
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    ),
  );
}

class Acceso extends StatefulWidget {
  const Acceso({super.key});
  @override
  State<Acceso> createState() => _AccesoState();
}

class _AccesoState extends State<Acceso> {
  final formulario = GlobalKey<FormState>();
  final correo = TextEditingController(),
      password = TextEditingController(),
      nombre = TextEditingController();
  bool registro = false;
  String? error;
  @override
  void dispose() {
    correo.dispose();
    password.dispose();
    nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<LecturaController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Tu espacio lector')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Obx(() {
            if (c.autenticado) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Hola, ${c.usuario.value!['nombre']}'),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Tus favoritos se guardan en este dispositivo.',
                    ),
                  ),
                  FilledButton(
                    onPressed: () async {
                      await c.salir();
                      Get.back();
                    },
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formulario,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.local_library_outlined, size: 64),
                    const SizedBox(height: 24),
                    if (registro)
                      TextFormField(
                        controller: nombre,
                        maxLength: 40,
                        decoration: const InputDecoration(
                          labelText: 'Nombre público',
                        ),
                        validator: (v) => v!.trim().length < 2
                            ? 'Escribe al menos 2 caracteres.'
                            : null,
                      ),
                    TextFormField(
                      controller: correo,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                      ),
                      validator: (v) =>
                          !RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(v!.trim())
                          ? 'Introduce un correo válido.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: password,
                      obscureText: true,
                      maxLength: 72,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                      validator: (v) => v!.length < 8
                          ? 'Utiliza al menos 8 caracteres.'
                          : null,
                    ),
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    FilledButton(
                      onPressed: c.ocupado.value
                          ? null
                          : () async {
                              if (!formulario.currentState!.validate()) return;
                              final mensaje = await c.entrar(
                                correo.text,
                                password.text,
                                nombre: registro ? nombre.text : null,
                              );
                              if (!mounted) return;
                              if (mensaje == null) {
                                Get.back();
                              } else {
                                setState(() => error = mensaje);
                              }
                            },
                      child: Text(
                        c.ocupado.value
                            ? 'Conectando…'
                            : registro
                            ? 'Crear cuenta'
                            : 'Entrar',
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        registro = !registro;
                        error = null;
                      }),
                      child: Text(
                        registro ? 'Ya tengo una cuenta' : 'Crear una cuenta',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class Detalle extends GetView<LecturaController> {
  final Libro libro;
  const Detalle(this.libro, {super.key});
  Future<void> editar(
    BuildContext context, [
    Map<String, dynamic>? resena,
  ]) async {
    if (!controller.autenticado) {
      Get.to(() => const Acceso());
      return;
    }
    final texto = TextEditingController(
      text: resena?['texto'] as String? ?? '',
    );
    int puntuacion = (resena?['puntuacion'] as int?) ?? 5;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, actualizar) => AlertDialog(
          title: Text(resena == null ? 'Compartir reseña' : 'Editar mi reseña'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<int>(
                    value: puntuacion,
                    isExpanded: true,
                    items: List.generate(
                      5,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('${i + 1} estrellas'),
                      ),
                    ),
                    onChanged: (v) => actualizar(() => puntuacion = v!),
                  ),
                  TextField(
                    controller: texto,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 1200,
                    decoration: const InputDecoration(
                      labelText:
                          'Tu opinión, sin spoilers (mínimo 10 caracteres)',
                    ),
                  ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            Obx(
              () => FilledButton(
                onPressed: controller.ocupado.value
                    ? null
                    : () async {
                        if (texto.text.trim().length < 10) {
                          actualizar(
                            () => error = 'Escribe al menos 10 caracteres.',
                          );
                          return;
                        }
                        final mensaje = await controller.guardarResena(
                          libro,
                          puntuacion,
                          texto.text,
                          id: resena?['id'] as int?,
                        );
                        if (!context.mounted) return;
                        if (mensaje == null) {
                          Navigator.pop(dialogContext);
                        } else {
                          actualizar(() => error = mensaje);
                        }
                      },
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
    texto.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Entre páginas')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.menu_book_outlined, size: 72),
            const SizedBox(height: 24),
            Text(
              libro.titulo,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(libro.autor, style: Theme.of(context).textTheme.titleLarge),
            Text('Año registrado: ${libro.anio ?? 'Sin dato'}'),
            const SizedBox(height: 12),
            SelectableText('Fuente: ${libro.fuente}'),
            Obx(
              () => OutlinedButton.icon(
                icon: Icon(
                  controller.favoritos.contains(libro.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                label: Text(
                  controller.favoritos.contains(libro.id)
                      ? 'Quitar de favoritos'
                      : 'Guardar en favoritos',
                ),
                onPressed: () async {
                  final mensaje = await controller.alternarFavorito(libro);
                  if (context.mounted) {
                    informar(context, mensaje);
                  }
                },
              ),
            ),
            const Divider(height: 40),
            Text(
              'La comunidad opina',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            FilledButton(
              onPressed: () => editar(context),
              child: const Text('Escribir mi reseña'),
            ),
            TextButton(
              onPressed: () => controller.verResenas(libro.id),
              child: const Text('Actualizar reseñas'),
            ),
            Obx(() {
              if (controller.cargandoResenas.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.errorResenas.value.isNotEmpty) {
                return Estado(
                  controller.errorResenas.value,
                  accion: () => controller.verResenas(libro.id),
                );
              }
              if (controller.listaResenas.isEmpty) {
                return const Estado(
                  'Todavía no hay reseñas. Comparte la primera.',
                );
              }
              return Column(
                children: controller.listaResenas
                    .map(
                      (r) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r['autor']} · ${r['puntuacion']} ★',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(r['texto'] as String),
                              if (r['usuario_id'] == controller.usuarioId)
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () => editar(context, r),
                                      child: const Text('Editar'),
                                    ),
                                    TextButton(
                                      onPressed: controller.ocupado.value
                                          ? null
                                          : () async {
                                              final confirmar =
                                                  await showDialog<bool>(
                                                    context: context,
                                                    builder: (d) => AlertDialog(
                                                      title: const Text(
                                                        '¿Eliminar tu reseña?',
                                                      ),
                                                      content: const Text(
                                                        'Esta acción no se puede deshacer.',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                d,
                                                                false,
                                                              ),
                                                          child: const Text(
                                                            'Cancelar',
                                                          ),
                                                        ),
                                                        FilledButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                d,
                                                                true,
                                                              ),
                                                          child: const Text(
                                                            'Eliminar',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                              if (confirmar == true) {
                                                final mensaje = await controller
                                                    .eliminar(
                                                      libro,
                                                      r['id'] as int,
                                                    );
                                                if (context.mounted) {
                                                  informar(context, mensaje);
                                                }
                                              }
                                            },
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            }),
          ],
        ),
      ),
    ),
  );
}

class Asistente extends StatefulWidget {
  const Asistente({super.key});
  @override
  State<Asistente> createState() => _AsistenteState();
}

class _AsistenteState extends State<Asistente> {
  final consulta = TextEditingController();
  @override
  void dispose() {
    consulta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<LecturaController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Un libro para ti')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 56),
              const SizedBox(height: 20),
              Text(
                'Cuéntanos qué te apetece leer',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Consulta nuestro catálogo y tus favoritos. Tu consulta se envía a Gemini mediante el servidor. Evita incluir datos personales. Las recomendaciones pueden contener errores.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: consulta,
                maxLength: 800,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText:
                      'Por ejemplo: busco misterio y personajes complejos',
                ),
              ),
              Obx(
                () => FilledButton.icon(
                  onPressed: c.pensando.value
                      ? null
                      : () => c.recomendar(consulta.text),
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    c.pensando.value
                        ? 'Buscando tu próxima lectura…'
                        : 'Recomendar libros',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Obx(
                () => c.pensando.value
                    ? const LinearProgressIndicator()
                    : const SizedBox.shrink(),
              ),
              Obx(
                () => c.errorIA.value.isNotEmpty
                    ? Text(
                        c.errorIA.value,
                        style: const TextStyle(color: Colors.red),
                      )
                    : const SizedBox.shrink(),
              ),
              Obx(
                () => c.respuestaIA.value.isEmpty
                    ? const SizedBox.shrink()
                    : Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: SelectableText(c.respuestaIA.value),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
