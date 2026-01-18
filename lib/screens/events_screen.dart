import 'dart:async';
import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/event_store.dart';
import '../services/log_service.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<Event> _events = [];
  bool _loading = true;
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
    final events = await EventStore.instance.getActiveEvents();
    setState(() {
      _events = events;
      _loading = false;
    });
  }

  Future<void> _startEvent() async {
    final result = await showDialog<Event>(
      context: context,
      builder: (ctx) => const EventPickerDialog(),
    );
    if (result != null) {
      await EventStore.instance.startEvent(result);
      await LogService.instance.logEventStarted(result);
      _load();
    }
  }

  Future<void> _addRetroactiveEvent() async {
    final result = await showDialog<RetroactiveEventResult>(
      context: context,
      builder: (ctx) => const RetroactiveEventDialog(),
    );
    if (result != null) {
      await LogService.instance.logRetroactiveEvent(
        result.event,
        result.stopEarliest,
        result.stopLatest,
      );
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
      _load();
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? const Center(child: Text('No active events. Tap + to start one.'))
              : ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (ctx, i) {
                    final e = _events[i];
                    final duration = DateTime.now().toUtc().difference(e.startEarliest);
                    return ListTile(
                      leading: Icon(_iconFor(e.type)),
                      title: Text(e.displayName),
                      subtitle: Text('Started: ${_formatStartTime(e)} (${_formatDuration(duration)})'),
                      trailing: IconButton(
                        icon: const Icon(Icons.stop, color: Colors.red),
                        onPressed: () => _stopEvent(e),
                        tooltip: 'Stop',
                      ),
                    );
                  },
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'retroactive',
            onPressed: _addRetroactiveEvent,
            tooltip: 'Add past event',
            child: const Icon(Icons.history),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'start',
            onPressed: _startEvent,
            tooltip: 'Start event',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class EventPickerDialog extends StatelessWidget {
  const EventPickerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start Event'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: EventType.values.length,
          itemBuilder: (ctx, i) {
            final type = EventType.values[i];
            return ListTile(
              title: Text(Event.labelFor(type)),
              onTap: () async {
                if (type == EventType.other) {
                  final customName = await showDialog<String>(
                    context: context,
                    builder: (ctx) => const CustomEventNameDialog(),
                  );
                  if (customName != null && customName.trim().isNotEmpty && context.mounted) {
                    Navigator.pop(context, Event(type: type, customName: customName.trim()));
                  }
                } else {
                  Navigator.pop(context, Event(type: type));
                }
              },
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
  bool _useWindow = false;
  TimeOfDay? _earliestTime;
  TimeOfDay? _latestTime;

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    _earliestTime = now;
    _latestTime = now;
  }

  Future<void> _pickTime(bool isEarliest) async {
    final initial = isEarliest ? _earliestTime! : _latestTime!;
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

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:$m $ampm';
  }

  void _submit() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_useWindow) {
      final earliest = today.add(Duration(hours: _earliestTime!.hour, minutes: _earliestTime!.minute)).toUtc();
      final latest = today.add(Duration(hours: _latestTime!.hour, minutes: _latestTime!.minute)).toUtc();
      Navigator.pop(context, StopEventResult(stopEarliest: earliest, stopLatest: latest));
    } else {
      final stopTime = DateTime.now().toUtc();
      Navigator.pop(context, StopEventResult(stopEarliest: stopTime, stopLatest: stopTime));
    }
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
            CheckboxListTile(
              title: const Text('Estimate stop time'),
              subtitle: const Text('Enter a time window instead of now'),
              value: _useWindow,
              onChanged: (v) => setState(() => _useWindow = v ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            if (_useWindow) ...[
              const SizedBox(height: 16),
              const Text('Earliest stop time:', style: TextStyle(fontWeight: FontWeight.bold)),
              ListTile(
                title: Text(_formatTimeOfDay(_earliestTime!)),
                trailing: const Icon(Icons.access_time),
                onTap: () => _pickTime(true),
                contentPadding: EdgeInsets.zero,
              ),
              const Text('Latest stop time:', style: TextStyle(fontWeight: FontWeight.bold)),
              ListTile(
                title: Text(_formatTimeOfDay(_latestTime!)),
                trailing: const Icon(Icons.access_time),
                onTap: () => _pickTime(false),
                contentPadding: EdgeInsets.zero,
              ),
            ],
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

class RetroactiveEventResult {
  final Event event;
  final DateTime stopEarliest;
  final DateTime stopLatest;

  RetroactiveEventResult({
    required this.event,
    required this.stopEarliest,
    required this.stopLatest,
  });
}

class RetroactiveEventDialog extends StatefulWidget {
  const RetroactiveEventDialog({super.key});

  @override
  State<RetroactiveEventDialog> createState() => _RetroactiveEventDialogState();
}

class _RetroactiveEventDialogState extends State<RetroactiveEventDialog> {
  EventType? _selectedType;
  String? _customName;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startEarliest = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _startLatest = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _stopEarliest = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _stopLatest = const TimeOfDay(hour: 13, minute: 0);

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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime(String which) async {
    TimeOfDay initial;
    switch (which) {
      case 'startEarliest':
        initial = _startEarliest;
      case 'startLatest':
        initial = _startLatest;
      case 'stopEarliest':
        initial = _stopEarliest;
      case 'stopLatest':
        initial = _stopLatest;
      default:
        return;
    }

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        switch (which) {
          case 'startEarliest':
            _startEarliest = picked;
          case 'startLatest':
            _startLatest = picked;
          case 'stopEarliest':
            _stopEarliest = picked;
          case 'stopLatest':
            _stopLatest = picked;
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
      startEarliest: _combineDateTime(_selectedDate, _startEarliest),
      startLatest: _combineDateTime(_selectedDate, _startLatest),
    );

    Navigator.pop(
      context,
      RetroactiveEventResult(
        event: event,
        stopEarliest: _combineDateTime(_selectedDate, _stopEarliest),
        stopLatest: _combineDateTime(_selectedDate, _stopLatest),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventLabel = _selectedType != null
        ? (_customName ?? Event.labelFor(_selectedType!))
        : 'Select event type';

    return AlertDialog(
      title: const Text('Add Past Event'),
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
            ListTile(
              title: const Text('Date'),
              subtitle: Text(_formatDate(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            const Text('Start Time Window', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Earliest'),
                    subtitle: Text(_formatTimeOfDay(_startEarliest)),
                    onTap: () => _pickTime('startEarliest'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('Latest'),
                    subtitle: Text(_formatTimeOfDay(_startLatest)),
                    onTap: () => _pickTime('startLatest'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const Divider(),
            const Text('Stop Time Window', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Earliest'),
                    subtitle: Text(_formatTimeOfDay(_stopEarliest)),
                    onTap: () => _pickTime('stopEarliest'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('Latest'),
                    subtitle: Text(_formatTimeOfDay(_stopLatest)),
                    onTap: () => _pickTime('stopLatest'),
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
        TextButton(
          onPressed: _selectedType != null ? _submit : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
