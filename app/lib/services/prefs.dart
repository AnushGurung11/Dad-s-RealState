import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Thin wrapper around [SharedPreferences] for small UI preferences. Kept
/// separate from [JsonStore] which owns all domain data.
class Prefs {
  Prefs(this._prefs);

  final SharedPreferences _prefs;

  static Future<Prefs> load() async {
    return Prefs(await SharedPreferences.getInstance());
  }

  /// Last month the user had selected in the payments screen (YYYY-MM).
  Future<String?> currentMonth() async => _prefs.getString(AppConfig.prefKeyCurrentMonth);

  Future<void> setCurrentMonth(String month) async {
    await _prefs.setString(AppConfig.prefKeyCurrentMonth, month);
  }
}
