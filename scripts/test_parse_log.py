#!/usr/bin/env python3
"""Tests for parse_log.py

Run with:
    uv run --with-requirements scripts/requirements.txt pytest scripts
"""

import pandas as pd
import pytest
from parse_log import COLUMNS, main, parse_log

# A realistic log covering every entry type, as the current app writes it
SAMPLE_LOG = """\
2024-01-15T10:30:00.000-05:00\tDEVICE_ADDED\tuuid-123\tnickname="MyWatch"\ttype=watch\tstatus=loose\tlocation=leftWrist\tmake="Garmin"\tmodel="Venu 3"\tsn=SN123\tpower=on
2024-01-15T10:32:00.000-05:00\tDEVICE_UPDATED\tuuid-123\t"MyWatch"\tnickname="My Watch Renamed"\ttype=wristband\tsn=SN456\tstatus=worn\tlocation=rightWrist\tmodel="Venu 3S"\tpower=off
2024-01-15T10:45:00.000-05:00\tDEVICE_UPDATED\tuuid-123\t"My Watch Renamed"\tstatus=loose
2024-01-15T10:50:00.000-05:00\tDEVICE_UPDATED\tuuid-123\t"My Watch Renamed"\tstatus=worn\teffective=2024-01-15T10:40:00.000-05:00
2024-01-15T11:00:00.000-05:00\tEVENT_STARTED\tuuid-event1\twalk
2024-01-15T11:05:00.000-05:00\tEVENT_STARTED\tuuid-event2\trun\tearliest=2024-01-15T10:55:00.000-05:00\tlatest=2024-01-15T11:00:00.000-05:00
2024-01-15T11:10:00.000-05:00\tEVENT_STARTED\tuuid-event3\tworkout\t2024-01-15T10:45:00.000-05:00
2024-01-15T11:30:00.000-05:00\tEVENT_STOPPED\tuuid-event1\twalk\t2024-01-15T11:00:00.000-05:00
2024-01-15T11:35:00.000-05:00\tEVENT_STOPPED\tuuid-event2\trun\tearliest=2024-01-15T10:55:00.000-05:00\tlatest=2024-01-15T11:00:00.000-05:00\tearliest=2024-01-15T11:25:00.000-05:00\tlatest=2024-01-15T11:35:00.000-05:00
2024-01-15T11:40:00.000-05:00\tEVENT_STARTED\tuuid-event4\tswim
2024-01-15T11:41:00.000-05:00\tEVENT_CANCELLED\tuuid-event4\tswim
2024-01-15T12:00:00.000-05:00\tGLOBAL_NOTE\tUser added a custom note
2024-01-15T12:05:00.000-05:00\tDEVICE_NOTE\tuuid-123\tMyWatch\tDevice-specific note
2024-01-15T12:10:00.000-05:00\tACTIVITY_NOTE\tuuid-event1\tWalk\tEvent-specific note
2024-01-15T12:15:00.000-05:00\tEVENT_RETROACTIVE\tuuid-event5\tinBed\t2024-01-14T22:00:00.000-05:00\t2024-01-15T06:00:00.000-05:00
2024-01-15T18:00:00.000-05:00\tGLOBAL_TRACKING\toff
2024-01-17T09:00:00.000-05:00\tGLOBAL_TRACKING\ton
2024-01-17T09:05:00.000-05:00\tDEVICE_DELETED\tuuid-123\t"My Watch Renamed"
"""


def _ts(s):
    return pd.Timestamp(s)


def _write(tmp_path, content):
    path = tmp_path / "worn_log.txt"
    path.write_text(content, encoding="utf-8")
    return str(path)


@pytest.fixture
def df(tmp_path):
    return parse_log(_write(tmp_path, SAMPLE_LOG))


def _rows(df, event_type):
    return df[df["event_type"] == event_type]


def test_columns_and_row_count(df):
    assert len(df) == 18
    assert list(df.columns) == COLUMNS


