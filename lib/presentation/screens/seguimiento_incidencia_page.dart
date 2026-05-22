import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Librería universal para interactuar con la Web sin romper la compilación móvil
import 'package:universal_html/html.dart' as html;

// Instancia global de acceso a Supabase
final supabase = Supabase.instance.client;

class SeguimientoIncidenciaPage extends StatefulWidget {
  final String folioIncidencia; // Recibe el folio del reporte a evaluar

  const SeguimientoIncidenciaPage({super.key, required this.folioIncidencia});

  @override
  State<SeguimientoIncidenciaPage> createState() => _SeguimientoIncidenciaPageState();
}

class _SeguimientoIncidenciaPageState extends State<SeguimientoIncidenciaPage> {
  bool _cargandoDatos = true;
  bool _guardando = false;
  Map<String, dynamic>? _datosIncidencia;

  // Variables de estado administrativas
  String _procedeCobro = "si";
  String _nivelGravedad = "Medio"; // Vinculado a 'nivel_gravedad'

  // Controladores para los campos de texto financieros y acuerdos
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _cuotasController = TextEditingController();
  final TextEditingController _acuerdoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDetallesIncidencia();
  }

  @override
  void dispose() {
    _montoController.dispose();
    _cuotasController.dispose();
    _acuerdoController.dispose();
    super.dispose();
  }

  // --- LEER DATOS DESDE SUPABASE ---
  Future<void> _cargarDetallesIncidencia() async {
    try {
      final data = await supabase
          .from('incidencias')
          .select()
          .eq('folio', widget.folioIncidencia)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _datosIncidencia = data;
          _cargandoDatos = false;
          
          // Mapeo exacto basado en las columnas reales de tu Supabase
          if (data['procede_cobro'] != null) _procedeCobro = data['procede_cobro'];
          if (data['nivel_gravedad'] != null) _nivelGravedad = data['nivel_gravedad'];
          _montoController.text = data['monto_dano']?.toString() ?? '';
          _cuotasController.text = data['cuotas_autorizadas']?.toString() ?? '';
          _acuerdoController.text = data['acuerdo_comentario'] ?? '';
        });
      } else {
        _showMsg("❌ No se encontró el registro con el folio proporcionado.", Colors.red);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _showMsg("❌ Error al cargar datos: $e", Colors.red);
    }
  }

  // --- FUNCIÓN PARA FILTRAR Y VER PENDIENTES ---
  Future<void> _abrirModalPendientes() async {
    // 1. Mostrar modal de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.green)),
    );

    try {
      // 2. Traer la información
      final data = await supabase.from('incidencias').select();

      if (!mounted) return;
      Navigator.pop(context); // Cerrar modal de carga

      // 3. Filtrar en la aplicación (ignora mayúsculas/minúsculas)
      final List<dynamic> pendientes = data.where((incidencia) {
        final estado = incidencia['estado']?.toString().toLowerCase() ?? '';
        return estado == 'pendiente';
      }).toList();

      // 4. Mostrar los resultados
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Incidencias Pendientes", style: TextStyle(color: Colors.green)),
          content: SizedBox(
            width: double.maxFinite,
            child: pendientes.isEmpty
                ? const Text("No hay incidencias en estado Pendiente.")
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: pendientes.length,
                    itemBuilder: (context, index) {
                      final item = pendientes[index];
                      return ListTile(
                        leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        title: Text("Folio: ${item['folio'] ?? 'S/F'}"),
                        subtitle: Text("Unidad: ${item['unidad_id'] ?? 'N/A'} - Motorista: ${item['motorista'] ?? 'N/A'}"),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Cerrar", style: TextStyle(color: Colors.green))
            )
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showMsg("❌ Error al cargar pendientes: $e", Colors.red);
    }
  }

  // --- ACTUALIZAR REGISTRO EN SUPABASE ---
  Future<void> _actualizarSeguimiento() async {
    setState(() => _guardando = true);

    try {
      // Mapeo 100% fiel a tu tabla de Supabase para evitar el error PGRST204
      await supabase.from('incidencias').update({
        'procede_cobro': _procedeCobro,
        'nivel_gravedad': _nivelGravedad,
        'monto_dano': _procedeCobro == "si" && _montoController.text.isNotEmpty 
            ? double.tryParse(_montoController.text.trim()) 
            : null,
        'cuotas_autorizadas': _procedeCobro == "si" && _cuotasController.text.isNotEmpty 
            ? int.tryParse(_cuotasController.text.trim()) 
            : null,
        'acuerdo_comentario': _acuerdoController.text.trim(),
        'estado': 'En Proceso',
      }).eq('folio', widget.folioIncidencia);

      _showMsg("✅ Evaluación administrativa guardada correctamente.", Colors.green);
      
      if (_datosIncidencia != null) {
        _datosIncidencia!['procede_cobro'] = _procedeCobro;
        _datosIncidencia!['nivel_gravedad'] = _nivelGravedad;
        _datosIncidencia!['monto_dano'] = _montoController.text;
        _datosIncidencia!['cuotas_autorizadas'] = _cuotasController.text;
        _datosIncidencia!['acuerdo_comentario'] = _acuerdoController.text;
      }

      // Dispara la descarga e impresión si estás ejecutando en entorno Web
      if (kIsWeb) {
        _descargarEImprimirReporte();
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showMsg("❌ Error al guardar resolución: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // --- FUNCIÓN DE IMPRESIÓN COMPATIBLE CON UNIVERSAL_HTML ---
  void _descargarEImprimirReporte() {
    if (_datosIncidencia == null) return;

    final String folio = _datosIncidencia!['folio'] ?? 'S/F';
    final String motorista = _datosIncidencia!['motorista'] ?? 'N/A';
    final String supervisor = _datosIncidencia!['supervisor'] ?? 'No asignado';
    final String unidad = _datosIncidencia!['unidad_id'] ?? 'N/A';
    final String tipoVehiculo = _datosIncidencia!['tipo_vehiculo'] ?? '';
    final String depto = _datosIncidencia!['departamento'] ?? '';
    final String muni = _datosIncidencia!['municipio'] ?? '';
    final String dist = _datosIncidencia!['distrito'] ?? '';
    
    final String procede = _procedeCobro == "si" ? "Sí, Procede Cobro" : "No Procede";
    final String monto = _procedeCobro == "si" && _montoController.text.isNotEmpty ? _montoController.text : "0.00";
    final String cuotas = _procedeCobro == "si" && _cuotasController.text.isNotEmpty ? _cuotasController.text : "0";
    final String comentarios = _acuerdoController.text.isNotEmpty ? _acuerdoController.text : "Sin observaciones adicionales.";

    final String contenidoHtml = '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Reporte Seguimiento - Folio $folio</title>
      <style>
        body { font-family: 'Arial', sans-serif; margin: 45px; color: #333; line-height: 1.6; }
        .header-container { text-align: center; border-bottom: 3px solid #00A859; padding-bottom: 12px; margin-bottom: 25px; }
        .header-container h1 { margin: 0; color: #00A859; font-size: 24px; letter-spacing: 1px; }
        .header-container p { margin: 5px 0 0 0; font-size: 12px; font-weight: bold; color: #555; }
        .info-box { background-color: #f9f9f9; border: 1px solid #e0e0e0; padding: 15px; margin-bottom: 25px; border-radius: 6px; }
        .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; font-size: 13px; }
        .section-title { font-size: 14px; font-weight: bold; color: #00A859; margin-top: 25px; margin-bottom: 8px; border-bottom: 1px solid #ddd; padding-bottom: 4px; text-transform: uppercase; }
        .data-table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; }
        .data-table th, .data-table td { border: 1px solid #ddd; padding: 10px; text-align: left; }
        .data-table th { background-color: #f4fbf7; font-weight: bold; color: #00A859; width: 35%; }
        .legal-text { font-size: 11.5px; text-align: justify; margin-top: 35px; color: #444; border: 1px dashed #ccc; padding: 12px; background-color: #fafafa; }
        .signature-area { margin-top: 80px; display: flex; justify-content: space-between; }
        .signature-space { width: 30%; text-align: center; border-top: 1px solid #333; padding-top: 6px; font-size: 12px; font-weight: bold; }
      </style>
    </head>
    <body>
      <div class="header-container">
        <h1>GRUPO CYRECO</h1>
        <p>ACTA DE COMPROMISO Y RESOLUCIÓN DE INCIDENCIA</p>
      </div>
      <div class="info-box">
        <div class="info-grid">
          <div><strong>N° FOLIO:</strong> $folio</div>
          <div><strong>ESTADO DEL ACUERDO:</strong> En Proceso</div>
          <div><strong>SUPERVISOR:</strong> $supervisor</div>
          <div><strong>MOTORISTA:</strong> $motorista</div>
          <div><strong>UNIDAD / EQUIPO:</strong> $unidad ($tipoVehiculo)</div>
          <div><strong>UBICACIÓN COLES:</strong> $dist, $muni, $depto</div>
        </div>
      </div>
      <div class="section-title">Detalles de la Evaluación Administrativa</div>
      <table class="data-table">
        <tr>
          <th>¿Procede Cobro Interno?</th>
          <td>$procede</td>
        </tr>
        <tr>
          <th>Nivel de Gravedad / Impacto:</th>
          <td>$_nivelGravedad</td>
        </tr>
        <tr>
          <th>Monto Total Liquidado:</th>
          <td><strong>\$$monto USD</strong></td>
        </tr>
        <tr>
          <th>Plazo de Cuotas Autorizadas:</th>
          <td>$cuotas cuota(s) quincenal(es)</td>
        </tr>
        <tr>
          <th>Comentarios del Acuerdo:</th>
          <td>$comentarios</td>
        </tr>
      </table>
      <div class="legal-text">
        Por medio de la presente acta de mutuo acuerdo, el colaborador/motorista abajo firmante ratifica estar conforme con la valoración técnica del siniestro o desperfecto mecánico imputado a la unidad asignada. De manera voluntaria y consciente, autoriza a la administración de Grupo Cyreco a efectuar las deducciones indicadas en las cuotas descritas en este documento para resarcir los daños materiales presentados.
      </div>
      <div class="signature-area">
        <div class="signature-space">Firma del Motorista<br>DUI: ________________</div>
        <div class="signature-space">Firma de Supervisor<br>Control Operativo</div>
        <div class="signature-space">Por Grupo Cyreco<br>Autorización Administrativa</div>
      </div>
      <script>
        window.onload = function() {
          window.print();
          setTimeout(function() { window.close(); }, 500);
        }
      </script>
    </body>
    </html>
    ''';

    final blob = html.Blob([contenidoHtml], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoDatos) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    final Map<String, dynamic> fotosGuardadas = _datosIncidencia?['fotos'] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text("Seguimiento: ${widget.folioIncidencia}"),
        backgroundColor: const Color(0xFF00A859),
        foregroundColor: Colors.white,
        actions: [
          // BOTÓN DE FILTRO AGREGADO AQUÍ
          IconButton(
            icon: const Icon(Icons.filter_list_alt),
            tooltip: 'Ver Pendientes',
            onPressed: _abrirModalPendientes,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResumenIncidencia(),
            const SizedBox(height: 15),
            _buildGaleriaFotos(fotosGuardadas),
            const SizedBox(height: 15),
            _buildFormularioEvaluacion(),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _guardando ? null : _actualizarSeguimiento,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A859),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _guardando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("GUARDAR EVALUACIÓN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildResumenIncidencia() => Card(
        color: Colors.grey.shade50,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Datos del Reporte", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              const Divider(),
              Text("🏆 Motorista: ${_datosIncidencia?['motorista'] ?? 'N/A'}"),
              Text("📋 Supervisor: ${_datosIncidencia?['supervisor'] ?? 'No asignado'}"),
              Text("🚒 Unidad: ${_datosIncidencia?['unidad_id'] ?? 'N/A'} (${_datosIncidencia?['tipo_vehiculo'] ?? 'N/A'})"),
              Text("📍 Ubicación: ${_datosIncidencia?['distrito'] ?? 'N/A'}, ${_datosIncidencia?['municipio'] ?? 'N/A'}"),
              Text("📝 Descripción: ${_datosIncidencia?['descripcion'] ?? 'Sin descripción.'}"),
            ],
          ),
        ),
      );

  Widget _buildGaleriaFotos(Map<String, dynamic> fotos) {
    if (fotos.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Evidencias Fotográficas", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const Divider(),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: fotos.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.network(entry.value.toString(), width: 100, fit: BoxFit.cover),
                          ),
                        ),
                        Text(entry.key, style: const TextStyle(fontSize: 10))
                      ],
                    ),
                  );
                }).toList(),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFormularioEvaluacion() => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Resolución Administrativa", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              const Divider(),
              
              const Text("¿Procede Cobro Externo/Interno?", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              DropdownButtonFormField<String>(
                initialValue: _procedeCobro,
                items: const [
                  DropdownMenuItem(value: "si", child: Text("Sí, Procede")),
                  DropdownMenuItem(value: "no", child: Text("No Procede")),
                ],
                onChanged: (v) => setState(() => _procedeCobro = v ?? "si"),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),

              const Text("Nivel de Gravedad / Impacto", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              DropdownButtonFormField<String>(
                initialValue: _nivelGravedad,
                items: const [
                  DropdownMenuItem(value: "Bajo", child: Text("Bajo (Raspones/Leve)")),
                  DropdownMenuItem(value: "Medio", child: Text("Medio (Daño Estructural)")),
                  DropdownMenuItem(value: "Alto", child: Text("Alto (Pérdida/Colisión)")),
                ],
                onChanged: (v) => setState(() => _nivelGravedad = v ?? "Medio"),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),

              if (_procedeCobro == "si") ...[
                TextFormField(
                  controller: _montoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: "Monto del Daño (\$)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cuotasController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Cuotas de Descuento Autorizadas", border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_month)),
                ),
                const SizedBox(height: 12),
              ],

              TextFormField(
                controller: _acuerdoController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Comentarios del Acuerdo / Resolución", border: OutlineInputBorder(), alignLabelWithHint: true),
              ),
            ],
          ),
        ),
      );

  void _showMsg(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
}