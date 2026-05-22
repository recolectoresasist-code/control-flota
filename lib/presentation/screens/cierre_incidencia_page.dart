import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

final supabase = Supabase.instance.client;

class CierreIncidenciaPage extends StatefulWidget {
  final String folioIncidencia;

  const CierreIncidenciaPage({super.key, required this.folioIncidencia});

  @override
  State<CierreIncidenciaPage> createState() => _CierreIncidenciaPageState();
}

class _CierreIncidenciaPageState extends State<CierreIncidenciaPage> {
  bool _cargandoDatos = true;
  bool _guardando = false;
  Map<String, dynamic>? _datosIncidencia;

  // Controladores de formulario
  final TextEditingController _solucionController = TextEditingController();
  final TextEditingController _costoRealController = TextEditingController();
  final TextEditingController _acuerdoMontoController = TextEditingController();

  // Manejo de la imagen de evidencia
  XFile? _imagenSeleccionada;
  Uint8List? _bytesImagen; 
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _solucionController.dispose();
    _costoRealController.dispose();
    _acuerdoMontoController.dispose();
    super.dispose();
  }

  // --- CARGAR DATOS GENERALES DEL REPORTE ---
  Future<void> _cargarDatosIniciales() async {
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
          // Sugerimos en el formulario el monto_dano si ya se pre-calculó en fases previas
          if (data['monto_dano'] != null) {
            _acuerdoMontoController.text = data['monto_dano'].toString();
          }
        });
      } else {
        _showMsg("❌ No se encontró la incidencia.", Colors.red);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _showMsg("❌ Error al cargar datos: $e", Colors.red);
    }
  }

  // --- SELECCIONAR FOTO DESDE LA CÁMARA O GALERÍA ---
  Future<void> _seleccionarFoto(ImageSource fuente) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: fuente,
        imageQuality: 75,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imagenSeleccionada = image;
          _bytesImagen = bytes;
        });
      }
    } catch (e) {
      _showMsg("❌ Error al seleccionar imagen: $e", Colors.red);
    }
  }

  // --- SUBIR IMAGEN AL STORAGE DE SUPABASE ---
  Future<String?> _subirEvidenciaStorage() async {
    if (_bytesImagen == null || _imagenSeleccionada == null) return null;

    try {
      final fileExt = _imagenSeleccionada!.name.split('.').last;
      final fileName = 'soluciones/${widget.folioIncidencia}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('fotos_incidencias').uploadBinary(
            fileName,
            _bytesImagen!,
            fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
          );

      final String publicUrl = supabase.storage.from('fotos_incidencias').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      _showMsg("❌ Error al subir la foto al Storage: $e", Colors.red);
      return null;
    }
  }

  // --- PROCESAR EL CIERRE FINAL EN BASE DE DATOS Y DISPARAR IMPRESIÓN ---
  Future<void> _procesarCierreIncidencia() async {
    if (_solucionController.text.trim().isEmpty) {
      _showMsg("📋 Por favor, ingresa el dictamen o detalles de los trabajos realizados.", Colors.orange);
      return;
    }
    if (_bytesImagen == null) {
      _showMsg("📸 La fotografía de la evidencia final de cierre es obligatoria.", Colors.orange);
      return;
    }
    if (_acuerdoMontoController.text.trim().isEmpty) {
      _showMsg("💰 Especifica el monto acordado para el finiquito de responsabilidad.", Colors.orange);
      return;
    }

    setState(() => _guardando = true);

    try {
      final urlFoto = await _subirEvidenciaStorage();
      if (urlFoto == null) {
        setState(() => _guardando = false);
        return; 
      }

      // Estructura adaptada 100% a las columnas reales encontradas en tu BD de Supabase
      final estructuraCierre = {
        'estado': 'SOLVENTADO', // Guardamos en mayúsculas coherente con las pestañas del reporte
        'foto_solucion': urlFoto, // Columna real en BD en vez de foto_cierre_url
        'acuerdo_comentario': _solucionController.text.trim(), // Columna real en BD en vez de dictamen_cierre
        'costo_real_reparacion': _costoRealController.text.isNotEmpty ? double.tryParse(_costoRealController.text.trim()) : null,
        'monto_dano': double.tryParse(_acuerdoMontoController.text.trim()) ?? 0.0, // Columna real en BD en vez de acuerdo_monto
        'fecha_cierre': DateTime.now().toIso8601String(),
      };

      await supabase.from('incidencias').update(estructuraCierre).eq('folio', widget.folioIncidencia);

      _showMsg("🔒 Incidencia guardada en base de datos. Abriendo Finiquito...", Colors.green);

      // Creamos un mapa extendido local para mandarlo a la impresora con los datos frescos del formulario
      final datosParaImprimir = Map<String, dynamic>.from(_datosIncidencia!)..addAll(estructuraCierre);
      
      // Lanzamos la impresión del acta de finiquito institucional
      await _generarEImprimirFiniquito(datosParaImprimir);

      if (mounted) Navigator.pop(context, true); 
    } catch (e) {
      _showMsg("❌ Error al guardar el cierre: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // --- MOTOR IMPRESOR DEL ACTA DE FINIQUITO CORPORATIVO ---
  Future<void> _generarEImprimirFiniquito(Map<String, dynamic> datos) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Encabezado Corporativo GRUPO CYRECO
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("GRUPO CYRECO S.A. DE C.V.", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                    pw.Text(" FOLIO CIERRE: ${datos['folio'] ?? 'S/N'}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                  ],
                ),
                pw.Text("Control de Daños y Gestión Operativa de Flota", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 2, color: PdfColors.green900),
                pw.SizedBox(height: 15),

                // Título Oficial del Documento
                pw.Center(
                  child: pw.Text("ACTA DE FINIQUITO Y ACUERDO MUTUO DE CONFORMIDAD", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 20),

                // Declaración de Hechos y Apertura Legal
                pw.Text(
                  "En las instalaciones de control operativo de GRUPO CYRECO, se hace constar de mutuo acuerdo el cierre y solución formal de la incidencia registrada en la bitácora de flota vehicular bajo las siguientes especificaciones técnicas y cláusulas de conformidad recíproca:",
                  style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 1.4),
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 15),

                // Sección I: Detalles de asignación
                pw.Text("I. DATOS DE LA UNIDAD Y PERSONAL OPERATIVO:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.green900)),
                pw.SizedBox(height: 6),
                pw.Bullet(text: "Unidad / Placa de Equipo: ${datos['unidad_id'] ?? 'N/A'} (${datos['tipo_vehiculo'] ?? 'N/A'})"),
                pw.Bullet(text: "Motorista Asignado: ${datos['motorista'] ?? 'N/A'}"),
                pw.Bullet(text: "Supervisor Operativo responsable: ${datos['supervisor'] ?? 'N/A'}"),
                pw.Bullet(text: "Ubicación Geográfica: ${datos['distrito'] ?? 'N/A'}, ${datos['municipio'] ?? 'N/A'}, ${datos['departamento'] ?? 'N/A'}"),
                pw.Bullet(text: "Fecha de Ocurrencia del Siniestro: ${datos['fecha_incidencia'] ?? 'N/A'}"),
                pw.SizedBox(height: 15),

                // Sección II: Diagnóstico y Resolución Económica (Campos adaptados)
                pw.Text("II. TRABAJOS DE REPARACIÓN Y ACUERDO ECONÓMICO:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.green900)),
                pw.SizedBox(height: 6),
                pw.Text("Detalle de Trabajos y Solución en Taller:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey800)),
                pw.Text("${datos['acuerdo_comentario'] ?? 'Sin dictamen registrado'}", style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                pw.SizedBox(height: 8),
                
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Costo Real Evaluado de Reparación: \$${datos['costo_real_reparacion'] ?? '0.00'}", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(" MONTO TOTAL ACORDADO DE FINIQUITO: \$${datos['monto_dano'] ?? '0.00'}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                  ],
                ),
                pw.SizedBox(height: 15),

                // Sección III: Cláusulas de Liberación de Responsabilidad
                pw.Text("III. CLAUSULA DE FINIQUITO Y CIERRE LIBRE DE ACCIÓN:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.green900)),
                pw.SizedBox(height: 6),
                pw.Text(
                  "Ambas partes firman y manifiestan estar plenamente conformes con las reparaciones físicas de la unidad de transporte, el estado técnico operativo devuelto y los términos de amortización o pago pactados en este acto. Por medio de este documento, se extienden recíprocamente el más amplio finiquito que en derecho proceda, declarando la incidencia totalmente SOLVENTADA en los registros de GRUPO CYRECO y comprometiéndose a no entablar reclamos ni acciones administrativas, civiles o laborales en el futuro por este concepto.",
                  style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 1.4),
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 55),

                // Bloque de firmas de validación y respaldo
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Container(width: 160, decoration: const pw.BoxDecoration(
                            border: pw.Border(top: pw.BorderSide(width: 1, color: PdfColors.black))
                        )
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text("Firma del Motorista", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text("DUI: _________________", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(width: 160, decoration: const pw.BoxDecoration(
                            border: pw.Border(top: pw.BorderSide(width: 1, color: PdfColors.black))
                          )
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text("Control de Flota GRUPO CYRECO", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text("Firma y Sello Operativo", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    // Dispara la ventana nativa de impresión
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoDatos) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Cierre de Incidencia: ${widget.folioIncidencia}"),
        backgroundColor: const Color(0xFF00A859),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResumenCabecera(),
            const SizedBox(height: 15),
            _buildSeccionCamara(),
            const SizedBox(height: 15),
            _buildFormularioCierre(),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _guardando ? null : _procesarCierreIncidencia,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A859),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _guardando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("PROCESAR CIERRE Y GENERAR FINIQUITO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildResumenCabecera() => Card(
        color: Colors.grey.shade50,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Camión / Unidad: ${_datosIncidencia?['unidad_id'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("Motorista asignado: ${_datosIncidencia?['motorista'] ?? 'N/A'}"),
              Text("Daño Evaluado Inicial: \$${_datosIncidencia?['monto_dano'] ?? '0.00'} USD"),
              const Divider(),
              Text("Fallo Inicial: ${_datosIncidencia?['descripcion'] ?? 'N/A'}", style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      );

  Widget _buildSeccionCamara() => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Evidencia de Reparación (Foto Final) *", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              const Divider(),
              const SizedBox(height: 5),
              Center(
                child: _bytesImagen == null
                    ? Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                        child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _bytesImagen!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _seleccionarFoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Cámara"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _seleccionarFoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Galería"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                  ),
                ],
              )
            ],
          ),
        ),
      );

  Widget _buildFormularioCierre() => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Información del Taller / Reparación", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              const Divider(),
              const SizedBox(height: 10),
              TextFormField(
                controller: _solucionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Detalle de Trabajos Realizados (Dictamen Final) *",
                  hintText: "Ej: Planchado de compuerta trasera, pintura de bumper y cambio de focos traseros.",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costoRealController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Costo Taller (\$)",
                        prefixIcon: Icon(Icons.build_circle_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: TextFormField(
                      controller: _acuerdoMontoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Monto Acuerdo Finiquito (\$)*",
                        prefixIcon: Icon(Icons.handshake_outlined),
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

  void _showMsg(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
}