def test_time_columns_keep_log_offset(df):
    """With one UTC offset in the log, times stay in that offset."""
    for col in ["log_time", "start_time", "stop_earliest", "effective_time"]:
        assert isinstance(df[col].dtype, pd.DatetimeTZDtype)
    first = df.iloc[0]["log_time"]
    assert (first.hour, first.minute) == (10, 30)
    assert first.utcoffset() == pd.Timedelta(hours=-5)


def test_device_added(df):
    row = _rows(df, "DEVICE_ADDED").iloc[0]
    assert row["id"] == "uuid-123"
    assert row["name"] == "MyWatch"
    assert row["device_type"] == "watch"
    assert row["status"] == "loose"
    assert row["location"] == "leftWrist"
    assert row["make"] == "Garmin"
    assert row["model"] == "Venu 3"
    assert row["serial_number"] == "SN123"
    assert row["power"] == "on"


def test_device_updated_with_changes(df):
    row = _rows(df, "DEVICE_UPDATED").iloc[0]
    assert row["name"] == "My Watch Renamed"  # new name
    assert row["device_type"] == "wristband"
    assert pd.isna(row["make"])  # unchanged, so not written
    assert row["model"] == "Venu 3S"
    assert row["serial_number"] == "SN456"
    assert row["status"] == "worn"
    assert row["location"] == "rightWrist"
    assert row["power"] == "off"


def test_device_updated_only_fills_changed_fields(df):
    row = _rows(df, "DEVICE_UPDATED").iloc[1]
    assert row["name"] == "My Watch Renamed"  # old name, from the quoted field
    assert row["status"] == "loose"
    assert pd.isna(row["location"])
    assert pd.isna(row["effective_time"])


def test_device_updated_with_effective_time(df):
    row = _rows(df, "DEVICE_UPDATED").iloc[2]
    assert row["status"] == "worn"
    assert row["effective_time"] == _ts("2024-01-15T10:40:00-05:00")


def test_device_deleted(df):
    row = _rows(df, "DEVICE_DELETED").iloc[0]
    assert row["id"] == "uuid-123"
    assert row["name"] == "My Watch Renamed"


def test_event_started_now(df):
    row = _rows(df, "EVENT_STARTED").iloc[0]
    assert row["id"] == "uuid-event1"
    assert row["event_subtype"] == "walk"
    for col in ["start_time", "start_earliest", "start_latest"]:
        assert pd.isna(row[col])


def test_event_started_with_window(df):
    row = _rows(df, "EVENT_STARTED").iloc[1]
    assert row["event_subtype"] == "run"
    assert pd.isna(row["start_time"])
    assert row["start_earliest"] == _ts("2024-01-15T10:55:00-05:00")
    assert row["start_latest"] == _ts("2024-01-15T11:00:00-05:00")


def test_event_started_backdated(df):
    row = _rows(df, "EVENT_STARTED").iloc[2]
    assert row["event_subtype"] == "workout"
    assert row["start_time"] == _ts("2024-01-15T10:45:00-05:00")
    assert pd.isna(row["start_earliest"])


def test_event_stopped_start_only(df):
    """A lone time on EVENT_STOPPED is the start; the stop is log_time."""
    row = _rows(df, "EVENT_STOPPED").iloc[0]
    assert row["id"] == "uuid-event1"
    assert row["start_time"] == _ts("2024-01-15T11:00:00-05:00")
    for col in ["stop_time", "stop_earliest", "stop_latest"]:
        assert pd.isna(row[col])


def test_event_stopped_with_both_windows(df):
    row = _rows(df, "EVENT_STOPPED").iloc[1]
    assert row["id"] == "uuid-event2"
    assert row["start_earliest"] == _ts("2024-01-15T10:55:00-05:00")
    assert row["start_latest"] == _ts("2024-01-15T11:00:00-05:00")
    assert row["stop_earliest"] == _ts("2024-01-15T11:25:00-05:00")
    assert row["stop_latest"] == _ts("2024-01-15T11:35:00-05:00")


