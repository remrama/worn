import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';
import '../models/event.dart';

class LogService {
  static const _key = 'worn_log';
  static LogService? _instance;
  SharedPreferences? _prefs;
  final List<String> _logLines = [];

  LogService._();

  static LogService get instance {
    _instance ??= LogService._();
    return _instance!;
  }

  Future<void> _ensureLoaded() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    final content = _prefs!.getString(_key);
    if (content != null && content.isNotEmpty) {
      _logLines.clear();
      _logLines.addAll(content.split('\n').where((l) => l.isNotEmpty));
    }
  }

  Future<void> _save() async {
    await _prefs!.setString(_key, _logLines.join('\n'));
  }

  String _timestamp() => DateTime.now().toUtc().toIso8601String();

  Future<void> _append(String line) async {
    await _ensureLoaded();
    _logLines.add(line);
    await _save();
  }

  Future<void> logDeviceAdded(Device device) async {
    final sn = device.serialNumber ?? 'none';
    await _append(
      '${_timestamp()}\tDEVICE_ADDED\t${device.id}\t${device.name}\t${device.location.name}\t$sn',
    );
  }

  Future<void> logDeviceEdited(Device oldDevice, Device newDevice) async {
    final changes = <String>[];
    if (oldDevice.name != newDevice.name) {
      changes.add('name:${oldDevice.name}->${newDevice.name}');
    }
    if (oldDevice.serialNumber != newDevice.serialNumber) {
      changes.add('sn:${oldDevice.serialNumber ?? "none"}->${newDevice.serialNumber ?? "none"}');
    }
    if (changes.isNotEmpty) {
      await _append(
        '${_timestamp()}\tDEVICE_EDITED\t${newDevice.id}\t${changes.join(",")}',
      );
    }
  }

  Future<void> logDeviceDeleted(Device device) async {
    await _append(
      '${_timestamp()}\tDEVICE_DELETED\t${device.id}\t${device.name}',
    );
  }

  Future<void> logLocationChanged(Device device, DeviceLocation oldLocation, DeviceLocation newLocation) async {
    await _append(
      '${_timestamp()}\tLOCATION_CHANGED\t${device.id}\t${device.name}\t${oldLocation.name}->${newLocation.name}',
    );
  }

  Future<void> logNote(String note, {Device? device}) async {
    final sanitized = note.replaceAll('\t', ' ').replaceAll('\n', ' ');
    if (device != null) {
      await _append('${_timestamp()}\tNOTE\t${device.id}\t${device.name}\t$sanitized');
    } else {
      await _append('${_timestamp()}\tNOTE\t$sanitized');
    }
  }

  Future<void> logEventStarted(Event event) async {
    await _append(
      '${_timestamp()}\tEVENT_STARTED\t${event.id}\t${event.type.name}\t${event.displayName}',
    );
  }

  Future<void> logEventStopped(Event event, Duration duration) async {
    final minutes = duration.inMinutes;
    await _append(
      '${_timestamp()}\tEVENT_STOPPED\t${event.id}\t${event.type.name}\t${event.displayName}\t$minutes',
    );
  }

  Future<List<String>> getLogLines() async {
    await _ensureLoaded();
    return List.unmodifiable(_logLines);
  }

  Future<String> getLogContent() async {
    await _ensureLoaded();
    return _logLines.join('\n');
  }
}
