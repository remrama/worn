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

  // Test-only method to reset the singleton state
  static void resetForTesting() {
    _instance = null;
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
      '${_timestamp()}\tDEVICE_ADDED\t${device.id}\t${device.name}\t${device.deviceType.name}\t${device.status.name}\t${device.location.name}\t$sn',
    );
  }

  Future<void> logDeviceEdited(Device oldDevice, Device newDevice) async {
    final changes = <String>[];
    if (oldDevice.name != newDevice.name) {
      changes.add('name:${newDevice.name}');
    }
    if (oldDevice.deviceType != newDevice.deviceType) {
      changes.add('deviceType:${newDevice.deviceType.name}');
    }
    if (oldDevice.serialNumber != newDevice.serialNumber) {
      changes.add('sn:${newDevice.serialNumber ?? "none"}');
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

  Future<void> logStatusChanged(Device device, DeviceStatus newStatus) async {
    await _append(
      '${_timestamp()}\tSTATUS_CHANGED\t${device.id}\t${device.name}\t${newStatus.name}',
    );
  }

  Future<void> logLocationChanged(Device device, DeviceLocation newLocation) async {
    await _append(
      '${_timestamp()}\tLOCATION_CHANGED\t${device.id}\t${device.name}\t${newLocation.name}',
    );
  }

  Future<void> logDevicePowerChanged(Device device, bool isPoweredOn) async {
    final powerState = isPoweredOn ? 'on' : 'off';
    await _append(
      '${_timestamp()}\tPOWER_CHANGED\t${device.id}\t${device.name}\t$powerState',
    );
  }

  Future<void> logNote(String note, {Device? device, Event? event}) async {
    final sanitized = note.replaceAll('\t', ' ').replaceAll('\n', ' ');
    if (device != null) {
      await _append('${_timestamp()}\tNOTE\t${device.id}\t${device.name}\t$sanitized');
    } else if (event != null) {
      await _append('${_timestamp()}\tNOTE\t${event.id}\t${event.displayName}\t$sanitized');
    } else {
      await _append('${_timestamp()}\tNOTE\t$sanitized');
    }
  }

  String _formatTimeWindow(DateTime earliest, DateTime latest) {
    if (earliest == latest) {
      return earliest.toIso8601String();
    }
    return '${earliest.toIso8601String()}..${latest.toIso8601String()}';
  }

  Future<void> logEventStarted(Event event) async {
    final startWindow = _formatTimeWindow(event.startEarliest, event.startLatest);
    await _append(
      '${_timestamp()}\tEVENT_STARTED\t${event.id}\t${event.type.name}\t$startWindow',
    );
  }

  Future<void> logEventStopped(
    Event event,
    DateTime stopEarliest,
    DateTime stopLatest,
  ) async {
    final startWindow = _formatTimeWindow(event.startEarliest, event.startLatest);
    final stopWindow = _formatTimeWindow(stopEarliest, stopLatest);
    await _append(
      '${_timestamp()}\tEVENT_STOPPED\t${event.id}\t${event.type.name}\t$startWindow\t$stopWindow',
    );
  }

  Future<void> logEventCancelled(Event event) async {
    final startWindow = _formatTimeWindow(event.startEarliest, event.startLatest);
    await _append(
      '${_timestamp()}\tEVENT_CANCELLED\t${event.id}\t${event.type.name}\t$startWindow',
    );
  }

  Future<void> logRetroactiveEvent(
    Event event,
    DateTime stopEarliest,
    DateTime stopLatest,
  ) async {
    final startWindow = _formatTimeWindow(event.startEarliest, event.startLatest);
    final stopWindow = _formatTimeWindow(stopEarliest, stopLatest);
    await _append(
      '${_timestamp()}\tEVENT_RETROACTIVE\t${event.id}\t${event.type.name}\t$startWindow\t$stopWindow',
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

  Future<void> logTrackingPaused() async {
    await _append('${_timestamp()}\tTRACKING_PAUSED');
  }

  Future<void> logTrackingResumed() async {
    await _append('${_timestamp()}\tTRACKING_RESUMED');
  }
}
