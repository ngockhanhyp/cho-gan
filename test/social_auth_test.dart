import 'dart:async';
import 'dart:convert';

import 'package:cho_gan/cloud_app.dart';
import 'package:cho_gan/social_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-public-key',
      httpClient: MockClient(
        (request) async => http.Response(
          request.url.path.endsWith('/user')
              ? jsonEncode({
                  'id': '11111111-1111-4111-8111-111111111111',
                  'aud': 'authenticated',
                  'app_metadata': {},
                  'user_metadata': {'name': 'Người thử'},
                })
              : '[]',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });

  test(
    'Callback returns to current web install and strips tokens and queries',
    () {
      expect(
        passySocialRedirect(
          web: true,
          base: Uri.parse('https://passy.id.vn/?code=secret#/listing/123'),
        ),
        'https://passy.id.vn/',
      );
      expect(
        passySocialRedirect(
          web: true,
          base: Uri.parse('http://localhost:8788/test/?error=bad'),
        ),
        'http://localhost:8788/test/',
      );
      expect(
        passySocialRedirect(
          web: false,
          base: Uri.parse('https://passy.id.vn/'),
        ),
        passyMobileAuthRedirect,
      );
    },
  );

  test('OAuth cancellation/error never exposes callback descriptions', () {
    expect(
      socialCallbackMessage(
        Uri.parse(
          'https://passy.id.vn/?error=access_denied&error_description=private',
        ),
      ),
      contains('hủy'),
    );
    final message = socialCallbackMessage(
      Uri.parse(
        'https://passy.id.vn/#error=server_error&error_description=secret-token',
      ),
    );
    expect(message, isNot(contains('secret-token')));
    expect(
      socialCallbackMessage(Uri.parse('https://passy.id.vn/#/listing/123')),
      isNull,
    );
  });

  test(
    'Public provider settings correctly separate Google and Facebook',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/auth/v1/settings');
        expect(request.headers.containsKey('authorization'), false);
        return http.Response(
          jsonEncode({
            'external': {'google': true, 'facebook': false},
          }),
          200,
        );
      });
      addTearDown(client.close);
      expect(
        await isSocialProviderEnabled(OAuthProvider.google, client: client),
        true,
      );
      expect(
        await isSocialProviderEnabled(OAuthProvider.facebook, client: client),
        false,
      );
    },
  );

  test('Bad settings never launch an unverified provider', () async {
    final client = MockClient((_) async => http.Response('[]', 200));
    addTearDown(client.close);
    await expectLater(
      isSocialProviderEnabled(OAuthProvider.google, client: client),
      throwsA(isA<AuthException>()),
    );
  });

  testWidgets(
    'Both buttons bypass email validation; launch failure allows retry',
    (t) async {
      final calls = <OAuthProvider>[];
      await t.pumpWidget(
        MaterialApp(
          home: Login(
            showFacebook: true,
            socialSignIn: (provider) async {
              calls.add(provider);
              return false;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('sign-in-google')));
      await t.pumpAndSettle();
      expect(calls, [OAuthProvider.google]);
      expect(find.text('Nhập email hợp lệ'), findsNothing);
      expect(find.textContaining('Không mở được'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('sign-in-facebook')));
      await t.pumpAndSettle();
      expect(calls, [OAuthProvider.google, OAuthProvider.facebook]);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Pending OAuth blocks duplicate attempts and user can cancel waiting',
    (t) async {
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var attempts = 0;
      final completer = Completer<bool>();
      await t.pumpWidget(
        MaterialApp(
          home: Login(
            showFacebook: true,
            socialSignIn: (_) {
              attempts++;
              return completer.future;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('sign-in-google')));
      await t.pump();
      expect(
        t
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('sign-in-facebook')),
            )
            .onPressed,
        isNull,
      );
      completer.complete(true);
      await t.pumpAndSettle();
      expect(attempts, 1);
      await t.tap(find.text('Quay lại chọn cách đăng nhập'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('sign-in-facebook')),
            )
            .onPressed,
        isNotNull,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Disabled provider shows a readable error and leaves email usable',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Login(
            showFacebook: true,
            socialSignIn: (_) async =>
                throw const AuthException('provider_disabled'),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('sign-in-facebook')));
      await t.pumpAndSettle();
      expect(find.textContaining('chưa được kích hoạt'), findsOneWidget);
      expect(
        t
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('sign-in-google')),
            )
            .onPressed,
        isNotNull,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Successful Supabase session closes social login once', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Login(socialSignIn: (_) async => true),
                ),
              ),
              child: const Text('Mở đăng nhập'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Mở đăng nhập'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('sign-in-facebook')), findsNothing);
    await t.tap(find.byKey(const ValueKey('sign-in-google')));
    await t.pumpAndSettle();
    expect(find.text('Quay lại chọn cách đăng nhập'), findsOneWidget);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    String segment(Map<String, Object> data) =>
        base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
    final token =
        '${segment({'alg': 'HS256', 'typ': 'JWT'})}.${segment({'sub': '11111111-1111-4111-8111-111111111111', 'iat': now, 'exp': now + 3600})}.c2lnbmF0dXJl';
    await t.runAsync(
      () => Supabase.instance.client.auth.setSession(
        'test-refresh',
        accessToken: token,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Mở đăng nhập'), findsOneWidget);
    expect(find.byKey(const ValueKey('sign-in-google')), findsNothing);
    expect(t.takeException(), isNull);
    await t.runAsync(() => Supabase.instance.client.auth.signOut());
  });
}
