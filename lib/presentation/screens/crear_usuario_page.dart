import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class CrearUsuarioPage extends StatefulWidget {
  const CrearUsuarioPage({super.key});

  @override
  State<CrearUsuarioPage> createState() => _CrearUsuarioPageState();
}

class _CrearUsuarioPageState extends State<CrearUsuarioPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  
  // Lista de roles predefinidos (puedes cambiarlos según tus necesidades)
  final List<String> _roles = ['administrador', 'SUPERVISOR', 'reportes'];
  String? _rolSeleccionado;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _registrarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    
    setState(() => _isLoading = true);

    try {
      // Insertar el nuevo registro en la tabla usuarios_roles
      await supabase.from('usuarios_roles').insert({
        'email': email,
        'rol': _rolSeleccionado,
      });

      if (mounted) {
        _mostrarMensaje("Usuario registrado exitosamente.", esExito: true);
        // Limpiar el formulario tras el éxito
        _emailController.clear();
        setState(() {
          _rolSeleccionado = null;
        });
      }
    } on PostgrestException catch (error) {
      // Manejar el caso de que el correo ya exista si tienes una llave única (Unique)
      if (error.message.contains('duplicate key')) {
        _mostrarMensaje("Este correo ya se encuentra registrado.");
      } else {
        _mostrarMensaje("Error en la base de datos: ${error.message}");
      }
    } catch (e) {
      _mostrarMensaje("Error inesperado: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarMensaje(String mensaje, {bool esExito = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esExito ? const Color(0xFF00A859) : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nuevo Usuario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Registrar Personal",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Asigna un correo electrónico institucional y el rol correspondiente para habilitar el acceso a la plataforma.",
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 30),

              // Campo de Correo Electrónico
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Correo Electrónico",
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "El correo es obligatorio";
                  }
                  // Validación básica de formato de email
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                    return "Ingresa un correo electrónico válido";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Selector de Rol (Dropdown)
              DropdownButtonFormField<String>(
                initialValue: _rolSeleccionado,
                hint: const Text("Seleccionar Rol"),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _roles.map((String rol) {
                  return DropdownMenuItem<String>(
                    value: rol,
                    child: Text(rol),
                  );
                }).toList(),
                onChanged: (String? nuevoRol) {
                  setState(() {
                    _rolSeleccionado = nuevoRol;
                  });
                },
                validator: (value) => value == null ? "Debes seleccionar un rol" : null,
              ),
              const SizedBox(height: 35),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A859),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                  ),
                  onPressed: _isLoading ? null : _registrarUsuario,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_outlined),
                            SizedBox(width: 8),
                            Text("Guardar Usuario", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
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