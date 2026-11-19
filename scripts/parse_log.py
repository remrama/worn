#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = ["pandas>=2.0"]
# ///
"""
Parse a Worn log export into a pandas DataFrame, one row per log entry.

Command line (uv installs pandas on the fly):
    uv run scripts/parse_log.py worn_log.txt
    uv run scripts/parse_log.py worn_log.txt --csv worn_log.csv
    uv run scripts/parse_log.py worn_log.txt --tz America/Chicago

Python:
    from parse_log import parse_log
    df = parse_log("worn_log.txt")

See "Parsing the log" in the README for the log format and what each
column means.
"""

from __future__ import annotations

import argparse
import warnings
from datetime import datetime, timezone

import pandas as pd

COLUMNS = [
    "log_time",
    "event_type",
    "id",
    "name",
    "device_type",
    "status",
    "location",
    "make",
    "model",
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

TIME_COLUMNS = [
    "log_time",
    "effective_time",
    "start_time",
    "start_earliest",
    "start_latest",
    "stop_time",
    "stop_earliest",
    "stop_latest",
]

# key=value fields on DEVICE_* entries and the column each one fills
_DEVICE_FIELDS = {
    "nickname": "name",
    "type": "device_type",
    "status": "status",
    "location": "location",
    "make": "make",
    "model": "model",
    "sn": "serial_number",
    "power": "power",
}


def _parse_timestamp(ts_str: str) -> datetime:
    """Parse an ISO 8601 timestamp with a UTC offset.

    Accepts a 'Z' suffix too, which Python < 3.11 cannot parse natively.
    """
    if ts_str.endswith("Z"):
        ts_str = ts_str[:-1] + "+00:00"
    return datetime.fromisoformat(ts_str)


def _unquote(value: str) -> str:
    """Strip one pair of surrounding double quotes: '"My Watch"' -> 'My Watch'."""
    if len(value) >= 2 and value[0] == value[-1] == '"':
        return value[1:-1]
    return value


def _parse_device_fields(fields: list[str]) -> dict:
    """Parse key=value fields from DEVICE_ADDED and DEVICE_UPDATED entries."""
    result = {}
    for field in fields:
        key, sep, value = field.partition("=")
        if not sep:
            continue
        if key in _DEVICE_FIELDS:
            value = _unquote(value)
            if key == "sn" and value == "none":
                # Blank (or cleared) is "", distinct from missing (NaN),
                # which on DEVICE_UPDATED means the field did not change.
                value = ""
            result[_DEVICE_FIELDS[key]] = value
        elif key == "effective":
            result["effective_time"] = _parse_timestamp(value)
    return result


def _parse_time_specs(fields: list[str]) -> list[tuple]:
    """Split the trailing fields of an EVENT_* entry into time specs, in order.

    A spec is either a bare timestamp (a precise backdated time) or an
    earliest=/latest= pair (an uncertainty window). Specs are positional:
    the first is the start and the second, if present, is the stop.

    Returns a list of (time, earliest, latest) tuples.
    """
    specs = []
    for field in fields:
        if field.startswith("earliest="):
            specs.append([None, _parse_timestamp(field[len("earliest=") :]), None])
        elif field.startswith("latest="):
            latest = _parse_timestamp(field[len("latest=") :])
            if specs and specs[-1][1] is not None and specs[-1][2] is None:
                specs[-1][2] = latest  # closes the window opened by earliest=
            else:
                specs.append([None, None, latest])
        elif field:
            try:
                specs.append([_parse_timestamp(field), None, None])
            except ValueError:
                continue  # not a timestamp; ignore
    return [tuple(spec) for spec in specs]


def _parse_event_head(row: dict, rest: list[str]) -> list[str]:
    """Fill id, event_subtype and name from the leading fields of an EVENT_* entry.

    Custom-named `other` events carry name="..." right after the event type.
    Returns the fields after it, which are the time specs.
    """
    row["id"] = rest[0]
    row["event_subtype"] = rest[1]
    rest = rest[2:]
    if rest and rest[0].startswith("name="):
        row["name"] = _unquote(rest[0][len("name=") :])
        rest = rest[1:]
    return rest


def _time_columns(specs: list[tuple], prefixes: list[str]) -> dict:
    """Map positional time specs onto start_*/stop_* columns."""
    result = {}
    for prefix, (time, earliest, latest) in zip(prefixes, specs):
        result[f"{prefix}_time"] = time
        result[f"{prefix}_earliest"] = earliest
        result[f"{prefix}_latest"] = latest
    return result


def _parse_line(fields: list[str]) -> dict:
    """Parse one tab-split log line into a row dict."""
    row = dict.fromkeys(COLUMNS)
    row["log_time"] = _parse_timestamp(fields[0])
    row["event_type"] = entry = fields[1]
    rest = fields[2:]

    if entry == "DEVICE_ADDED":
        row["id"] = rest[0]
        row.update(_parse_device_fields(rest[1:]))

    elif entry == "DEVICE_UPDATED":
        # id, "old name", then only the fields that changed
        row["id"] = rest[0]
        row["name"] = _unquote(rest[1])
        row.update(_parse_device_fields(rest[2:]))

    elif entry == "DEVICE_DELETED":
        row["id"] = rest[0]
        row["name"] = _unquote(rest[1])

    elif entry in ("DEVICE_NOTE", "ACTIVITY_NOTE"):
        row["id"] = rest[0]
        row["name"] = rest[1]
        row["note"] = rest[2] if len(rest) > 2 else None

    elif entry == "GLOBAL_NOTE":
        row["note"] = rest[0] if rest else None

    elif entry in ("EVENT_STARTED", "EVENT_STOPPED", "EVENT_RETROACTIVE"):
        time_fields = _parse_event_head(row, rest)
        prefixes = ["start"] if entry == "EVENT_STARTED" else ["start", "stop"]
        row.update(_time_columns(_parse_time_specs(time_fields), prefixes))

    elif entry == "EVENT_CANCELLED":
        _parse_event_head(row, rest)

    elif entry == "GLOBAL_TRACKING":
        row["tracking_state"] = rest[0]

    return row


def _target_timezone(log_times: list[datetime]):
    """Pick one time zone for every time column when the caller gave none.

    Uses the log's own UTC offset if it never changes. If it does (a DST
    change, travel), falls back to UTC and warns.
    """
    offsets = {t.utcoffset() for t in log_times}
    if len(offsets) == 1 and None not in offsets:
        return timezone(offsets.pop())
    if len(offsets) > 1:
        warnings.warn(
            "Log contains more than one UTC offset (e.g., a daylight saving "
            "change or travel), so all times were converted to UTC. Pass "
            "tz='America/Chicago' (or your zone) to get local times instead.",
            stacklevel=3,
        )
    return timezone.utc


def parse_log(filepath: str, tz: str | None = None) -> pd.DataFrame:
    """
    Parse a Worn log export into a DataFrame with one row per log entry.

    Args:
        filepath: Path to the exported log file.
        tz: Time zone for all time columns, e.g. "UTC" or "America/Chicago".
            By default, times keep the log's own UTC offset. If that offset
            changes within the log (a DST change, travel), times are converted
            to UTC and a warning is issued.

    Returns:
        DataFrame with these columns (empty where they don't apply):
        - log_time: When the entry was written
        - event_type: Entry type (DEVICE_ADDED, EVENT_STARTED, ...)
        - id: Device or event UUID
        - name: Device nickname (DEVICE_*), event name (ACTIVITY_NOTE), or
          custom name of an `other` event (EVENT_*)
        - device_type, status, location, make, model, serial_number, power: Device
          properties (DEVICE_UPDATED only fills the ones that changed). A
          blank or cleared make, model or serial_number is "", not missing.
        - event_subtype: Event type for EVENT_* (walk, run, inBed, ...)
        - effective_time: Backdated time of a DEVICE_UPDATED change
        - start_time / stop_time: Precise backdated start / stop time
        - start_earliest, start_latest / stop_earliest, stop_latest:
          Uncertainty window around the start / stop time
        - note: Note text for *_NOTE entries
        - tracking_state: on/off for GLOBAL_TRACKING

        All time columns are timezone-aware datetimes. An EVENT_* row with
        no start (or stop) time means it happened at log_time.
    """
    rows = []
    with open(filepath, "r", encoding="utf-8") as f:
        for line_number, line in enumerate(f, start=1):
            fields = line.rstrip("\r\n").split("\t")
            if len(fields) < 2:
                continue  # blank or malformed line
            try:
                rows.append(_parse_line(fields))
            except (ValueError, IndexError) as e:
                raise ValueError(
                    f"{filepath}, line {line_number}: can't parse {line.strip()!r} ({e})"
                ) from e

    df = pd.DataFrame(rows, columns=COLUMNS)
    if tz is None:
        tz = _target_timezone(list(df["log_time"]))
    for col in TIME_COLUMNS:
        df[col] = pd.to_datetime(df[col], utc=True).dt.tz_convert(tz)
    return df


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Parse a Worn log export and print a summary."
    )
    parser.add_argument("log_file", help="exported log file (e.g. worn_log.txt)")
    parser.add_argument(
        "--tz",
        help="convert all times to this zone, e.g. UTC or America/Chicago",
    )
    parser.add_argument(
        "--csv", metavar="PATH", help="also write the parsed table to a CSV file"
    )
    args = parser.parse_args(argv)

    df = parse_log(args.log_file, tz=args.tz)
    print(f"Parsed {len(df)} log entries")
    if len(df):
        print(f"From {df['log_time'].min()} to {df['log_time'].max()}")
        print("\nEntries by type:")
        for entry_type, count in df["event_type"].value_counts().items():
            print(f"  {entry_type:<20}{count}")

    if args.csv:
        df.to_csv(args.csv, index=False)
        print(f"\nWrote {args.csv}")


if __name__ == "__main__":
    main()
