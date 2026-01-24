#!/usr/bin/env python3
"""Tests for parse_log.py"""

import tempfile

import pandas as pd
import pytest
from parse_log import parse_log


# Sample log content covering all event types
SAMPLE_LOG = """2024-01-15T10:30:00.000-05:00\tDEVICE_ADDED\tuuid-123\tname="MyWatch"\ttype=watch\tstatus=loose\tlocation=leftWrist\tsn=SN123\tpower=on
2024-01-15T10:32:00.000-05:00\tDEVICE_UPDATED\tuuid-123\t"MyWatch"\tname="My Watch Renamed"\ttype=wristband\tsn=SN456\tstatus=worn\tlocation=rightWrist\tpower=off
2024-01-15T10:45:00.000-05:00\tDEVICE_UPDATED\tuuid-123\t"My Watch Renamed"\tstatus=loose
2024-01-15T10:50:00.000-05:00\tDEVICE_UPDATED\tuuid-123\t"My Watch Renamed"\tstatus=worn\teffective=2024-01-15T10:40:00.000Z
2024-01-15T11:00:00.000-05:00\tEVENT_STARTED\tuuid-event1\twalk
2024-01-15T11:05:00.000-05:00\tEVENT_STARTED\tuuid-event2\trun\tearliest=2024-01-15T11:00:00.000-05:00\tlatest=2024-01-15T11:05:00.000-05:00
2024-01-15T11:10:00.000-05:00\tEVENT_STARTED\tuuid-event3\tworkout\t2024-01-15T10:45:00.000-05:00
2024-01-15T11:30:00.000-05:00\tEVENT_STOPPED\tuuid-event1\twalk
2024-01-15T11:35:00.000-05:00\tEVENT_STOPPED\tuuid-event2\trun\tearliest=2024-01-15T11:30:00.000-05:00\tlatest=2024-01-15T11:35:00.000-05:00
2024-01-15T11:40:00.000-05:00\tEVENT_CANCELLED\tuuid-event4\tswim
2024-01-15T12:00:00.000-05:00\tGLOBAL_NOTE\tUser added a custom note
2024-01-15T12:05:00.000-05:00\tDEVICE_NOTE\tuuid-123\tMyWatch\tDevice-specific note
2024-01-15T12:10:00.000-05:00\tACTIVITY_NOTE\tuuid-event1\tWalk\tEvent-specific note
2024-01-15T12:15:00.000-05:00\tEVENT_RETROACTIVE\tuuid-event5\tinBed\t2024-01-14T22:00:00.000-05:00\t2024-01-15T06:00:00.000-05:00
2024-01-15T18:00:00.000-05:00\tGLOBAL_TRACKING\toff
2024-01-17T09:00:00.000-05:00\tGLOBAL_TRACKING\ton
2024-01-17T09:05:00.000-05:00\tDEVICE_DELETED\tuuid-123\t"My Watch Renamed"
"""


@pytest.fixture
def sample_log_file():
    """Create a temporary log file for testing."""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
        f.write(SAMPLE_LOG)
        return f.name


def test_parse_log_returns_dataframe(sample_log_file):
    """Test that parse_log returns a DataFrame with expected columns."""
    df = parse_log(sample_log_file)

    assert len(df) == 17  # 17 log entries in sample

    expected_columns = [
        "log_time",
        "event_type",
        "id",
        "name",
        "device_type",
        "status",
        "location",
        "serial_number",
        "power",
        "event_subtype",
        "effective_time",
        "start_time",
        "start_earliest",
        "start_latest",
        "stop_time",
        "stop_earliest",
        "stop_latest",
        "note",
        "tracking_state",
    ]
    assert list(df.columns) == expected_columns


def test_device_added(sample_log_file):
    """Test DEVICE_ADDED parsing."""
    df = parse_log(sample_log_file)
    row = df[df["event_type"] == "DEVICE_ADDED"].iloc[0]

    assert row["id"] == "uuid-123"
    assert row["name"] == "MyWatch"
    assert row["device_type"] == "watch"
    assert row["status"] == "loose"
    assert row["location"] == "leftWrist"
    assert row["serial_number"] == "SN123"
    assert row["power"] == "on"


def test_device_updated_with_changes(sample_log_file):
    """Test DEVICE_UPDATED parsing with multiple changes."""
    df = parse_log(sample_log_file)
    rows = df[df["event_type"] == "DEVICE_UPDATED"]

    # First update: multiple fields changed
    row = rows.iloc[0]
    assert row["name"] == "My Watch Renamed"
    assert row["device_type"] == "wristband"
    assert row["status"] == "worn"
    assert row["power"] == "off"


