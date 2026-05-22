import 'package:flutter/material.dart';

class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Encabezado del Menú con los colores de Grupo Cyreco
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF00A859), // Verde institucional
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 30,
                  child: Icon(Icons.local_shipping, color: Color(0xFF00A859), size: 35),
                ),
                SizedBox(height: 10),
                Text(
                  "GRUPO CYRECO",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Control de Flota y Logística",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          // Sección de Operaciones
          ListTile(
            leading: const Icon(Icons.home_outlined, color: Color(0xFF00A859)),
            title: const Text("Inicio"),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.minor_crash_outlined, color: Colors.orange),
            title: const Text("Registrar Incidencia"),
            onTap: () {
              Navigator.pop(context); // Cierra el drawer
              Navigator.pushNamed(context, '/registro_incidencia');
            },
          ),
          
          const Divider(), // Separador visual
          
          // Sección de Administración
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 10, bottom: 5),
            child: Text(
              "ADMINISTRACIÓN", 
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined, color: Colors.blue),
            title: const Text("Carga Masiva de Equipos"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/carga_masiva');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text("Configuración"),
            onTap: () {
              // Espacio para futuras configuraciones
            },
          ),
          
          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Cerrar Sesión"),
            onTap: () {
              // Lógica de logout aquí
            },
          ),
        ],
      ),
    );
  }
}