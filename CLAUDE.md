# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/claude-code) when working with code in this repository.

## Project Overview

**Worn** is a minimal Flutter application for logging wearable device status and event detection. It allows users to add/manage wearable devices (smartwatches, fitness trackers), track device location (loose, charging, or body placement), and export event logs in tab-separated format for external analysis.

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
- **Services** (`lib/services/`): Singleton instances for business logic and persistence
- **Screens** (`lib/screens/`): Stateful widgets using setState for state management

**No external state management framework** - uses simple setState pattern with singleton services.

## Directory Structure

```
lib/
├── main.dart              # App entry point & main navigation
├── models/
│   └── device.dart        # Device model with DeviceLocation enum
├── screens/
│   ├── devices_screen.dart  # Device management UI
│   └── history_screen.dart  # Log viewing & export
├── services/
│   ├── device_store.dart    # Device persistence (singleton)
│   └── log_service.dart     # Event logging (singleton)
└── widgets/               # Custom reusable widgets
```

## Data Persistence

Uses `SharedPreferences` with these keys:
- `worn_devices`: JSON-encoded list of device maps
- `worn_log`: Newline-separated tab-delimited log entries

## Key Patterns

- **Singletons**: Access services via `DeviceStore.instance` and `LogService.instance`
- **Immutability**: Device model uses copyWith for updates
- **Enums**: `DeviceLocation` (loose/charging/leftWrist/rightWrist/etc.)
- **Validation**: DeviceStore throws exceptions for duplicate device names

## Log Format

Tab-separated entries with UTC ISO 8601 timestamps:
```
2024-01-15T10:30:00.000Z	DEVICE_ADDED	uuid	MyWatch	loose	SN123
2024-01-15T10:35:00.000Z	LOCATION_CHANGED	uuid	MyWatch	loose->leftWrist
2024-01-15T10:40:00.000Z	NOTE	User added a custom note
```

## Testing

- Unit tests in `test/device_test.dart` for Device model
- Widget tests in `test/widget_test.dart` for navigation UI
