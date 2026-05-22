import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';


// Acceso directo al cliente global de Supabase
final supabase = Supabase.instance.client;

class AuditoriaEquipoPage extends StatefulWidget {
  const AuditoriaEquipoPage({super.key});

  @override
  State<AuditoriaEquipoPage> createState() => _AuditoriaEquipoPageState();
}

class _AuditoriaEquipoPageState extends State<AuditoriaEquipoPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  // Variables de control de estado
  String? _tipoEquipoSeleccionado;
  String? _idEquipoSeleccionado;
  String _estadoSeleccionado = 'SIN DAÑOS';
  bool _guardandoTotal = false;
  bool _cargandoEquipos = false;

  // Listado de IDs filtrados que se traerán de Supabase
  List<String> _listaIdsFiltrados = [];

  // Tipos de camiones definidos para Grupo Cyreco
  final List<String> _tiposEquipo = [
    'COMPACTADOR',
    'VOLQUETA',
    'LIVIANO',
    'CABEZALES',
    'GONDOLAS',
    'GRUA',
    'BIOINFECCIOSO'
  ];

  // Mapa de fotos locales temporales usando XFile (Idéntico a RegistroIncidencia)
  final Map<String, XFile?> _fotosLocales = {
    'frontal': null,
    'trasera': null,
    'izquierda': null,
    'derecha': null,
  };

  @override
  void initState() {
    super.initState();
  }

  /// 🔄 Cargar códigos de equipos filtrados desde Supabase
  Future<void> _cargarEquiposPorTipo(String tipo) async {
    setState(() {
      _cargandoEquipos = true;
      _idEquipoSeleccionado = null;
      _listaIdsFiltrados = [];
    });

    try {
      final List<dynamic> response = await supabase
          .from('equipos')
          .select('id_unidad')
          .eq('tipo', tipo)
          .order('id_unidad', ascending: true);

      if (response.isNotEmpty) {
        setState(() {
          _listaIdsFiltrados = response
              .map((item) => item['id_unidad'].toString())
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        _showMsg("❌ Error al cargar unidades: $e", Colors.red);
      }
    } finally {
      if (mounted) setState(() => _cargandoEquipos = false);
    }
  }

  /// 🔄 Desplegar hoja inferior para elegir origen de la imagen
  void _mostrarOpcionesFoto(String lado) {
    if (_idEquipoSeleccionado == null) {
      _showMsg("⚠️ Primero seleccione el ID del Equipo.", Colors.orange);
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (bc) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF00A859)),
              title: const Text('Galería'),
              onTap: () {
                _seleccionarImagen(lado, ImageSource.gallery);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Color(0xFF00A859)),
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

  /// 📸 Captura local de la foto en el mapa temporal
  Future<void> _seleccionarImagen(String lado, ImageSource fuente) async {
    final XFile? photo = await _picker.pickImage(source: fuente, imageQuality: 50);
    if (photo != null) {
      setState(() {
        _fotosLocales[lado] = photo;
      });
    }
  }

  /// 📤 Motor de subida binario/archivo a Supabase Storage Bucket
  Future<String?> _subirImagenSupabase(String folderName, String lado, XFile imageFile) async {
    try {
      final String uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
      final String pathArchivo = '$folderName/${lado}_$uniqueId.jpg';

      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        await supabase.storage.from('imagenes_auditoria').uploadBinary(pathArchivo, bytes);
      } else {
        final file = File(imageFile.path);
        await supabase.storage.from('imagenes_auditoria').upload(pathArchivo, file);
      }

      // Generar y retornar URL pública
      final String publicUrl = supabase.storage.from('imagenes_auditoria').getPublicUrl(pathArchivo);
      return publicUrl;
    } catch (e) {
      debugPrint("Error subiendo foto $lado a Storage: $e");
      return null;
    }
  }

  /// 💾 Guardar reporte definitivo
  Future<void> _subirYGuardarAuditoriaTotal() async {
    if (!_formKey.currentState!.validate()) return;

    // 1. Validar estrictamente que estén las 4 fotos asignadas en la UI
    List<String> requeridas = ['frontal', 'trasera', 'izquierda', 'derecha'];
    for (var lado in requeridas) {
      if (_fotosLocales[lado] == null) {
        _showMsg("❌ Es obligatorio capturar la imagen del lado: $lado", Colors.red);
        return;
      }
    }

    setState(() => _guardandoTotal = true); // Activar pantalla de carga
    final String folderName = _idEquipoSeleccionado!.replaceAll(':', '_').replaceAll(' ', '_');

    try {
      Map<String, String> urlsFotosFinales = {};

      // 2. Iterar sobre las fotos locales subiéndolas a Supabase
      for (var lado in requeridas) {
        XFile? archivo = _fotosLocales[lado];
        if (archivo != null) {
          String? url = await _subirImagenSupabase(folderName, lado, archivo);
          
          if (url != null) {
            urlsFotosFinales[lado] = url; // Guardamos la URL pública en el mapa final JSON
          } else {
            // Si falla la subida de una de ellas, abortamos para proteger la integridad del registro
            _showMsg("❌ No se pudo obtener la URL de la foto $lado", Colors.red);
            setState(() => _guardandoTotal = false);
            return;
          }
        }
      }

      // 3. Guardar registro relacional en la tabla 'estado_equipos'
      await supabase.from('estado_equipos').insert({
        'id_equipo': _idEquipoSeleccionado,
        'tipo_equipo': _tipoEquipoSeleccionado,
        'estado': _estadoSeleccionado,
        'fotos': urlsFotosFinales, // Se almacena como objeto JSONB en la BD
      });

      if (mounted) {
        _showMsg("✅ Registro de Estado de Equipo guardado con éxito", const Color(0xFF00A859));
        Navigator.pop(context, true); // Retornar exitosamente
      }
    } catch (e) {
      if (mounted) {
        _showMsg("❌ Error al guardar registro final: $e", Colors.red);
      }
    } finally {
      if (mounted) setState(() => _guardandoTotal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Auditoría Física 360°"),
        backgroundColor: const Color(0xFF00A859),
        foregroundColor: Colors.white,
      ),
      body: _guardandoTotal
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00A859)),
                  SizedBox(height: 15),
                  Text(
                    "Subiendo imágenes a Supabase y guardando reporte...",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  )
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Control e Inventario de Unidades",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),

                    // Dropdown: Tipo de Equipo
                    DropdownButtonFormField<String>(
                      initialValue: _tipoEquipoSeleccionado,
                      decoration: const InputDecoration(
                        labelText: "Tipo de Equipo",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_shipping_outlined),
                      ),
                      items: _tiposEquipo.toSet().map((tipo) {
                        return DropdownMenuItem(value: tipo, child: Text(tipo));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _tipoEquipoSeleccionado = val);
                          _cargarEquiposPorTipo(val);
                        }
                      },
                      validator: (value) => value == null ? "Seleccione el tipo de equipo" : null,
                    ),
                    const SizedBox(height: 15),

                    // Dropdown: ID del Equipo
                    DropdownButtonFormField<String>(
                      initialValue: _idEquipoSeleccionado,
                      disabledHint: Text(
                        _tipoEquipoSeleccionado == null 
                            ? "Primero seleccione un tipo" 
                            : "Cargando unidades..."
                      ),
                      decoration: InputDecoration(
                        labelText: "ID del Equipo (Código)",
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.badge_outlined),
                        suffixIcon: _cargandoEquipos 
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A859)),
                              )
                            : null,
                      ),
                      items: _cargandoEquipos ? null : _listaIdsFiltrados.toSet().map((id) {
                        return DropdownMenuItem(value: id, child: Text(id));
                      }).toList(),
                      onChanged: _cargandoEquipos ? null : (val) {
                        setState(() => _idEquipoSeleccionado = val);
                      },
                      validator: (value) => value == null ? "Seleccione el código del equipo" : null,
                    ),
                    const SizedBox(height: 15),

                    const Text("Estado Físico Actual:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text("ÓPTIMO / SIN DAÑOS")),
                            selected: _estadoSeleccionado == 'SIN DAÑOS',
                            selectedColor: const Color(0xFF00A859).withValues(alpha: 0.2),
                            checkmarkColor: const Color(0xFF00A859),
                            labelStyle: TextStyle(
                              color: _estadoSeleccionado == 'SIN DAÑOS' ? const Color(0xFF00A859) : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (selected) {
                              if (selected) setState(() => _estadoSeleccionado = 'SIN DAÑOS');
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text("CON DAÑOS")),
                            selected: _estadoSeleccionado == 'CON DAÑOS',
                            selectedColor: Colors.red.withValues(alpha: 0.2),
                            checkmarkColor: Colors.red,
                            labelStyle: TextStyle(
                              color: _estadoSeleccionado == 'CON DAÑOS' ? Colors.red : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (selected) {
                              if (selected) setState(() => _estadoSeleccionado = 'CON DAÑOS');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    const Text(
                      "Evidencia Fotográfica Requerida (4 Lados)",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 15),
                    
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.3,
                      children: [
                        _construirBotonFotoImagePicker("frontal", "Lado Frontal"),
                        _construirBotonFotoImagePicker("trasera", "Lado Trasero"),
                        _construirBotonFotoImagePicker("izquierda", "Perfil Izquierdo"),
                        _construirBotonFotoImagePicker("derecha", "Perfil Derecho"),
                      ],
                    ),
                    const SizedBox(height: 35),

                    // Botón de Enviar Final
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _guardandoTotal ? null : _subirYGuardarAuditoriaTotal,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text("REGISTRAR ESTADO DE EQUIPO", style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A859),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Widget para renderizar las vistas previas de las fotos usando la caché de ImagePicker
  Widget _construirBotonFotoImagePicker(String llave, String etiqueta) {
    XFile? img = _fotosLocales[llave];

    return InkWell(
      onTap: () => _mostrarOpcionesFoto(llave),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: img == null ? Colors.grey.shade300 : const Color(0xFF00A859), width: 2),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: img == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, color: Colors.grey[600], size: 26),
                  const SizedBox(height: 4),
                  Text(etiqueta, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text("Tocar para capturar", style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: kIsWeb 
                    ? Image.network(img.path, fit: BoxFit.cover) 
                    : Image.file(File(img.path), fit: BoxFit.cover),
              ),
      ),
    );
  }

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}