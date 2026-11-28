part of 'cloud_app.dart';

const _importColumns = ['title', 'description', 'price', 'category', 'area', 'image_url'];
const _importAliases = {
  'tiêu đề': 'title', 'tên món đồ': 'title', 'nội dung': 'description',
  'mô tả': 'description', 'giá': 'price', 'danh mục': 'category',
  'khu vực': 'area', 'ảnh': 'image_url', 'link ảnh': 'image_url',
};

String? _listingImageMime(Uint8List bytes) => switch (bytes) {
  [0xff, 0xd8, 0xff, ...] => 'image/jpeg',
  [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, ...] => 'image/png',
  [0x52, 0x49, 0x46, 0x46, _, _, _, _, 0x57, 0x45, 0x42, 0x50, ...] => 'image/webp',
  _ => null,
};

String _newOwnerBatchId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final id = bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  return '${id.substring(0, 8)}-${id.substring(8, 12)}-${id.substring(12, 16)}-${id.substring(16, 20)}-${id.substring(20)}';
}

class _ImportListing {
  final int line;
  final Map<String, dynamic> values;
  final List<Uri> images;
  final paths = <String>[];

  _ImportListing(this.line, this.values, this.images);
}

class OwnerImportPage extends StatefulWidget {
  const OwnerImportPage({super.key});

  @override
  State<OwnerImportPage> createState() => _OwnerImportPageState();
}

class _OwnerImportPageState extends State<OwnerImportPage> {
  late final String? ownerId;
  final sheetLink = TextEditingController();
  final googleClient = TextEditingController();
  final rows = <_ImportListing>[];
  final errors = <String>[];
  bool busy = false;
  int posted = 0;
  String progress = '';
  String? batchId;
  bool submitted = false;

  @override
  void initState() {
    super.initState();
    ownerId = db.auth.currentUser?.id;
    SharedPreferences.getInstance().then((prefs) {
      if (mounted && googleClient.text.isEmpty) {
        googleClient.text = prefs.getString('passy_sheets_oauth_client') ?? '';
      }
    });
  }

  @override
  void dispose() {
    _discardUploads();
    sheetLink.dispose();
    googleClient.dispose();
    super.dispose();
  }

  void _discardUploads() {
    if (submitted || db.auth.currentUser?.id != ownerId) return;
    final paths = [for (final row in rows) ...row.paths];
    if (paths.isNotEmpty) {
      unawaited(db.storage.from('listing-images').remove(paths).then<void>((_) {}, onError: (_) {}));
    }
  }

  void _parse(String json) {
    final workbook = List<List<dynamic>>.from(jsonDecode(json));
    if (workbook.length < 2) throw const FormatException('Bảng chưa có dữ liệu.');
    if (workbook.length > 51) throw const FormatException('Mỗi lô nhận tối đa 50 tin.');
    String cell(Object? value) => value?.toString().replaceFirst('\uFEFF', '').trim() ?? '';
    final headers = workbook.first.map((value) {
      final normalized = cell(value).toLowerCase();
      return _importAliases[normalized] ?? normalized;
    }).toList();
    if (!_importColumns.every(headers.contains) || headers.where(_importColumns.contains).toSet().length !=
        headers.where(_importColumns.contains).length) {
      throw const FormatException('Dòng đầu phải có đủ sáu tên cột khác nhau theo mẫu.');
    }
    rows.clear();
    errors.clear();
    for (final (index, row) in workbook.skip(1).indexed) {
      if (row.every((value) => cell(value).isEmpty)) continue;
      final line = index + 2;
      String field(String name) {
        final column = headers.indexOf(name);
        return column < row.length ? cell(row[column]) : '';
      }
      final title = field('title');
      final description = field('description');
      final price = int.tryParse(field('price'));
      final category = field('category');
      final area = field('area');
      final urls = field('image_url').split(RegExp(r'[|\n]'))
          .map((text) => Uri.tryParse(text.trim())).toList();
      final issues = <String>[
        if (title.length < 4 || title.length > 160) 'tiêu đề 4–160 ký tự',
        if (description.length < 10 || description.length > 4000) 'mô tả 10–4.000 ký tự',
        if (price == null || price < 0 || price > 100000000000) 'giá nguyên bằng đồng',
        if (!categoryIcons.containsKey(category) || category == 'Tất cả') 'danh mục hợp lệ',
        if (area.isEmpty || area.length > 100) 'khu vực',
        if (urls.length > 10 || urls.any((uri) =>
            uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty))
          '1–10 link ảnh HTTPS',
      ];
      if (issues.isNotEmpty) {
        errors.add('Dòng $line · ${issues.join(', ')}');
      } else {
        rows.add(_ImportListing(line, {
          'title': title, 'description': description, 'price': price,
          'category': category, 'area': area,
        }, urls.cast<Uri>()));
      }
    }
    if (rows.isEmpty && errors.isEmpty) errors.add('Bảng chưa có tin đăng.');
    batchId = _newOwnerBatchId();
  }

