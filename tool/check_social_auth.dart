import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:cho_gan/supabase_config.dart';

/// Read only. Prints availability flags, never tokens or provider secrets.
Future<void> main() async {
  final client = http.Client();
  try {
    final response = await client
        .get(
          Uri.parse('$passySupabaseUrl/auth/v1/settings'),
          headers: {'apikey': passySupabasePublishableKey},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      stderr.writeln(
        'Unable to check Auth settings (HTTP ${response.statusCode}).',
      );
      exitCode = 1;
      return;
    }
    final settings = jsonDecode(response.body) as Map;
    final providers = settings['external'] as Map? ?? {};
    stdout.writeln(
      jsonEncode({
        for (final name in ['google', 'facebook'])
          name: providers[name] == true,
      }),
    );
  } catch (_) {
    stderr.writeln('Unable to reach public Auth settings.');
    exitCode = 1;
  } finally {
    client.close();
  }
}
