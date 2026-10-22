import '../models/marca.dart';
import '../models/proveedor.dart';
import '../network/api_client.dart';

/// Marcas y proveedores de producto.
///
/// Los dos catalogos son opcionales: un producto puede registrarse sin marca
/// ni proveedor, y por eso los campos se mandan como `null` y no como cadena
/// vacia (el backend espera enteros o ausencia).
///
/// En los dos catalogos el borrado es logico (`activo = false`) y el nombre
/// sigue reservado por el indice unico sobre `lower(nombre)`: volver a
/// escribir el nombre de uno desactivado lo reactiva en vez de duplicarlo.
class CatalogService {
  final ApiClient _apiClient;

  CatalogService(this._apiClient);

  // ------------------------------------------------------------------ marcas

  Future<List<Marca>> fetchMarcas() async {
    final json = await _apiClient.getJson('/api/marcas/') as List<dynamic>;
    return json
        .map((item) => Marca.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Marca> createMarca(String nombre) async {
    final json = await _apiClient.postJson(
      '/api/marcas/',
      <String, dynamic>{'nombre': nombre},
    );
    return Marca.fromJson(json as Map<String, dynamic>);
  }

  Future<Marca> renombrarMarca(int id, String nombre) async {
    final json = await _apiClient.putJson(
      '/api/marcas/$id',
      <String, dynamic>{'nombre': nombre},
    );
    return Marca.fromJson(json as Map<String, dynamic>);
  }

  Future<bool> desactivarMarca(int id) async {
    await _apiClient.deleteJson('/api/marcas/$id');
    return true;
  }

  // ------------------------------------------------------------- proveedores

  Future<List<Proveedor>> fetchProveedores() async {
    final json = await _apiClient.getJson('/api/proveedores/') as List<dynamic>;
    return json
        .map((item) => Proveedor.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Proveedor> createProveedor({
    required String nombre,
    String? contacto,
    String? telefono,
    String? email,
  }) async {
    final json = await _apiClient.postJson('/api/proveedores/', <String, dynamic>{
      'nombre': nombre,
      'contacto': _oVacio(contacto),
      'telefono': _oVacio(telefono),
      'email': _oVacio(email),
    });
    return Proveedor.fromJson(json as Map<String, dynamic>);
  }

  Future<Proveedor> actualizarProveedor(
    int id, {
    required String nombre,
    String? contacto,
    String? telefono,
    String? email,
  }) async {
    final json = await _apiClient.putJson('/api/proveedores/$id', <String, dynamic>{
      'nombre': nombre,
      'contacto': _oVacio(contacto),
      'telefono': _oVacio(telefono),
      'email': _oVacio(email),
    });
    return Proveedor.fromJson(json as Map<String, dynamic>);
  }

  Future<bool> desactivarProveedor(int id) async {
    await _apiClient.deleteJson('/api/proveedores/$id');
    return true;
  }

  /// Un campo de texto en blanco se manda como null, no como "".
  ///
  /// El backend ya normaliza los vacios, pero mandarlos limpios evita
  /// depender de esa normalizacion y hace el payload legible en los logs.
  static String? _oVacio(String? valor) {
    final texto = valor?.trim();
    return (texto == null || texto.isEmpty) ? null : texto;
  }
}