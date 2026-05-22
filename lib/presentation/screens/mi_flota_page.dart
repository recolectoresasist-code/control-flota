import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Instancia global de acceso a Supabase
final supabase = Supabase.instance.client;

class MiFlotaPage extends StatelessWidget {
  const MiFlotaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Flota Cyreco"),
        backgroundColor: const Color(0xFF00A859),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // Escucha en tiempo real los cambios en la tabla 'equipos' de Supabase
        stream: supabase.from('equipos').stream(primaryKey: ['id_unidad']),
        builder: (context, snapshot) {
          // Si hay un error en la conexión o RLS
          if (snapshot.hasError) {
            return Center(child: Text("❌ Error al cargar flota: ${snapshot.error}"));
          }

          // Mientras espera que carguen los datos iniciales
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00A859)));
          }

          final listaEquipos = snapshot.data!;

          // Si la tabla de equipos está completamente vacía
          if (listaEquipos.isEmpty) {
            return const Center(
              child: Text(
                "No hay equipos registrados en la flota todavía.",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
            itemCount: listaEquipos.length,
            itemBuilder: (context, i) {
              final v = listaEquipos[i];
              
              // Mapeo adaptado a las columnas de tu tabla de Supabase
              final String idUnidad = v['id_unidad'] ?? 'S/N';
              final String tipoVehiculo = v['tipo'] ?? 'NO ESPECIFICADO';
              final String placaVehiculo = v['placa'] ?? 'S/P';
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.local_shipping, color: Color(0xFF00A859)),
                  ),
                  title: Text(
                    "Unidad: $idUnidad",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text("Clase: $tipoVehiculo\nPlaca: $placaVehiculo"),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Activo",
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}