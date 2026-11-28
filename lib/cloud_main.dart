import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_app.dart';
import 'i18n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PassyLocale.initialize();
  await Supabase.initialize(
    url: 'https://yfqvfkmbvaaujheiivuz.supabase.co',
    publishableKey: 'sb_publishable_VtzXKFOkFZzwNQxWLjG57w_YMBwDNpC',
  );
  runApp(const ChoGan());
}
