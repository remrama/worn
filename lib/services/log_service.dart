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
    final power = device.isPoweredOn ? 'on' : 'off';
    await _append(
      '${_timestamp()}\tDEVICE_ADDED\t${device.id}\tname="${device.name}"\ttype=${device.deviceType.name}\tstatus=${device.status.name}\tlocation=${device.location.name}\tsn=$sn\tpower=$power',
    );
  }

  Future<void> logDeviceEdited(Device oldDevice, Device newDevice) async {
    if (oldDevice.name != newDevice.name) {
      await _append(
        '${_timestamp()}\tDEVICE_NAME_UPDATED\t${newDevice.id}\t${newDevice.name}',
      );
    }
    if (oldDevice.deviceType != newDevice.deviceType) {
      await _append(
        '${_timestamp()}\tDEVICE_TYPE_UPDATED\t${newDevice.id}\t${newDevice.name}\t${newDevice.deviceType.name}',
      );
    }
    if (oldDevice.serialNumber != newDevice.serialNumber) {
      final sn = newDevice.serialNumber ?? 'none';
      await _append(
        '${_timestamp()}\tDEVICE_SN_UPDATED\t${newDevice.id}\t${newDevice.name}\t$sn',
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
      '${_timestamp()}\tDEVICE_STATUS_UPDATED\t${device.id}\t${device.name}\t${newStatus.name}',
    );
  }

  Future<void> logLocationChanged(Device device, DeviceLocation newLocation) async {
    await _append(
      '${_timestamp()}\tDEVICE_LOCATION_UPDATED\t${device.id}\t${device.name}\t${newLocation.name}',
    );
  }

  Future<void> logDevicePowerChanged(Device device, bool isPoweredOn) async {
    final powerState = isPoweredOn ? 'on' : 'off';
    await _append(
      '${_timestamp()}\tDEVICE_POWER_UPDATED\t${device.id}\t${device.name}\t$powerState',
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