def test_event_cancelled(df):
    row = _rows(df, "EVENT_CANCELLED").iloc[0]
    assert row["id"] == "uuid-event4"
    assert row["event_subtype"] == "swim"


def test_event_retroactive_with_start_and_stop(df):
    row = _rows(df, "EVENT_RETROACTIVE").iloc[0]
    assert row["id"] == "uuid-event5"
    assert row["event_subtype"] == "inBed"
    assert row["start_time"] == _ts("2024-01-14T22:00:00-05:00")
    assert row["stop_time"] == _ts("2024-01-15T06:00:00-05:00")


def test_notes(df):
    row = _rows(df, "GLOBAL_NOTE").iloc[0]
    assert pd.isna(row["id"])
    assert row["note"] == "User added a custom note"

    row = _rows(df, "DEVICE_NOTE").iloc[0]
    assert (row["id"], row["name"]) == ("uuid-123", "MyWatch")
    assert row["note"] == "Device-specific note"

    row = _rows(df, "ACTIVITY_NOTE").iloc[0]
    assert (row["id"], row["name"]) == ("uuid-event1", "Walk")
    assert row["note"] == "Event-specific note"


def test_global_tracking(df):
    rows = _rows(df, "GLOBAL_TRACKING")
    assert list(rows["tracking_state"]) == ["off", "on"]


def test_empty_file(tmp_path):
    df = parse_log(_write(tmp_path, ""))
    assert len(df) == 0
    assert list(df.columns) == COLUMNS


def test_bad_line_reports_line_number(tmp_path):
    content = "2024-01-15T10:30:00.000-05:00\tGLOBAL_TRACKING\ton\nnot a time\tGLOBAL_TRACKING\toff"
    with pytest.raises(ValueError, match="line 2"):
        parse_log(_write(tmp_path, content))


def test_serial_number_none(tmp_path):
    line = '2024-01-15T10:30:00.000-05:00\tDEVICE_ADDED\tuuid-123\tnickname="Watch"\ttype=watch\tstatus=loose\tlocation=leftWrist\tsn=none\tpower=on'
    df = parse_log(_write(tmp_path, line))
    assert df.iloc[0]["serial_number"] == ""


def test_blank_make_and_model(tmp_path):
    lines = [
        '2024-01-15T10:30:00.000-05:00\tDEVICE_ADDED\tuuid-123\tnickname="Watch"\ttype=watch\tstatus=loose\tlocation=leftWrist\tmake=""\tmodel=""\tsn=none\tpower=on',
        '2024-01-15T10:31:00.000-05:00\tDEVICE_UPDATED\tuuid-123\t"Watch"\tmake=""',
    ]
    df = parse_log(_write(tmp_path, "\n".join(lines)))
    assert list(df["make"]) == ["", ""]
    assert df.iloc[0]["model"] == ""


def test_cleared_field_differs_from_unchanged(tmp_path):
    """A cleared make is "", an unchanged one is NaN, so ffill keeps the clear."""
    lines = [
        '2024-01-15T10:30:00.000-05:00\tDEVICE_ADDED\tuuid-123\tnickname="Watch"\ttype=watch\tstatus=loose\tlocation=leftWrist\tmake="Garmin"\tmodel="Venu 3"\tsn=SN1\tpower=on',
        '2024-01-15T10:31:00.000-05:00\tDEVICE_UPDATED\tuuid-123\t"Watch"\tmake=""\tsn=none',
        '2024-01-15T10:32:00.000-05:00\tDEVICE_UPDATED\tuuid-123\t"Watch"\tstatus=worn',
    ]
    df = parse_log(_write(tmp_path, "\n".join(lines)))
    cleared, unchanged = df.iloc[1], df.iloc[2]
    assert (cleared["make"], cleared["serial_number"]) == ("", "")
    assert pd.isna(cleared["model"])
    assert pd.isna(unchanged["make"]) and pd.isna(unchanged["serial_number"])
    filled = df[["make", "model", "serial_number"]].ffill().iloc[2]
    assert list(filled) == ["", "Venu 3", ""]


