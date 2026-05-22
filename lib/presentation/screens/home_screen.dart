import 'dart:async'; // Necesario para el temporizador de inactividad
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Instancia global de acceso a Supabase
final supabase = Supabase.instance.client;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userEmail = '';
  String _userRole = 'sin_acceso';
  bool _isLoading = true;
  bool _isInit = false; // Control para didChangeDependencies
  
  // Declaramos el temporizador
  Timer? _inactividadTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Aquí es seguro leer el correo que viene del Login
    if (!_isInit) {
      _userEmail = ModalRoute.of(context)?.settings.arguments as String? ?? '';
      _obtenerRolDeUsuario();
      _reiniciarTemporizador(); // Iniciamos el conteo
      _isInit = true;
    }
  }

  // --- LÓGICA DE ROLES ---
  Future<void> _obtenerRolDeUsuario() async {
    if (_userEmail.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final data = await supabase
          .from('usuarios_roles')
          .select('rol')
          .eq('email', _userEmail)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _userRole = data['rol'] ?? 'sin_acceso';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LÓGICA DE INACTIVIDAD (3 MINUTOS) ---
  void _reiniciarTemporizador() {
    _inactividadTimer?.cancel(); // Cancelamos el anterior
    
    _inactividadTimer = Timer(const Duration(minutes: 3), () {
      _cerrarSesionPorInactividad();
    });
  }

  void _cerrarSesionPorInactividad() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sesión cerrada por inactividad (3 min)."),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _inactividadTimer?.cancel(); // Limpiamos la memoria al salir
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Definimos qué puede ver cada rol
    final bool isAdmin = _userRole == 'administrador';
    final bool isRegistro = _userRole == 'SUPERVISOR';
    final bool isReportes = _userRole == 'reportes';
    

    // Listener envuelve toda la pantalla para detectar toques y reiniciar el timer
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _reiniciarTemporizador(), // Al tocar
      onPointerMove: (_) => _reiniciarTemporizador(), // Al deslizar
      
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "GRUPO CYRECO",
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF00A859),
          foregroundColor: Colors.white,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "Cerrar Sesión",
              onPressed: () {
                _inactividadTimer?.cancel();
                Navigator.pushReplacementNamed(context, '/login');
              },
            )
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A859)))
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Encabezado ---
                          const Text(
                            "Panel Control de Flota",
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Usuario: $_userEmail\nRol activo: ${_userRole.toUpperCase()}",
                            style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 25),

                          // --- SECCIÓN 1: OPERACIONES (Solo Admin y Registro) ---
                          if (isAdmin || isRegistro) ...[
                            const _SeccionTitulo(titulo: "📋 Operaciones y Daños en Ruta"),
                            const SizedBox(height: 10),
                            _menuItem(
                              context,
                              title: "Nuevo Registro de Daño",
                              subtitle: "Reporte inicial, siniestros y toma de evidencias",
                              icon: Icons.add_a_photo_outlined,
                              color: const Color(0xFF00A859),
                              onTap: () => Navigator.pushNamed(context, '/registro'),
                            ),
                            ],
                            if (isAdmin) ...[
                            _menuItem(
                              context,
                              title: "Seguimiento y Acuerdo",
                              subtitle: "Definir montos, cuotas y convenios con motoristas",
                              icon: Icons.assignment_late_outlined,
                              color: Colors.orange,
                              onTap: () => _mostrarSeleccionIncidencia(context),
                            ),
                            _menuItem(
                              context,
                              title: "Cierre Administrativo",
                              subtitle: "Finalizar y archivar proceso de incidencia solventada",
                              icon: Icons.assignment_turned_in_outlined,
                              color: const Color(0xFF607D8B),
                              onTap: () => _mostrarSeleccionCierre(context),
                            ),
                            const SizedBox(height: 20),
                          

                          // --- SECCIÓN 2: AUDITORÍA FISICA (Solo Admin) ---
                          
                            const _SeccionTitulo(titulo: "🚛 Inventario y Estado Físico"),
                            const SizedBox(height: 10),
                            _menuItem(
                              context,
                              title: "Auditoría de Equipos",
                              subtitle: "Inspección visual y control preventivo 360°",
                              icon: Icons.youtube_searched_for_sharp,
                              color: const Color(0xFF00796B),
                              onTap: () => Navigator.pushNamed(context, '/auditoria'),
                            ),
                            _menuItem(
                              context,
                              title: "Catálogo General de Flota",
                              subtitle: "Ingresar, modificar y dar de baja unidades",
                              icon: Icons.edit_note_outlined,
                              color: Colors.blue.shade700,
                              onTap: () => Navigator.pushNamed(context, '/gestion_equipos'),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // --- SECCIÓN 3: REPORTES (Solo Admin y Reportes) ---
                          if (isAdmin || isReportes) ...[
                            const _SeccionTitulo(titulo: "📊 Reportes y Estadísticas analíticas"),
                            const SizedBox(height: 10),
                            _menuItem(
                              context,
                              title: "Dashboard de Rendimiento",
                              subtitle: "Gráficos de incidencias, unidades y motoristas críticos",
                              icon: Icons.analytics_outlined,
                              color: Colors.purple.shade700,
                              onTap: () => Navigator.pushNamed(context, '/reporteria'),
                              
                            ),
                          ],

                          if (isAdmin || isAdmin) ...[
                            const _SeccionTitulo(titulo: "Aministracion de usuarios"),
                            const SizedBox(height: 10),
                            _menuItem(context,
                             title: "Usuarios", 
                             subtitle: "Editor de Usuario",
                            icon: Icons.supervised_user_circle_outlined,
                             color: Colors.indigoAccent,
                              onTap: () => Navigator.pushNamed(context, '/crear_usuario')
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  // Pie de aplicación
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Center(
                      child: Text(
                        "v1.1.0 - 2026 • Grupo Cyreco",
                        style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  )
                ],
              ),
      ),
    );
  }

  // --- MODAL PARA PROCESO 2: SEGUIMIENTO Y ACUERDO ---
  void _mostrarSeleccionIncidencia(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Incidencias Pendientes", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: supabase.from('incidencias').stream(primaryKey: ['folio']),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF00A859)));
                    }
                    
                    final rawDocs = snapshot.data!;
                    final docs = rawDocs.where((doc) {
                      final estado = doc['estado']?.toString().toLowerCase() ?? '';
                      return estado == 'pendiente';
                    }).toList();

                    if (docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 50, color: Colors.green),
                            SizedBox(height: 10),
                            Text("No hay incidencias en estado Pendiente"),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index];
                        final String idIncidencia = (data['folio'] ?? data['id'] ?? '').toString();
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 1,
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Icon(Icons.local_shipping, color: Colors.white, size: 20),
                            ),
                            title: Text(data['motorista'] ?? "Sin Nombre", 
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Unidad: ${data['unidad_id'] ?? 'S/N'}\nEstado: ${data['estado'] ?? 'Pendiente'}"),
                            isThreeLine: true,
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(
                                context, 
                                '/seguimiento', 
                                arguments: idIncidencia
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- MODAL PARA PROCESO 3: CIERRE ADMINISTRATIVO ---
  void _mostrarSeleccionCierre(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lock_outline, color: Color(0xFF607D8B)),
                      SizedBox(width: 8),
                      Text("Equipos En Proceso", 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: supabase.from('incidencias').stream(primaryKey: ['folio']),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF00A859)));
                    }
                    
                    final rawDocs = snapshot.data!;
                    final docs = rawDocs.where((doc) {
                      final estado = doc['estado']?.toString().toLowerCase() ?? '';
                      return estado == 'en proceso';
                    }).toList();

                    if (docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.gavel_outlined, size: 50, color: Colors.grey),
                            SizedBox(height: 10),
                            Text(
                              "No hay reportes 'En Proceso' pendientes.\nPrimero defina el acuerdo administrativo.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index];
                        final String idIncidencia = (data['folio'] ?? data['id'] ?? '').toString();
                        final String unidad = data['unidad_id'] ?? 'S/N';
                        final String motorista = data['motorista'] ?? 'Sin Nombre';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 1,
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFF607D8B),
                              child: Icon(Icons.build_circle_outlined, color: Colors.white, size: 20),
                            ),
                            title: Text("Folio: $idIncidencia", 
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Unidad: $unidad\nMotorista: $motorista"),
                            isThreeLine: true,
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF00A859)),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(
                                context, 
                                '/cierre', 
                                arguments: idIncidencia
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Elemento de Menú Optimizado
  Widget _menuItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Colors.black),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[600], height: 1.2),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget Helper para los Títulos de las Categorías
class _SeccionTitulo extends StatelessWidget {
  final String titulo;
  const _SeccionTitulo({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        titulo,
        style: TextStyle(
          fontSize: 13, 
          fontWeight: FontWeight.bold, 
          color: Colors.green.shade900, 
          letterSpacing: 0.3
        ),
      ),
    );
  }
}