import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worn/models/device.dart';
import 'package:worn/models/event.dart';
import 'package:worn/services/log_service.dart';

void main() {
  group('LogService event cancellation', () {
    setUp(() async {
      // Clear shared preferences before each test
      SharedPreferences.setMockInitialValues({});
      // Reset the singleton to ensure clean state for each test
      LogService.resetForTesting();
    });

    test('logEventCancelled creates EVENT_CANCELLED log entry', () async {
      final service = LogService.instance;
      final event = Event(
        id: 'test-event-id',
        type: EventType.inBed,
        startEarliest: DateTime.utc(2024, 1, 15, 22, 0),
        startLatest: DateTime.utc(2024, 1, 15, 22, 30),
      );

      await service.logEventCancelled(event);

      final logLines = await service.getLogLines();
      expect(logLines.length, 1);

      final logLine = logLines.first;
      expect(logLine, contains('EVENT_CANCELLED'));
      expect(logLine, contains('test-event-id'));
      expect(logLine, contains('inBed'));
      // Cancelled events should not include any start window metadata
      expect(logLine, isNot(contains('earliest=')));
      expect(logLine, isNot(contains('latest=')));
    });

    test('logEventCancelled does not include start window or stop time',
        () async {
      final service = LogService.instance;
      final event = Event(
        type: EventType.workout,
        startEarliest: DateTime.utc(2024, 1, 15, 14, 0),
        startLatest: DateTime.utc(2024, 1, 15, 14, 0),
      );

      await service.logEventCancelled(event);

      final logLines = await service.getLogLines();
      final logLine = logLines.last;

      // Verify it's a cancellation
      expect(logLine, contains('EVENT_CANCELLED'));

      // Count tab-separated fields - should have 4 fields for cancelled events
      // (timestamp, EVENT_CANCELLED, id, type)
      final fields = logLine.split('\t');
      expect(fields.length, 4);

      // Verify no stop window
      expect(logLine, isNot(contains('STOPPED')));
    });
  });

  group('LogService tracking log methods', () {
    setUp(() async {
      // Clear shared preferences before each test
      SharedPreferences.setMockInitialValues({});
      // Reset the singleton to ensure clean state for each test
      LogService.resetForTesting();
    });

    test('logTrackingPaused creates GLOBAL_TRACKING off log entry', () async {
      final service = LogService.instance;

      await service.logTrackingPaused();

      final logLines = await service.getLogLines();
      expect(logLines.length, 1);

      final logLine = logLines.first;
      expect(logLine, contains('GLOBAL_TRACKING'));
      expect(logLine, contains('off'));

      // Verify format: timestamp\tGLOBAL_TRACKING\toff
      final fields = logLine.split('\t');
      expect(fields.length, 3);
      expect(fields[1], 'GLOBAL_TRACKING');
      expect(fields[2], 'off');
    });

    test('logTrackingResumed creates GLOBAL_TRACKING on log entry', () async {
      final service = LogService.instance;

      await service.logTrackingResumed();

      final logLines = await service.getLogLines();
      expect(logLines.length, 1);

      final logLine = logLines.first;
      expect(logLine, contains('GLOBAL_TRACKING'));
      expect(logLine, contains('on'));

      // Verify format: timestamp\tGLOBAL_TRACKING\ton
      final fields = logLine.split('\t');
      expect(fields.length, 3);
      expect(fields[1], 'GLOBAL_TRACKING');
      expect(fields[2], 'on');
    });

    test('tracking log entries include valid ISO 8601 timestamps', () async {
      final service = LogService.instance;

      await service.logTrackingPaused();
      await service.logTrackingResumed();

      final logLines = await service.getLogLines();
      expect(logLines.length, 2);

      for (final logLine in logLines) {
        final fields = logLine.split('\t');
        final timestamp = fields[0];

        // Verify timestamp can be parsed as DateTime
        expect(() => DateTime.parse(timestamp), returnsNormally);

        // Verify it includes timezone offset (e.g., +00:00 or -05:00)
        expect(timestamp, matches(RegExp(r'[+-]\d{2}:\d{2}$')));
      }
    });

    test('tracking log methods can be called multiple times', () async {
      final service = LogService.instance;

      await service.logTrackingPaused();
      await service.logTrackingResumed();
      await service.logTrackingPaused();
      await service.logTrackingResumed();

      final logLines = await service.getLogLines();
      expect(logLines.length, 4);

      expect(logLines[0], contains('GLOBAL_TRACKING\toff'));
      expect(logLines[1], contains('GLOBAL_TRACKING\ton'));
      expect(logLines[2], contains('GLOBAL_TRACKING\toff'));
      expect(logLines[3], contains('GLOBAL_TRACKING\ton'));
    });
  });

  group('LogService device make and model', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LogService.resetForTesting();
    });

    test('logDeviceAdded writes make and model before sn', () async {
      final service = LogService.instance;
      await service.logDeviceAdded(Device(
        id: 'device-1',
        name: 'MyWatch',
        make: 'Garmin',
        model: 'Venu 3',
        serialNumber: 'SN1',
      ));

      final fields = (await service.getLogLines()).first.split('\t');
      final make = fields.indexOf('make="Garmin"');
      final model = fields.indexOf('model="Venu 3"');
      expect(make, greaterThan(0));
      expect(model, make + 1);
      expect(fields[model + 1], 'sn=SN1');
      expect(fields[3], 'nickname="MyWatch"');
    });

    test('logDeviceUpdated writes a renamed device as nickname=', () async {
      final service = LogService.instance;
      final oldDevice = Device(id: 'device-5', name: 'Old');
      await service.logDeviceUpdated(
          oldDevice, oldDevice.copyWith(name: 'New'));

      final fields = (await service.getLogLines()).first.split('\t');
      expect(fields.sublist(3), ['"Old"', 'nickname="New"']);
    });

    test('logDeviceAdded writes empty quotes when make and model are unset',
        () async {
      final service = LogService.instance;
      await service.logDeviceAdded(Device(id: 'device-2', name: 'MyRing'));

      final fields = (await service.getLogLines()).first.split('\t');
      expect(fields, contains('make=""'));
      expect(fields, contains('model=""'));
    });

    test('logDeviceUpdated writes only the changed make or model', () async {
      final service = LogService.instance;
      final oldDevice =
          Device(id: 'device-3', name: 'MyBand', make: 'Polar', model: 'A');
      final newDevice = Device(
          id: 'device-3', name: 'MyBand', make: 'Polar', model: 'Verity');

      await service.logDeviceUpdated(oldDevice, newDevice);

      final logLine = (await service.getLogLines()).first;
      expect(logLine, contains('model="Verity"'));
      expect(logLine, isNot(contains('make=')));
    });

    test('logDeviceUpdated writes empty quotes when make is cleared', () async {
      final service = LogService.instance;
      final oldDevice = Device(id: 'device-4', name: 'MyBand', make: 'Polar');
      final newDevice = Device(id: 'device-4', name: 'MyBand');

      await service.logDeviceUpdated(oldDevice, newDevice);

      final logLine = (await service.getLogLines()).first;
      expect(logLine.split('\t'), contains('make=""'));
    });
  });

  group('LogService device field sanitizing', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LogService.resetForTesting();
    });

    test('tabs and line breaks in device text cannot add fields', () async {
      final service = LogService.instance;
      final device = Device(
        id: 'device-1',
        name: 'My\tWatch',
        make: 'Gar\nmin',
        model: 'Venu\tstatus=charging\t3',
      );
      await service.logDeviceAdded(device);
      final renamed = device.copyWith(name: 'New\r\nName', model: 'X\tY');
      await service.logDeviceUpdated(device, renamed);
      await service.logNote('hi', device: renamed);
      await service.logDeviceDeleted(renamed);

      final lines = await service.getLogLines();
      expect(lines.length, 4);
      final added = lines[0].split('\t');
      expect(added, contains('nickname="My Watch"'));
      expect(added, contains('make="Gar min"'));
      expect(added, contains('model="Venu status=charging 3"'));
      expect(added.where((f) => f.startsWith('status=')), ['status=loose']);
      expect(lines[1].split('\t').sublist(3),
          ['"My Watch"', 'nickname="New  Name"', 'model="X Y"']);
      expect(lines[2].split('\t').sublist(3), ['New  Name', 'hi']);
      expect(lines[3].split('\t').sublist(3), ['"New  Name"']);
    });
  });

  group('LogService device update with effective time', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LogService.resetForTesting();
    });

    test(
        'logDeviceUpdated without effectiveTime does not include effective field',
        () async {
      final service = LogService.instance;
      final oldDevice = Device(
        id: 'device-123',
        name: 'MyWatch',
        deviceType: DeviceType.watch,
        status: DeviceStatus.loose,
      );
      final newDevice = oldDevice.copyWith(status: DeviceStatus.worn);

      await service.logDeviceUpdated(oldDevice, newDevice);

      final logLines = await service.getLogLines();
      expect(logLines.length, 1);

      final logLine = logLines.first;
      expect(logLine, contains('DEVICE_UPDATED'));
      expect(logLine, contains('status=worn'));
      expect(logLine, isNot(contains('effective=')));
    });

    test('logDeviceUpdated with effectiveTime includes effective field',
        () async {
      final service = LogService.instance;
      final oldDevice = Device(
        id: 'device-456',
        name: 'MyRing',
        deviceType: DeviceType.ring,
        status: DeviceStatus.charging,
      );
      final newDevice = oldDevice.copyWith(status: DeviceStatus.worn);
      final effectiveTime = DateTime.utc(2024, 1, 15, 10, 30);

      await service.logDeviceUpdated(oldDevice, newDevice,
          effectiveTime: effectiveTime);

      final logLines = await service.getLogLines();
      expect(logLines.length, 1);

      final logLine = logLines.first;
      expect(logLine, contains('DEVICE_UPDATED'));
      expect(logLine, contains('status=worn'));
      // Like every other timestamp, effective time is local with an offset
      final effectiveField =
          logLine.split('\t').firstWhere((f) => f.startsWith('effective='));
      final value = effectiveField.substring('effective='.length);
      expect(value, matches(RegExp(r'[+-]\d{2}:\d{2}$')));
      expect(DateTime.parse(value).isAtSameMomentAs(effectiveTime), isTrue);
    });

    test('logDeviceUpdated effective field appears after status change',
        () async {
      final service = LogService.instance;
      final oldDevice = Device(
        id: 'device-789',
        name: 'MyBand',
        deviceType: DeviceType.wristband,
        status: DeviceStatus.worn,
      );
      final newDevice = oldDevice.copyWith(status: DeviceStatus.loose);
      final effectiveTime = DateTime.utc(2024, 1, 15, 9, 0);

      await service.logDeviceUpdated(oldDevice, newDevice,
          effectiveTime: effectiveTime);

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      // Verify format: status change comes before effective time
      final statusIndex = logLine.indexOf('status=loose');
      final effectiveIndex = logLine.indexOf('effective=');
      expect(statusIndex, lessThan(effectiveIndex));
    });
  });

  group('LogService time window formatting', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LogService.resetForTesting();
    });

    test('logEventStarted with same earliest/latest near now omits timestamp',
        () async {
      final service = LogService.instance;
      // Use current time (within 60 seconds tolerance)
      final now = DateTime.now().toUtc();
      final event = Event(
        id: 'test-id',
        type: EventType.walk,
        startEarliest: now,
        startLatest: now,
      );

      await service.logEventStarted(event);

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      // Should NOT contain any time window - the log timestamp IS the event time
      expect(logLine, isNot(contains('earliest=')));
      expect(logLine, isNot(contains('latest=')));
      // Log line should end with the event type (no trailing timestamp)
      expect(logLine, endsWith('walk'));
    });

    test(
        'logEventStarted with same earliest/latest backdated outputs single timestamp',
        () async {
      final service = LogService.instance;
      // Use a backdated time (more than 60 seconds in the past)
      final backdatedTime = DateTime.utc(2024, 1, 15, 10, 30);
      final event = Event(
        id: 'test-id',
        type: EventType.run,
        startEarliest: backdatedTime,
        startLatest: backdatedTime,
      );

      await service.logEventStarted(event);

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      // Should NOT contain earliest=/latest= format (not a window)
      expect(logLine, isNot(contains('earliest=')));
      expect(logLine, isNot(contains('latest=')));
      // Should contain a backdated timestamp (2024-01-15, converted to local timezone)
      expect(logLine, contains('2024-01-15'));
      // Should have more fields than just timestamp + type (includes backdated time)
      final fields = logLine.split('\t');
      expect(fields.length,
          5); // timestamp, EVENT_STARTED, id, type, backdated_time
    });

    test(
        'logEventStarted with different earliest/latest outputs key=value pairs',
        () async {
      final service = LogService.instance;
      final event = Event(
        id: 'test-id',
        type: EventType.walk,
        startEarliest: DateTime.utc(2024, 1, 15, 10, 0),
        startLatest: DateTime.utc(2024, 1, 15, 10, 30),
      );

      await service.logEventStarted(event);

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      // Should contain earliest= and latest= fields
      expect(logLine, contains('earliest='));
      expect(logLine, contains('latest='));
    });

    test(
        'logEventStopped with time window outputs earliest/latest for stop time',
        () async {
      final service = LogService.instance;
      final event = Event(
        id: 'test-id',
        type: EventType.run,
        startEarliest: DateTime.utc(2024, 1, 15, 10, 0),
        startLatest: DateTime.utc(2024, 1, 15, 10, 0),
      );

      await service.logEventStopped(
        event,
        DateTime.utc(2024, 1, 15, 11, 0),
        DateTime.utc(2024, 1, 15, 11, 15),
      );

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      expect(logLine, contains('EVENT_STOPPED'));
      // Stop time should have earliest=/latest= since they differ
      expect(logLine, contains('earliest='));
      expect(logLine, contains('latest='));
    });

    test('logEventStopped writes start before stop', () async {
      final service = LogService.instance;
      final event = Event(
        id: 'test-id',
        type: EventType.run,
        startEarliest: DateTime.utc(2024, 1, 15, 10, 0),
        startLatest: DateTime.utc(2024, 1, 15, 10, 0),
      );

      await service.logEventStopped(
        event,
        DateTime.utc(2024, 1, 15, 11, 0),
        DateTime.utc(2024, 1, 15, 11, 15),
      );

      final fields = (await service.getLogLines()).first.split('\t');
      // timestamp, EVENT_STOPPED, id, type, start, stop earliest, stop latest
      expect(fields.length, 7);
      expect(
          DateTime.parse(fields[4])
              .isAtSameMomentAs(DateTime.utc(2024, 1, 15, 10, 0)),
          isTrue);
      expect(fields[5], startsWith('earliest='));
      expect(fields[6], startsWith('latest='));
    });

    test('logEventStopped omits both times when start and stop are now',
        () async {
      final service = LogService.instance;
      final now = DateTime.now().toUtc();
      final event = Event(
        id: 'test-id',
        type: EventType.walk,
        startEarliest: now,
        startLatest: now,
      );

      await service.logEventStopped(event, now, now);

      final logLine = (await service.getLogLines()).first;
      expect(logLine, endsWith('\twalk'));
    });

    test(
        'logEventStopped writes start near now when a stop time is written, '
        'so a lone time is always the start', () async {
      final service = LogService.instance;
      final now = DateTime.now().toUtc();
      final event = Event(
        id: 'test-id',
        type: EventType.walk,
        startEarliest: now,
        startLatest: now,
      );

      await service.logEventStopped(
        event,
        now,
        now.add(const Duration(seconds: 30)),
      );

      final fields = (await service.getLogLines()).first.split('\t');
      // timestamp, EVENT_STOPPED, id, type, start, stop earliest, stop latest
      expect(fields.length, 7);
      expect(DateTime.parse(fields[4]).isAtSameMomentAs(now), isTrue);
      expect(fields[5], startsWith('earliest='));
      expect(fields[6], startsWith('latest='));
    });

    test(
        'logEventStopped with a backdated start and stop now writes start only',
        () async {
      final service = LogService.instance;
      final now = DateTime.now().toUtc();
      final start = now.subtract(const Duration(minutes: 30));
      final event = Event(
        id: 'test-id',
        type: EventType.walk,
        startEarliest: start,
        startLatest: start,
      );

      await service.logEventStopped(event, now, now);

      final fields = (await service.getLogLines()).first.split('\t');
      // timestamp, EVENT_STOPPED, id, type, start
      expect(fields.length, 5);
      expect(DateTime.parse(fields[4]).isAtSameMomentAs(start), isTrue);
    });

    test('logRetroactiveEvent writes start then stop', () async {
      final service = LogService.instance;
      final event = Event(
        id: 'test-id',
        type: EventType.inBed,
        startEarliest: DateTime.utc(2024, 1, 14, 22, 0),
        startLatest: DateTime.utc(2024, 1, 14, 22, 30),
      );

      await service.logRetroactiveEvent(
        event,
        DateTime.utc(2024, 1, 15, 6, 0),
        DateTime.utc(2024, 1, 15, 6, 0),
      );

      final fields = (await service.getLogLines()).first.split('\t');
      // timestamp, EVENT_RETROACTIVE, id, type, start earliest, start latest,
      // stop
      expect(fields.length, 7);
      expect(fields[1], 'EVENT_RETROACTIVE');
      expect(fields[4], startsWith('earliest='));
      expect(fields[5], startsWith('latest='));
      expect(
          DateTime.parse(fields[6])
              .isAtSameMomentAs(DateTime.utc(2024, 1, 15, 6, 0)),
          isTrue);
    });
  });

  group('LogService custom event names', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LogService.resetForTesting();
    });

    Event nap({DateTime? start, DateTime? startLatest}) => Event(
          id: 'nap-id',
          type: EventType.other,
          customName: 'Nap',
          startEarliest: start,
          startLatest: startLatest,
        );

    Future<List<String>> lastFields() async =>
        (await LogService.instance.getLogLines()).last.split('\t');

    test('logEventStarted writes name after the type', () async {
      await LogService.instance.logEventStarted(nap());

      final fields = await lastFields();
      // timestamp, EVENT_STARTED, id, type, name
      expect(fields.length, 5);
      expect(fields.sublist(1),
          ['EVENT_STARTED', 'nap-id', 'other', 'name="Nap"']);
    });

    test('logEventStarted writes the start window after the name', () async {
      await LogService.instance.logEventStarted(nap(
        start: DateTime.utc(2024, 1, 15, 13, 0),
        startLatest: DateTime.utc(2024, 1, 15, 13, 15),
      ));

      final fields = await lastFields();
      expect(fields.length, 7);
      expect(fields[3], 'other');
      expect(fields[4], 'name="Nap"');
      expect(fields[5], startsWith('earliest='));
      expect(fields[6], startsWith('latest='));
    });

    test('logEventStopped writes name, then start, then stop', () async {
      await LogService.instance.logEventStopped(
        nap(start: DateTime.utc(2024, 1, 15, 13, 0)),
        DateTime.utc(2024, 1, 15, 14, 0),
        DateTime.utc(2024, 1, 15, 14, 15),
      );

      final fields = await lastFields();
      // timestamp, EVENT_STOPPED, id, type, name, start, stop earliest,
      // stop latest
      expect(fields.length, 8);
      expect(fields[1], 'EVENT_STOPPED');
      expect(fields[4], 'name="Nap"');
      expect(
          DateTime.parse(fields[5])
              .isAtSameMomentAs(DateTime.utc(2024, 1, 15, 13, 0)),
          isTrue);
      expect(fields[6], startsWith('earliest='));
      expect(fields[7], startsWith('latest='));
    });

    test('logRetroactiveEvent writes name, then start, then stop', () async {
      await LogService.instance.logRetroactiveEvent(
        nap(start: DateTime.utc(2024, 1, 15, 13, 0)),
        DateTime.utc(2024, 1, 15, 14, 0),
        DateTime.utc(2024, 1, 15, 14, 0),
      );

      final fields = await lastFields();
      // timestamp, EVENT_RETROACTIVE, id, type, name, start, stop
      expect(fields.length, 7);
      expect(fields[1], 'EVENT_RETROACTIVE');
      expect(fields[4], 'name="Nap"');
      expect(
          DateTime.parse(fields[5])
              .isAtSameMomentAs(DateTime.utc(2024, 1, 15, 13, 0)),
          isTrue);
      expect(
          DateTime.parse(fields[6])
              .isAtSameMomentAs(DateTime.utc(2024, 1, 15, 14, 0)),
          isTrue);
    });

    test('logEventCancelled writes name after the type', () async {
      await LogService.instance.logEventCancelled(nap());

      final fields = await lastFields();
      expect(fields.sublist(1),
          ['EVENT_CANCELLED', 'nap-id', 'other', 'name="Nap"']);
    });

    test('different custom events are told apart', () async {
      final meditate = Event(type: EventType.other, customName: 'Meditate');

      await LogService.instance.logEventStarted(nap());
      await LogService.instance.logEventStarted(meditate);

      final lines = await LogService.instance.getLogLines();
      expect(lines[0], endsWith('\tother\tname="Nap"'));
      expect(lines[1], endsWith('\tother\tname="Meditate"'));
    });

    test('name replaces tabs and newlines with spaces', () async {
      await LogService.instance.logEventStarted(
          Event(type: EventType.other, customName: 'Power\tnap\nat noon'));

      final fields = await lastFields();
      expect(fields.length, 5);
      expect(fields[4], 'name="Power nap at noon"');
    });

    test('other events without a custom name write no name field', () async {
      final service = LogService.instance;
      final event = Event(type: EventType.other);

      await service.logEventStarted(event);
      await service.logEventStopped(
          event, event.startEarliest, event.startLatest);
      await service.logRetroactiveEvent(
          event, event.startEarliest, event.startLatest);
      await service.logEventCancelled(event);

      for (final line in await service.getLogLines()) {
        expect(line, isNot(contains('name=')));
        expect(line, endsWith('\tother'));
      }
    });

    test('non-other events are unchanged, even with a stray custom name',
        () async {
      final service = LogService.instance;
      final now = DateTime.now().toUtc();
      final event = Event(
        id: 'walk-id',
        type: EventType.walk,
        customName: 'Ignored',
        startEarliest: now,
        startLatest: now,
      );

      await service.logEventStarted(event);
      await service.logEventStopped(event, now, now);
      await service.logRetroactiveEvent(event, now, now);
      await service.logEventCancelled(event);

      final lines = await service.getLogLines();
      expect(lines.map((l) => l.split('\t').sublist(1)).toList(), [
        ['EVENT_STARTED', 'walk-id', 'walk'],
        ['EVENT_STOPPED', 'walk-id', 'walk'],
        ['EVENT_RETROACTIVE', 'walk-id', 'walk'],
        ['EVENT_CANCELLED', 'walk-id', 'walk'],
      ]);
    });
  });

  group('LogService note entry types', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LogService.resetForTesting();
    });

    test('logNote without device or event creates GLOBAL_NOTE entry', () async {
      final service = LogService.instance;

      await service.logNote('Test global note');

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      expect(logLine, contains('GLOBAL_NOTE'));
      expect(logLine, contains('Test global note'));
      expect(logLine, isNot(contains('DEVICE_NOTE')));
      expect(logLine, isNot(contains('ACTIVITY_NOTE')));
    });

    test('logNote with device creates DEVICE_NOTE entry', () async {
      final service = LogService.instance;
      final device = Device(
        id: 'device-123',
        name: 'MyWatch',
        deviceType: DeviceType.watch,
      );

      await service.logNote('Device specific note', device: device);

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      expect(logLine, contains('DEVICE_NOTE'));
      expect(logLine, contains('device-123'));
      expect(logLine, contains('MyWatch'));
      expect(logLine, contains('Device specific note'));
    });

    test('logNote with event creates ACTIVITY_NOTE entry', () async {
      final service = LogService.instance;
      final event = Event(
        id: 'event-456',
        type: EventType.walk,
      );

      await service.logNote('Event specific note', event: event);

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      expect(logLine, contains('ACTIVITY_NOTE'));
      expect(logLine, contains('event-456'));
      expect(logLine, contains('Walk'));
      expect(logLine, contains('Event specific note'));
    });

    test('logNote sanitizes tabs and newlines', () async {
      final service = LogService.instance;

      await service.logNote('Note with\ttab and\nnewline');

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      // Tabs and newlines should be replaced with spaces
      expect(logLine, contains('Note with tab and newline'));
      expect(
          logLine, isNot(contains('\t\t'))); // No double tabs from note content
    });
  });
}