def test_older_logs_without_make_and_model(tmp_path):
    line = '2024-01-15T10:30:00.000-05:00\tDEVICE_ADDED\tuuid-123\tnickname="Watch"\ttype=watch\tstatus=loose\tlocation=leftWrist\tsn=none\tpower=on'
    df = parse_log(_write(tmp_path, line))
    assert pd.isna(df.iloc[0]["make"])
    assert pd.isna(df.iloc[0]["model"])


def test_names_with_quotes_and_equals(tmp_path):
    lines = [
        '2024-01-15T10:30:00.000-05:00\tDEVICE_ADDED\tuuid-1\tnickname="My "Best" Watch=1"\ttype=watch\tstatus=loose\tlocation=leftWrist\tsn=none\tpower=on',
        '2024-01-15T10:31:00.000-05:00\tDEVICE_DELETED\tuuid-1\t"My "Best" Watch=1"',
    ]
    df = parse_log(_write(tmp_path, "\n".join(lines)))
    assert list(df["name"]) == ['My "Best" Watch=1'] * 2


def test_z_suffix_timestamp(tmp_path):
    """Older logs wrote effective= in UTC with a Z suffix."""
    line = '2024-01-15T10:30:00.000-05:00\tDEVICE_UPDATED\tuuid-123\t"Watch"\tstatus=worn\teffective=2024-01-15T15:20:00.000Z'
    df = parse_log(_write(tmp_path, line))
    effective = df.iloc[0]["effective_time"]
    assert effective == _ts("2024-01-15T15:20:00Z")
    # Shown in the log's own offset, like every other time column
    assert (effective.hour, effective.minute) == (10, 20)


def test_event_stopped_precise_start_and_stop_window(tmp_path):
    """Regression: the stop window used to land in the start_* columns."""
    line = (
        "2024-01-15T12:00:00.000-05:00\tEVENT_STOPPED\tuuid-1\trun\t"
        "2024-01-15T10:00:00.000-05:00\t"
        "earliest=2024-01-15T11:50:00.000-05:00\tlatest=2024-01-15T12:00:00.000-05:00"
    )
    row = parse_log(_write(tmp_path, line)).iloc[0]
    assert row["start_time"] == _ts("2024-01-15T10:00:00-05:00")
    assert pd.isna(row["start_earliest"]) and pd.isna(row["start_latest"])
    assert pd.isna(row["stop_time"])
    assert row["stop_earliest"] == _ts("2024-01-15T11:50:00-05:00")
    assert row["stop_latest"] == _ts("2024-01-15T12:00:00-05:00")


def test_event_stopped_start_window_and_precise_stop(tmp_path):
    """Regression: the precise stop time used to land in start_time."""
    line = (
        "2024-01-15T12:00:00.000-05:00\tEVENT_STOPPED\tuuid-1\trun\t"
        "earliest=2024-01-15T10:00:00.000-05:00\tlatest=2024-01-15T10:05:00.000-05:00\t"
        "2024-01-15T11:30:00.000-05:00"
    )
    row = parse_log(_write(tmp_path, line)).iloc[0]
    assert pd.isna(row["start_time"])
    assert row["start_earliest"] == _ts("2024-01-15T10:00:00-05:00")
    assert row["start_latest"] == _ts("2024-01-15T10:05:00-05:00")
    assert row["stop_time"] == _ts("2024-01-15T11:30:00-05:00")
    assert pd.isna(row["stop_earliest"]) and pd.isna(row["stop_latest"])