def test_device_updated_with_effective_time(sample_log_file):
    """Test DEVICE_UPDATED with backdated effective time (Z suffix)."""
    df = parse_log(sample_log_file)
    rows = df[df["event_type"] == "DEVICE_UPDATED"]

    # Fourth entry has effective time with Z suffix
    row = rows.iloc[2]
    assert row["status"] == "worn"
    assert row["effective_time"] is not None
    assert row["effective_time"].year == 2024
    assert row["effective_time"].month == 1
    assert row["effective_time"].day == 15
    assert row["effective_time"].hour == 10
    assert row["effective_time"].minute == 40


def test_event_started_no_window(sample_log_file):
    """Test EVENT_STARTED without time window."""
    df = parse_log(sample_log_file)
    rows = df[df["event_type"] == "EVENT_STARTED"]
    row = rows.iloc[0]

    assert row["id"] == "uuid-event1"
    assert row["event_subtype"] == "walk"
    assert pd.isna(row["start_earliest"])
    assert pd.isna(row["start_latest"])
    assert pd.isna(row["start_time"])


def test_event_started_with_window(sample_log_file):
    """Test EVENT_STARTED with earliest/latest window."""
    df = parse_log(sample_log_file)
    rows = df[df["event_type"] == "EVENT_STARTED"]
    row = rows.iloc[1]

    assert row["id"] == "uuid-event2"
    assert row["event_subtype"] == "run"
    assert row["start_earliest"] is not None
    assert row["start_latest"] is not None
    assert row["start_earliest"].hour == 11
    assert row["start_earliest"].minute == 0
    assert row["start_latest"].hour == 11
    assert row["start_latest"].minute == 5


def test_event_started_backdated(sample_log_file):
    """Test EVENT_STARTED with single backdated timestamp."""
    df = parse_log(sample_log_file)
    rows = df[df["event_type"] == "EVENT_STARTED"]
    row = rows.iloc[2]

    assert row["id"] == "uuid-event3"
    assert row["event_subtype"] == "workout"
    assert row["start_time"] is not None
    assert row["start_time"].hour == 10
    assert row["start_time"].minute == 45


def test_event_stopped_no_window(sample_log_file):
    """Test EVENT_STOPPED without time window."""
    df = parse_log(sample_log_file)
    rows = df[df["event_type"] == "EVENT_STOPPED"]
    row = rows.iloc[0]

    assert row["id"] == "uuid-event1"
    assert row["event_subtype"] == "walk"
    # No start or stop windows
    assert pd.isna(row["start_time"])
    assert pd.isna(row["stop_time"])
    assert pd.isna(row["start_earliest"])
    assert pd.isna(row["stop_earliest"])


def test_event_stopped_with_stop_window(sample_log_file):
    """Test EVENT_STOPPED with stop time window."""
    df = parse_log(sample_log_file)
    rows = df[df["event_type"] == "EVENT_STOPPED"]
    row = rows.iloc[1]

    assert row["id"] == "uuid-event2"
    assert row["event_subtype"] == "run"
    # This log entry only has a stop window (no start window recorded)
    assert row["start_earliest"] is not None  # First earliest/latest pair
    assert row["start_latest"] is not None


def test_event_cancelled(sample_log_file):
    """Test EVENT_CANCELLED parsing."""
    df = parse_log(sample_log_file)
    row = df[df["event_type"] == "EVENT_CANCELLED"].iloc[0]

    assert row["id"] == "uuid-event4"
    assert row["event_subtype"] == "swim"


def test_global_note(sample_log_file):
    """Test GLOBAL_NOTE parsing."""
    df = parse_log(sample_log_file)
    row = df[df["event_type"] == "GLOBAL_NOTE"].iloc[0]

    assert row["id"] is None
    assert row["note"] == "User added a custom note"


def test_device_note(sample_log_file):
    """Test DEVICE_NOTE parsing."""
    df = parse_log(sample_log_file)
    row = df[df["event_type"] == "DEVICE_NOTE"].iloc[0]

    assert row["id"] == "uuid-123"
    assert row["name"] == "MyWatch"
    assert row["note"] == "Device-specific note"


def test_activity_note(sample_log_file):
    """Test ACTIVITY_NOTE parsing."""
    df = parse_log(sample_log_file)
    row = df[df["event_type"] == "ACTIVITY_NOTE"].iloc[0]

    assert row["id"] == "uuid-event1"
    assert row["name"] == "Walk"
    assert row["note"] == "Event-specific note"


def test_event_retroactive_with_start_and_stop(sample_log_file):
    """Test EVENT_RETROACTIVE parsing with both start and stop times.

    EVENT_RETROACTIVE can have both a start window and a stop window.
    The sample log has two bare timestamps: start time and stop time.
    """
    df = parse_log(sample_log_file)
    row = df[df["event_type"] == "EVENT_RETROACTIVE"].iloc[0]

    assert row["id"] == "uuid-event5"
    assert row["event_subtype"] == "inBed"

    # Start time: 2024-01-14T22:00:00.000-05:00
    assert row["start_time"] is not None
    assert row["start_time"].day == 14
    assert row["start_time"].hour == 22
    assert row["start_time"].minute == 0

    # Stop time: 2024-01-15T06:00:00.000-05:00
    assert row["stop_time"] is not None
    assert row["stop_time"].day == 15
    assert row["stop_time"].hour == 6
    assert row["stop_time"].minute == 0


