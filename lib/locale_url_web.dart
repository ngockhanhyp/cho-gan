import 'package:web/web.dart' as web;

void updateLocaleUrl(String code) {
  final current = Uri.parse(web.window.location.href);
  final next = current.replace(
    queryParameters: {...current.queryParameters, 'lang': code},
  );
  web.window.history.replaceState(null, '', next.toString());
  web.window.document.documentElement?.setAttribute('lang', code);
}
