
[![Build Android APK](https://github.com/remrama/worn/actions/workflows/build-android.yml/badge.svg)](https://github.com/remrama/worn/actions/workflows/build-android.yml)
---

<br>
<div align="center">
    <img src="./logo/banner.png" alt="Worn banner" width="300">
</div>

A minimal Flutter app for logging wearable device status and event detection.

## Features

- **Logs tab**: Unified view for devices and active events
  - Add/edit devices with name and optional serial number
  - Tap chip to set device location (loose, charging, or body part)
  - Start/stop/cancel events with time window estimates for retroactive logging
  - Add timestamped notes (general or device-specific)
  - **Persistent notification**: Silent notification shows active events and their durations to remind you to stop them
  - **Tracking toggle**: Pause/resume tracking to mark periods when logs may be unreliable
- **History tab**: View raw log, copy to clipboard for parsing

## Event Types

Watch TV, In Bed, Lights Out, Walk, Run, Workout, Swim, Other (custom name)

## Log Format

Tab-separated with UTC ISO 8601 timestamps. Time windows use `..` separator:

```
2024-01-15T10:30:00.000Z	DEVICE_ADDED	uuid	MyWatch	loose	SN123
2024-01-15T10:35:00.000Z	LOCATION_CHANGED	uuid	MyWatch	loose->leftWrist
2024-01-15T11:00:00.000Z	EVENT_STARTED	uuid	walk	Walk	2024-01-15T11:00:00.000Z
2024-01-15T11:30:00.000Z	EVENT_STOPPED	uuid	walk	Walk	2024-01-15T11:00:00.000Z	2024-01-15T11:25:00.000Z..2024-01-15T11:30:00.000Z
2024-01-15T12:00:00.000Z	EVENT_CANCELLED	uuid	inBed	In Bed	2024-01-15T11:45:00.000Z
2024-01-15T12:00:00.000Z	NOTE	User added a custom note
2024-01-15T18:00:00.000Z	TRACKING_PAUSED
2024-01-17T09:00:00.000Z	TRACKING_RESUMED
```

## Setup

```bash
flutter pub get
flutter test
flutter run
```

### Web Support

This app now supports Flutter web! To build and run the web version:

```bash
flutter build web --release
# Or run in development
flutter run -d chrome
```

For maintainers: See [SETUP_VERCEL.md](SETUP_VERCEL.md) for instructions on configuring automatic web preview deployments for pull requests.

## Structure

```
lib/
├── main.dart
├── models/
│   ├── device.dart
│   └── event.dart
├── screens/
│   ├── logs_screen.dart
│   └── history_screen.dart
└── services/
    ├── device_store.dart
    ├── event_store.dart
    ├── log_service.dart
    ├── notification_service.dart
    └── tracking_service.dart
```
