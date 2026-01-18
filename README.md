
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
  - Start/stop events with time window estimates for retroactive logging
  - Add timestamped notes (general or device-specific)
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
2024-01-15T12:00:00.000Z	NOTE	User added a custom note
```

## Setup

```bash
flutter pub get
flutter test
flutter run
```

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
    └── log_service.dart
```