  Future<void> _read(bool fromGoogle, {bool privateSheet = false}) async {
    if (busy || submitted) return;
    if (fromGoogle && sheetLink.text.trim().isEmpty) {
      notice(context, 'Dán link Google Sheets.');
      return;
    }
    if (privateSheet && !googleClient.text.trim().endsWith('.apps.googleusercontent.com')) {
      notice(context, 'Nhập OAuth Client ID của Passy để mở bảng tính riêng tư.');
      return;
    }
    setState(() { busy = true; progress = 'Đang đọc bảng…'; });
    try {
      final clientId = googleClient.text.trim();
      final link = sheetLink.text.trim();
      final json = !fromGoogle ? await readOwnerWorkbook()
          : privateSheet ? await readOwnerSheet(clientId, link)
          : await readPublicOwnerSheet(link);
      if (!mounted || json.isEmpty) return;
      if (privateSheet) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('passy_sheets_oauth_client', clientId);
      }
      if (mounted) {
        _discardUploads();
        setState(() { posted = 0; _parse(json); });
      }
    } on FormatException catch (error) {
      if (mounted) setState(() { rows.clear(); errors..clear()..add(error.message); });
    } catch (_) {
      if (mounted) setState(() {
        rows.clear();
        errors..clear()..add(fromGoogle
          ? privateSheet
            ? 'Không đọc được bảng riêng tư. Kiểm tra quyền xem, Client ID và giới hạn 50 dòng.'
            : 'Không đọc được bảng. Kiểm tra link đúng tab, quyền “Bất kỳ ai có đường liên kết” và giới hạn 50 dòng.'
          : 'Không đọc được tệp. Hãy chọn XLSX hoặc CSV tối đa 5 MB và 50 dòng.');
      });
    } finally {
      if (mounted) setState(() { busy = false; progress = ''; });
    }
  }

  Future<Uint8List> _download(Uri uri) async {
    final client = http.Client();
    const limit = 5 * 1024 * 1024;
    try {
      final request = http.Request('GET', uri);
      final response = await client.send(request).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 || (response.contentLength ?? 0) > limit) {
        throw const FormatException('Link ảnh lỗi hoặc ảnh vượt 5 MB.');
      }
      final bytes = await response.stream
          .timeout(const Duration(seconds: 15)).fold<BytesBuilder>(BytesBuilder(), (output, chunk) {
        if (output.length + chunk.length > limit) throw const FormatException('Ảnh vượt 5 MB.');
        return output..add(chunk);
      });
      return bytes.takeBytes();
    } finally {
      client.close();
    }
  }

  Future<void> _publish() async {
    if (busy || rows.isEmpty || errors.isNotEmpty || ownerId == null) return;
    final approved = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: Text('Đăng ${rows.length} tin lên chợ?'),
      content: const Text('Tin hiển thị công khai và đứng tên tài khoản chủ đang đăng nhập.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Đăng lên chợ')),
      ],
    ));
    if (!mounted || approved != true || db.auth.currentUser?.id != ownerId) return;
    setState(() { busy = true; progress = 'Đang kiểm tra quyền đăng…'; });
    try {
      if (await db.rpc('is_passy_owner') != true) throw const FormatException('Tài khoản thiếu quyền chủ Passy.');
      for (final row in rows) {
        for (var index = row.paths.length; index < row.images.length; index++) {
          if (!mounted || db.auth.currentUser?.id != ownerId) return;
          setState(() => progress = 'Dòng ${row.line} · Đang tải ảnh ${index + 1}/${row.images.length}');
          try {
            final bytes = await _download(row.images[index]);
            final mime = _listingImageMime(bytes);
            if (mime == null) throw const FormatException('Ảnh phải là JPG, PNG hoặc WebP.');
            final ext = {'image/png': 'png', 'image/webp': 'webp'}[mime] ?? 'jpg';
            final path = '$ownerId/${DateTime.now().microsecondsSinceEpoch}-$index.$ext';
            if (!mounted || db.auth.currentUser?.id != ownerId) return;
            await db.storage.from('listing-images').uploadBinary(path, bytes,
              fileOptions: FileOptions(contentType: mime));
            row.paths.add(path);
          } catch (_) {
            throw FormatException('Dòng ${row.line}, ảnh ${index + 1} · Dùng link tải trực tiếp JPG, PNG hoặc WebP tối đa 5 MB, cho phép Passy đọc ảnh.');
          }
        }
      }
      if (!mounted || db.auth.currentUser?.id != ownerId) return;
      setState(() { submitted = true; progress = 'Đang đăng cả lô…'; });
      final count = await db.rpc('owner_import_listings', params: {
        'batch': batchId,
        'listings': [for (final row in rows) {...row.values, 'photos': row.paths}],
      });
      if (mounted) setState(() {
        posted = count as int;
        rows.clear();
        submitted = false;
      });
    } on FormatException catch (error) {
      if (mounted) notice(context, error.message);
    } catch (error) {
      if (mounted) notice(context, friendly(error));
    } finally {
      if (mounted) setState(() { busy = false; progress = ''; });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(canPop: !busy, child: Scaffold(
    appBar: AppBar(title: const Text('Đăng tin hàng loạt')),
    body: PageBody(maxWidth: 820, children: [
      const Text('Dùng tab đầu của Excel hoặc dán link đúng tab Google Sheets. Mỗi dòng là một tin và tối đa 50 tin mỗi lô.'),
      const SizedBox(height: 8),
      const Text('Cột ảnh nhận link HTTPS trực tiếp. Phân cách nhiều link bằng dấu |. Giá 0 là cho tặng.'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: busy ? null : () => downloadOwnerCsv('passy-mau-dang-tin.csv',
          '\uFEFF${_importColumns.join(',')}\r\n'),
          icon: const Icon(Icons.download), label: const Text('Tải mẫu cho Excel')),
        FilledButton.icon(onPressed: busy || submitted ? null : () => _read(false),
          icon: const Icon(Icons.upload_file), label: const Text('Chọn tệp XLSX hoặc CSV')),
      ]),
      const SizedBox(height: 12),
      TextField(controller: sheetLink, enabled: !busy && !submitted,
        decoration: const InputDecoration(labelText: 'Link Google Sheets')),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: busy || submitted ? null : () => _read(true),
        child: const Text('Đọc link chia sẻ')),
      const Text('Trong Google Sheets, chọn Chia sẻ → Bất kỳ ai có đường liên kết → Người xem.'),
      ExpansionTile(
        title: const Text('Dùng bảng tính riêng tư'),
        children: [
          TextField(controller: googleClient, enabled: !busy && !submitted,
            decoration: const InputDecoration(labelText: 'Google OAuth Client ID')),
          OutlinedButton(onPressed: busy || submitted ? null : () => _read(true, privateSheet: true),
            child: const Text('Đăng nhập Google và đọc bảng')),
        ],
      ),
      if (busy) ...[const LinearProgressIndicator(), Text(progress)],
      if (posted > 0) Text('Đã đăng $posted tin.'),
      for (final error in errors) ListTile(leading: const Icon(Icons.error_outline), title: Text(error)),
      if (rows.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('${rows.length} tin trong bản xem trước'),
        for (final row in rows)
          ListTile(
            title: Text('Dòng ${row.line} · ${row.values['title']}'),
            subtitle: Text('${money(row.values['price'])} · ${row.values['category']} · ${row.values['area']} · ${row.images.length} ảnh'),
          ),
        FilledButton(onPressed: busy || errors.isNotEmpty ? null : _publish,
          child: Text(submitted ? 'Thử lại cùng lô' : 'Xác nhận đăng ${rows.length} tin')),
      ],
    ]),
  ));
}
