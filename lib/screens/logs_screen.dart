import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/device.dart';
import '../models/event.dart';
import '../services/device_store.dart';
import '../services/event_store.dart';
import '../services/log_service.dart';
import '../services/notification_service.dart';
import '../services/tracking_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  static const String _trackingPausedMessage =
      'Only device configurations and notes can be updated while tracking is paused.';

  List<Device> _devices = [];
  List<Event> _events = [];
  bool _loading = true;
  bool _isTracking = true;
  Timer? _durationTimer;
  StreamSubscription<String>? _statusSubscription;
  StreamSubscription<EventNotificationAction>? _eventActionSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _durationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _statusSubscription = NotificationService.instance.onDeviceStatusChanged.listen(
      (_) => _load(),
      onError: (Object error) {
        debugPrint('Error in onDeviceStatusChanged stream: $error');
      },
    );
    _eventActionSubscription = NotificationService.instance.onEventAction.listen(
      _handleEventAction,
      onError: (Object error) {
        debugPrint('Error in onEventAction stream: $error');
      },
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _statusSubscription?.cancel();
    _eventActionSubscription?.cancel();
    super.dispose();
  }

  /// Handle event actions from notification buttons (Note/Stop/Cancel).
  void _handleEventAction(EventNotificationAction action) {
    if (!mounted) return;

    // Find the event by ID
    final event = _events.where((e) => e.id == action.eventId).firstOrNull;
    if (event == null) {
      _load(); // Refresh in case events changed
      return;
    }

    // Trigger the appropriate dialog
    switch (action.action) {
      case 'note':
        _addEventNote(event);
      case 'stop':
        _stopEvent(event);
      case 'cancel':
        _cancelEvent(event);
      default:
        debugPrint('Unknown event action: ${action.action}');
    }
  }

  Future<void> _load() async {
    final devices = await DeviceStore.instance.getDevices();
    final events = await EventStore.instance.getActiveEvents();
    final isTracking = await TrackingService.instance.isTracking();
    setState(() {
      _devices = devices;
      _events = events;
      _isTracking = isTracking;
      _loading = false;
    });
    // Update notifications only when tracking is active
    // Check mounted to avoid unnecessary work after widget disposal
    if (!mounted) return;
    if (isTracking) {
      await NotificationService.instance.updateAllEventNotifications(events);
      await NotificationService.instance.updateAllDeviceNotifications(devices);
    } else {
      await NotificationService.instance.cancelAllEventNotifications(events);
      await NotificationService.instance.cancelAllDeviceNotifications(devices);
    }
  }

  Future<void> _toggleTracking() async {
    final newValue = !_isTracking;
    // Prevent turning off tracking while events are active
    if (!newValue && _events.isNotEmpty) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Active Events'),
            content: const Text('Tracking cannot be paused while an event is active.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
      return;
    }
    await TrackingService.instance.setTracking(newValue);
    if (newValue) {
      await LogService.instance.logTrackingResumed();
      // Restore device notifications when tracking resumes
      await NotificationService.instance.updateAllDeviceNotifications(_devices);
    } else {
      await LogService.instance.logTrackingPaused();
      // Cancel device notifications when tracking is paused
      await NotificationService.instance.cancelAllDeviceNotifications(_devices);
    }
    setState(() {
      _isTracking = newValue;
    });
  }

  // Device methods
  Future<void> _addDevice() async {
    final result = await showDialog<DeviceDialogResult>(
      context: context,
      builder: (ctx) => const DeviceDialog(),
    );
    if (result != null && result.device != null) {
      try {
        await DeviceStore.instance.addDevice(result.device!);
        await LogService.instance.logDeviceAdded(result.device!);
        if (result.device!.isPoweredOn) {
          await NotificationService.instance.updateDeviceNotification(result.device!);
        }
        _load();
      } catch (e) {
        if (e.toString().contains('Device name must be unique')) {
          _showDuplicateNameError();
        } else {
          rethrow;
        }
      }
    }
  }

  Future<void> _editDevice(Device device) async {
    final result = await showDialog<DeviceDialogResult>(
      context: context,
      builder: (ctx) => DeviceDialog(device: device),
    );
    if (result == null) return;

    if (result.deleteRequested) {
      await DeviceStore.instance.deleteDevice(device.id);
      await LogService.instance.logDeviceDeleted(device);
      await NotificationService.instance.cancelDeviceNotification(device.id);
      _load();
      return;
    }

    if (result.device != null) {
      try {
        await DeviceStore.instance.updateDevice(result.device!);
        await LogService.instance.logDeviceUpdated(device, result.device!);
        // Update or cancel notification based on power state
        if (result.device!.isPoweredOn) {
          await NotificationService.instance.updateDeviceNotification(result.device!);
        } else {
          await NotificationService.instance.cancelDeviceNotification(result.device!.id);
        }
        _load();
      } catch (e) {
        if (e.toString().contains('Device name must be unique')) {
          _showDuplicateNameError();
        } else {
          rethrow;
        }
      }
    }
  }

  Future<void> _showDuplicateNameError() async {
    if (mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Device name must be unique and cannot be the same as any active device.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  Future<void> _showTrackingPausedWarning() async {
    if (mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tracking Paused'),
          content: const Text(_trackingPausedMessage),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  Future<void> _changeStatus(
    Device device,
    DeviceStatus newStatus, {
    DateTime? effectiveTime,
  }) async {
    if (!_isTracking) {
      _showTrackingPausedWarning();
      return;
    }
    if (newStatus == device.status) return;
    final updated = device.copyWith(status: newStatus);
    await DeviceStore.instance.updateDevice(updated);
    await LogService.instance.logDeviceUpdated(
      device,
      updated,
      effectiveTime: effectiveTime,
    );
    await NotificationService.instance.updateDeviceNotification(updated);
    _load();
  }

  Future<void> _showBackdateStatusSheet(Device device, DeviceStatus newStatus) async {
    if (!_isTracking) {
      _showTrackingPausedWarning();
      return;
    }

    final now = DateTime.now();
    final result = await showModalBottomSheet<DateTime?>(
      context: context,
      builder: (ctx) => _BackdateBottomSheet(now: now),
    );

    if (result != null && mounted) {
      await _changeStatus(device, newStatus, effectiveTime: result);
    }
  }

  Future<void> _addDeviceNote(Device device) async {
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => NoteDialog(deviceName: device.name),
    );
    if (note != null && note.trim().isNotEmpty) {
      await LogService.instance.logNote(note.trim(), device: device);
    }
  }

  Future<void> _addEventNote(Event event) async {
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => NoteDialog(eventName: event.displayName),
    );
    if (note != null && note.trim().isNotEmpty) {
      await LogService.instance.logNote(note.trim(), event: event);
    }
  }

  // Event methods
  Future<void> _addEvent() async {
    if (!_isTracking) {
      _showTrackingPausedWarning();
      return;
    }
    final result = await showDialog<AddEventResult>(
      context: context,
      builder: (ctx) => const AddEventDialog(),
    );
    if (result != null) {
      if (result.includeStop) {
        await LogService.instance.logRetroactiveEvent(
          result.event,
          result.stopEarliest!,
          result.stopLatest!,
        );
      } else {
        await EventStore.instance.startEvent(result.event);
        await LogService.instance.logEventStarted(result.event);
        _load();
      }
    }
  }

  Future<void> _stopEvent(Event event) async {
    final result = await showDialog<StopEventResult>(
      context: context,
      builder: (ctx) => StopEventDialog(event: event),
    );
    if (result != null) {
      await EventStore.instance.stopEvent(event.id);
      await LogService.instance.logEventStopped(
        event,
        result.stopEarliest,
        result.stopLatest,
      );
      await NotificationService.instance.cancelEventNotification(event.id);
      _load();
    }
  }

  Future<void> _cancelEvent(Event event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Event'),
        content: Text('Cancel "${event.displayName}"? This will log that the event was cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel Event')),
        ],
      ),
    );
    if (confirm == true) {
      await EventStore.instance.stopEvent(event.id);
      await LogService.instance.logEventCancelled(event);
      await NotificationService.instance.cancelEventNotification(event.id);
      _load();
    }
  }

  // Note method
  Future<void> _addNote() async {
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => const NoteDialog(),
    );
    if (note != null && note.trim().isNotEmpty) {
      await LogService.instance.logNote(note.trim());
    }
  }

  // Formatting helpers
  IconData _iconFor(EventType type) {
    switch (type) {
      case EventType.watchTv:
        return Icons.tv;
      case EventType.inBed:
        return Icons.bed;
      case EventType.lightsOut:
        return Icons.nightlight;
      case EventType.walk:
        return Icons.directions_walk;
      case EventType.run:
        return Icons.directions_run;
      case EventType.workout:
        return Icons.fitness_center;
      case EventType.swim:
        return Icons.pool;
      case EventType.other:
        return Icons.event;
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:$m $ampm';
  }

  String _formatStartTime(Event e) {
    if (e.hasStartWindow) {
      return '${_formatTime(e.startEarliest)} - ${_formatTime(e.startLatest)}';
    }
    return _formatTime(e.startEarliest);
  }

  Widget _statusToggle(Device d) {
    Widget buildButton(DeviceStatus status, String label, Color activeColor) {
      final isSelected = d.status == status;
      return GestureDetector(
        onTap: () => _changeStatus(d, status),
        onLongPress: () => _showBackdateStatusSheet(d, status),
        child: Container(
          constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : null,
            border: Border.all(color: activeColor.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : null,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildButton(DeviceStatus.worn, 'W', Colors.orange),
        const SizedBox(width: 2),
        buildButton(DeviceStatus.loose, 'L', Colors.grey),
        const SizedBox(width: 2),
        buildButton(DeviceStatus.charging, 'C', Colors.green),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Logs')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        backgroundColor: _isTracking ? null : Colors.orange.shade100,
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isTracking ? 'Tracking' : 'Paused',
                style: TextStyle(
                  fontSize: 12,
                  color: _isTracking ? Colors.green : Colors.orange.shade800,
                ),
              ),
              Switch(
                value: _isTracking,
                onChanged: (_) => _toggleTracking(),
                activeThumbColor: Colors.green,
                inactiveThumbColor: Colors.orange,
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        children: [
          // Devices section
          const ListTile(
            title: Text('Devices', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            dense: true,
          ),
          if (_devices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('No devices added yet.', style: TextStyle(color: Colors.grey)),
            )
          else
            ..._devices.map((d) => ListTile(
                  leading: Opacity(
                    opacity: d.isPoweredOn ? 1.0 : 0.3,
                    child: Icon(Device.iconFor(d.deviceType)),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(d.name),
                      if (d.serialNumber != null)
                        Text(
                          d.serialNumber!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _statusToggle(d),
                      IconButton(
                        icon: const Icon(Icons.note_add, size: 20),
                        onPressed: () => _addDeviceNote(d),
                        tooltip: 'Add note',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editDevice(d),
                        tooltip: 'Edit',
                      ),
                    ],
                  ),
                )),
          const Divider(),
          // Events section
          const ListTile(
            title: Text('Active Events', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            dense: true,
          ),
          if (_events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('No active events.', style: TextStyle(color: Colors.grey)),
            )
          else
            ..._events.map((e) {
              final duration = DateTime.now().toUtc().difference(e.startEarliest);
              return ListTile(
                leading: Icon(_iconFor(e.type)),
                title: Text(e.displayName),
                subtitle: Text('Started: ${_formatStartTime(e)} (${_formatDuration(duration)})'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.note_add, size: 20),
                      onPressed: () => _addEventNote(e),
                      tooltip: 'Add note',
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop, color: Colors.orange),
                      onPressed: () => _stopEvent(e),
                      tooltip: 'Stop',
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _cancelEvent(e),
                      tooltip: 'Cancel',
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'note',
            onPressed: _addNote,
            tooltip: 'Add note',
            child: const Icon(Icons.note_add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'event',
            onPressed: _addEvent,
            tooltip: 'Add event',
            child: const Icon(Icons.event),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'device',
            onPressed: _addDevice,
            tooltip: 'Add device',
            child: const Icon(Icons.watch),
          ),
        ],
      ),
    );
  }
}

// Device dialog result
class DeviceDialogResult {
  final Device? device;
  final bool deleteRequested;

  DeviceDialogResult.save(Device this.device) : deleteRequested = false;
  DeviceDialogResult.delete() : device = null, deleteRequested = true;
}

// Device dialogs
class DeviceDialog extends StatefulWidget {
  final Device? device;
  const DeviceDialog({super.key, this.device});

  @override
  State<DeviceDialog> createState() => _DeviceDialogState();
}

class _DeviceDialogState extends State<DeviceDialog> {
  final _nameController = TextEditingController();
  final _snController = TextEditingController();
  late DeviceType _selectedType;
  late DeviceLocation _selectedLocation;
  late DeviceStatus _selectedStatus;
  late bool _isPoweredOn;

  @override
  void initState() {
    super.initState();
    if (widget.device != null) {
      _nameController.text = widget.device!.name;
      _snController.text = widget.device!.serialNumber ?? '';
      _selectedType = widget.device!.deviceType;
      _selectedLocation = widget.device!.location;
      _selectedStatus = widget.device!.status;
      _isPoweredOn = widget.device!.isPoweredOn;
    } else {
      _selectedType = DeviceType.watch;
      _selectedLocation = Device.defaultLocationFor(DeviceType.watch);
      _selectedStatus = DeviceStatus.loose;
      _isPoweredOn = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _snController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final sn = _snController.text.trim();

    final device = Device(
      id: widget.device?.id,
      name: name,
      deviceType: _selectedType,
      status: widget.device?.status ?? _selectedStatus,
      location: _selectedLocation,
      serialNumber: sn.isEmpty ? null : sn,
      isPoweredOn: _isPoweredOn,
    );
    Navigator.pop(context, DeviceDialogResult.save(device));
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text('Delete "${widget.device!.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      Navigator.pop(context, DeviceDialogResult.delete());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.device != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Device' : 'Add Device'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Device Type'),
              child: DropdownButton<DeviceType>(
                value: _selectedType,
                isExpanded: true,
                underline: const SizedBox(),
                items: DeviceType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(Device.iconFor(type), size: 20),
                        const SizedBox(width: 8),
                        Text(Device.typeLabel(type)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                      // Reset location to default if current is not valid for new type
                      final availableLocations = Device.availableLocationsFor(value);
                      if (!availableLocations.contains(_selectedLocation)) {
                        _selectedLocation = Device.defaultLocationFor(value);
                      }
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Body Location'),
              child: DropdownButton<DeviceLocation>(
                value: _selectedLocation,
                isExpanded: true,
                underline: const SizedBox(),
                items: Device.availableLocationsFor(_selectedType).map((loc) {
                  return DropdownMenuItem(
                    value: loc,
                    child: Text(Device.locationLabel(loc)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedLocation = value);
                  }
                },
              ),
            ),
            if (!isEdit) ...[
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Initial Status'),
                child: DropdownButton<DeviceStatus>(
                  value: _selectedStatus,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: DeviceStatus.values.map((status) {
                    final label = switch (status) {
                      DeviceStatus.worn => 'Worn (W)',
                      DeviceStatus.loose => 'Loose (L)',
                      DeviceStatus.charging => 'Charging (C)',
                    };
                    return DropdownMenuItem(
                      value: status,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedStatus = value);
                    }
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _snController,
              decoration: const InputDecoration(labelText: 'Serial Number (optional)'),
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            ),
            const SizedBox(height: 16),
            const Divider(),
            SwitchListTile(
              title: const Text('Powered On'),
              value: _isPoweredOn,
              onChanged: (v) => setState(() => _isPoweredOn = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (isEdit) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Device', style: TextStyle(color: Colors.red)),
                onTap: _confirmDelete,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: Text(isEdit ? 'Save' : 'Add')),
      ],
    );
  }
}

class NoteDialog extends StatefulWidget {
  final String? deviceName;
  final String? eventName;
  const NoteDialog({super.key, this.deviceName, this.eventName});

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.deviceName != null
        ? 'Note for ${widget.deviceName}'
        : widget.eventName != null
            ? 'Note for ${widget.eventName}'
            : 'Add Global Note';
    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: 'Enter your note...'),
        autofocus: true,
        maxLines: 3,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

// Event dialogs and result classes
class AddEventResult {
  final Event event;
  final bool includeStop;
  final DateTime? stopEarliest;
  final DateTime? stopLatest;

  AddEventResult({
    required this.event,
    required this.includeStop,
    this.stopEarliest,
    this.stopLatest,
  });
}

class AddEventDialog extends StatefulWidget {
  const AddEventDialog({super.key});

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  EventType? _selectedType;
  String? _customName;
  bool _includeStop = false;

  late DateTime _startEarliestDate;
  late DateTime _startLatestDate;
  late DateTime _stopEarliestDate;
  late DateTime _stopLatestDate;

  late TimeOfDay _startEarliestTime;
  late TimeOfDay _startLatestTime;
  late TimeOfDay _stopEarliestTime;
  late TimeOfDay _stopLatestTime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final nowTime = TimeOfDay.now();

    _startEarliestDate = now;
    _startLatestDate = now;
    _stopEarliestDate = now;
    _stopLatestDate = now;

    _startEarliestTime = nowTime;
    _startLatestTime = nowTime;
    _stopEarliestTime = nowTime;
    _stopLatestTime = nowTime;
  }

  Future<void> _selectType() async {
    final type = await showDialog<EventType>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Event Type'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: EventType.values.length,
            itemBuilder: (ctx, i) {
              final t = EventType.values[i];
              return ListTile(
                title: Text(Event.labelFor(t)),
                onTap: () => Navigator.pop(ctx, t),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
    if (type != null) {
      if (type == EventType.other) {
        if (!mounted) return;
        final name = await showDialog<String>(
          context: context,
          builder: (ctx) => const CustomEventNameDialog(),
        );
        if (name != null && name.trim().isNotEmpty && mounted) {
          setState(() {
            _selectedType = type;
            _customName = name.trim();
          });
        }
      } else {
        setState(() {
          _selectedType = type;
          _customName = null;
        });
      }
    }
  }

  Future<void> _pickDate(String which) async {
    DateTime initial;
    switch (which) {
      case 'startEarliest':
        initial = _startEarliestDate;
      case 'startLatest':
        initial = _startLatestDate;
      case 'stopEarliest':
        initial = _stopEarliestDate;
      case 'stopLatest':
        initial = _stopLatestDate;
      default:
        return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        switch (which) {
          case 'startEarliest':
            _startEarliestDate = picked;
          case 'startLatest':
            _startLatestDate = picked;
          case 'stopEarliest':
            _stopEarliestDate = picked;
          case 'stopLatest':
            _stopLatestDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime(String which) async {
    TimeOfDay initial;
    switch (which) {
      case 'startEarliest':
        initial = _startEarliestTime;
      case 'startLatest':
        initial = _startLatestTime;
      case 'stopEarliest':
        initial = _stopEarliestTime;
      case 'stopLatest':
        initial = _stopLatestTime;
      default:
        return;
    }

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        switch (which) {
          case 'startEarliest':
            _startEarliestTime = picked;
          case 'startLatest':
            _startLatestTime = picked;
          case 'stopEarliest':
            _stopEarliestTime = picked;
          case 'stopLatest':
            _stopLatestTime = picked;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:$m $ampm';
  }

  String _formatDate(DateTime d) {
    return '${d.month}/${d.day}/${d.year}';
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute).toUtc();
  }

  String? _validateTimes() {
    final now = DateTime.now().toUtc();
    final startEarliest = _combineDateTime(_startEarliestDate, _startEarliestTime);
    final startLatest = _combineDateTime(_startLatestDate, _startLatestTime);

    // No future start times
    if (startEarliest.isAfter(now)) {
      return 'Start earliest time cannot be in the future.';
    }
    if (startLatest.isAfter(now)) {
      return 'Start latest time cannot be in the future.';
    }

    // Start window: earliest must not be after latest
    if (startEarliest.isAfter(startLatest)) {
      return 'Start earliest time cannot be after start latest time.';
    }

    if (_includeStop) {
      final stopEarliest = _combineDateTime(_stopEarliestDate, _stopEarliestTime);
      final stopLatest = _combineDateTime(_stopLatestDate, _stopLatestTime);

      // Stop window: earliest must not be after latest
      if (stopEarliest.isAfter(stopLatest)) {
        return 'Stop earliest time cannot be after stop latest time.';
      }

      // Start must be before stop: latest start <= earliest stop
      if (startLatest.isAfter(stopEarliest)) {
        return 'Start latest time cannot be after stop earliest time.';
      }

      // Retroactive events must have non-zero duration
      if (startLatest == stopEarliest) {
        return 'Start and stop times cannot be the same for retroactive events.';
      }
    }

    return null;
  }

  Future<void> _showValidationError(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invalid Time'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _submit() {
    if (_selectedType == null) return;

    final validationError = _validateTimes();
    if (validationError != null) {
      _showValidationError(validationError);
      return;
    }

    final event = Event(
      type: _selectedType!,
      customName: _customName,
      startEarliest: _combineDateTime(_startEarliestDate, _startEarliestTime),
      startLatest: _combineDateTime(_startLatestDate, _startLatestTime),
    );

    Navigator.pop(
      context,
      AddEventResult(
        event: event,
        includeStop: _includeStop,
        stopEarliest: _includeStop ? _combineDateTime(_stopEarliestDate, _stopEarliestTime) : null,
        stopLatest: _includeStop ? _combineDateTime(_stopLatestDate, _stopLatestTime) : null,
      ),
    );
  }

  Widget _buildDateTimeRow(String label, String dateKey, String timeKey, DateTime date, TimeOfDay time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _pickDate(dateKey),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 4),
                      Text(_formatDate(date)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _pickTime(timeKey),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 4),
                      Text(_formatTimeOfDay(time)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventLabel = _selectedType != null
        ? (_customName ?? Event.labelFor(_selectedType!))
        : 'Select event type';

    return AlertDialog(
      title: const Text('Add Event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: const Text('Event Type'),
              subtitle: Text(eventLabel),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectType,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            const Text('Start Time', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildDateTimeRow('Earliest', 'startEarliest', 'startEarliest', _startEarliestDate, _startEarliestTime),
            _buildDateTimeRow('Latest', 'startLatest', 'startLatest', _startLatestDate, _startLatestTime),
            const Divider(),
            CheckboxListTile(
              title: const Text('Include stop time'),
              subtitle: const Text('Log as completed event'),
              value: _includeStop,
              onChanged: (v) => setState(() => _includeStop = v ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            if (_includeStop) ...[
              const Text('Stop Time', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildDateTimeRow('Earliest', 'stopEarliest', 'stopEarliest', _stopEarliestDate, _stopEarliestTime),
              _buildDateTimeRow('Latest', 'stopLatest', 'stopLatest', _stopLatestDate, _stopLatestTime),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: _selectedType != null ? _submit : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class CustomEventNameDialog extends StatefulWidget {
  const CustomEventNameDialog({super.key});

  @override
  State<CustomEventNameDialog> createState() => _CustomEventNameDialogState();
}

class _CustomEventNameDialogState extends State<CustomEventNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom Event Name'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: 'Enter event name...'),
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}

class StopEventResult {
  final DateTime stopEarliest;
  final DateTime stopLatest;

  StopEventResult({required this.stopEarliest, required this.stopLatest});
}

class StopEventDialog extends StatefulWidget {
  final Event event;
  const StopEventDialog({super.key, required this.event});

  @override
  State<StopEventDialog> createState() => _StopEventDialogState();
}

class _StopEventDialogState extends State<StopEventDialog> {
  late DateTime _earliestDate;
  late DateTime _latestDate;
  late TimeOfDay _earliestTime;
  late TimeOfDay _latestTime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _earliestDate = now;
    _latestDate = now;
    _earliestTime = TimeOfDay.now();
    _latestTime = TimeOfDay.now();
  }

  Future<void> _pickDate(bool isEarliest) async {
    final initial = isEarliest ? _earliestDate : _latestDate;
    final firstDate = widget.event.startEarliest.toLocal();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(firstDate.year, firstDate.month, firstDate.day),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        if (isEarliest) {
          _earliestDate = picked;
        } else {
          _latestDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime(bool isEarliest) async {
    final initial = isEarliest ? _earliestTime : _latestTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isEarliest) {
          _earliestTime = picked;
        } else {
          _latestTime = picked;
        }
      });
    }
  }

  String _formatDate(DateTime d) {
    return '${d.month}/${d.day}/${d.year}';
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:$m $ampm';
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute).toUtc();
  }

  String? _validateTimes() {
    final stopEarliest = _combineDateTime(_earliestDate, _earliestTime);
    final stopLatest = _combineDateTime(_latestDate, _latestTime);

    // Stop window: earliest must not be after latest
    if (stopEarliest.isAfter(stopLatest)) {
      return 'Stop earliest time cannot be after stop latest time.';
    }

    // Start must be before stop: event's latest start <= stop earliest
    if (widget.event.startLatest.isAfter(stopEarliest)) {
      return 'Stop earliest time cannot be before the event\'s latest possible start time.';
    }

    return null;
  }

  Future<void> _showValidationError(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invalid Time'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _submit() {
    final validationError = _validateTimes();
    if (validationError != null) {
      _showValidationError(validationError);
      return;
    }

    final earliest = _combineDateTime(_earliestDate, _earliestTime);
    final latest = _combineDateTime(_latestDate, _latestTime);
    Navigator.pop(context, StopEventResult(stopEarliest: earliest, stopLatest: latest));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Stop "${widget.event.displayName}"'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Earliest stop:', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: Text(_formatDate(_earliestDate)),
                    leading: const Icon(Icons.calendar_today, size: 20),
                    onTap: () => _pickDate(true),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: Text(_formatTimeOfDay(_earliestTime)),
                    leading: const Icon(Icons.access_time, size: 20),
                    onTap: () => _pickTime(true),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const Text('Latest stop:', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: Text(_formatDate(_latestDate)),
                    leading: const Icon(Icons.calendar_today, size: 20),
                    onTap: () => _pickDate(false),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: Text(_formatTimeOfDay(_latestTime)),
                    leading: const Icon(Icons.access_time, size: 20),
                    onTap: () => _pickTime(false),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Stop')),
      ],
    );
  }
}

class _BackdateBottomSheet extends StatefulWidget {
  final DateTime now;
  const _BackdateBottomSheet({required this.now});

  @override
  State<_BackdateBottomSheet> createState() => _BackdateBottomSheetState();
}

class _BackdateBottomSheetState extends State<_BackdateBottomSheet> {
  String _formatTimeAgo(Duration d) {
    if (d.inMinutes < 60) {
      return '${d.inMinutes}m ago';
    }
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (minutes == 0) {
      return '${hours}h ago';
    }
    return '${hours}h ${minutes}m ago';
  }

  Future<void> _pickCustomTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.now,
      firstDate: widget.now.subtract(const Duration(days: 7)),
      lastDate: widget.now,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.now),
    );
    if (time == null || !mounted) return;

    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    // Validate not in future
    if (combined.isAfter(widget.now)) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Invalid Time'),
          content: const Text('Effective time cannot be in the future.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    if (mounted) {
      Navigator.pop(context, combined);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presets = [
      const Duration(minutes: 15),
      const Duration(minutes: 30),
      const Duration(hours: 1),
      const Duration(hours: 2),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'When did this happen?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final preset in presets)
                  ActionChip(
                    label: Text(_formatTimeAgo(preset)),
                    onPressed: () {
                      Navigator.pop(context, widget.now.subtract(preset));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickCustomTime,
              icon: const Icon(Icons.access_time),
              label: const Text('Custom time...'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
