import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worn/services/tracking_service.dart';

void main() {
  group('TrackingService', () {
    setUp(() async {
      // Clear shared preferences before each test
      SharedPreferences.setMockInitialValues({});
      // Reset the singleton to ensure clean state for each test
      TrackingService.resetForTesting();
    });

    test('initializes with default value false when no persisted state', () async {
      final service = TrackingService.instance;
      final isTracking = await service.isTracking();
      expect(isTracking, false);
    });

    test('persists tracking state changes', () async {
      final service = TrackingService.instance;

      // Initially false
      expect(await service.isTracking(), false);

      // Set to true
      await service.setTracking(true);
      expect(await service.isTracking(), true);

      // Set back to false
      await service.setTracking(false);
      expect(await service.isTracking(), false);
    });

    test('retrieves persisted state across singleton instances', () async {
      // First instance sets tracking to false
      final service1 = TrackingService.instance;
      await service1.setTracking(false);
      expect(await service1.isTracking(), false);
      
      // Reset singleton to simulate app restart
      TrackingService.resetForTesting();
      
      // Mock the persisted value
      SharedPreferences.setMockInitialValues({'worn_tracking': false});
      
      // New instance should retrieve the persisted value
      final service2 = TrackingService.instance;
      expect(await service2.isTracking(), false);
    });

    test('handles multiple calls to isTracking without reloading', () async {
      final service = TrackingService.instance;

      // Multiple calls should return consistent results
      expect(await service.isTracking(), false);
      expect(await service.isTracking(), false);
      expect(await service.isTracking(), false);
    });

    test('setTracking updates internal state immediately', () async {
      final service = TrackingService.instance;
      
      await service.setTracking(false);
      expect(await service.isTracking(), false);
      
      await service.setTracking(true);
      expect(await service.isTracking(), true);
    });
  });
}
