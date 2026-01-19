import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import 'notification_service.dart';

class EventStore {
  static const _key = 'worn_active_events';
  static EventStore? _instance;
  SharedPreferences? _prefs;
  final List<Event> _events = [];

  EventStore._();

  static EventStore get instance {
    _instance ??= EventStore._();
    return _instance!;
  }

  Future<void> _ensureLoaded() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    final json = _prefs!.getString(_key);
    if (json != null) {
      final list = jsonDecode(json) as List;
      _events.clear();
      _events.addAll(list.map((e) => Event.fromMap(e as Map<String, dynamic>)));
    }
  }

  Future<void> _save() async {
    final json = jsonEncode(_events.map((e) => e.toMap()).toList());
    await _prefs!.setString(_key, json);
  }

  Future<List<Event>> getActiveEvents() async {
    await _ensureLoaded();
    return List.unmodifiable(_events);
  }

  Future<void> startEvent(Event event) async {
    await _ensureLoaded();
    _events.add(event);
    await _save();
    await NotificationService.instance.updateNotification(_events);
  }

  Future<void> stopEvent(String id) async {
    await _ensureLoaded();
    _events.removeWhere((e) => e.id == id);
    await _save();
    await NotificationService.instance.updateNotification(_events);
  }
}
