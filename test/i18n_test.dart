import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cho_gan/i18n.dart';
import 'package:cho_gan/i18n_catalog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PassyLocale.current.value = const Locale('vi');
  });
  test('catalog preserves every dynamic placeholder in both languages', () {
    Set<String> placeholders(String s) =>
        RegExp(r'\{\d+\}').allMatches(s).map((m) => m[0]!).toSet();
    for (final entry in passyTranslations.entries) {
      expect(entry.value.length, 2);
      for (final value in entry.value) {
        expect(value, isNotEmpty);
        expect(placeholders(value), placeholders(entry.key), reason: entry.key);
      }
    }
  });
  test(
    'English and Korean labels preserve interpolated area and item data',
    () async {
      await PassyLocale.change('en');
      expect(tr('Đăng tin'), 'Post');
      expect(tr('Tìm món đồ ở Cầu Giấy'), 'Find items in Cầu Giấy');
      expect(tr('Kết quả cho “Ghế của Khánh”'), 'Results for “Ghế của Khánh”');
      expect(tr('1 giờ trước'), '1 hour ago');
      expect(tr('2 giờ trước'), '2 hours ago');
      expect(
        localizedListingDescription('Tình trạng: Mới\n\nNội dung của Khánh'),
        'Condition: New\n\nNội dung của Khánh',
      );
      await PassyLocale.change('ko');
      expect(tr('Đăng tin'), '글쓰기');
      expect(tr('Tìm món đồ ở Cầu Giấy'), 'Cầu Giấy에서 물건 찾기');
      expect(tr('Kết quả cho “Ghế của Khánh”'), '“Ghế của Khánh” 검색 결과');
      expect(tr('Cầu Giấy'), 'Cầu Giấy');
      expect(tr('Chiếc ghế riêng của tôi'), 'Chiếc ghế riêng của tôi');
    },
  );
  test(
    'language persists and Vietnamese remains the original source',
    () async {
      await PassyLocale.change('ko');
      PassyLocale.current.value = const Locale('vi');
      await PassyLocale.initialize();
      expect(PassyLocale.current.value.languageCode, 'ko');
      await PassyLocale.change('vi');
      expect(tr('Tìm món đồ ở Cầu Giấy'), 'Tìm món đồ ở Cầu Giấy');
    },
  );
  testWidgets('visible labels update without translating user text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(children: [PassyText('Đăng tin'), Text('Cộng đồng')]),
      ),
    );
    await PassyLocale.change('en');
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w.runtimeType == Text && (w as Text).data == 'Post',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w.runtimeType == Text && (w as Text).data == 'Cộng đồng',
      ),
      findsOneWidget,
    );
    await PassyLocale.change('ko');
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w.runtimeType == Text && (w as Text).data == '글쓰기',
      ),
      findsOneWidget,
    );
  });
}
