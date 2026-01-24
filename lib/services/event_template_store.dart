import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../models/event_template.dart';
import 'event_store.dart';

class EventTemplateStore {
  static const _key = 'worn_event_templates';
  static EventTemplateStore? _instance;
  SharedPreferences? _prefs;
  final List<EventTemplate> _templates = [];
  bool _migrationDone = false;

  EventTemplateStore._();

  static EventTemplateStore get instance {
    _instance ??= EventTemplateStore._();
    return _instance!;
  }

  Future<void> _ensureLoaded() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    final json = _prefs!.getString(_key);
    if (json != null) {
      final list = jsonDecode(json) as List;
      _templates.clear();
      _templates.addAll(
          list.map((e) => EventTemplate.fromMap(e as Map<String, dynamic>)));
    }
  }

  Future<void> _save() async {
    final json = jsonEncode(_templates.map((t) => t.toMap()).toList());
    await _prefs!.setString(_key, json);
  }

  Future<List<EventTemplate>> getTemplates() async {
    await _ensureLoaded();
    return List.unmodifiable(_templates);
  }

  Future<void> addTemplate(EventTemplate template) async {
    await _ensureLoaded();
    // Check for duplicate (same type and customName for "other")
    final exists = _templates.any((t) =>
        t.type == template.type &&
        (template.type != EventType.other ||
            t.customName == template.customName));
    if (exists) {
      throw Exception('Event type already exists');
    }
    _templates.add(template);
    await _save();
  }

  Future<void> removeTemplate(String id) async {
    await _ensureLoaded();
    // Check if there's an active event for this template
    final template = _templates.firstWhere(
      (t) => t.id == id,
      orElse: () => throw Exception('Template with id $id not found'),
    );
    final activeEvents = await EventStore.instance.getActiveEvents();
    final isActive = activeEvents.any((e) => template.matchesEvent(e));
    if (isActive) {
      throw Exception('Cannot remove template while event is active');
    }
    _templates.removeWhere((t) => t.id == id);
    await _save();
  }

  /// Migrate existing active events to templates.
  /// Only runs once per session to avoid repeated SharedPreferences reads.
  Future<void> migrateFromActiveEvents() async {
    if (_migrationDone) return;
    _migrationDone = true;

    await _ensureLoaded();
    final activeEvents = await EventStore.instance.getActiveEvents();
    for (final event in activeEvents) {
      final exists = _templates.any((t) => t.matchesEvent(event));
      if (!exists) {
        _templates.add(EventTemplate(
          type: event.type,
          customName: event.customName,
        ));
      }
    }
    if (activeEvents.isNotEmpty) {
      await _save();
    }
  }
}
