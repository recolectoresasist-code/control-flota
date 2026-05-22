import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// IMPORTACIONES CON PREFIJOS PARA FORZAR LA LECTURA CORRECTA (EVITA AMBIGÜEDAD)
import 'package:cyreco_flota_control/presentation/screens/login_page.dart' as login;
import 'package:cyreco_flota_control/presentation/screens/home_screen.dart' as home;
import 'package:cyreco_flota_control/presentation/screens/registro_incidencia_page.dart' as registro;
import 'package:cyreco_flota_control/presentation/screens/seguimiento_incidencia_page.dart' as seguimiento;
import 'package:cyreco_flota_control/presentation/screens/cierre_incidencia_page.dart' as cierre;
import 'package:cyreco_flota_control/presentation/screens/auditoria_equipo_page.dart' as auditoria;
import 'package:cyreco_flota_control/presentation/screens/gestion_equipos_page.dart' as gestion;
import 'package:cyreco_flota_control/presentation/screens/reporteria_flota_page.dart' as reporteria;
import 'package:cyreco_flota_control/presentation/screens/crear_usuario_page.dart' as crear_usuario;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización única con tu servidor de Supabase
  await Supabase.initialize(
    url: 'https://vurxmaesgapehbbkgwnu.supabase.co',
    anonKey: 'sb_publishable_R7oImYkwc5VjNBRkgtTbxQ_tDC8AY8a',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Control de Flota - GRUPO CYRECO',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A859),
          primary: const Color(0xFF00A859),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
      ),
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        
        // 🟢 MANEJO DE RUTAS PARA PASAR EL FOLIO A LA PANTALLA DE SEGUIMIENTO
        if (settings.name == '/seguimiento') {
          final args = settings.arguments;
          return MaterialPageRoute(
            settings: settings, // <-- AGREGADO PARA PRESERVAR EL ARGUMENTO
            builder: (context) => seguimiento.SeguimientoIncidenciaPage(
              folioIncidencia: args is String ? args : 'SIN-FOLIO',
            ),
          );
        }

        // 🟢 NUEVA RUTA: PASAR EL FOLIO A LA PANTALLA DE CIERRE/SOLVENTACIÓN
        if (settings.name == '/cierre') {
          final args = settings.arguments;
          return MaterialPageRoute(
            settings: settings, // <-- AGREGADO PARA PRESERVAR EL ARGUMENTO
            builder: (context) => cierre.CierreIncidenciaPage(
              folioIncidencia: args is String ? args : 'SIN-FOLIO',
            ),
          );
        }

        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const login.LoginScreen(), settings: settings);
          
          case '/home': // <-- CORREGIDO DE '/' A '/home'
            return MaterialPageRoute(builder: (_) => const home.HomeScreen(), settings: settings); // <-- AGREGADO settings
            
          case '/registro':
            return MaterialPageRoute(builder: (_) => const registro.RegistroIncidenciaPage(), settings: settings);
          case '/auditoria':
            return MaterialPageRoute(builder: (context) => const auditoria.AuditoriaEquipoPage(), settings: settings);
          case '/gestion_equipos':
            return MaterialPageRoute(builder: (context) => const gestion.GestionEquiposPage(), settings: settings);
          case '/reporteria':
            return MaterialPageRoute(builder: (context) => const reporteria.ReporteriaFlotaPage(), settings: settings);
          case '/crear_usuario':
            return MaterialPageRoute(builder: (_) => const crear_usuario.CrearUsuarioPage(), settings: settings);
          default:
            // Si no encuentra la ruta, lo manda al login por seguridad
            return MaterialPageRoute(builder: (_) => const login.LoginScreen(), settings: settings);
        }
      },
    );
  }
}