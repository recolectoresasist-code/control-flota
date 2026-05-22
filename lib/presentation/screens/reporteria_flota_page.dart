import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cyreco_flota_control/presentation/widgets/mapa_incidencias_widget.dart'; 

final supabase = Supabase.instance.client;

class ReporteriaFlotaPage extends StatefulWidget {
  const ReporteriaFlotaPage({super.key});

  @override
  State<ReporteriaFlotaPage> createState() => _ReporteriaFlotaPageState();
}

class _ReporteriaFlotaPageState extends State<ReporteriaFlotaPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _cargando = false;

  // Colecciones de Datos Analíticos
  List<dynamic> _historialAuditorias = [];
  List<dynamic> _historialIncidenciasRaw = []; 
  List<dynamic> _historialIncidenciasFiltradas = []; 
  
  List<Map<String, dynamic>> _topEquiposIncidencias = [];
  List<Map<String, dynamic>> _topMotoristasIncidencias = [];

  // Estados de los Filtros Unificados
  String _deptoSeleccionado = 'Todos';
  String _municipioSeleccionado = 'Todos';
  String _distritoSeleccionado = 'Todos';
  String _equipoSeleccionado = 'Todos';
  DateTimeRange? _rangoFechas;

  // Listas Únicas para los Comboboxes Dinámicamente
  List<String> _listaDeptos = ['Todos'];
  List<String> _listaMunicipios = ['Todos'];
  List<String> _listaDistritos = ['Todos'];
  List<String> _listaEquipos = ['Todos'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarTodaLaReporteria();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- CARGA DE DATOS DESDE SUPABASE ---
  Future<void> _cargarTodaLaReporteria() async {
    setState(() => _cargando = true);
    try {
      final List<dynamic> auds = await supabase
          .from('estado_equipos')
          .select('*')
          .order('created_at', ascending: false);

      final List<dynamic> incs = await supabase
          .from('incidencias')
          .select('*')
          .order('folio', ascending: false);

      setState(() {
        _historialAuditorias = auds;
        _historialIncidenciasRaw = incs;
        _historialIncidenciasFiltradas = incs; 
        
        _generarListasDeFiltros(incs);
        _procesarMetricasTop(incs);
      });
    } catch (e) {
      debugPrint("Error extrayendo reportes analíticos: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _generarListasDeFiltros(List<dynamic> datos) {
    Set<String> deptos = {};
    Set<String> munis = {};
    Set<String> distritos = {};
    Set<String> equipos = {};

    for (var inc in datos) {
      if (inc['departamento'] != null) deptos.add(inc['departamento'].toString());
      if (inc['municipio'] != null) munis.add(inc['municipio'].toString());
      if (inc['distrito'] != null) distritos.add(inc['distrito'].toString());
      if (inc['unidad_id'] != null) equipos.add(inc['unidad_id'].toString());
    }

    _listaDeptos = ['Todos', ...deptos];
    _listaMunicipios = ['Todos', ...munis];
    _listaDistritos = ['Todos', ...distritos];
    _listaEquipos = ['Todos', ...equipos];
  }

  // --- APLICACIÓN DE FILTROS EN TIEMPO REAL ---
  void _aplicarFiltros() {
    setState(() {
      _historialIncidenciasFiltradas = _historialIncidenciasRaw.where((inc) {
        final cumpleDepto = _deptoSeleccionado == 'Todos' || inc['departamento'] == _deptoSeleccionado;
        final cumpleMuni = _municipioSeleccionado == 'Todos' || inc['municipio'] == _municipioSeleccionado;
        final cumpleDistrito = _distritoSeleccionado == 'Todos' || inc['distrito'] == _distritoSeleccionado;
        final cumpleEquipo = _equipoSeleccionado == 'Todos' || inc['unidad_id'].toString() == _equipoSeleccionado;
        
        bool cumpleFecha = true;
        if (_rangoFechas != null && inc['fecha_incidencia'] != null) {
          final fechaInc = DateTime.tryParse(inc['fecha_incidencia'].toString());
          if (fechaInc != null) {
            cumpleFecha = fechaInc.isAfter(_rangoFechas!.start.subtract(const Duration(days: 1))) && 
                          fechaInc.isBefore(_rangoFechas!.end.add(const Duration(days: 1)));
          }
        }
        return cumpleDepto && cumpleMuni && cumpleDistrito && cumpleEquipo && cumpleFecha;
      }).toList();
      
      _procesarMetricasTop(_historialIncidenciasFiltradas);
    });
  }

  void _procesarMetricasTop(List<dynamic> datos) {
    Map<String, int> conteoEquipos = {};
    Map<String, int> conteoMotoristas = {};

    for (var inc in datos) {
      String equipo = inc['unidad_id']?.toString() ?? 'DESCONOCIDO';
      String motorista = inc['motorista']?.toString() ?? 'SIN ASIGNAR';

      conteoEquipos[equipo] = (conteoEquipos[equipo] ?? 0) + 1;
      conteoMotoristas[motorista] = (conteoMotoristas[motorista] ?? 0) + 1;
    }

    var listEq = conteoEquipos.entries.map((e) => {'id': e.key, 'total': e.value}).toList();
    listEq.sort((a, b) => (b['total'] as num).compareTo(a['total'] as num));

    var listMot = conteoMotoristas.entries.map((e) => {'nombre': e.key, 'total': e.value}).toList();
    listMot.sort((a, b) => (b['total'] as num).compareTo(a['total'] as num));

    _topEquiposIncidencias = listEq.take(5).toList();
    _topMotoristasIncidencias = listMot.take(5).toList();
  }

  // --- BARRA UNIFICADA DE FILTROS ---
  Widget _buildBarraFiltrosUnificada() {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildFiltroDropdown("Departamento", _deptoSeleccionado, _listaDeptos, (val) {
              _deptoSeleccionado = val!;
              _aplicarFiltros();
            }),
            _buildFiltroDropdown("Municipio", _municipioSeleccionado, _listaMunicipios, (val) {
              _municipioSeleccionado = val!;
              _aplicarFiltros();
            }),
            _buildFiltroDropdown("Distrito", _distritoSeleccionado, _listaDistritos, (val) {
              _distritoSeleccionado = val!;
              _aplicarFiltros();
            }),
            _buildFiltroDropdown("Equipo", _equipoSeleccionado, _listaEquipos, (val) {
              _equipoSeleccionado = val!;
              _aplicarFiltros();
            }),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range, color: Color(0xFF00A859)),
              label: Text(
                _rangoFechas == null 
                  ? "Filtrar por Fecha" 
                  : "${_rangoFechas!.start.day}/${_rangoFechas!.start.month} - ${_rangoFechas!.end.day}/${_rangoFechas!.end.month}",
                style: const TextStyle(color: Colors.black87, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey)),
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(primary: Color(0xFF00A859)),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  _rangoFechas = picked;
                  _aplicarFiltros();
                }
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.clear_all, color: Colors.red),
              label: const Text("Limpiar", style: TextStyle(color: Colors.red)),
              onPressed: () {
                setState(() {
                  _deptoSeleccionado = 'Todos';
                  _municipioSeleccionado = 'Todos';
                  _distritoSeleccionado = 'Todos';
                  _equipoSeleccionado = 'Todos';
                  _rangoFechas = null;
                  _historialIncidenciasFiltradas = List.from(_historialIncidenciasRaw);
                  _procesarMetricasTop(_historialIncidenciasFiltradas);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroDropdown(String label, String valor, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(valor) ? valor : 'Todos',
              isDense: true,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel de Control y Analítica Cyreco"),
        backgroundColor: const Color(0xFF00A859),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart), text: "Estadísticas"),
            Tab(icon: Icon(Icons.playlist_add_check), text: "Auditorías Físicas"),
            Tab(icon: Icon(Icons.report_problem_outlined), text: "Historial Incidencias"),
            Tab(icon: Icon(Icons.map_outlined), text: "Mapa Geo-Siniestros"),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A859)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGraficosView(),
                _buildAuditoriasListView(),
                _buildIncidenciasListView(),
                _buildMapaGeoView(),
              ],
            ),
    );
  }

  // --- VISTA 1: ESTADÍSTICAS ---
  Widget _buildGraficosView() {
    if (_historialIncidenciasFiltradas.isEmpty) {
      return const Center(child: Text("No hay suficientes datos registrados para trazar gráficos métricos."));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Ranking: Unidades con Más Incidencias", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(height: 200, child: _buildBarChart(_topEquiposIncidencias, isEquipo: true)),
          const SizedBox(height: 30),
          const Text("Ranking: Conductores con Más Siniestros", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildDriversRankingList(),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> datos, {required bool isEquipo}) {
    if (datos.isEmpty) return const SizedBox();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (datos.first['total'] as int).toDouble() + 2,
        barGroups: datos.asMap().entries.map((entry) {
          int index = entry.key;
          var item = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (item['total'] as int).toDouble(),
                color: isEquipo ? const Color(0xFF00A859) : Colors.redAccent,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              )
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                int index = value.toInt();
                if (index >= 0 && index < datos.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      isEquipo ? datos[index]['id'].toString() : datos[index]['nombre'].toString().split(' ').first,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriversRankingList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _topMotoristasIncidencias.length,
      itemBuilder: (context, idx) {
        final mot = _topMotoristasIncidencias[idx];
        return Card(
          color: idx == 0 ? Colors.red.shade50 : Colors.white,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: idx == 0 ? Colors.red : const Color(0xFF00A859),
              foregroundColor: Colors.white,
              child: Text("${idx + 1}"),
            ),
            title: Text(mot['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(15)),
              child: Text("${mot['total']} Incidentes", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        );
      },
    );
  }

  // --- VISTA 2: AUDITORÍAS FÍSICAS ---
  Widget _buildAuditoriasListView() {
    if (_historialAuditorias.isEmpty) return const Center(child: Text("Sin registros de auditorías físicas de flota."));
    return ListView.builder(
      itemCount: _historialAuditorias.length,
      itemBuilder: (context, i) {
        final aud = _historialAuditorias[i];
        final bool tieneDanos = aud['estado'] == 'CON DAÑOS';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Icon(Icons.check_circle_outline, color: tieneDanos ? Colors.red : const Color(0xFF00A859)),
            title: Text("Unidad: ${aud['id_equipo'] ?? 'Desconocido'}", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Clasificación: ${aud['tipo_equipo'] ?? 'N/A'}\nEstado evaluado: ${aud['estado']}"),
          ),
        );
      },
    );
  }

  // --- VISTA 3: HISTORIAL SEGMENTADO POR ESTADOS ---
  Widget _buildIncidenciasListView() {
    final pendientes = _historialIncidenciasFiltradas.where((inc) => inc['estado']?.toString().toUpperCase() == 'PENDIENTE').toList();
    final enProceso = _historialIncidenciasFiltradas.where((inc) => inc['estado']?.toString().toUpperCase() == 'EN PROCESO').toList();
    final solventados = _historialIncidenciasFiltradas.where((inc) => inc['estado']?.toString().toUpperCase() == 'SOLVENTADO').toList();

    return Column(
      children: [
        _buildBarraFiltrosUnificada(), 
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  color: Colors.grey.shade100,
                  child: TabBar(
                    labelColor: const Color(0xFF00A859),
                    unselectedLabelColor: Colors.black54,
                    indicatorColor: const Color(0xFF00A859),
                    indicatorWeight: 3,
                    tabs: [
                      Tab(text: "Pendientes (${pendientes.length})"),
                      Tab(text: "En Proceso (${enProceso.length})"),
                      Tab(text: "Solventados (${solventados.length})"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildListaPorEstado(pendientes, Colors.orange),
                      _buildListaPorEstado(enProceso, Colors.blue),
                      _buildListaPorEstado(solventados, const Color(0xFF00A859)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListaPorEstado(List<dynamic> lista, Color colorEstado) {
    if (lista.isEmpty) {
      return const Center(
        child: Text(
          "No hay incidencias en este estado con los filtros aplicados.",
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }

    return ListView.builder(
      itemCount: lista.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, i) {
        final inc = lista[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 2,
          child: ListTile(
            onTap: () => _mostrarDetalleTrazabilidad(inc), 
            isThreeLine: true,
            leading: Icon(Icons.receipt_long, color: colorEstado, size: 35),
            title: Text(
              "Folio: ${inc['folio'] ?? 'S/N'}", 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)
            ),
            subtitle: Text(
              "🚚 Unidad: ${inc['unidad_id']} | 👤 Motorista: ${inc['motorista']}\n"
              "📍 ${inc['municipio'] ?? 'N/A'}, ${inc['distrito'] ?? 'N/A'}\n"
              "📅 ${inc['fecha_incidencia'] ?? 'N/A'}"
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ),
        );
      },
    );
  }

  // --- MODAL DE DETALLE COMPLETO (TRAZABILIDAD 1 -> 2 -> 3) ---
  void _mostrarDetalleTrazabilidad(dynamic inc) {
    final String estadoActual = (inc['estado'] ?? 'PENDIENTE').toString().toUpperCase();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(20),
            // SOLUCIÓN LÍNEA 499: Usamos constraints para definir el maxHeight correctamente en el Container
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  // SOLUCIÓN LÍNEA 505: Se cambió de 'between' a 'spaceBetween'
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "TRAZABILIDAD COMPLETA - FOLIO ${inc['folio'] ?? 'S/N'}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                        Text("Estado actual: $estadoActual", style: TextStyle(color: _getColorEstado(inc['estado']), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const Divider(height: 20, thickness: 1.2),
                
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // ETAPA 1: REGISTRO DEL SINIESTRO
                        _buildEtapaTimeline(
                          titulo: "1. Registro Inicial del Siniestro",
                          fecha: inc['fecha_incidencia'],
                          colorEtapa: Colors.orange,
                          completada: true,
                          contenido: [
                            _buildInfoText("Motorista", inc['motorista']),
                            _buildInfoText("Supervisor", inc['supervisor']),
                            _buildInfoText("Equipo / Unidad", inc['unidad_id']),
                            _buildInfoText("Tipo Vehículo", inc['tipo_vehiculo']),
                            _buildInfoText("Ubicación", "${inc['distrito'] ?? 'N/A'}, ${inc['municipio'] ?? 'N/A'}"),
                            _buildInfoText("Fallo/Daño reportado", inc['descripcion']),
                          ],
                          urlFoto: inc['fotos'], 
                        ),

                        // ETAPA 2: GESTIÓN EN TALLER / PROCESO (Sin evidencia fotográfica)
                        _buildEtapaTimeline(
                          titulo: "2. Gestión en Proceso (Reparaciones / Talleres)",
                          fecha: inc['fecha_proceso'], 
                          colorEtapa: Colors.blue,
                          completada: estadoActual == 'EN PROCESO' || estadoActual == 'SOLVENTADO',
                          ocultarFoto: true, // Campo deshabilitado
                          contenido: [
                            _buildInfoText("Taller encargado", inc['taller_nombre'] ?? 'N/A'),
                            _buildInfoText("Avance o comentarios técnico", inc['comentarios_proceso'] ?? 'Sin comentarios registrados aún.'),
                          ],
                        ),

                        // ETAPA 3: SOLVENTADO / CIERRE (foto_solucion)
                        _buildEtapaTimeline(
                          titulo: "3. Cierre de Caso y Acuerdos Mutuos",
                          fecha: inc['fecha_cierre'], 
                          colorEtapa: const Color(0xFF00A859),
                          completada: estadoActual == 'SOLVENTADO',
                          isLast: true,
                          contenido: [
                            _buildInfoText("Dictamen Técnico Final", inc['dictamen_cierre'] ?? 'Sin dictamen final registrado.'),
                            _buildInfoText("Costo Real de Reparación", inc['costo_real_reparacion'] != null ? "\$${inc['costo_real_reparacion']}" : 'N/A'),
                            _buildInfoText("Monto Acuerdo Finiquito", inc['acuerdo_monto'] != null ? "\$${inc['acuerdo_monto']}" : 'N/A'),
                          ],
                          urlFoto: inc['foto_solucion'], // Campo corregido
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

 Widget _buildEtapaTimeline({
  required String titulo,
  dynamic fecha,
  required Color colorEtapa,
  required bool completada,
  required List<Widget> contenido,
  dynamic urlFoto, // Cambiado a dynamic para aceptar Map o String
  bool isLast = false,
  bool ocultarFoto = false,
}) {
  return Opacity(
    opacity: completada ? 1.0 : 0.45,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: completada ? colorEtapa : Colors.grey,
                shape: BoxShape.circle,
              ),
              child: Icon(
                completada ? Icons.check : Icons.lock_clock,
                size: 14,
                color: Colors.white,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 120, // Altura ajustada para dar espacio al contenido
                color: completada ? colorEtapa : Colors.grey.shade300,
              ),
          ],
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: completada ? colorEtapa.withValues(alpha: 0.3) : Colors.grey.shade200
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: completada ? colorEtapa : Colors.black54
                        ),
                      ),
                    ),
                    Text(
                      fecha?.toString() ?? 'Pendiente',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...contenido,
                
                if (!ocultarFoto) ...[
                  const SizedBox(height: 10),
                  const Text(
                    "Evidencia Fotográfica:",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)
                  ),
                  const SizedBox(height: 6),
                  
                  // LÓGICA DE RENDERIZADO SEGÚN EL TIPO DE DATO
                  Builder(builder: (context) {
                    // Si urlFoto es un Mapa (JSON de Supabase), renderizamos la primera imagen o un carrusel
                    if (urlFoto is Map) {
                      final fotos = Map<String, dynamic>.from(urlFoto);
                      if (fotos.isEmpty) return _buildPlaceholderNoImage("Sin imágenes");
                      
                      // Mostramos la primera disponible (o podrías hacer un ListView horizontal)
                      final primeraUrl = fotos.values.first.toString();
                      return _renderImagen(primeraUrl);
                    } 
                    // Si urlFoto es un String simple
                    else if (urlFoto != null && urlFoto.toString().isNotEmpty) {
                      return _renderImagen(urlFoto.toString());
                    }
                    
                    // Si no hay nada
                    return _buildPlaceholderNoImage(completada ? "No se adjuntó foto" : "Fase no completada");
                  }),
                ],
              ],
            ),
          ),
        )
      ],
    ),
  );
}

// Widget auxiliar para no repetir código de renderizado de imagen
Widget _renderImagen(String url) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: Image.network(
      url,
      height: 110,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholderNoImage("Error al cargar la imagen");
      },
    ),
  );
}

  Widget _buildPlaceholderNoImage(String texto) {
    return Container(
      height: 90,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24),
          const SizedBox(height: 4),
          Text(texto, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInfoText(String etiqueta, dynamic valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          children: [
            TextSpan(text: "$etiqueta: ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: valor?.toString() ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  // --- VISTA 4: MAPA GEO-SINIESTROS ---
  Widget _buildMapaGeoView() {
    return Column(
      children: [
        _buildBarraFiltrosUnificada(),
        Expanded(
          child: _historialIncidenciasFiltradas.isEmpty
              ? const Center(child: Text("No hay siniestros que coincidan con los filtros seleccionados."))
              : MapaIncidenciasWidget(incidencias: _historialIncidenciasFiltradas),
        ),
      ],
    );
  }

  Color _getColorEstado(String? estado) {
    switch (estado?.toUpperCase()) {
      case 'PENDIENTE': return Colors.orange;
      case 'EN PROCESO': return Colors.blue;
      case 'SOLVENTADO': return const Color(0xFF00A859);
      default: return Colors.grey;
    }
  }
}