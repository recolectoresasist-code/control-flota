import 'dart:io';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

// Instancia global de acceso a Supabase
final supabase = Supabase.instance.client;

class LevantamientoEquipoPage extends StatefulWidget {
  const LevantamientoEquipoPage({super.key});

  @override
  State<LevantamientoEquipoPage> createState() => _LevantamientoEquipoPageState();
}

class _LevantamientoEquipoPageState extends State<LevantamientoEquipoPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  String? _tipoVehiculoSel, _unidadSeleccionada;
  bool _guardando = false;
  bool _cargandoUnidades = false;

  final List<String> _tiposVehiculos = ['COMPACTADOR', 'LIVIANO', 'VOLQUETA', 'CABEZALES', 'GONDOLAS', 'GRUA', 'BIOINFECCIOSO'];
  List<String> _unidadesDisponibles = [];

  // Mapas para almacenar fotos y sus respectivos detalles de daños
  final Map<String, XFile?> _fotos = {
    'Frontal': null,
    'Trasera': null,
    'Lateral Izquierdo': null,
    'Lateral Derecho': null,
  };

  final Map<String, TextEditingController> _detallesControllers = {
    'Frontal': TextEditingController(),
    'Trasera': TextEditingController(),
    'Lateral Izquierdo': TextEditingController(),
    'Lateral Derecho': TextEditingController(),
  };

  @override
  void dispose() {
    _detallesControllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  // --- CONSULTA ASÍNCRONA DE UNIDADES EN SUPABASE ---
  Future<void> _cargarUnidadesPorTipo(String tipo) async {
    setState(() {
      _cargandoUnidades = true;
      _unidadesDisponibles = [];
      _unidadSeleccionada = null;
    });

    try {
      final List<dynamic> response = await supabase
          .from('equipos')
          .select('id_unidad')
          .eq('tipo', tipo);

      setState(() {
        _unidadesDisponibles = response.map((e) => e['id_unidad'].toString()).toList();
        _unidadesDisponibles.sort();
      });
    } catch (e) {
      _showMsg("Error al obtener unidades: $e", Colors.red);
    } finally {
      setState(() => _cargandoUnidades = false);
    }
  }

  Future<void> _tomarFoto(String lado) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (photo != null) setState(() => _fotos[lado] = photo);
  }

  // --- GUARDAR REPORTE DE INSPECCIÓN ---
  Future<void> _guardarLevantamiento() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    final idLevantamiento = "LEV-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}";

    try {
      // Inserción directa en la nueva tabla 'levantamientos_flota'
      await supabase.from('levantamientos_flota').insert({
        'folio': idLevantamiento,
        'tipo_vehiculo': _tipoVehiculoSel,
        'unidad_id': _unidadSeleccionada,
        'inspeccion': {
          'frontal': _detallesControllers['Frontal']!.text.trim(),
          'trasera': _detallesControllers['Trasera']!.text.trim(),
          'lat_izquierdo': _detallesControllers['Lateral Izquierdo']!.text.trim(),
          'lat_derecho': _detallesControllers['Lateral Derecho']!.text.trim(),
        },
        'estado': 'COMPLETADO'
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Inspección guardada con éxito en Supabase"), backgroundColor: Colors.green)
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _showMsg("❌ Error al guardar levantamiento: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inspección Técnica de Flota"),
        backgroundColor: const Color(0xFF00A859),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderInfo(),
              const SizedBox(height: 20),
              const Text("REGISTRO DE ESTADO FÍSICO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
              const Divider(),
              
              ...['Frontal', 'Trasera', 'Lateral Izquierdo', 'Lateral Derecho'].map((lado) => _buildSeccionInspeccion(lado)),

              const SizedBox(height: 30),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _tipoVehiculoSel,
              decoration: const InputDecoration(labelText: "Tipo de Equipo", border: OutlineInputBorder()),
              items: _tiposVehiculos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _tipoVehiculoSel = v);
                  _cargarUnidadesPorTipo(v);
                }
              },
              validator: (v) => v == null ? "Seleccione tipo de equipo" : null,
            ),
            const SizedBox(height: 12),
            _buildUnidadSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildUnidadSelector() {
    if (_tipoVehiculoSel == null) return const SizedBox.shrink();
    if (_cargandoUnidades) return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator(color: Colors.green)));

    return DropdownButtonFormField<String>(
      initialValue: _unidadSeleccionada,
      decoration: const InputDecoration(labelText: "ID de Unidad (Nomenclatura)", border: OutlineInputBorder()),
      items: _unidadesDisponibles.map((id) => DropdownMenuItem(value: id, child: Text(id))).toList(),
      onChanged: (v) => setState(() => _unidadSeleccionada = v),
      validator: (v) => v == null ? "Seleccione unidad" : null,
    );
  }

  Widget _buildSeccionInspeccion(String lado) {
    XFile? img = _fotos[lado];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Vista $lado", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _tomarFoto(lado),
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(border: Border.all(color: img == null ? Colors.grey : Colors.green), borderRadius: BorderRadius.circular(8)),
                    child: img == null 
                      ? const Icon(Icons.camera_enhance, color: Colors.grey)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(7), 
                          child: kIsWeb ? Image.network(img.path, fit: BoxFit.cover) : Image.file(File(img.path), fit: BoxFit.cover)
                        ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextFormField(
                    controller: _detallesControllers[lado],
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Detalle de daños",
                      hintText: "Ej: Rayón profundo, golpe en tolva...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() => SizedBox(
    width: double.infinity, height: 50,
    child: ElevatedButton(
      onPressed: _guardando ? null : _guardarLevantamiento,
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A859)),
      child: _guardando 
        ? const CircularProgressIndicator(color: Colors.white) 
        : const Text("FINALIZAR REGISTRO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ),
  );

  void _showMsg(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
}