# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/claude-code) when working with code in this repository.

## Project Overview

**Worn** is a minimal Flutter application for logging wearable device status and event detection. It allows users to add/manage wearable devices (smartwatches, fitness trackers, rings, etc.), track device location (loose, charging, or body placement), track device power state (on/off), and export event logs in tab-separated format for external analysis. Device types determine available wear locations, and the app includes persistent notifications for active events.

## Key Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Run tests
flutter test

# Check for lint violations
flutter analyze

# Format code
dart format lib test

# Generate app icons
dart run flutter_launcher_icons
```

## Architecture

**Model-View-Service pattern with Singletons:**

- **Models** (`lib/models/`): Immutable data classes with copyWith, toMap/fromMap
  - Device model includes DeviceType enum (watch, ring, wristband, armband, chestStrap, headband, other)
  - Device model includes isPoweredOn boolean (defaults to true for backward compatibility)
  - Available locations filtered by device type
- **Services** (`lib/services/`): Singleton instances for business logic and persistence
- **Screens** (`lib/screens/`): Stateful widgets using setState for state management

**No external state management framework** - uses simple setState pattern with singleton services.

## Directory Structure

```
lib/
├── main.dart              # App entry point & 2-tab navigation (Logs, History)
├── models/
│   ├── device.dart        # Device model with DeviceType & DeviceLocation enums
│   └── event.dart         # Event model with EventType enum and time windows
├── screens/
│   ├── logs_screen.dart   # Unified device & event management UI with type icons
│   └── history_screen.dart  # Log viewing, export, and data wipe
├── services/
│   ├── device_store.dart  # Device persistence (singleton)
│   ├── event_store.dart   # Active event persistence (singleton)
│   ├── log_service.dart   # Event logging (singleton)
│   ├── notification_service.dart  # Persistent notification for active events (singleton)
│   └── tracking_service.dart  # Tracking state persistence (singleton, defaults to paused)
└── widgets/               # Custom reusable widgets
```

## Data Persistence

Uses `SharedPreferences` with these keys:
- `worn_devices`: JSON-encoded list of device maps
- `worn_events`: JSON-encoded list of active event maps
- `worn_log`: Newline-separated tab-delimited log entries
- `worn_tracking`: Boolean tracking state (true = tracking, false = paused, defaults to false)

## Key Patterns

- **Singletons**: Access services via `DeviceStore.instance`, `EventStore.instance`, `LogService.instance`, `NotificationService.instance` and `TrackingService.instance`
- **Immutability**: Device and Event models use copyWith for updates
- **Enums**:
  - `DeviceType` (watch, ring, wristband, armband, chestStrap, headband, other) with icons
  - `DeviceLocation` (loose, charging, plus body-specific locations filtered by device type)
  - `EventType` (watchTv/inBed/lightsOut/walk/run/workout/swim/other)
- **Time Windows**: Events support earliest/latest timestamps for retroactive logging uncertainty
- **Validation**: DeviceStore throws exceptions for duplicate device names
- **Persistent Notifications**: Silent, ongoing notifications display active events and durations (auto-updated when events start/stop)
- **Tracking State**: Defaults to paused on first launch; device config editable when paused
- **Power State**: Devices have isPoweredOn boolean (defaults to true); power changes are logged and UI shows dimmed icon when off
- **Notes**: Supports global notes, device-specific notes, and event-specific notes

## Log Format

Tab-separated entries with UTC ISO 8601 timestamps. Time windows use `..` separator. Uses internal variable names for parsing efficiency:
```
2024-01-15T10:30:00.000Z	DEVICE_ADDED	uuid	MyWatch	watch	loose	SN123
2024-01-15T10:35:00.000Z	LOCATION_CHANGED	uuid	MyWatch	leftWrist
2024-01-15T10:40:00.000Z	POWER_CHANGED	uuid	MyWatch	off
2024-01-15T11:00:00.000Z	EVENT_STARTED	uuid	walk	2024-01-15T11:00:00.000Z
2024-01-15T11:30:00.000Z	EVENT_STOPPED	uuid	walk	2024-01-15T11:00:00.000Z	2024-01-15T11:25:00.000Z..2024-01-15T11:30:00.000Z
2024-01-15T12:00:00.000Z	NOTE	User added a custom note
2024-01-15T12:05:00.000Z	NOTE	uuid	MyWatch	Device-specific note
2024-01-15T12:10:00.000Z	NOTE	eventId	Walk	Event-specific note
2024-01-15T18:00:00.000Z	TRACKING_PAUSED
2024-01-17T09:00:00.000Z	TRACKING_RESUMED
2024-01-17T09:05:00.000Z	POWER_CHANGED	uuid	MyWatch	on
```

## Testing

- Unit tests in `test/device_test.dart` for Device model
- Unit tests in `test/event_test.dart` for Event model
- Widget tests in `test/widget_test.dart` for navigation UI
