import 'package:cho_gan/location_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Opening picker needs no GPS and manual choice works', (t) async {
    final original = GeolocatorPlatform.instance;
    final platform = _DeniedLocation();
    GeolocatorPlatform.instance = platform;
    addTearDown(() => GeolocatorPlatform.instance = original);
    String? selected;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showLocationPicker(
                  context,
                  currentArea: 'Cầu Giấy',
                );
              },
              child: const Text('Chọn'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Chọn'));
    await t.pumpAndSettle();
    expect(platform.permissionRequests, 0);
    await t.scrollUntilVisible(
      find.text('Ba Đình'),
      180,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await t.tap(find.text('Ba Đình'));
    await t.pumpAndSettle();
    expect(selected, 'Ba Đình');
    expect(await loadPreferredPassyArea(), 'Ba Đình');
    expect(platform.permissionRequests, 0);
    expect(t.takeException(), isNull);
  });

  test('Unknown saved area is ignored', () async {
    SharedPreferences.setMockInitialValues({
      'passy.preferred_market_area': 'unknown',
    });
    expect(await loadPreferredPassyArea(), isNull);
  });

  testWidgets('Denied location still allows manual choice', (t) async {
    final original = GeolocatorPlatform.instance;
    final platform = _DeniedLocation();
    GeolocatorPlatform.instance = platform;
    addTearDown(() => GeolocatorPlatform.instance = original);
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showLocationPicker(context, currentArea: 'Cầu Giấy'),
              child: const Text('Chọn'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Chọn'));
    await t.pumpAndSettle();
    await t.tap(find.text('Dùng vị trí hiện tại'));
    await t.pumpAndSettle();
    expect(platform.permissionRequests, 1);
    expect(find.textContaining('Bạn chưa cho phép'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('Thanh Xuân'),
      180,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await t.tap(find.text('Thanh Xuân'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  test('Near supported market reference suggests it first', () {
    final areas = nearbyPassyAreas(21.0369, 105.7826, accuracyMeters: 100);
    expect(areas.first.area, 'Cầu Giấy');
    expect(areas.first.referenceDistanceKm, closeTo(0, 0.001));
    expect(areas.map((entry) => entry.area), isNot(contains('Tất cả Hà Nội')));
  });

  test('Outside coverage never silently maps to Hanoi', () {
    expect(nearbyPassyAreas(10.7769, 106.7009, accuracyMeters: 100), isEmpty);
  });

  test('Poor accuracy and invalid fixes do not suggest a district', () {
    expect(nearbyPassyAreas(21.0369, 105.7826, accuracyMeters: 4000), isEmpty);
    expect(nearbyPassyAreas(double.nan, 105.7826, accuracyMeters: 10), isEmpty);
    expect(nearbyPassyAreas(95, 105.7826, accuracyMeters: 10), isEmpty);
    expect(nearbyPassyAreas(21, 105, accuracyMeters: -1), isEmpty);
  });
}

class _DeniedLocation extends GeolocatorPlatform {
  int permissionRequests = 0;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;
  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return LocationPermission.denied;
  }
}
