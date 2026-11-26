import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

const passyMobileAuthRedirect = 'vn.passy.app://login-callback/';

/// Return to the same web installation without forwarding callback parameters.
String passySocialRedirect({required bool web, required Uri base}) =>
    web ? '${base.origin}${base.path}' : passyMobileAuthRedirect;

String socialProviderName(OAuthProvider provider) => switch (provider) {
  OAuthProvider.google => 'Google',
  OAuthProvider.facebook => 'Facebook',
  _ => throw ArgumentError('Unsupported Passy sign-in provider'),
};

String socialAuthErrorMessage(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('access_denied') || text.contains('cancel')) {
    return 'Bạn đã hủy đăng nhập. Có thể thử lại hoặc dùng email.';
  }
  if (text.contains('provider_disabled') || text.contains('not enabled')) {
    return 'Hình thức đăng nhập này chưa được kích hoạt. Bạn vẫn có thể dùng email.';
  }
  return 'Chưa đăng nhập được. Vui lòng thử lại hoặc dùng email.';
}

/// Never display raw OAuth descriptions, codes, tokens or callback URLs.
String? socialCallbackMessage(Uri uri) {
  final parameters = <String, String>{...uri.queryParameters};
  if (uri.fragment.contains('=')) {
    try {
      parameters.addAll(Uri.splitQueryString(uri.fragment));
    } on FormatException {
      return 'Liên kết đăng nhập không hợp lệ. Vui lòng thử lại.';
    }
  }
  if (parameters.containsKey('error') || parameters.containsKey('error_code')) {
    return socialAuthErrorMessage(
      parameters['error'] ?? parameters['error_code']!,
    );
  }
  return null;
}

/// Public Auth settings only; no admin key, provider secret or session needed.
Future<bool> isSocialProviderEnabled(
  OAuthProvider provider, {
  required http.Client client,
}) async {
  socialProviderName(provider);
  final response = await client
      .get(
        Uri.parse('$passySupabaseUrl/auth/v1/settings'),
        headers: {'apikey': passySupabasePublishableKey},
      )
      .timeout(const Duration(seconds: 8));
  if (response.statusCode != 200) {
    throw const AuthException('Unable to check sign-in availability');
  }
  final settings = jsonDecode(response.body);
  if (settings is! Map || settings['external'] is! Map) {
    throw const AuthException('Invalid sign-in settings');
  }
  return settings['external'][provider.name] == true;
}

Future<bool> startPassySocialSignIn(OAuthProvider provider) async {
  final client = http.Client();
  try {
    if (!await isSocialProviderEnabled(provider, client: client)) {
      throw const AuthException('provider_disabled');
    }
  } finally {
    client.close();
  }
  return Supabase.instance.client.auth.signInWithOAuth(
    provider,
    redirectTo: passySocialRedirect(web: kIsWeb, base: Uri.base),
    scopes: provider == OAuthProvider.facebook ? 'email' : null,
    queryParams: provider == OAuthProvider.google
        ? {'prompt': 'select_account'}
        : null,
    authScreenLaunchMode: kIsWeb
        ? LaunchMode.platformDefault
        : LaunchMode.externalApplication,
  );
}