def test_global_tracking(sample_log_file):
    """Test GLOBAL_TRACKING parsing."""
    df = parse_log(sample_log_file)
    rows = df[df["event_type"] == "GLOBAL_TRACKING"]

    assert len(rows) == 2
    assert rows.iloc[0]["tracking_state"] == "off"
    assert rows.iloc[1]["tracking_state"] == "on"


def test_device_deleted(sample_log_file):
    """Test DEVICE_DELETED parsing."""
    df = parse_log(sample_log_file)
    row = df[df["event_type"] == "DEVICE_DELETED"].iloc[0]

    assert row["id"] == "uuid-123"
    assert row["name"] == "My Watch Renamed"


def test_timestamp_parsing(sample_log_file):
    """Test that log_time timestamps are parsed correctly."""
    df = parse_log(sample_log_file)

    # First entry: 2024-01-15T10:30:00.000-05:00
    first_time = df.iloc[0]["log_time"]
    assert first_time.year == 2024
    assert first_time.month == 1
    assert first_time.day == 15
    assert first_time.hour == 10
    assert first_time.minute == 30


def test_empty_file():
    """Test parsing empty file."""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
        f.write("")
        filepath = f.name

    df = parse_log(filepath)
    assert len(df) == 0


def test_serial_number_none():
    """Test that sn=none is parsed as None."""
    log_content = '2024-01-15T10:30:00.000-05:00\tDEVICE_ADDED\tuuid-123\tname="Watch"\ttype=watch\tstatus=loose\tlocation=leftWrist\tsn=none\tpower=on'

    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
        f.write(log_content)
        filepath = f.name

    df = parse_log(filepath)
    assert df.iloc[0]["serial_number"] is None


def test_z_suffix_timestamp():
    """Test parsing timestamps with Z suffix (UTC) for Python <3.11 compatibility."""
    log_content = '2024-01-15T10:30:00.000-05:00\tDEVICE_UPDATED\tuuid-123\t"Watch"\tstatus=worn\teffective=2024-01-15T15:30:00.000Z'

    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
        f.write(log_content)
        filepath = f.name

    df = parse_log(filepath)
    row = df.iloc[0]
    assert row["effective_time"] is not None
    assert row["effective_time"].hour == 15
    assert row["effective_time"].minute == 30


def test_event_stopped_with_both_windows():
    """Test EVENT_STOPPED with both start and stop uncertainty windows."""
    log_content = (
        "2024-01-15T12:00:00.000-05:00\tEVENT_STOPPED\tuuid-123\trun\t"
        "earliest=2024-01-15T10:00:00.000-05:00\tlatest=2024-01-15T10:05:00.000-05:00\t"
        "earliest=2024-01-15T11:55:00.000-05:00\tlatest=2024-01-15T12:00:00.000-05:00"
    )

    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
        f.write(log_content)
        filepath = f.name

    df = parse_log(filepath)
    row = df.iloc[0]

    # Start window
    assert row["start_earliest"].hour == 10
    assert row["start_earliest"].minute == 0
    assert row["start_latest"].hour == 10
    assert row["start_latest"].minute == 5

    # Stop window
    assert row["stop_earliest"].hour == 11
    assert row["stop_earliest"].minute == 55
    assert row["stop_latest"].hour == 12
    assert row["stop_latest"].minute == 0


def test_event_retroactive_with_windows():
    """Test EVENT_RETROACTIVE with earliest/latest windows for both start and stop."""
    log_content = (
        "2024-01-15T12:00:00.000-05:00\tEVENT_RETROACTIVE\tuuid-123\tinBed\t"
        "earliest=2024-01-14T22:00:00.000-05:00\tlatest=2024-01-14T22:30:00.000-05:00\t"
        "earliest=2024-01-15T06:00:00.000-05:00\tlatest=2024-01-15T06:30:00.000-05:00"
    )

    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
        f.write(log_content)
        filepath = f.name

    df = parse_log(filepath)
    row = df.iloc[0]

    # Start window (bedtime uncertainty)
    assert row["start_earliest"].day == 14
    assert row["start_earliest"].hour == 22
    assert row["start_latest"].hour == 22
    assert row["start_latest"].minute == 30

    # Stop window (wake time uncertainty)
    assert row["stop_earliest"].day == 15
    assert row["stop_earliest"].hour == 6
    assert row["stop_latest"].hour == 6
    assert row["stop_latest"].minute == 30


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
