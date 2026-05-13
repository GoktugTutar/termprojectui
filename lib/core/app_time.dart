import '../core/api_client.dart';

/// Uygulama genelinde "şimdiki zaman" kaynağı.
/// Prod modda DateTime.now(), test modunda backend saatini döndürür.
class AppTime {
  static DateTime? _override;

  /// Uygulama başlangıcında bir kez çağrılır.
  /// Backend test modundaysa saatini çeker ve önbelleğe alır.
  static Future<void> init() async {
    try {
      final mode = await ApiClient.getMode();
      if (mode['mode'] == 'test') {
        final current = mode['current'] as String?;
        if (current != null && current.isNotEmpty) {
          _override = DateTime.parse(current);
        }
      } else {
        _override = null; // prod → gerçek saat
      }
    } catch (_) {
      _override = null; // bağlanamazsa gerçek saati kullan
    }
  }

  /// Geçerli zamanı döndürür.
  /// Test modunda backend saati, prod modunda DateTime.now().
  static DateTime now() => _override ?? DateTime.now();

  /// Bugünün tarihini YYYY-MM-DD formatında döndürür.
  static String todayStr() => now().toIso8601String().substring(0, 10);
}