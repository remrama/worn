import 'dart:async';
import 'package:flutter/material.dart';
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
      'Logging is currently paused. Enable tracking to add devices, events, or notes.';
  
  List<Device> _devices = [];
  List<Event> _events = [];
  bool _loading = true;
  bool _isTracking = true;
  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _durationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
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
    // Update notification to reflect current events with freshly calculated durations
    await NotificationService.instance.updateNotification(events);
  }

  Future<void> _toggleTracking() async {
    final newValue = !_isTracking;
    await TrackingService.instance.setTracking(newValue);
    if (newValue) {
      await LogService.instance.logTrackingResumed();
    } else {
      await LogService.instance.logTrackingPaused();
    }
    setState(() {
      _isTracking = newValue;
    });
  }

  // Device methods
  Future<void> _addDevice() async {
    if (!_isTracking) {
      _showTrackingPausedWarning();
      return;
    }
    final result = await showDialog<DeviceDialogResult>(
      context: context,
      builder: (ctx) => const DeviceDialog(),
    );
    if (result != null && result.device != null) {
      try {
        await DeviceStore.instance.addDevice(result.device!);
        await LogService.instance.logDeviceAdded(result.device!);
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
      if (!_isTracking) {
        _showTrackingPausedWarning();
        return;
      }
      await DeviceStore.instance.deleteDevice(device.id);
      await LogService.instance.logDeviceDeleted(device);
      _load();
      return;
    }

    if (result.device != null) {
      try {
        await DeviceStore.instance.updateDevice(result.device!);
        if (_isTracking) {
          // Log power change separately if it changed
          if (device.isPoweredOn != result.device!.isPoweredOn) {
            await LogService.instance.logDevicePowerChanged(result.device!, result.device!.isPoweredOn);
          }
          await LogService.instance.logDeviceEdited(device, result.device!);
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

  Future<void> _changeLocation(Device device) async {
    if (!_isTracking) {
      _showTrackingPausedWarning();
      return;
    }
    final newLocation = await showDialog<DeviceLocation>(
      context: context,
      builder: (ctx) => LocationPickerDialog(
        currentLocation: device.location,
        deviceType: device.deviceType,
      ),
    );
    if (newLocation != null && newLocation != device.location) {
      final oldLocation = device.location;
      final updated = device.copyWith(location: newLocation);
      await DeviceStore.instance.updateDevice(updated);
      await LogService.instance.logLocationChanged(device, oldLocation, newLocation);
      _load();
    }
  }

  Future<void> _addDeviceNote(Device device) async {
    if (!_isTracking) {
      _showTrackingPausedWarning();
      return;
    }
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => NoteDialog(deviceName: device.name),
    );
    if (note != null && note.trim().isNotEmpty) {
      await LogService.instance.logNote(note.trim(), device: device);
    }
  }

  Future<void> _addEventNote(Event event) async {
    if (!_isTracking) {
      _showTrackingPausedWarning();
      return;
    }
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
    if (!_isTracking) {
      _showTrackingPausedWarning();
      return;
    }
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
      _load();
    }
  }

  Future<void> _cancelEvent(Event event) async {
    if (!_isTracking) {
      _showTrackingPausedWarning();
      return;
    }
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
      _load();
    }
  }

  // Note method
  Future<void> _addNote() async {
    if (!_isTracking) {
      _showTrackingPausedWarning();
      return;
    }
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

  Widget _locationChip(Device d) {
    Color color;
    if (d.location == DeviceLocation.loose) {
      color = Colors.grey;
    } else if (d.location == DeviceLocation.charging) {
      color = Colors.orange;
    } else {
      color = Colors.green;
    }
    return GestureDetector(
      onTap: () => _changeLocation(d),
      child: Chip(
        label: Text(Device.locationLabel(d.location), style: const TextStyle(fontSize: 12)),
        backgroundColor: color.withValues(alpha: 0.2),
        side: BorderSide(color: color),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
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
                      _locationChip(d),
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
                      icon: const Icon(Icons.cancel, color: Colors.orange),
                      onPressed: () => _cancelEvent(e),
                      tooltip: 'Cancel',
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop, color: Colors.red),
                      onPressed: () => _stopEvent(e),
                      tooltip: 'Stop',
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
  late bool _isPoweredOn;

  @override
  void initState() {
    super.initState();
    if (widget.device != null) {
      _nameController.text = widget.device!.name;
      _snController.text = widget.device!.serialNumber ?? '';
      _selectedType = widget.device!.deviceType;
      _isPoweredOn = widget.device!.isPoweredOn;
    } else {
      _selectedType = DeviceType.watch;
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

    // Preserve existing location only if it's valid for the selected type,
    // otherwise fall back to a safe default.
    DeviceLocation location = DeviceLocation.loose;
    if (widget.device != null) {
      final existingLocation = widget.device!.location;
      final availableLocations = Device.availableLocationsFor(_selectedType);
      if (availableLocations.contains(existingLocation)) {
        location = existingLocation;
      }
    }

    final device = Device(
      id: widget.device?.id,
      name: name,
      deviceType: _selectedType,
      location: location,
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
            DropdownButtonFormField<DeviceType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(labelText: 'Device Type'),
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
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _snController,
              decoration: const InputDecoration(labelText: 'Serial Number (optional)'),
            ),
            if (isEdit) ...[
              const SizedBox(height: 16),
              const Divider(),
              SwitchListTile(
                title: const Text('Powered On'),
                value: _isPoweredOn,
                onChanged: (v) => setState(() => _isPoweredOn = v),
                contentPadding: EdgeInsets.zero,
              ),
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

class LocationPickerDialog extends StatelessWidget {
  final DeviceLocation currentLocation;
  final DeviceType deviceType;
  const LocationPickerDialog({
    super.key,
    required this.currentLocation,
    required this.deviceType,
  });

  @override
  Widget build(BuildContext context) {
    final availableLocations = Device.availableLocationsFor(deviceType);
    return AlertDialog(
      title: const Text('Set Location'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: availableLocations.length,
          itemBuilder: (ctx, i) {
            final loc = availableLocations[i];
            final isSelected = loc == currentLocation;
            return ListTile(
              title: Text(Device.locationLabel(loc)),
              leading: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
              onTap: () => Navigator.pop(context, loc),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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

  void _submit() {
    if (_selectedType == null) return;

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

  void _submit() {
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
