import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapaIncidenciasWidget extends StatefulWidget {
  final List<dynamic> incidencias;

  const MapaIncidenciasWidget({super.key, required this.incidencias});

  @override
  State<MapaIncidenciasWidget> createState() => _MapaIncidenciasWidgetState();
}

class _MapaIncidenciasWidgetState extends State<MapaIncidenciasWidget> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(covariant MapaIncidenciasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si los filtros cambiaron la lista, reenfocamos el mapa en el primer punto disponible
    if (widget.incidencias.isNotEmpty && oldWidget.incidencias != widget.incidencias) {
      final primerInc = widget.incidencias.first;
      if (primerInc['latitud'] != null && primerInc['longitud'] != null) {
        _mapController.move(
          LatLng((primerInc['latitud'] as num).toDouble(), (primerInc['longitud'] as num).toDouble()),
          11.0,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Marker> marcadores = [];
    List<CircleMarker> puntosCalor = [];

    for (var inc in widget.incidencias) {
      if (inc['latitud'] != null && inc['longitud'] != null) {
        final punto = LatLng(
          (inc['latitud'] as num).toDouble(), 
          (inc['longitud'] as num).toDouble()
        );

        // 1. Marcador exacto con ícono de ubicación e información detallada
        marcadores.add(
          Marker(
            point: punto,
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(
                        "Información de Siniestro - Folio ${inc['folio'] ?? 'S/N'}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDataInfoLine(Icons.person, "Motorista", inc['motorista']),
                            _buildDataInfoLine(Icons.supervisor_account_outlined, "Supervisor", inc['supervisor']),
                            const Divider(height: 10),
                            _buildDataInfoLine(Icons.local_shipping, "Equipo / Unidad", "${inc['unidad_id']} (${inc['tipo_vehiculo'] ?? 'N/A'})"),
                            const Divider(height: 10),
                            _buildDataInfoLine(Icons.map, "Departamento", inc['departamento']),
                            _buildDataInfoLine(Icons.location_city_outlined, "Municipio", inc['municipio']),
                            _buildDataInfoLine(Icons.location_history_sharp, "Distrito", inc['distrito']),
                            const Divider(height: 20),
                            const Text(
                              "Descripción de lo Ocurrido:",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF00A859)),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              width: double.maxFinite,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                inc['descripcion'] ?? 'Sin descripción detallada registrada.',
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cerrar", style: TextStyle(color: Color(0xFF00A859), fontWeight: FontWeight.bold)),
                        ),
                      ],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 10,
                    );
                  },
                );
              },
              child: const Icon(Icons.location_on, color: Colors.red, size: 35),
            ),
          ),
        );

        // 2. Efecto difuminado para el mapa de calor
        puntosCalor.add(
          CircleMarker(
            point: punto,
            radius: 45, 
            useRadiusInMeter: false,
            color: const Color(0x2BFF0000), // Rojo translúcido
            borderColor: const Color(0x02FF0000),
            borderStrokeWidth: 1,
          ),
        );
      }
    }

    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: LatLng(13.6929, -89.2182), // El Salvador central
        initialZoom: 9.5,
        maxZoom: 18,
        minZoom: 8,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.cyreco.flota_control',
        ),
        CircleLayer(circles: puntosCalor),
        MarkerLayer(markers: marcadores),
      ],
    );
  }

  Widget _buildDataInfoLine(IconData icono, String etiqueta, String? valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.black),
                children: [
                  TextSpan(text: "$etiqueta: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: valor ?? 'N/A', style: const TextStyle(color: Colors.black87)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}