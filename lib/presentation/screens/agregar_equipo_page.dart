import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Instancia global de acceso a tu base de datos Supabase
final supabase = Supabase.instance.client;

class AgregarEquipoPage extends StatefulWidget {
  const AgregarEquipoPage({super.key});

  @override
  State<AgregarEquipoPage> createState() => _AgregarEquipoPageState();
}

class _AgregarEquipoPageState extends State<AgregarEquipoPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Variables para capturar los datos del formulario
  String nomenclatura = '';
  String placa = '';
  String tipo = 'COMPACTADOR';
  bool _guardando = false;

  // Lista de tipos de camión según tu catálogo logístico
  final List<String> _tiposCamion = [
    'COMPACTADOR',
    'VOLQUETA',
    'LIVIANO',
    'CABEZALES',
    'GONDOLAS',
    'GRUA',
    'BIOINFECCIOSO'
  ];

  Future<void> _guardarEquipo() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _guardando = true);

    try {
      // Inserción limpia en PostgreSQL de Supabase en lugar de Firebase Collection
      await supabase.from('equipos').insert({
        'id_unidad': nomenclatura.trim().toUpperCase(), // Tu identificador único (Ej: RECO-FL-14)
        'placa': placa.trim().toUpperCase(),
        'tipo': tipo,
        // 'fecha_registro' se genera en Supabase automáticamente con now() si lo configuraste así
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Equipo registrado con éxito en Supabase"),
            backgroundColor: Colors.green,
          ),
        );
        _formKey.currentState!.reset();
        setState(() {
          tipo = 'COMPACTADOR';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error al guardar en Supabase: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Agregar Nuevo Equipo"),
        backgroundColor: const Color(0xFF00A859),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Registro de Unidades Vehiculares",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const Divider(),
              const SizedBox(height: 10),

              // Campo Nomenclatura / ID Unidad
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Nomenclatura (ID de Unidad)',
                  hintText: 'Ej: RECO-FL-14',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_shipping),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Requerido' : null,
                onSaved: (value) => nomenclatura = value ?? '',
              ),
              const SizedBox(height: 15),

              // Campo Placa
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Número de Placa',
                  hintText: 'Ej: P123-456',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Requerido' : null,
                onSaved: (value) => placa = value ?? '',
              ),
              const SizedBox(height: 15),

              // Dropdown Tipo de Camión
              DropdownButtonFormField<String>(
                initialValue: tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Vehículo',
                  border: OutlineInputBorder(),
                ),
                items: _tiposCamion.map((String t) {
                  return DropdownMenuItem<String>(
                    value: t,
                    child: Text(t),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    tipo = value ?? 'COMPACTADOR';
                  });
                },
              ),
              const SizedBox(height: 30),

              // Botón Guardar con indicador de carga
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardarEquipo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A859),
                  ),
                  child: _guardando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "GUARDAR EQUIPO",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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