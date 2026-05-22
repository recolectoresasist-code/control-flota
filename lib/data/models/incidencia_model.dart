class Incidencia {
  final String id; // El folio generado
  final String unidadId;
  final String motorista;
  final String estado; // 'Abierta', 'En Proceso', 'Cerrada'
  final String descripcion;

  Incidencia({required this.id, required this.unidadId, required this.motorista, required this.estado, required this.descripcion});
}