# Worn

A minimal Flutter app for tracking wearable device status. Designed for technical researchers who need a simple log of device state changes.

## Features

- **Devices tab**: Add/edit devices with name, placement, and optional serial number
- **Status toggle**: Tap to cycle through worn/loose/charging states
- **History tab**: View raw log, copy to clipboard for parsing

## Log Format

Tab-separated, parseable with Python:

```
2024-01-15T10:30:00.000Z	DEVICE_ADDED	uuid	MyWatch	leftWrist	SN123
2024-01-15T10:35:00.000Z	STATUS_CHANGED	uuid	MyWatch	loose->worn
2024-01-15T12:00:00.000Z	DEVICE_EDITED	uuid	placement:leftWrist->rightWrist
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
