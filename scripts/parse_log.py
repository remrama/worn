#!/usr/bin/env python3
"""
Parse Worn app log files into pandas DataFrames for analysis.

Usage:
    from parse_log import parse_log
    df = parse_log("path/to/exported_log.txt")

Requires Python 3.9+ for type hints. Compatible with Python <3.11 by
handling 'Z' suffix in ISO timestamps.
"""

import re
from datetime import datetime

import pandas as pd


def _parse_timestamp(ts_str: str) -> datetime:
    """Parse ISO 8601 timestamp with timezone offset.

    Handles both '+HH:MM' offsets and 'Z' suffix (UTC) for Python <3.11
    compatibility.
    """
    # Python <3.11 doesn't support 'Z' suffix in fromisoformat
    if ts_str.endswith("Z"):
        ts_str = ts_str[:-1] + "+00:00"
    return datetime.fromisoformat(ts_str)


def _parse_quoted_string(s: str) -> str:
    """Extract value from quoted string like name="My Watch"."""
    match = re.search(r'"([^"]*)"', s)
    return match.group(1) if match else s


def _parse_key_value(field: str) -> tuple[str, str]:
    """Parse key=value pair, handling quoted values."""
    if "=" not in field:
        return (field, field)
    key, value = field.split("=", 1)
    if value.startswith('"') and value.endswith('"'):
        value = value[1:-1]
    return (key, value)


def _parse_single_time_window(fields: list[str]) -> dict:
    """
    Parse a single time window from fields.

    Used for EVENT_STARTED which only has a start window.
    Returns dict with keys: start_time, start_earliest, start_latest
    """
    result = {"start_time": None, "start_earliest": None, "start_latest": None}

    for field in fields:
        if field.startswith("earliest="):
            result["start_earliest"] = _parse_timestamp(field.split("=", 1)[1])
        elif field.startswith("latest="):
            result["start_latest"] = _parse_timestamp(field.split("=", 1)[1])
        elif field and "=" not in field:
            # Single backdated timestamp (not a key=value pair)
            try:
                result["start_time"] = _parse_timestamp(field)
            except ValueError:
                pass  # Not a timestamp, skip

    return result


def _parse_dual_time_windows(fields: list[str]) -> dict:
    """
    Parse start and stop time windows from fields.

    Used for EVENT_STOPPED and EVENT_RETROACTIVE which can have both
    start and stop windows. The log format emits start window first,
    then stop window.

    Possible formats:
    - No windows: []
    - Start only (backdated): [timestamp]
    - Start only (window): [earliest=..., latest=...]
    - Start + stop (backdated): [start_ts, stop_ts]
    - Start + stop (windows): [earliest=..., latest=..., earliest=..., latest=...]
    - Mixed: [start_ts, earliest=..., latest=...] or [earliest=..., latest=..., stop_ts]

    Returns dict with keys: start_time, start_earliest, start_latest,
                           stop_time, stop_earliest, stop_latest
    """
    result = {
        "start_time": None,
        "start_earliest": None,
        "start_latest": None,
        "stop_time": None,
        "stop_earliest": None,
        "stop_latest": None,
    }

    # Track which earliest/latest we've seen to distinguish start vs stop
    seen_start_window = False
    bare_timestamps = []

    for field in fields:
        if field.startswith("earliest="):
            ts = _parse_timestamp(field.split("=", 1)[1])
            if not seen_start_window and result["start_earliest"] is None:
                result["start_earliest"] = ts
            else:
                result["stop_earliest"] = ts
        elif field.startswith("latest="):
            ts = _parse_timestamp(field.split("=", 1)[1])
            if not seen_start_window and result["start_latest"] is None:
                result["start_latest"] = ts
                seen_start_window = True  # Mark that we've completed a start window
            else:
                result["stop_latest"] = ts
        elif field and "=" not in field:
            # Bare timestamp - collect them in order
            try:
                bare_timestamps.append(_parse_timestamp(field))
            except ValueError:
                pass  # Not a timestamp, skip

    # Assign bare timestamps: first is start, second is stop
    if len(bare_timestamps) >= 1:
        result["start_time"] = bare_timestamps[0]
    if len(bare_timestamps) >= 2:
        result["stop_time"] = bare_timestamps[1]

    return result


def _parse_device_added(fields: list[str]) -> dict:
    """Parse DEVICE_ADDED entry fields."""
    result = {}
    for field in fields[3:]:  # Skip timestamp, event_type, id
        key, value = _parse_key_value(field)
        if key == "name":
            result["name"] = _parse_quoted_string(field)
        elif key == "type":
            result["device_type"] = value
        elif key == "status":
            result["status"] = value
        elif key == "location":
            result["location"] = value
        elif key == "sn":
            result["serial_number"] = None if value == "none" else value
        elif key == "power":
            result["power"] = value
    return result


