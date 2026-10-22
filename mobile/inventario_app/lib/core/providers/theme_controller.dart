import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda la preferencia de tema (modo claro / modo noche).
///
/// Vive en SharedPreferences y no en la sesion del usuario a proposito: la
/// eleccion es del dispositivo, no de la cuenta. Asi el mismo movil mantiene
/// el tema aunque se cierre sesion y se entre con otro usuario.
///
/// El valor por defecto es [ThemeMode.dark] para que la app se vea igual que
/// siempre en un equipo nuevo y el cambio sea algo que el usuario activa
/// conscientemente, no algo que le pase al actualizar.
class ThemeController extends ChangeNotifier {
  ThemeController._(this._modo);

  /// Constructor directo, para pruebas y para quien quiera fijar el modo sin
  /// tocar disco. En la app se usa [cargar].
  @visibleForTesting
  factory ThemeController.inicial(ThemeMode modo) => ThemeController._(modo);

  static const String _clave = 'tema_modo';

  ThemeMode _modo;

  ThemeMode get modo => _modo;

  /// Si la interfaz esta en modo noche.
  bool get esNoche => _modo == ThemeMode.dark;

  /// Lee la preferencia guardada. Se llama antes de `runApp` para que la app
  /// arranque ya en el modo elegido y no parpadee de noche a claro.
  static Future<ThemeController> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_clave);
    final modo = guardado == 'claro' ? ThemeMode.light : ThemeMode.dark;
    return ThemeController._(modo);
  }

  /// Pasa de modo noche a modo claro y al reves.
  Future<void> alternar() async {
    await setModo(esNoche ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setModo(ThemeMode modo) async {
    if (modo == _modo) {
      return;
    }
    _modo = modo;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, modo == ThemeMode.light ? 'claro' : 'noche');
  }
}