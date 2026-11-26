import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cho_gan/demo_main.dart';

void main() {
  testWidgets('Feed and saved items work', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    await tester.pumpWidget(Market(prefs: p));
    await tester.pumpAndSettle();
    expect(find.text('Đồ cũ, niềm vui mới.'), findsOneWidget);
    expect(find.text('Đăng tin'), findsOneWidget);
    await tester.tap(find.text('Của tôi'));
    await tester.pumpAndSettle();
    expect(find.text('Tin của tôi'), findsOneWidget);
  });
}
