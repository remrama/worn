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

  /// Formats a DateTime as ISO 8601 with timezone offset (e.g., 2024-01-15T10:30:00.000-05:00)
  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    // Dart's toIso8601String on local time omits timezone, so we append it
    final isoBase = local.toIso8601String();
    return '$isoBase$sign$hours:$minutes';
  }

  String _timestamp() => _formatDateTime(DateTime.now());

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

  Future<void> logDeviceUpdated(
    Device oldDevice,
    Device newDevice, {
    DateTime? effectiveTime,
  }) async {
    final changes = <String>[];

    if (oldDevice.name != newDevice.name) {
      changes.add('name="${newDevice.name}"');
    }
    if (oldDevice.deviceType != newDevice.deviceType) {
      changes.add('type=${newDevice.deviceType.name}');
    }
    if (oldDevice.serialNumber != newDevice.serialNumber) {
      changes.add('sn=${newDevice.serialNumber ?? 'none'}');
    }
    if (oldDevice.status != newDevice.status) {
      changes.add('status=${newDevice.status.name}');
    }
    if (oldDevice.location != newDevice.location) {
      changes.add('location=${newDevice.location.name}');
    }
    if (oldDevice.isPoweredOn != newDevice.isPoweredOn) {
      changes.add('power=${newDevice.isPoweredOn ? 'on' : 'off'}');
    }

    if (changes.isEmpty) return;

    // Add effective timestamp if backdated
    if (effectiveTime != null) {
      changes.add('effective=${effectiveTime.toUtc().toIso8601String()}');
    }

    await _append(
      '${_timestamp()}\tDEVICE_UPDATED\t${newDevice.id}\t"${oldDevice.name}"\t${changes.join('\t')}',
    );
  }

  Future<void> logDeviceDeleted(Device device) async {
    await _append(
      '${_timestamp()}\tDEVICE_DELETED\t${device.id}\t"${device.name}"',
    );
  }

  Future<void> logNote(String note, {Device? device, Event? event}) async {
    final sanitized = note.replaceAll('\t', ' ').replaceAll('\n', ' ');
    if (device != null) {
      await _append(
          '${_timestamp()}\tDEVICE_NOTE\t${device.id}\t${device.name}\t$sanitized');
    } else if (event != null) {
      await _append(
          '${_timestamp()}\tACTIVITY_NOTE\t${event.id}\t${event.displayName}\t$sanitized');
    } else {
      await _append('${_timestamp()}\tGLOBAL_NOTE\t$sanitized');
    }
  }

  /// Formats a time window for logging.
  /// - Returns null if earliest == latest AND within 60 seconds of logTime (use log timestamp)
  /// - Returns single timestamp if earliest == latest but backdated
  /// - Returns 'earliest=...\tlatest=...' if there's a window
  String? _formatTimeWindow(
      DateTime earliest, DateTime latest, DateTime logTime) {
    if (earliest == latest) {
      // Check if it's close to "now" (within 60 seconds of log time)
      final diff = logTime.difference(earliest).abs();
      if (diff.inSeconds <= 60) {
        // Close to now - use log timestamp as event time
        return null;
      }
      // Backdated precise time - output single timestamp
      return _formatDateTime(earliest);
    }
    return 'earliest=${_formatDateTime(earliest)}\tlatest=${_formatDateTime(latest)}';
  }

  Future<void> logEventStarted(Event event) async {
    final now = DateTime.now();
    final startWindow =
        _formatTimeWindow(event.startEarliest, event.startLatest, now);
    final parts = [
      _formatDateTime(now),
      'EVENT_STARTED',
      event.id,
      event.type.name,
    ];
    if (startWindow != null) {
      parts.add(startWindow);
    }
    await _append(parts.join('\t'));
  }

  Future<void> logEventStopped(
    Event event,
    DateTime stopEarliest,
    DateTime stopLatest,
  ) async {
    final now = DateTime.now();
    final startWindow =
        _formatTimeWindow(event.startEarliest, event.startLatest, now);
    final stopWindow = _formatTimeWindow(stopEarliest, stopLatest, now);
    final parts = [
      _formatDateTime(now),
      'EVENT_STOPPED',
      event.id,
      event.type.name,
    ];
    if (startWindow != null) {
      parts.add(startWindow);
    }
    if (stopWindow != null) {
      parts.add(stopWindow);
    }
    await _append(parts.join('\t'));
  }

  Future<void> logEventCancelled(Event event) async {
    await _append(
      '${_timestamp()}\tEVENT_CANCELLED\t${event.id}\t${event.type.name}',
    );
  }

  Future<void> logRetroactiveEvent(
    Event event,
    DateTime stopEarliest,
    DateTime stopLatest,
  ) async {
    final now = DateTime.now();
    final startWindow =
        _formatTimeWindow(event.startEarliest, event.startLatest, now);
    final stopWindow = _formatTimeWindow(stopEarliest, stopLatest, now);
    final parts = [
      _formatDateTime(now),
      'EVENT_RETROACTIVE',
      event.id,
      event.type.name,
    ];
    if (startWindow != null) {
      parts.add(startWindow);
    }
    if (stopWindow != null) {
      parts.add(stopWindow);
    }
    await _append(parts.join('\t'));
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
    await _append('${_timestamp()}\tGLOBAL_TRACKING\toff');
  }

  Future<void> logTrackingResumed() async {
    await _append('${_timestamp()}\tGLOBAL_TRACKING\ton');
  }
}
