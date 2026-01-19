import 'package:shared_preferences/shared_preferences.dart';

class TrackingService {
  static const _key = 'worn_tracking';
  static TrackingService? _instance;
  SharedPreferences? _prefs;
  bool _isTracking = true;

  TrackingService._();

  static TrackingService get instance {
    _instance ??= TrackingService._();
    return _instance!;
  }

  Future<void> _ensureLoaded() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    _isTracking = _prefs!.getBool(_key) ?? true;
  }

  Future<bool> isTracking() async {
    await _ensureLoaded();
    return _isTracking;
  }

  Future<void> setTracking(bool value) async {
    await _ensureLoaded();
    _isTracking = value;
    await _prefs!.setBool(_key, value);
  }
}
