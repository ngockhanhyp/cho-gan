import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('passyCreateOwnerSheet')
external JSPromise<JSString> _createSheet(JSString clientId, JSString title, JSString rows);

Future<String> createOwnerSheet(String clientId, String title, String rows) async =>
    (await _createSheet(clientId.toJS, title.toJS, rows.toJS).toDart).toDart;

void downloadOwnerCsv(String filename, String content) {
  final blob = web.Blob([content.toJS].toJS, web.BlobPropertyBag(type: 'text/csv;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.appendChild(link);
  link.click();
  link.remove();
  Future<void>.delayed(const Duration(seconds: 5), () => web.URL.revokeObjectURL(url));
}
