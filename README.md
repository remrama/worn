
[![Build Android APK](https://github.com/remrama/worn/actions/workflows/build-android.yml/badge.svg)](https://github.com/remrama/worn/actions/workflows/build-android.yml)
---

<br>
<div align="center">
    <img src="./logo/banner.png" alt="Worn banner" width="300">
</div>

**Manual logging for creating ground-truth data to evaluate wearable device algorithms.**

## What This Is

Worn is a minimalist mobile app for manually logging when you wear a device and what you're doing. The output is a timestamped log file you can use as ground truth for evaluating wearable algorithms—wear-time detection, sleep/wake classification, activity recognition, etc.

This is *not* automatic detection. It's the opposite: you manually log events so you have a reference to compare against automated outputs from commercial wearables or your own algorithms.

## Who This Is For

Researchers who need ground-truth data for wearable validation studies. Realistically, this is useful to maybe 5 people in the world. If you're evaluating Fitbit's sleep detection or building your own wear-time classifier, you need to know when someone *actually* went to bed or *actually* wore the device. Worn makes that logging less painful.

## Primary Use Cases

- **Wear-time validation**: Log when a device is on your body vs. loose/charging, to evaluate wear-time detection algorithms
- **Sleep tracking validation**: Log bedtime, lights-out, and wake windows to compare against automatic sleep staging
- **Activity labeling**: Mark activity windows (walking, running, etc.) as ground truth for activity classification

## Design Philosophy

Minimalist, borderline brutalist. No bells and whistles—just logging. The target audience is tiny and technical, so the UI prioritizes function over polish.

## Features

- **Logs tab**: Add devices, set their location (body part, loose, charging), start/stop events
- **History tab**: View and export raw log for external parsing
- **Persistent notifications**: Reminds you to stop active events so you don't forget
- **Time windows**: Support for "earliest/latest" timestamps when logging retroactively
- **Tracking toggle**: Pause logging during periods of unreliable data

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
