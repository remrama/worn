import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';

class DeviceStore {
  static const _key = 'worn_devices';
  static DeviceStore? _instance;
  SharedPreferences? _prefs;
  final List<Device> _devices = [];

  DeviceStore._();

  static DeviceStore get instance {
    _instance ??= DeviceStore._();
    return _instance!;
  }

  Future<void> _ensureLoaded() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    final json = _prefs!.getString(_key);
    if (json != null) {
      final list = jsonDecode(json) as List;
      _devices.clear();
      _devices.addAll(list.map((e) => Device.fromMap(e as Map<String, dynamic>)));
    }
  }

  Future<void> _save() async {
    final json = jsonEncode(_devices.map((d) => d.toMap()).toList());
    await _prefs!.setString(_key, json);
  }

  Future<List<Device>> getDevices() async {
    await _ensureLoaded();
    return List.unmodifiable(_devices);
  }

  Future<void> addDevice(Device device) async {
    await _ensureLoaded();
    if (_devices.any((d) => d.name == device.name)) {
      throw Exception('Device name must be unique');
    }
    _devices.add(device);
    await _save();
  }

  Future<void> updateDevice(Device device) async {
    await _ensureLoaded();
    final idx = _devices.indexWhere((d) => d.id == device.id);
    if (idx == -1) throw Exception('Device not found');
    if (_devices.any((d) => d.id != device.id && d.name == device.name)) {
      throw Exception('Device name must be unique');
    }
    _devices[idx] = device;
    await _save();
  }

  Future<void> deleteDevice(String id) async {
    await _ensureLoaded();
    _devices.removeWhere((d) => d.id == id);
    await _save();
  }
}
