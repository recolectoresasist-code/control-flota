import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SetupService {
  // Instancia del cliente de Supabase
  final _client = Supabase.instance.client;

  /// 1. OBTENER DEPARTAMENTOS ÚNICOS
  /// Devuelve la lista de departamentos en MAYÚSCULAS desde 'ubicaciones_sv'
  Future<List<String>> getDepartamentos() async {
    try {
      final List<dynamic> response = await _client
          .from('ubicaciones_sv')
          .select('departamento');

      // Extraer los nombres, remover duplicados y ordenar alfabéticamente
      final departamentos = response
          .map((item) => item['departamento'].toString().trim())
          .toSet()
          .toList();
      
      departamentos.sort();
      return departamentos;
    } catch (e) {
      debugPrint("Error en getDepartamentos: $e");
      return [];
    }
  }

  /// 2. OBTENER MUNICIPIOS FILTRADOS POR DEPARTAMENTO
  /// Busca coincidencia exacta respetando que el departamento está en MAYÚSCULAS
  Future<List<String>> getMunicipios(String departamento) async {
    try {
      final List<dynamic> response = await _client
          .from('ubicaciones_sv')
          .select('municipio')
          .eq('departamento', departamento);

      final municipios = response
          .map((item) => item['municipio'].toString().trim())
          .toSet()
          .toList();

      municipios.sort();
      return municipios;
    } catch (e) {
      debugPrint("Error en getMunicipios: $e");
      return [];
    }
  }

  /// 3. OBTENER DISTRITOS FILTRADOS POR MUNICIPIO
  Future<List<String>> getDistritos(String municipio) async {
    try {
      final List<dynamic> response = await _client
          .from('ubicaciones_sv')
          .select('distrito')
          .eq('municipio', municipio);

      final distritos = response
          .map((item) => item['distrito'].toString().trim())
          .toSet()
          .toList();

      distritos.sort();
      return distritos;
    } catch (e) {
      debugPrint("Error en getDistritos: $e");
      return [];
    }
  }

  /// 4. OBTENER NÚMEROS DE EQUIPO (`id_unidad`) FILTRADOS POR TIPO DE VEHÍCULO
  /// El parámetro 'tipo' se envía en MAYÚSCULAS (ej. 'COMPACTADOR', 'VOLQUETA', 'LIVIANO')
  Future<List<String>> getUnidadesPorTipo(String tipo) async {
    try {
      final List<dynamic> response = await _client
          .from('equipos')
          .select('id_unidad')
          .eq('tipo', tipo.toUpperCase().trim()); // Forzamos mayúsculas por seguridad

      final unidades = response
          .map((item) => item['id_unidad'].toString().trim())
          .toList();

      unidades.sort();
      return unidades;
    } catch (e) {
      debugPrint("Error en getUnidadesPorTipo: $e");
      return [];
    }
  }
}