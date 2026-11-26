import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://yfqvfkmbvaaujheiivuz.supabase.co',
    publishableKey: 'sb_publishable_VtzXKFOkFZzwNQxWLjG57w_YMBwDNpC',
  );
  runApp(const ChoGan());
}
