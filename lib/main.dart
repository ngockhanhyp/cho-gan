import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_app.dart';
import 'i18n.dart';
import 'social_auth.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PassyLocale.initialize();
  final callbackMessage = socialCallbackMessage(Uri.base);
  await Supabase.initialize(
    url: passySupabaseUrl,
    publishableKey: passySupabasePublishableKey,
  );
  runApp(ChoGan(authMessage: callbackMessage));
}
