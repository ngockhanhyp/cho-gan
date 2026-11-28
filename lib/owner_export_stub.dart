void downloadOwnerCsv(String filename, String content) =>
    throw UnsupportedError('Tải CSV khả dụng trên web.');

Future<String> createOwnerSheet(String clientId, String title, String rows) =>
    Future.error(UnsupportedError('Google Sheets khả dụng trên web.'));

Future<String> readOwnerWorkbook() => Future.error(UnsupportedError('Chỉ hỗ trợ trên web.'));

Future<String> readOwnerSheet(String clientId, String url) =>
    Future.error(UnsupportedError('Chỉ hỗ trợ trên web.'));

Future<String> readPublicOwnerSheet(String url) =>
    Future.error(UnsupportedError('Chỉ hỗ trợ trên web.'));