def test_event_retroactive_with_windows(tmp_path):
    line = (
        "2024-01-15T12:00:00.000-05:00\tEVENT_RETROACTIVE\tuuid-1\tinBed\t"
        "earliest=2024-01-14T22:00:00.000-05:00\tlatest=2024-01-14T22:30:00.000-05:00\t"
        "earliest=2024-01-15T06:00:00.000-05:00\tlatest=2024-01-15T06:30:00.000-05:00"
    )
    row = parse_log(_write(tmp_path, line)).iloc[0]
    assert row["start_earliest"] == _ts("2024-01-14T22:00:00-05:00")
    assert row["start_latest"] == _ts("2024-01-14T22:30:00-05:00")
    assert row["stop_earliest"] == _ts("2024-01-15T06:00:00-05:00")
    assert row["stop_latest"] == _ts("2024-01-15T06:30:00-05:00")


def test_built_in_events_have_no_name(df):
    events = df[df["event_type"].str.startswith("EVENT_")]
    assert len(events) == 8
    assert events["name"].isna().all()


# Custom-named `other` events carry name="..." right after the event type
CUSTOM_LOG = """\
2024-01-15T13:00:00.000-05:00\tEVENT_STARTED\tuuid-nap\tother\tname="Nap"
2024-01-15T13:05:00.000-05:00\tEVENT_STARTED\tuuid-med\tother\tname="Meditate"\tearliest=2024-01-15T12:55:00.000-05:00\tlatest=2024-01-15T13:00:00.000-05:00
2024-01-15T13:30:00.000-05:00\tEVENT_STOPPED\tuuid-med\tother\tname="Meditate"\tearliest=2024-01-15T12:55:00.000-05:00\tlatest=2024-01-15T13:00:00.000-05:00\t2024-01-15T13:25:00.000-05:00
2024-01-15T14:00:00.000-05:00\tEVENT_STOPPED\tuuid-nap\tother\tname="Nap"\t2024-01-15T13:00:00.000-05:00
2024-01-15T15:00:00.000-05:00\tEVENT_RETROACTIVE\tuuid-read\tother\tname="Read"\t2024-01-15T14:00:00.000-05:00\tearliest=2024-01-15T14:40:00.000-05:00\tlatest=2024-01-15T14:45:00.000-05:00
2024-01-15T15:05:00.000-05:00\tEVENT_STARTED\tuuid-str\tother\tname="Stretch"\t2024-01-15T15:00:00.000-05:00
2024-01-15T15:06:00.000-05:00\tEVENT_CANCELLED\tuuid-str\tother\tname="Stretch"
2024-01-15T15:10:00.000-05:00\tEVENT_STARTED\tuuid-old\tother
"""


@pytest.fixture
def custom_df(tmp_path):
    return parse_log(_write(tmp_path, CUSTOM_LOG))


def test_custom_event_names(custom_df):
    assert list(custom_df["event_subtype"]) == ["other"] * 8
    assert list(custom_df["name"][:7]) == [
        "Nap",
        "Meditate",
        "Meditate",
        "Nap",
        "Read",
        "Stretch",
        "Stretch",
    ]


def test_other_event_without_name(custom_df):
    """Logs written before custom names were recorded have no name= field."""
    row = custom_df.iloc[7]
    assert row["id"] == "uuid-old"
    assert pd.isna(row["name"])
    assert pd.isna(row["start_time"])


def test_custom_event_started_now(custom_df):
    row = custom_df.iloc[0]
    for col in ["start_time", "start_earliest", "start_latest"]:
        assert pd.isna(row[col])


def test_custom_event_started_with_window(custom_df):
    row = custom_df.iloc[1]
    assert pd.isna(row["start_time"])
    assert row["start_earliest"] == _ts("2024-01-15T12:55:00-05:00")
    assert row["start_latest"] == _ts("2024-01-15T13:00:00-05:00")


def test_custom_event_started_backdated(custom_df):
    row = custom_df.iloc[5]
    assert row["start_time"] == _ts("2024-01-15T15:00:00-05:00")
    assert pd.isna(row["start_earliest"])


