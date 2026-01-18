
[![Build Android APK](https://github.com/remrama/worn/actions/workflows/build-android.yml/badge.svg)](https://github.com/remrama/worn/actions/workflows/build-android.yml)
---

<br>
<div align="center">
    <img src="./logo/banner.png" alt="Worn banner" width="300">
</div>

A minimal Flutter app for logging wearable device status and event detection.

## Features

- **Devices tab**: Add/edit devices with name and optional serial number
- **Location tracking**: Tap chip to set location (loose, charging, or body part)
- **Notes**: Add timestamped notes to the log
- **History tab**: View raw log, copy to clipboard for parsing

## Log Format

Tab-separated:

```
2024-01-15T10:30:00.000Z	DEVICE_ADDED	uuid	MyWatch	loose	SN123
2024-01-15T10:35:00.000Z	LOCATION_CHANGED	uuid	MyWatch	loose->leftWrist
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
├── models/device.dart
├── screens/devices_screen.dart
├── screens/history_screen.dart
└── services/
    ├── device_store.dart
    └── log_service.dart
```
