import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class GestionEquiposPage extends StatefulWidget {
  const GestionEquiposPage({super.key});

  @override
  State<GestionEquiposPage> createState() => _GestionEquiposPageState();
}

class _GestionEquiposPageState extends State<GestionEquiposPage> {
  List<Map<String, dynamic>> _equipos = [];
  bool _cargando = false;

  final List<String> _tiposVehiculos = [
    'COMPACTADOR', 'LIVIANO', 'VOLQUETA', 'CABEZAL', 'GONDOLA', 'GRUA', 'BIOINFECCIOSO'
  ];

  @override
  void initState() {
    super.initState();
    _cargarEquipos();
  }

  Future<void> _cargarEquipos() async {
    setState(() => _cargando = true);
    try {
      final List<dynamic> response = await supabase
          .from('equipos')
          .select('*')
          .order('id_unidad', ascending: true);
      
      setState(() {
        _equipos = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      _showMsg("❌ Error al cargar equipos: $e", Colors.red);
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarEquipo(String idUnidad) async {
    try {
      await supabase.from('equipos').delete().eq('id_unidad', idUnidad);
      _showMsg("🗑️ Equipo eliminado correctamente", Colors.orange);
      _cargarEquipos();
    } catch (e) {
      _showMsg("❌ Error al eliminar: Verifica que no tenga auditorías vinculadas", Colors.red);
    }
  }

  void _abrirFormulario({Map<String, dynamic>? equipo}) {
    final isEdit = equipo != null;
    final idController = TextEditingController(text: isEdit ? equipo['id_unidad'] : '');
    final placaController = TextEditingController(text: isEdit ? equipo['placa'] ?? '' : '');
    String? tipoSeleccionado = isEdit ? equipo['tipo'] : _tiposVehiculos.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? "✏️ Modificar Equipo" : "🚛 Agregar Nuevo Equipo"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: idController,
                  enabled: !isEdit, // El ID/Código no se edita si es llave primaria
                  decoration: const InputDecoration(labelText: "Código de Unidad (ID)", border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tipoSeleccionado,
                  decoration: const InputDecoration(labelText: "Tipo de Camión", border: OutlineInputBorder()),
                  items: _tiposVehiculos.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setDialogState(() => tipoSeleccionado = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: placaController,
                  decoration: const InputDecoration(labelText: "Placa", border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A859)),
              onPressed: () async {
              if (idController.text.trim().isEmpty) return;
              
              final datos = {
                'id_unidad': idController.text.trim().toUpperCase(),
                'tipo': tipoSeleccionado,
                'placa': placaController.text.trim().toUpperCase(),
              };

              // 1. 🟢 RESPUESTA AL ERROR: Capturamos las referencias de los contextos ANTES del await
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              try {
                if (isEdit) {
                  await supabase.from('equipos').update(datos).eq('id_unidad', equipo['id_unidad']);
                } else {
                  await supabase.from('equipos').insert(datos);
                }

                // 2. 🟢 Verificamos si el componente principal sigue vivo
                if (!mounted) return;

                // 3. 🟢 Usamos la referencia guardada para cerrar el diálogo sin tocar 'context'
                navigator.pop();
                _cargarEquipos();
                
                // Mostramos el mensaje de éxito de forma segura
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text("✅ Guardado con éxito"), 
                    backgroundColor: Color(0xFF00A859),
                  ),
                );
                
              } catch (e) {
                if (!mounted) return;
                
                // Mostramos el mensaje de error de forma segura
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text("❌ Error al guardar: $e"), 
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
              child: const Text("Guardar", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Catálogo de Equipos / Flota"),
        backgroundColor: const Color(0xFF00A859),
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A859)))
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _equipos.length,
              itemBuilder: (context, i) {
                final eq = _equipos[i];
                return Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping, color: Color(0xFF00A859), size: 36),
                    title: Text("${eq['id_unidad']} - ${eq['tipo']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Placa: ${eq['placa'] ?? 'N/A'}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _abrirFormulario(equipo: eq)),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _mostrarConfirmacionEliminar(eq['id_unidad']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00A859),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _abrirFormulario(),
      ),
    );
  }

  void _mostrarConfirmacionEliminar(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar Unidad?"),
        content: Text("Esta acción eliminará el equipo $id permanentemente del inventario."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _eliminarEquipo(id);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  void _showMsg(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
}