def test_custom_event_stopped_start_window_and_precise_stop(custom_df):
    row = custom_df.iloc[2]
    assert pd.isna(row["start_time"])
    assert row["start_earliest"] == _ts("2024-01-15T12:55:00-05:00")
    assert row["start_latest"] == _ts("2024-01-15T13:00:00-05:00")
    assert row["stop_time"] == _ts("2024-01-15T13:25:00-05:00")
    assert pd.isna(row["stop_earliest"]) and pd.isna(row["stop_latest"])


def test_custom_event_stopped_start_only(custom_df):
    row = custom_df.iloc[3]
    assert row["start_time"] == _ts("2024-01-15T13:00:00-05:00")
    for col in ["stop_time", "stop_earliest", "stop_latest"]:
        assert pd.isna(row[col])


def test_custom_event_retroactive(custom_df):
    row = custom_df.iloc[4]
    assert row["start_time"] == _ts("2024-01-15T14:00:00-05:00")
    assert pd.isna(row["start_earliest"])
    assert pd.isna(row["stop_time"])
    assert row["stop_earliest"] == _ts("2024-01-15T14:40:00-05:00")
    assert row["stop_latest"] == _ts("2024-01-15T14:45:00-05:00")


def test_custom_event_cancelled(custom_df):
    row = custom_df.iloc[6]
    assert row["event_type"] == "EVENT_CANCELLED"
    assert row["id"] == "uuid-str"
    assert row["name"] == "Stretch"


def test_custom_event_name_with_quotes_and_equals(tmp_path):
    line = (
        "2024-01-15T12:00:00.000-05:00\tEVENT_STOPPED\tuuid-1\tother\t"
        'name="Nap = "power" nap"\t2024-01-15T11:00:00.000-05:00'
    )
    row = parse_log(_write(tmp_path, line)).iloc[0]
    assert row["name"] == 'Nap = "power" nap'
    assert row["start_time"] == _ts("2024-01-15T11:00:00-05:00")


# A log spanning the US spring-forward change (CST -06:00 -> CDT -05:00)
DST_LOG = """\
2024-03-09T22:00:00.000-06:00\tEVENT_STARTED\tuuid-1\tinBed
2024-03-10T07:00:00.000-05:00\tEVENT_STOPPED\tuuid-1\tinBed\t2024-03-09T22:00:00.000-06:00
"""


def test_mixed_offsets_convert_to_utc_with_warning(tmp_path):
    with pytest.warns(UserWarning, match="more than one UTC offset"):
        df = parse_log(_write(tmp_path, DST_LOG))
    assert str(df["log_time"].dt.tz) == "UTC"
    assert df.iloc[1]["log_time"] == _ts("2024-03-10T12:00:00Z")
    assert df.iloc[1]["start_time"] == _ts("2024-03-10T04:00:00Z")


def test_tz_argument_converts_all_times(tmp_path):
    df = parse_log(_write(tmp_path, DST_LOG), tz="America/Chicago")
    assert str(df["log_time"].dt.tz) == "America/Chicago"
    stop = df.iloc[1]
    assert (stop["log_time"].hour, stop["start_time"].hour) == (7, 22)
    # Durations are correct across the DST change: 22:00 CST -> 07:00 CDT
    assert stop["log_time"] - stop["start_time"] == pd.Timedelta(hours=8)


def test_cli_summary_and_csv(tmp_path, capsys):
    log_file = _write(tmp_path, SAMPLE_LOG)
    csv_file = tmp_path / "parsed.csv"
    main([log_file, "--csv", str(csv_file)])

    out = capsys.readouterr().out
    assert "Parsed 18 log entries" in out
    assert "EVENT_STARTED" in out

    csv = pd.read_csv(csv_file)
    assert list(csv.columns) == COLUMNS
    assert len(csv) == 18


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
