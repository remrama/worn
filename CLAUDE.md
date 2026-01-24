# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/claude-code) when working with code in this repository.

## Project Overview

**Worn** is a minimalist Flutter app for manually logging wearable device status and events. The output is a timestamped log file that serves as ground-truth data for evaluating wearable algorithms (wear-time detection, sleep/wake classification, activity recognition).

### Purpose

This is *not* automatic detection—it's the opposite. Researchers manually log when they wear a device and what they're doing, creating reference data to compare against automated outputs from commercial wearables or custom algorithms.

### Target Audience

Researchers validating wearable algorithms. Realistically ~5 people. Primary use cases:
- **Wear-time validation**: Log when a device is on-body vs. loose/charging
- **Sleep tracking validation**: Log bedtime, lights-out, and wake windows
- **Activity labeling**: Mark activity windows as ground truth

### Design Philosophy

Minimalist, borderline brutalist. The tiny, technical audience means UI prioritizes function over polish. No feature creep—just logging.

### Core Functionality

- Add/manage wearable devices (watches, rings, bands, etc.)
- Track device status (worn, loose, charging) with quick 3-way toggle on device list
- Track device body location (set in device edit menu, only relevant when worn)
- Track device power state (on/off)
- Add tracked event types (like devices), then Start/Stop with one tap
- Long-press Start/Stop for backdated times with optional uncertainty windows
- Long-press event row to log retroactive events (start + stop in one dialog)
- Export tab-separated logs for external analysis
- Persistent notifications to prevent forgetting active events

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

