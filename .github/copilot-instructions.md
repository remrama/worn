# Copilot Coding Agent Instructions

This document provides guidance for the GitHub Copilot coding agent to work efficiently with this Flutter repository.

## Repository Overview

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

### Technical Details

- **Type**: Flutter mobile application (Android/Web)
- **Language**: Dart
- **SDK**: Flutter stable channel, Dart SDK >=3.0.0 <4.0.0
- **Size**: Small (~15 source files)
- **State Management**: Simple setState pattern with singleton services (no external state management framework)

## Build Commands

**Always run commands in this order for a clean build:**

```bash
# 1. Install dependencies (REQUIRED before any other command)
flutter pub get

# 2. Generate app icons (required for builds)
dart run flutter_launcher_icons

# 3. Run linter to check for issues
flutter analyze

# 4. Format code
dart format lib test

# 5. Run tests
flutter test

# 6. Build Android APK
flutter build apk --release
```

**Key notes:**
- Always run `flutter pub get` before running tests, builds, or other commands
- The `dart run flutter_launcher_icons` step generates required app icons for builds
- Tests must pass before building; the CI workflow runs tests before building

## Project Structure

```
lib/
├── main.dart              # App entry point, 2-tab navigation (Logs, History)
├── models/
│   ├── device.dart        # Device model with DeviceLocation enum
│   └── event.dart         # Event model with EventType enum
├── screens/
│   ├── logs_screen.dart   # Unified device & event management UI
│   └── history_screen.dart  # Log viewing & export
└── services/
    ├── device_store.dart  # Device persistence (singleton)
    ├── event_store.dart   # Active event persistence (singleton)
    └── log_service.dart   # Event logging (singleton)
```

## Configuration Files

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Dependencies and Flutter configuration |
| `analysis_options.yaml` | Lint rules (uses flutter_lints package) |
| `.github/workflows/build-android.yml` | CI workflow for Android builds |

## Architecture Patterns

**Model-View-Service pattern:**
- **Models** (`lib/models/`): Immutable data classes with `copyWith`, `toMap`/`fromMap`
- **Services** (`lib/services/`): Singleton instances accessed via `ServiceName.instance`
- **Screens** (`lib/screens/`): Stateful widgets using `setState` for state management

**Data persistence:** Uses `SharedPreferences` with keys:
- `worn_devices`: JSON-encoded list of devices
- `worn_active_events`: JSON-encoded list of active events
- `worn_log`: Newline-separated tab-delimited log entries

## Linting Rules

The `analysis_options.yaml` enforces these rules:
- `prefer_const_constructors`
- `prefer_const_literals_to_create_immutables`
- `avoid_print`
- `prefer_single_quotes`
- `unnecessary_this`

Always run `flutter analyze` before committing to ensure compliance.

## Testing

Tests are located in `test/`:
- `device_test.dart`: Unit tests for Device model
- `event_test.dart`: Unit tests for Event model
- `widget_test.dart`: Widget tests for navigation UI

**Important:** The widget tests use `pump()` instead of `pumpAndSettle()` because `LogsScreen` has a `Timer.periodic` for live duration updates that would cause `pumpAndSettle()` to timeout.

Run tests: `flutter test`

## CI/CD Pipeline

The GitHub workflow (`.github/workflows/build-android.yml`) runs on:
- Push to `main` or `dev` branches
- Pull requests to `main` or `dev` branches

**CI steps executed in order:**
1. Checkout code
2. Set up Java 17 (Temurin distribution)
3. Set up Flutter (stable channel)
4. `flutter pub get`
5. `dart run flutter_launcher_icons`
6. `flutter test`
7. `flutter build apk --release`
8. Upload APK artifact

## Making Changes

1. **Before changing code:**
   - Run `flutter pub get` to ensure dependencies are installed
   - Run `flutter analyze` to understand current lint status

2. **After changing code:**
   - Run `dart format lib test` to format code
   - Run `flutter analyze` to check for lint violations
   - Run `flutter test` to verify tests pass

3. **For model changes:**
   - Update `toMap`/`fromMap` methods if serialization changes
   - Add migration handling in `fromMap` for backward compatibility
   - Add corresponding tests in `test/`

4. **For service changes:**
   - Maintain singleton pattern (`ServiceName.instance`)
   - Use async/await for SharedPreferences operations

## Common Patterns

**Creating a new model:**
```dart
class MyModel {
  final String id;
  final String name;

  MyModel({String? id, required this.name}) : id = id ?? const Uuid().v4();

  MyModel copyWith({String? name}) => MyModel(id: id, name: name ?? this.name);

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory MyModel.fromMap(Map<String, dynamic> map) =>
      MyModel(id: map['id'], name: map['name']);
}
```

**Accessing a service:**
```dart
final devices = await DeviceStore.instance.getDevices();
```

## Trust These Instructions

The information above has been validated against the actual codebase. Only perform additional searches if:
- The instructions appear incomplete for your specific task
- You encounter errors not covered here
- The codebase structure has changed

For standard development tasks (adding features, fixing bugs, updating models), these instructions provide complete guidance.
