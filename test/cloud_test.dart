import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cho_gan/cloud_app.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-public-key',
      httpClient: MockClient(
        (request) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  test('Vietnamese money formatting', () {
    expect(money(0), 'Cho tặng');
    expect(money(1250000), '1.250.000 đ');
  });
  testWidgets('Mobile feed loads and posting requires login', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const ChoGan());
    await t.pumpAndSettle();
    expect(
      find.text('Chưa có món nào ở đây'),
      findsOneWidget,
      reason: t
          .widgetList<Text>(find.byType(Text))
          .map((x) => x.data)
          .join(' | '),
    );
    expect(t.takeException(), isNull);
    await t.tap(find.text('Đăng tin'));
    await t.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await t.pumpAndSettle();
    expect(find.text('Nhập email hợp lệ'), findsOneWidget);
    expect(find.text('Ít nhất 8 ký tự'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Community join requires account and mobile layout fits', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const ChoGan());
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Khu phố')));
    await t.pumpAndSettle();
    expect(find.text('Nhập mã mời'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.text('Nhập mã mời'));
    await t.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);
  });
  testWidgets('Invalid listing link has a readable fallback', (t) async {
    await t.pumpWidget(const MaterialApp(home: ListingLink(id: 'missing')));
    await t.pumpAndSettle();
    expect(
      find.text('Tin không còn hiển thị hoặc liên kết không hợp lệ.'),
      findsOneWidget,
    );
  });
}