# Generate app icons (only needed when updating assets/icon/icon.png)
# Generated icons are committed to the repo and used by builds automatically
dart run flutter_launcher_icons
```

## CI/CD Workflows

- **test.yml**: Runs tests and analyze on all pushes to main and PRs (fast gate)
- **build-android.yml**: Development APK builds on pushes to main
- **deploy-web-preview.yml**: Web preview deployments for all PRs to main
- **release.yml**: Production release pipeline triggered by version tags (v*.*.*)

**Note:** Icon generation (`dart run flutter_launcher_icons`) is NOT required in CI workflows. The generated icon files are already committed to the repository and used automatically during builds. Only run this command locally when updating the source icon image.

## Architecture

**Model-View-Service pattern with Singletons:**

- **Models** (`lib/models/`): Immutable data classes with copyWith, toMap/fromMap
  - Device model includes DeviceType enum (watch, ring, wristband, armband, chestStrap, headband, other)
  - Device model includes DeviceStatus enum (worn, loose, charging) for quick status toggle
  - Device model includes DeviceLocation enum for body placement (filtered by device type)
  - Device model includes isPoweredOn boolean (defaults to true for backward compatibility)
  - EventTemplate model represents tracked event types (persistent list of events user wants to track)
  - Event model represents active/running events with start time windows
- **Services** (`lib/services/`): Singleton instances for business logic and persistence
- **Screens** (`lib/screens/`): Stateful widgets using setState for state management

**No external state management framework** - uses simple setState pattern with singleton services.

## Directory Structure

```
lib/
├── main.dart              # App entry point & 2-tab navigation (Logs, History)
├── models/
│   ├── device.dart        # Device model with DeviceType, DeviceStatus & DeviceLocation enums
│   ├── event.dart         # Event model with EventType enum and time windows
│   └── event_template.dart  # EventTemplate model for tracked event types
├── screens/
│   ├── logs_screen.dart   # Unified device & event management UI with type icons
│   └── history_screen.dart  # Log viewing, export, and data wipe
├── services/
│   ├── device_store.dart  # Device persistence (singleton)
│   ├── event_store.dart   # Active event persistence (singleton)
│   ├── event_template_store.dart  # Event template persistence (singleton)
│   ├── log_service.dart   # Event logging (singleton)
│   ├── notification_service.dart  # Persistent notification for active events (singleton)
│   └── tracking_service.dart  # Tracking state persistence (singleton, defaults to paused)
└── widgets/               # Custom reusable widgets
```

## Data Persistence

Uses `SharedPreferences` with these keys:
- `worn_devices`: JSON-encoded list of device maps
- `worn_active_events`: JSON-encoded list of active event maps
- `worn_event_templates`: JSON-encoded list of tracked event type templates
- `worn_log`: Newline-separated tab-delimited log entries
- `worn_tracking`: Boolean tracking state (true = tracking, false = paused, defaults to false)

## Key Patterns

- **Singletons**: Access services via `DeviceStore.instance`, `EventStore.instance`, `EventTemplateStore.instance`, `LogService.instance`, `NotificationService.instance` and `TrackingService.instance`
- **Immutability**: Device and Event models use copyWith for updates
- **Enums**:
  - `DeviceType` (watch, ring, wristband, armband, chestStrap, headband, other) with icons
  - `DeviceStatus` (worn, loose, charging) for quick status toggle
  - `DeviceLocation` (body-specific locations filtered by device type)
  - `EventType` (inBed/lightsOut/walk/run/workout/swim/watchTv/other)
- **Time Windows**: Events support earliest/latest timestamps for retroactive logging uncertainty
- **Event Templates**: Users maintain a persistent list of event types they want to track (like devices). Each template shows Start/Stop toggle button. Tap for instant action, long-press for windowed time picker. Long-press row (when not running) for retroactive event logging.
- **Backdating**: Long-press on W/L/C status buttons or event Start/Stop buttons shows preset times (15m, 30m, 1h, 2h ago) or custom time picker for retroactive changes
- **Validation**: DeviceStore throws exceptions for duplicate device names
- **Persistent Notifications**: Silent, ongoing notifications display active events and durations (auto-updated when events start/stop)
- **Tracking State**: Defaults to paused on first launch; device config editable when paused
- **Power State**: Devices have isPoweredOn boolean (defaults to true); power changes are logged and UI shows dimmed icon when off
- **Notes**: Supports global notes, device-specific notes, and event-specific notes

## Log Format

Tab-separated entries with ISO 8601 timestamps including timezone offset (e.g., `-05:00`). Event times are handled as follows:
- **Current time** (within 60s of log time): No separate timestamp (log entry timestamp IS the event time)
- **Backdated precise time**: Single timestamp appended
- **Time window** (uncertainty): `earliest=` and `latest=` key=value pairs appended

Uses internal variable names for parsing efficiency:
```
2024-01-15T10:30:00.000-05:00	DEVICE_ADDED	uuid	name="MyWatch"	type=watch	status=loose	location=leftWrist	sn=SN123	power=on
2024-01-15T10:32:00.000-05:00	DEVICE_UPDATED	uuid	"MyWatch"	name="My Watch Renamed"	type=wristband	sn=SN456	status=worn	location=rightWrist	power=off
2024-01-15T10:45:00.000-05:00	DEVICE_UPDATED	uuid	"My Watch Renamed"	status=loose
2024-01-15T11:00:00.000-05:00	EVENT_STARTED	uuid	walk
2024-01-15T11:05:00.000-05:00	EVENT_STARTED	uuid	run	earliest=2024-01-15T11:00:00.000-05:00	latest=2024-01-15T11:05:00.000-05:00
2024-01-15T11:10:00.000-05:00	EVENT_STARTED	uuid	workout	2024-01-15T10:45:00.000-05:00
2024-01-15T11:30:00.000-05:00	EVENT_STOPPED	uuid	walk
2024-01-15T11:35:00.000-05:00	EVENT_STOPPED	uuid	run	earliest=2024-01-15T11:30:00.000-05:00	latest=2024-01-15T11:35:00.000-05:00
2024-01-15T11:40:00.000-05:00	EVENT_CANCELLED	uuid	swim
2024-01-15T12:00:00.000-05:00	GLOBAL_NOTE	User added a custom note
2024-01-15T12:05:00.000-05:00	DEVICE_NOTE	uuid	MyWatch	Device-specific note
2024-01-15T12:10:00.000-05:00	ACTIVITY_NOTE	eventId	Walk	Event-specific note
2024-01-15T18:00:00.000-05:00	GLOBAL_TRACKING	off
2024-01-17T09:00:00.000-05:00	GLOBAL_TRACKING	on
2024-01-17T09:05:00.000-05:00	DEVICE_UPDATED	uuid	"My Watch Renamed"	power=on
```

## Testing

- Unit tests in `test/device_test.dart` for Device model
- Unit tests in `test/event_test.dart` for Event model
- Unit tests in `test/event_template_test.dart` for EventTemplate model
- Widget tests in `test/widget_test.dart` for navigation UI
