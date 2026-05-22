import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cyreco_flota_control/main.dart'; // Asegúrate que este nombre coincida con tu pubspec.yaml

void main() {
  testWidgets('Carga inicial de Home Cyreco', (WidgetTester tester) async {
    // Construye la aplicación de Grupo Cyreco
    await tester.pumpWidget(const MyApp());

    // Verifica que el título institucional aparezca en el sitio web
    expect(find.text('Panel de Control de Incidencias'), findsOneWidget);
    
    // Verifica que existan las opciones principales
    expect(find.byIcon(Icons.add_a_photo), findsOneWidget);
  });
}