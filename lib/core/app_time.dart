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
          setOverride(DateTime.parse(current));
        }
      } else {
        clearOverride(); // prod → gerçek saat
      }
    } catch (_) {
      clearOverride(); // bağlanamazsa gerçek saati kullan
    }
  }

  /// Geçerli zamanı döndürür.
  /// Test modunda backend saati, prod modunda DateTime.now().
  static DateTime now() => _override ?? DateTime.now();

  /// Bugünün tarihini YYYY-MM-DD formatında döndürür.
  static String todayStr() {
    final dt = now().toLocal();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Test modunda çalışma zamanı saat override'ını günceller.
  static void setOverride(DateTime dt) {
    _override = dt.toLocal();
  }

  static void clearOverride() {
    _override = null;
  }
}
