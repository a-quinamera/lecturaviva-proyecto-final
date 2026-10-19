import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'controllers/lectura_controller.dart';
import 'data/repositorio.dart';
import 'ui/pantallas.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
    final caja = await Hive.openBox('lecturaviva');
    Get.put(LecturaController(Repositorio(caja)));
    runApp(const LecturaViva());
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Estado(
            'No se pudo abrir el almacenamiento local. Cierra y vuelve a abrir la aplicación.',
          ),
        ),
      ),
    );
  }
}

class LecturaViva extends StatelessWidget {
  const LecturaViva({super.key});
  @override
  Widget build(BuildContext context) => GetMaterialApp(
    title: 'LecturaViva',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff27564b)),
      scaffoldBackgroundColor: const Color(0xfffaf8f3),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xfffaf8f3)),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: const CardThemeData(elevation: 0, color: Colors.white),
    ),
    home: const Inicio(),
  );
}
