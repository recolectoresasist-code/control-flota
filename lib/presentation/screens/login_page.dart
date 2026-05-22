import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    final email = _emailController.text.trim().toLowerCase();
    
    if (email.isEmpty) {
      _mostrarMensaje("Por favor, ingresa tu correo electrónico.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Consultamos directamente la tabla usuarios_roles
      final data = await supabase
          .from('usuarios_roles')
          .select('rol')
          .eq('email', email)
          .maybeSingle();

      if (data != null && data['rol'] != null) {
        // Si existe en la base, lo dejamos pasar y le enviamos el correo a la siguiente pantalla
        if (mounted) {
          Navigator.pushReplacementNamed(
            context, 
            '/home', // <-- Esta ruta ahora coincide con main.dart
            arguments: email, // Pasamos el correo como argumento
          );
        }
      } else {
        _mostrarMensaje("Acceso denegado. Correo no registrado.");
      }
    } catch (e) {
      _mostrarMensaje("Error de conexión: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logoreco.PNG',
                height: 175, // Puedes ajustar este tamaño (100, 120, 140) según cómo se vea en pantalla
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              const Text(
                "CONTROL DE FLOTA",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              Text(
                "Acceso Interno",
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 35),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Correo Electrónico",
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

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
                  onPressed: _isLoading ? null : _ingresar,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Ingresar",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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