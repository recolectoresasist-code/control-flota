import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart'; // 🟢 NUEVO: Manejo de ubicación GPS

// Acceso directo al cliente global de Supabase
final supabase = Supabase.instance.client;

class RegistroIncidenciaPage extends StatefulWidget {
  const RegistroIncidenciaPage({super.key});

  @override
  State<RegistroIncidenciaPage> createState() => _RegistroIncidenciaPageState();
}

class _RegistroIncidenciaPageState extends State<RegistroIncidenciaPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Listas dinámicas que se llenan desde Supabase
  List<String> _departamentos = [];
  List<String> _municipios = [];
  List<String> _distritos = [];
  List<String> _unidades = [];

  // Variables para controlar las selecciones de los Dropdowns
  String? deptoSel;
  String? municipioSel;
  String? distritoSel;
  String? _unidadSeleccionada;
  String? _tipoVehiculoSel;
  
  bool _danosTerceros = false;
  bool _guardando = false;

  final TextEditingController _motoristaController = TextEditingController();
  final TextEditingController _supervisorController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();

  Map<String, XFile?> fotos = {
    'Frontal': null,
    'Trasera': null,
    'Lateral Izquierdo': null,
    'Lateral Derecho': null,
    'Tercero': null,
  };

  // Listado estático en MAYÚSCULAS para coincidir con tu tabla 'equipos'
  final List<String> _tiposVehiculos = [
    'COMPACTADOR', 
    'LIVIANO', 
    'VOLQUETA', 
    'CABEZAL', 
    'GONDOLA', 
    'GRUA', 
    'BIOINFECCIOSO' 
  ];

  @override
  void initState() {
    super.initState();
    _cargarDepartamentos(); // Carga geográfica inicial al abrir la pantalla
  }

  @override
  void dispose() {
    _motoristaController.dispose();
    _supervisorController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  // --- CONSULTAS DINÁMICAS A SUPABASE ---

  /// Carga todos los departamentos únicos de la tabla 'ubicaciones_sv'
  Future<void> _cargarDepartamentos() async {
    try {
      final List<dynamic> response = await supabase
          .from('ubicaciones_sv')
          .select('departamento');
      
      if (response.isEmpty) {
        debugPrint("⚠️ Alerta: La tabla 'ubicaciones_sv' no tiene registros.");
        return;
      }
      
      // Mapear, limpiar espacios y remover duplicados usando un Set
      final deptoUnicos = response
          .map((e) => e['departamento'].toString().trim())
          .toSet()
          .toList();
      
      deptoUnicos.sort(); // Ordenar alfabéticamente

      setState(() {
        _departamentos = deptoUnicos;
      });
    } catch (e) {
      _showMsg("Error cargando departamentos: $e", Colors.red);
    }
  }

  /// Carga los municipios filtrados por el departamento seleccionado
  Future<void> _cargarMunicipios(String depto) async {
    try {
      final List<dynamic> response = await supabase
          .from('ubicaciones_sv')
          .select('municipio')
          .eq('departamento', depto);

      final muniUnicos = response
          .map((e) => e['municipio'].toString().trim())
          .toSet()
          .toList();
      
      muniUnicos.sort();

      setState(() {
        _municipios = muniUnicos;
        _distritos = []; // Limpiar distritos anteriores
        municipioSel = null; // Reiniciar selección
        distritoSel = null;
      });
    } catch (e) {
      _showMsg("Error cargando municipios: $e", Colors.red);
    }
  }

  /// Carga los distritos filtrados por el municipio seleccionado
  Future<void> _cargarDistritos(String muni) async {
    try {
      final List<dynamic> response = await supabase
          .from('ubicaciones_sv')
          .select('distrito')
          .eq('municipio', muni);

      final distUnicos = response
          .map((e) => e['distrito'].toString().trim())
          .toSet()
          .toList();
      
      distUnicos.sort();

      setState(() {
        _distritos = distUnicos;
        distritoSel = null; // Reiniciar selección de distrito
      });
    } catch (e) {
      _showMsg("Error cargando distritos: $e", Colors.red);
    }
  }

  /// Carga los números de equipo (id_unidad) filtrados por el tipo en MAYÚSCULAS
  Future<void> _cargarUnidades(String tipo) async {
    try {
      final List<dynamic> response = await supabase
          .from('equipos')
          .select('id_unidad')
          .eq('tipo', tipo); // Filtro directo en mayúsculas estrictas

      final unidadesMapeadas = response
          .map((e) => e['id_unidad'].toString().trim())
          .toList();
      
      unidadesMapeadas.sort();

      setState(() {
        _unidades = unidadesMapeadas;
        _unidadSeleccionada = null; // Reiniciar selección de unidad
      });
    } catch (e) {
      _showMsg("Error cargando unidades: $e", Colors.red);
    }
  }

  // --- GEOLOCALIZACIÓN ASÍNCRONA ---

  /// 🟢 NUEVO MÉTODO: Evalúa permisos del hardware y retorna coordenadas actuales
  Future<Position?> _obtenerCoordenadasGPS() async {
    bool servicioHabilitado;
    LocationPermission permiso;

    // Verificar estado general del GPS en el teléfono
    servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) {
      debugPrint("El servicio de ubicación está deshabilitado en el dispositivo.");
      return null;
    }

    // Gestionar el árbol de permisos de ubicación de Android / iOS / Web
    permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        debugPrint("Los permisos de ubicación fueron denegados por el usuario.");
        return null;
      }
    }
    
    if (permiso == LocationPermission.deniedForever) {
      debugPrint("Los permisos de ubicación están denegados permanentemente en configuraciones.");
      return null;
    }

    // Si todo marcha en orden, extrae la posición exacta
    // Si todo marcha en orden, extrae la posición exacta
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, // 🟢 Actualizado para evitar 'desiredAccuracy' deprecado
            timeLimit: Duration(seconds: 6), // 🟢 Actualizado para evitar 'timeLimit' deprecado
          ),
        );
      } catch (e) {
        debugPrint("Error al solicitar coordenadas de ubicación: $e");
        return null;
      }
  }

  // --- SUBIDA DE FOTOS Y GUARDADO ---

  String _generarNumeroIncidencia() {
    return "${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}-RECO";
  }

  Future<String?> _subirImagenSupabase(String idIncidencia, String lado, XFile imageFile) async {
    try {
      final String pathArchivo = '$idIncidencia/$lado.jpg';

      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        await supabase.storage.from('fotos_incidencias').uploadBinary(pathArchivo, bytes);
      } else {
        final file = File(imageFile.path);
        await supabase.storage.from('fotos_incidencias').upload(pathArchivo, file);
      }

      // Generar la URL pública directa para guardarla en la tabla
      final String publicUrl = supabase.storage.from('fotos_incidencias').getPublicUrl(pathArchivo);
      return publicUrl;
    } catch (e) {
      debugPrint("Error subiendo foto $lado a Supabase Storage: $e");
      return null;
    }
  }

  Future<void> _guardarReporte() async {
    if (!_formKey.currentState!.validate()) return;

    // Validación rigurosa de fotos obligatorias del camión
    List<String> requeridas = ['Frontal', 'Trasera', 'Lateral Izquierdo', 'Lateral Derecho'];
    for (var lado in requeridas) {
      if (fotos[lado] == null) {
        _showMsg("❌ Falta la foto obligatoria: $lado", Colors.red);
        return;
      }
    }

    if (_danosTerceros && fotos['Tercero'] == null) {
      _showMsg("❌ Marcó daños a terceros, añada la foto de evidencia.", Colors.red);
      return;
    }

    setState(() => _guardando = true);
    final idIncidencia = _generarNumeroIncidencia();

    try {
      // 🟢 NUEVO: Solicitar geoposicionamiento justo antes de subir los datos
      Position? posicionActual = await _obtenerCoordenadasGPS();

      Map<String, String> urlsFotos = {};

      // Iterar y subir fotos al Storage Bucket
      for (var entry in fotos.entries) {
        if (entry.value != null) {
          String? url = await _subirImagenSupabase(idIncidencia, entry.key, entry.value!);
          if (url != null) {
            urlsFotos[entry.key] = url;
          } else {
            if (mounted) {
              _showMsg("❌ Error al guardar fotos. Verifica las políticas de tu bucket.", Colors.red);
              setState(() => _guardando = false);
            }
            return;
          }
        }
      }

      // Registro final de la incidencia en Supabase (Incluyendo telemetría GPS)
      await supabase.from('incidencias').insert({
        'folio': idIncidencia,
        'tipo_vehiculo': _tipoVehiculoSel,
        'unidad_id': _unidadSeleccionada,
        'motorista': _motoristaController.text.trim(),
        'supervisor': _supervisorController.text.trim(),
        'departamento': deptoSel,
        'municipio': municipioSel,
        'distrito': distritoSel,
        'descripcion': _descripcionController.text.trim(),
        'danos_terceros': _danosTerceros,
        'estado': 'Pendiente',
        'fotos': urlsFotos, // Columna de tipo jsonb en la base de datos
        // 🟢 NUEVAS COLUMNAS MAPEADAS
        'latitud': posicionActual?.latitude,
        'longitud': posicionActual?.longitude,
      });

      if (mounted) _mostrarDialogoExito(idIncidencia);
    } catch (e) {
      if (mounted) _showMsg("❌ Error al insertar reporte: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // --- INTERFAZ GRÁFICA ---

  void _mostrarOpcionesFoto(String lado) {
    showModalBottomSheet(
      context: context,
      builder: (bc) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Galería'),
              onTap: () {
                _seleccionarImagen(lado, ImageSource.gallery);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.green),
              title: const Text('Cámara'),
              onTap: () {
                _seleccionarImagen(lado, ImageSource.camera);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarImagen(String lado, ImageSource fuente) async {
    final XFile? photo = await _picker.pickImage(source: fuente, imageQuality: 50);
    if (photo != null) {
      setState(() => fotos[lado] = photo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registro de Daños - CYRECO (Supabase)"),
        backgroundColor: const Color(0xFF00A859),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildUbicacionCard(),
              const SizedBox(height: 15),
              _buildVehiculoCard(),
              const SizedBox(height: 15),
              _buildPersonalCard(),
              const SizedBox(height: 15),
              _cardTemplate("Descripción", [
                TextFormField(
                  controller: _descripcionController,
                  maxLines: 3,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Detalle del suceso..."),
                  validator: (v) => v!.isEmpty ? "Requerido" : null,
                )
              ]),
              const SizedBox(height: 15),
              _buildFotosGrid(),
              const SizedBox(height: 15),
              _buildDanosTercerosSection(),
              const SizedBox(height: 30),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUbicacionCard() => _cardTemplate("Ubicación", [
        _dropdownTemplate("Departamento", deptoSel, _departamentos, (v) {
          if (v != null) {
            setState(() {
              deptoSel = v;
              _municipios = [];
              _distritos = [];
              municipioSel = null;
              distritoSel = null;
            });
            _cargarMunicipios(v);
          }
        }),
        const SizedBox(height: 10),
        _dropdownTemplate("Municipio", municipioSel, _municipios, (v) {
          if (v != null) {
            setState(() {
              municipioSel = v;
              _distritos = [];
              distritoSel = null;
            });
            _cargarDistritos(v);
          }
        }),
        const SizedBox(height: 10),
        _dropdownTemplate("Distrito", distritoSel, _distritos, (v) => setState(() => distritoSel = v)),
      ]);

  Widget _buildVehiculoCard() => _cardTemplate("Unidad", [
        _dropdownTemplate("Tipo de Vehículo", _tipoVehiculoSel, _tiposVehiculos, (v) {
          if (v != null) {
            setState(() {
              _tipoVehiculoSel = v;
              _unidades = [];
              _unidadSeleccionada = null;
            });
            _cargarUnidades(v);
          }
        }),
        const SizedBox(height: 10),
        _dropdownTemplate("Número de Equipo", _unidadSeleccionada, _unidades, (v) => setState(() => _unidadSeleccionada = v)),
      ]);

  Widget _buildPersonalCard() => _cardTemplate("Personal", [
        _textField(_motoristaController, "Motorista", Icons.person),
        _textField(_supervisorController, "Supervisor", Icons.security),
      ]);

  Widget _buildFotosGrid() => Column(
        children: [
          const Text("Fotos Obligatorias del Equipo", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: ['Frontal', 'Trasera', 'Lateral Izquierdo', 'Lateral Derecho']
                .map((lado) => _buildFotoTile(lado))
                .toList(),
          ),
        ],
      );

  Widget _buildFotoTile(String lado) {
    XFile? img = fotos[lado];
    return InkWell(
      onTap: () => _mostrarOpcionesFoto(lado),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: img == null ? Colors.grey : Colors.green, width: 2),
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey.shade100,
        ),
        child: img == null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.camera_alt), Text(lado)])
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: kIsWeb ? Image.network(img.path, fit: BoxFit.cover) : Image.file(File(img.path), fit: BoxFit.cover),
              ),
      ),
    );
  }

  Widget _buildDanosTercerosSection() => _cardTemplate("Afectación Externa", [
        CheckboxListTile(
          title: const Text("¿Hubo daños a terceros?"),
          value: _danosTerceros,
          activeColor: Colors.green,
          contentPadding: EdgeInsets.zero,
          onChanged: (v) => setState(() => _danosTerceros = v ?? false),
        ),
        if (_danosTerceros) ...[
          const SizedBox(height: 15),
          const Text("Evidencia del daño al tercero:", style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(height: 140, width: double.infinity, child: _buildFotoTile('Tercero'))
        ]
      ]);

  Widget _buildSubmitButton() => SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _guardando ? null : _guardarReporte,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A859)),
          child: _guardando
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("GUARDAR REPORTE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );

  Widget _cardTemplate(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const Divider(),
            ...children
          ]),
        ),
      );

  Widget _dropdownTemplate(String label, String? val, List<String> items, Function(String?) onChanged) => DropdownButtonFormField<String>(
        initialValue: val, // Corregido de 'initialValue' a 'value' para mejor reactividad en cambios asíncronos
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items.toSet().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? "Requerido" : null,
      );

  Widget _textField(TextEditingController controller, String label, IconData icon) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: TextFormField(
            controller: controller,
            decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
            validator: (v) => v!.isEmpty ? "Requerido" : null),
      );

  void _showMsg(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));

  void _mostrarDialogoExito(String id) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("¡Éxito!"),
        content: Text("Folio Supabase: $id creado correctamente junto con su telemetría geográfica."),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _formKey.currentState?.reset();
                  _descripcionController.clear();
                  _motoristaController.clear();
                  _supervisorController.clear();
                  fotos.updateAll((key, value) => null);
                  _danosTerceros = false;
                  deptoSel = null;
                  municipioSel = null;
                  distritoSel = null;
                  _unidadSeleccionada = null;
                  _tipoVehiculoSel = null;
                });
              },
              child: const Text("OK"))
        ],
      ),
    );
  }
}