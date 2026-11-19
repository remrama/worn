
[![Build Android APK](https://github.com/remrama/worn/actions/workflows/build-android.yml/badge.svg)](https://github.com/remrama/worn/actions/workflows/build-android.yml)
---

<br>
<div align="center">
    <img src="./logo/banner.png" alt="Worn banner" width="300">
</div>
<br>

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

## Try It / Install

**Web (demo only)**: [worn-one.vercel.app](https://worn-one.vercel.app) — Good for a test drive, but not recommended for actual logging since this app requires frequent interaction and mobile access.

**Android**: Download the APK from the [latest release](https://github.com/remrama/worn/releases/latest) and sideload it. To sideload, open the downloaded APK file on your Android device and follow the prompts—you may need to enable "Install from unknown sources" in your device settings. This is the recommended way to use Worn.

**iOS**: Not available. No plans to support iOS.

## Features

- **Logs tab**: Add devices, set their location (body part, loose, charging), start/stop events
- **History tab**: View and export raw log for external parsing
- **Persistent notifications**: Reminds you to stop active events so you don't forget
- **Time windows**: Support for "earliest/latest" timestamps when logging retroactively
- **Tracking toggle**: Pause logging during periods of unreliable data

## Event Types

Watch TV, In Bed, Lights Out, Walk, Run, Workout, Swim, Other (custom name)

## Exporting Your Log

On the **History** tab, tap the share icon:

- **Share as file** (Android) sends `worn_log.txt` to Drive, email, etc. Use this one.
- **Share as text** shares the raw log as a message. It's the only option on the web demo.

## Log Format

The log is plain text, one entry per line, with fields separated by tabs. Here's a night of sleep followed by a walk logged after the fact (IDs shortened; real ones are UUIDs):

```
2024-01-14T22:00:00.000-05:00	GLOBAL_TRACKING	on
2024-01-14T22:01:00.000-05:00	DEVICE_ADDED	d1	name="Ring"	type=ring	status=worn	location=leftIndexFinger	sn=none	power=on
2024-01-14T22:30:00.000-05:00	EVENT_STARTED	e1	inBed
2024-01-14T22:50:00.000-05:00	EVENT_STARTED	e2	lightsOut	earliest=2024-01-14T22:40:00.000-05:00	latest=2024-01-14T22:45:00.000-05:00
2024-01-15T06:55:00.000-05:00	EVENT_STOPPED	e2	lightsOut	earliest=2024-01-14T22:40:00.000-05:00	latest=2024-01-14T22:45:00.000-05:00	2024-01-15T06:30:00.000-05:00
2024-01-15T07:00:00.000-05:00	EVENT_STOPPED	e1	inBed	2024-01-14T22:30:00.000-05:00
2024-01-15T07:05:00.000-05:00	DEVICE_UPDATED	d1	"Ring"	status=charging
2024-01-15T07:40:00.000-05:00	DEVICE_UPDATED	d1	"Ring"	status=worn	effective=2024-01-15T07:30:00.000-05:00
2024-01-15T07:41:00.000-05:00	DEVICE_NOTE	d1	Ring	Battery was at 20%
2024-01-15T12:00:00.000-05:00	EVENT_RETROACTIVE	e3	walk	2024-01-15T09:00:00.000-05:00	earliest=2024-01-15T09:40:00.000-05:00	latest=2024-01-15T09:45:00.000-05:00
```

Reading it: in bed at 22:30, lights out sometime between 22:40 and 22:45 (logged a few minutes late), lights on at 06:30, up at 07:00. The ring was charging from 07:05 until 07:30 (that change was logged at 07:40, so it's backdated with `effective=`). The walk ran from 09:00 until sometime between 09:40 and 09:45, all logged at noon.

### Fields

Every line starts with the same two fields:

1. **When the line was written**: ISO 8601 local time with UTC offset, e.g. `2024-01-15T07:00:00.000-05:00`
2. **Entry type**

The rest depends on the entry type:

| Entry type | Remaining fields | Written when |
|---|---|---|
| `DEVICE_ADDED` | device ID, `name="…"`, `type=`, `status=`, `location=`, `sn=` (`none` if blank), `power=` (`on`/`off`) | A device is added |
| `DEVICE_UPDATED` | device ID, `"old name"`, then only the fields that changed (same `key=value` form), then `effective=` if backdated | A device's status, location, power, or details change |
| `DEVICE_DELETED` | device ID, `"name"` | A device is deleted |
| `EVENT_STARTED` | event ID, event type, `name="…"` (custom events only), start time | Start is tapped |
| `EVENT_STOPPED` | event ID, event type, `name="…"` (custom events only), start time, stop time | Stop is tapped |
| `EVENT_RETROACTIVE` | event ID, event type, `name="…"` (custom events only), start time, stop time | A past event is logged in one go (long-press the event row) |
| `EVENT_CANCELLED` | event ID, event type, `name="…"` (custom events only) | A running event is cancelled (disregard its `EVENT_STARTED`) |
| `GLOBAL_NOTE` | note | A general note is added |
| `DEVICE_NOTE` | device ID, device name, note | A note is added to a device |
| `ACTIVITY_NOTE` | event ID, event name, note | A note is added to a running event |
| `GLOBAL_TRACKING` | `on` or `off` | Tracking is resumed or paused. Treat time between `off` and the next `on` as not covered by the log. |

Values used in those fields:

- **Event types**: `inBed`, `lightsOut`, `walk`, `run`, `workout`, `swim`, `watchTv`, `other`. Custom events are logged as `other`, with their name in a `name="…"` field right after the type (e.g. `name="Nap"`), so two custom events can be told apart. Other event types have no `name=` field.
- **Device types**: `watch`, `ring`, `wristband`, `armband`, `chestStrap`, `headband`, `other`
- **Device status**: `worn`, `loose`, `charging`
- **Device locations**: `leftWrist`, `rightWrist`, `leftAnkle`, `rightAnkle`, `leftUpperArm`, `rightUpperArm`, `leftThigh`, `rightThigh`, `chest`, `waist`, `neck`, `head`, `other`, and fingers as `leftIndexFinger` through `leftPinkyFinger`, `leftThumb` (same for `right…`)

### Event times

Each start or stop time on an `EVENT_*` line takes one of three forms:

| Form | Meaning |
|---|---|
| *(nothing)* | It happened when the line was written (within 60 seconds) |
| `2024-01-15T06:30:00.000-05:00` | It happened at exactly this time (backdated) |
| `earliest=…` `latest=…` | It happened sometime in this window |

Times are positional: the start comes first, then the stop. If an `EVENT_STOPPED` or `EVENT_RETROACTIVE` line has only one time, it's the start, and the stop is when the line was written. `EVENT_STOPPED` repeats the start time, so each `EVENT_STOPPED` and `EVENT_RETROACTIVE` line describes a complete event on its own.

Device changes work the same way: a `DEVICE_UPDATED` line with `effective=` happened at that time; without it, the change happened when the line was written.

## Parsing the Log

[`scripts/parse_log.py`](scripts/parse_log.py) turns the log into a [pandas](https://pandas.pydata.org) DataFrame with one row per line and one column per field. Use [uv](https://docs.astral.sh/uv/) to run it and it will install pandas for you. Without uv, you need Python 3.9+ with `pandas` installed.

**From the command line**, print a summary and save a CSV (handy for R, Excel, etc.):

```bash
uv run scripts/parse_log.py worn_log.txt --csv worn_log.csv
```

```
Parsed 10 log entries
From 2024-01-14 22:00:00-05:00 to 2024-01-15 12:00:00-05:00

Entries by type:
  EVENT_STARTED       2
  EVENT_STOPPED       2
  DEVICE_UPDATED      2
  GLOBAL_TRACKING     1
  DEVICE_ADDED        1
  DEVICE_NOTE         1
  EVENT_RETROACTIVE   1

Wrote worn_log.csv
```

**From Python**, copy `parse_log.py` next to your analysis code (or run from `scripts/`):

```python
from parse_log import parse_log

df = parse_log("worn_log.txt")
```

### Columns

| Column | Filled for | Contents |
|---|---|---|
| `log_time` | every row | When the line was written |
| `event_type` | every row | Entry type (`DEVICE_ADDED`, `EVENT_STOPPED`, …) |
| `id` | all but `GLOBAL_*` | Device or event ID. Use this, not the name, to follow a device or event across rows. |
| `name` | `DEVICE_*`, `ACTIVITY_NOTE`, custom `EVENT_*` | Device name (the new name if renamed), or event name. On `EVENT_*` rows, only custom (`other`) events have one. |
| `device_type`, `status`, `location`, `serial_number`, `power` | `DEVICE_ADDED`, `DEVICE_UPDATED` | Device fields. `DEVICE_UPDATED` only fills the ones that changed. |
| `effective_time` | `DEVICE_UPDATED` | When a backdated change actually happened |
| `event_subtype` | `EVENT_*` | Event type (`walk`, `inBed`, …) |
| `start_time`, `stop_time` | `EVENT_*` | Exact start / stop time when backdated |
| `start_earliest`, `start_latest`, `stop_earliest`, `stop_latest` | `EVENT_*` | Start / stop uncertainty window |
| `note` | `*_NOTE` | Note text |
| `tracking_state` | `GLOBAL_TRACKING` | `on` or `off` |

Empty cells are `NaN`/`NaT`. An empty `start_*` or `stop_*` (or `effective_time`) means it happened at `log_time`.

**Time zones**: all time columns keep the log's UTC offset. If the offset changes partway through, e.g. a daylight saving change or travel, times are converted to UTC and you get a warning. To get local times instead, pass your time zone: `parse_log("worn_log.txt", tz="America/Chicago")` or `--tz America/Chicago`.

### From rows to intervals

Most analyses want one row per event or per device status. For the example log above:

```python
import pandas as pd
from parse_log import parse_log

df = parse_log("worn_log.txt")

# Each EVENT_STOPPED / EVENT_RETROACTIVE row is one complete event
done = df[df["event_type"].isin(["EVENT_STOPPED", "EVENT_RETROACTIVE"])]

def best_guess(rows, prefix):
    """Exact time if logged, else the window's midpoint, else the line's own time."""
    earliest, latest = rows[f"{prefix}_earliest"], rows[f"{prefix}_latest"]
    return (
        rows[f"{prefix}_time"]
        .fillna(earliest + (latest - earliest) / 2)
        .fillna(rows["log_time"])
    )

events = pd.DataFrame({
    "event": done["name"].fillna(done["event_subtype"]),  # custom events by name
    "start": best_guess(done, "start"),
    "stop": best_guess(done, "stop"),
})
```

```
       event                     start                      stop
4  lightsOut 2024-01-14 22:42:30-05:00 2024-01-15 06:30:00-05:00
5      inBed 2024-01-14 22:30:00-05:00 2024-01-15 07:00:00-05:00
9       walk 2024-01-15 09:00:00-05:00 2024-01-15 09:42:30-05:00
```

The midpoint is only one choice. Keep `*_earliest` and `*_latest` if you want to account for the uncertainty, e.g. by scoring a wearable's output against both ends of the window.

Device status changes, starting from the status set when the device was added:

```python
changes = df[df["status"].notna()]
status = pd.DataFrame({
    "device": changes["id"],
    "status": changes["status"],
    "since": changes["effective_time"].fillna(changes["log_time"]),
}).sort_values(["device", "since"])  # backdated changes can be logged out of order
```

```
  device    status                     since
1     d1      worn 2024-01-14 22:01:00-05:00
6     d1  charging 2024-01-15 07:05:00-05:00
7     d1      worn 2024-01-15 07:30:00-05:00
```

Each status holds until that device's next status change. Location and power changes work the same way.
