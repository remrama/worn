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

  Future<void> _stopEvent(Event event) async {
    final now = DateTime.now().toUtc();
    final duration = now.difference(event.startTime);
    await EventStore.instance.stopEvent(event.id);
    await LogService.instance.logEventStopped(event, duration);
    _load();
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
                    final duration = DateTime.now().toUtc().difference(e.startTime);
                    return ListTile(
                      leading: Icon(_iconFor(e.type)),
                      title: Text(e.displayName),
                      subtitle: Text('Started: ${_formatTime(e.startTime)} (${_formatDuration(duration)})'),
                      trailing: IconButton(
                        icon: const Icon(Icons.stop, color: Colors.red),
                        onPressed: () => _stopEvent(e),
                        tooltip: 'Stop',
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startEvent,
        child: const Icon(Icons.add),
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
        TextButton(onPressed: _submit, child: const Text('Start')),
      ],
    );
  }
}
