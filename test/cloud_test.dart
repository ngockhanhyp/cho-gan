import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cho_gan/cloud_app.dart';

import 'dart:convert';

void main() {
  List<Map<String, dynamic>> sampleListings = [];
  setUp(() {
    sampleListings = [];
    SharedPreferences.setMockInitialValues({});
  });
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-public-key',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('/listings') ? sampleListings : [],
          ),
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
      find.text('Khu phố đang chờ món đồ đầu tiên!'),
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
    await t.tap(find.text('Khu phố'));
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

  testWidgets(
    'Desktop filter drafts cancel safely and applied filters affect results',
    (t) async {
      t.view.physicalSize = const Size(1280, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      sampleListings = [
        for (var i = 0; i < 3; i++)
          {
            'id': 'item-$i',
            'owner_id': 'seller',
            'title': 'Món thử $i',
            'price': [300000, 100000, 200000][i],
            'area': 'Cầu Giấy',
            'category': i == 2 ? 'Điện tử' : 'Nội thất',
            'status': i == 1 ? 'sold' : 'available',
            'image_path': '',
            'created_at': '2026-11-26T01:00:00Z',
            'profiles': {'name': 'Hàng xóm'},
          },
      ];
      await t.pumpWidget(const ChoGan());
      await t.pumpAndSettle();
      expect(find.text('3 món'), findsOneWidget);
      await t.tap(find.text('Bộ lọc'));
      await t.pumpAndSettle();
      await t.tap(find.text('Chỉ hiện món đang bán'));
      await t.tap(find.byTooltip('Đóng bộ lọc'));
      await t.pumpAndSettle();
      expect(find.text('3 món'), findsOneWidget);
      await t.tap(find.text('Bộ lọc'));
      await t.pumpAndSettle();
      await t.tap(find.text('Chỉ hiện món đang bán'));
      await t.tap(find.text('Áp dụng'));
      await t.pumpAndSettle();
      expect(find.text('2 món'), findsOneWidget);
      expect(find.text('Món thử 1'), findsNothing);
      await t.enterText(find.byType(TextField).first, 'Món thử 2');
      await t.pumpAndSettle();
      expect(find.text('1 món'), findsOneWidget);
      await t.tap(find.text('Món thử 2', findRichText: false).first);
      await t.pumpAndSettle();
      expect(find.text('Chi tiết món đồ'), findsOneWidget);
      expect(find.text('Nhắn tin hỏi mua'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