def _parse_device_updated(fields: list[str]) -> dict:
    """Parse DEVICE_UPDATED entry fields."""
    result = {"name": _parse_quoted_string(fields[3])}  # Old name in quotes

    for field in fields[4:]:  # Changes after old name
        key, value = _parse_key_value(field)
        if key == "name":
            result["name"] = _parse_quoted_string(field)  # New name
        elif key == "type":
            result["device_type"] = value
        elif key == "status":
            result["status"] = value
        elif key == "location":
            result["location"] = value
        elif key == "sn":
            result["serial_number"] = None if value == "none" else value
        elif key == "power":
            result["power"] = value
        elif key == "effective":
            result["effective_time"] = _parse_timestamp(value)
    return result


def parse_log(filepath: str) -> pd.DataFrame:
    """
    Parse a Worn app log file into a pandas DataFrame.

    Args:
        filepath: Path to the exported log file

    Returns:
        DataFrame with columns:
        - log_time: When the log entry was recorded
        - event_type: DEVICE_ADDED, EVENT_STARTED, etc.
        - id: Device or event UUID (NaN for GLOBAL_* events)
        - name: Device/event name where applicable
        - device_type: For DEVICE_* events
        - status: For DEVICE_* events
        - location: For DEVICE_* events
        - serial_number: For DEVICE_* events
        - power: on/off for DEVICE_* events
        - event_subtype: For EVENT_* (walk, run, inBed, etc.)
        - effective_time: Backdated time for DEVICE_UPDATED
        - start_time: Backdated start time for EVENT_*
        - start_earliest: Start of start uncertainty window
        - start_latest: End of start uncertainty window
        - stop_time: Backdated stop time for EVENT_STOPPED/RETROACTIVE
        - stop_earliest: Start of stop uncertainty window
        - stop_latest: End of stop uncertainty window
        - note: For *_NOTE events
        - tracking_state: For GLOBAL_TRACKING (on/off)
    """
    rows = []

    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n\r")
            if not line:
                continue

            fields = line.split("\t")
            if len(fields) < 2:
                continue

            row = {
                "log_time": _parse_timestamp(fields[0]),
                "event_type": fields[1],
                "id": None,
                "name": None,
                "device_type": None,
                "status": None,
                "location": None,
                "serial_number": None,
                "power": None,
                "event_subtype": None,
                "effective_time": None,
                "start_time": None,
                "start_earliest": None,
                "start_latest": None,
                "stop_time": None,
                "stop_earliest": None,
                "stop_latest": None,
                "note": None,
                "tracking_state": None,
            }

            event_type = fields[1]

            if event_type == "DEVICE_ADDED":
                row["id"] = fields[2]
                row.update(_parse_device_added(fields))

            elif event_type == "DEVICE_UPDATED":
                row["id"] = fields[2]
                row.update(_parse_device_updated(fields))

            elif event_type == "DEVICE_DELETED":
                row["id"] = fields[2]
                row["name"] = _parse_quoted_string(fields[3])

            elif event_type == "DEVICE_NOTE":
                row["id"] = fields[2]
                row["name"] = fields[3]
                row["note"] = fields[4] if len(fields) > 4 else None

            elif event_type == "ACTIVITY_NOTE":
                row["id"] = fields[2]
                row["name"] = fields[3]
                row["note"] = fields[4] if len(fields) > 4 else None

            elif event_type == "GLOBAL_NOTE":
                row["note"] = fields[2] if len(fields) > 2 else None

            elif event_type == "EVENT_STARTED":
                row["id"] = fields[2]
                row["event_subtype"] = fields[3]
                time_window = _parse_single_time_window(fields[4:])
                row.update(time_window)

            elif event_type == "EVENT_STOPPED":
                row["id"] = fields[2]
                row["event_subtype"] = fields[3]
                time_windows = _parse_dual_time_windows(fields[4:])
                row.update(time_windows)

            elif event_type == "EVENT_CANCELLED":
                row["id"] = fields[2]
                row["event_subtype"] = fields[3]

            elif event_type == "EVENT_RETROACTIVE":
                row["id"] = fields[2]
                row["event_subtype"] = fields[3]
                time_windows = _parse_dual_time_windows(fields[4:])
                row.update(time_windows)

            elif event_type == "GLOBAL_TRACKING":
                row["tracking_state"] = fields[2]

            rows.append(row)

    return pd.DataFrame(rows)


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Usage: python parse_log.py <log_file>")
        sys.exit(1)

    df = parse_log(sys.argv[1])
    print(f"Parsed {len(df)} log entries")
    print("\nColumns:", list(df.columns))
    print("\nEvent type counts:")
    print(df["event_type"].value_counts())
    print("\nSample rows:")
    print(df.head(10).to_string())
