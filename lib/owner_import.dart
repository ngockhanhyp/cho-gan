part of 'cloud_app.dart';

const _importColumns = ['title', 'description', 'price', 'category', 'area', 'image_url'];
const _importLabels = {
  'title': 'Tiêu đề', 'description': 'Mô tả', 'price': 'Giá (đồng)',
  'category': 'Danh mục', 'area': 'Khu vực', 'image_url': 'Link ảnh',
};
const _importSeparators = {
  'title': ' ', 'description': '\n', 'area': ', ', 'image_url': '\n',
};

String _importCell(Object? value) => value?.toString().replaceFirst('\uFEFF', '').trim() ?? '';

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
  final Map<String, String> fields;
  final paths = <String>[];
  List<XFile> localImages = [];
  int get photoCount => localImages.isEmpty ? imageLinks.length : localImages.length;

  _ImportListing(this.line, this.fields);

  int? get price {
    final amount = fields['price']!.replaceFirst(RegExp(r'\s*(đ|₫|vnd|vnđ)$', caseSensitive: false), '').trim();
    if (RegExp(r'^\d+$').hasMatch(amount)) return int.tryParse(amount);
    for (final separator in ['.', ',', ' ']) {
      final groups = amount.replaceAll('\u00a0', ' ').split(separator);
      if (groups.length > 1 && RegExp(r'^\d{1,3}$').hasMatch(groups.first) &&
          groups.skip(1).every(RegExp(r'^\d{3}$').hasMatch)) {
        return int.tryParse(groups.join());
      }
    }
    return null;
  }

  List<Uri?> get imageLinks => fields['image_url']!
      .split(RegExp(r'[|\n]')).map((value) => value.trim()).where((value) => value.isNotEmpty)
      .map(Uri.tryParse).toList();

  List<String> get issues {
    final links = imageLinks;
    final amount = price;
    final titleLength = fields['title']!.runes.length;
    final descriptionLength = fields['description']!.runes.length;
    final areaLength = fields['area']!.runes.length;
    final category = fields['category']!;
    return [
      if (titleLength < 4 || titleLength > 160) 'tiêu đề 4–160 ký tự',
      if (descriptionLength < 10 || descriptionLength > 4000) 'mô tả 10–4.000 ký tự',
      if (amount == null || amount < 0 || amount > 100000000000) 'giá nguyên bằng đồng',
      if (!categoryIcons.containsKey(category) || category == 'Tất cả') 'danh mục hợp lệ',
      if (areaLength < 1 || areaLength > 100) 'khu vực 1–100 ký tự',
      if (localImages.isEmpty && (links.isEmpty || links.length > 10 || links.any((uri) =>
          uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty)))
        '1–10 link ảnh HTTPS',
    ];
  }

  Map<String, dynamic> get payload => {
    for (final field in _importColumns)
      if (field != 'image_url') field: field == 'price' ? price : fields[field],
    'photos': paths,
  };
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
  final mapping = {for (final field in _importColumns) field: <int>[]};
  final stepKey = GlobalKey();
  List<List<dynamic>> source = [];
  String? readError;
  bool showMapping = false;
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

  void _discardUploads([Iterable<_ImportListing>? drafts]) {
    if (submitted || db.auth.currentUser?.id != ownerId) return;
    final paths = [for (final row in drafts ?? rows) ...row.paths];
    if (paths.isNotEmpty) {
      unawaited(db.storage.from('listing-images').remove(paths).then<void>((_) {}, onError: (_) {}));
    }
  }

  void _goToStep() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = stepKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 240), alignment: 0.03);
      }
    });
  }

  void _loadSource(String json) {
    final workbook = List<List<dynamic>>.from(jsonDecode(json));
    if (workbook.length < 2 || workbook.skip(1).every((row) =>
        row.every((value) => _importCell(value).isEmpty))) {
      throw const FormatException('Bảng chưa có dòng dữ liệu.');
    }
    if (workbook.length > 51) throw const FormatException('Mỗi lô nhận tối đa 50 tin.');
    _discardUploads();
    setState(() {
      source = workbook;
      rows.clear();
      for (final columns in mapping.values) {
        columns.clear();
      }
      showMapping = true;
      posted = 0;
    });
    _goToStep();
  }

  String _columnLabel(int index) {
    var number = index + 1;
    var letter = '';
    while (number > 0) {
      number--;
      letter = String.fromCharCode(65 + number % 26) + letter;
      number ~/= 26;
    }
    final header = index < source.first.length ? _importCell(source.first[index]) : '';
    return header.isEmpty ? 'Cột $letter' : '$letter · $header';
  }

  void _makePreview() {
    _discardUploads();
    setState(() {
      rows.clear();
      for (final (index, sourceRow) in source.skip(1).indexed) {
        if (sourceRow.every((value) => _importCell(value).isEmpty)) continue;
        rows.add(_ImportListing(index + 2, {
          for (final field in _importColumns)
            field: mapping[field]!.where((column) => column < sourceRow.length)
                .map((column) => _importCell(sourceRow[column])).where((value) => value.isNotEmpty)
                .join(_importSeparators[field] ?? ''),
        }));
      }
      showMapping = false;
      batchId = _newOwnerBatchId();
    });
    _goToStep();
  }

  Future<void> _editDraft(_ImportListing row) async {
    final values = Map<String, String>.of(row.fields);
    var localImages = row.localImages;
    var picking = false;
    final edited = await showDialog<bool>(context: context, builder: (dialog) =>
      StatefulBuilder(builder: (context, redraw) => AlertDialog(
      title: Text('Sửa tin · Dòng ${row.line}'),
      content: SizedBox(width: 560, child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final field in _importColumns)
            if (field == 'category')
              Padding(padding: const EdgeInsets.only(bottom: 12), child:
                _categoryPicker(values[field]!, (value) => values[field] = value))
            else Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(
              initialValue: values[field],
              decoration: InputDecoration(labelText: _importLabels[field],
                helperText: field == 'image_url' ? 'Mỗi link một dòng' : null),
              minLines: field == 'description' ? 4 : 1,
              maxLines: field == 'description' || field == 'image_url' ? 8 : 1,
              keyboardType: field == 'price' ? TextInputType.number : TextInputType.text,
              onChanged: (value) => values[field] = value.trim(),
            )),
          OutlinedButton.icon(
            onPressed: picking ? null : () async {
              redraw(() => picking = true);
              try {
                final files = await ImagePicker().pickMultiImage(limit: 10, maxWidth: 1600, imageQuality: 85);
                if (context.mounted && files.isNotEmpty) redraw(() => localImages = files.take(10).toList());
              } catch (_) {
                if (context.mounted) notice(context, 'Không chọn được tệp ảnh.');
              } finally {
                if (context.mounted) redraw(() => picking = false);
              }
            },
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Chọn ảnh từ thiết bị'),
          ),
          if (localImages.isNotEmpty)
            TextButton(onPressed: picking ? null : () => redraw(() => localImages = []),
              child: Text('Đã chọn ${localImages.length} ảnh. Dùng lại link ảnh')),

        ]),
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Hủy')),
        FilledButton(onPressed: picking ? null : () => Navigator.pop(dialog, true), child: const Text('Lưu bản nháp')),
      ],
    )));
    if (!mounted || edited != true) return;
    if (values['image_url'] != row.fields['image_url'] || !identical(localImages, row.localImages)) {
      _discardUploads([row]);
      row.paths.clear();
    }
    setState(() { row.fields.addAll(values); row.localImages = localImages; });
  }

  Widget _columnMapping(int width) => Column(
    key: stepKey, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Ghép cột với trường Passy', style: Theme.of(context).textTheme.titleLarge),
      const Text('Chọn cột cho từng trường. Với mô tả, mỗi cột đã chọn sẽ nằm trên một dòng theo thứ tự bên dưới. Trường để trống có thể điền trong bản xem trước.'),
      for (final field in _importColumns) ...[
        const SizedBox(height: 10),
        _fieldMapping(field, width),
      ],
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton(onPressed: busy || !mapping.values.any((columns) => columns.isNotEmpty)
            ? null : _makePreview, child: Text(rows.isEmpty ? 'Xem trước tin đăng' : 'Tạo lại bản xem trước')),
        if (rows.isNotEmpty) TextButton(onPressed: busy ? null : () {
          setState(() => showMapping = false);
          _goToStep();
        }, child: const Text('Quay lại bản nháp')),
      ]),
      if (rows.isNotEmpty)
        const Text('Tạo lại bản xem trước sẽ áp dụng cách ghép mới và thay thế các chỉnh sửa từng tin.'),
    ],
  );

  Widget _fieldMapping(String field, int width) {
    final columns = mapping[field]!;
    final multi = _importSeparators.containsKey(field);
    final available = [for (var i = 0; i < width; i++) if (!columns.contains(i)) i];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_importLabels[field]!, style: Theme.of(context).textTheme.titleSmall),
      for (final (index, column) in columns.indexed)
        Row(children: [
          Expanded(child: Text(_columnLabel(column), maxLines: 2, overflow: TextOverflow.ellipsis)),
          if (index > 0)
            IconButton(tooltip: 'Đưa cột lên trên', icon: const Icon(Icons.arrow_upward),
              onPressed: busy ? null : () => setState(() {
                columns.removeAt(index);
                columns.insert(index - 1, column);
              })),
          IconButton(tooltip: 'Bỏ cột', icon: const Icon(Icons.close),
            onPressed: busy ? null : () => setState(() => columns.removeAt(index))),
        ]),
      if ((multi || columns.isEmpty) && available.isNotEmpty)
        DropdownButton<int>(
          isExpanded: true,
          hint: Text(columns.isEmpty ? 'Chọn cột nguồn' : 'Ghép thêm cột'),
          items: [for (final column in available) DropdownMenuItem(
            value: column, child: Text(_columnLabel(column), overflow: TextOverflow.ellipsis))],
          onChanged: busy ? null : (column) {
            if (column != null) setState(() => columns.add(column));
          },
        ),
    ]);
  }

  Widget _categoryPicker(String current, ValueChanged<String> onChanged) {
    final categories = categoryIcons.keys.where((name) => name != 'Tất cả').toList();
    return DropdownButtonFormField<String>(
      initialValue: categories.contains(current) ? current : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: 'Danh mục Passy',
        helperText: current.isNotEmpty && !categories.contains(current) ? 'Danh mục từ bảng: $current' : null),
      hint: const Text('Chọn danh mục có sẵn'),
      items: [
        for (final name in categories) DropdownMenuItem(value: name, child: Text(name)),
      ],
      onChanged: busy || submitted ? null : (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  Widget _preview() {
    final invalid = rows.where((row) => row.issues.isNotEmpty).length;
    return Column(key: stepKey, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Bản xem trước · ${rows.length} tin', style: Theme.of(context).textTheme.titleLarge),
      if (invalid > 0) Text('$invalid tin cần bổ sung hoặc chỉnh sửa trước khi đăng.'),
      if (!submitted)
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: busy ? null : () {
            setState(() => showMapping = true);
            _goToStep();
          },
          icon: const Icon(Icons.swap_horiz), label: const Text('Đổi cách ghép cột'),
        )),
      for (final row in rows)
        Card(child: Column(children: [
        ListTile(
          title: Text('Dòng ${row.line} · ${row.fields['title']!.isEmpty ? 'Chưa có tiêu đề' : row.fields['title']}'),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text([
              if (row.price != null) money(row.price),
              if (row.fields['category']!.isNotEmpty) row.fields['category'],
              if (row.fields['area']!.isNotEmpty) row.fields['area'],
              '${row.photoCount} ảnh',
            ].join(' · ')),
            if (row.fields['description']!.isNotEmpty)
              Text(row.fields['description']!, maxLines: 4, overflow: TextOverflow.ellipsis),
            if (row.issues.isNotEmpty)
              Text('Cần kiểm tra ${row.issues.join(', ')}.',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
          trailing: IconButton(tooltip: 'Sửa tin dòng ${row.line}', icon: const Icon(Icons.edit_outlined),
            onPressed: busy || submitted ? null : () => _editDraft(row)),
          onTap: busy || submitted ? null : () => _editDraft(row),
        ),
        if (!categoryIcons.containsKey(row.fields['category']) || row.fields['category'] == 'Tất cả')
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _categoryPicker(row.fields['category']!, (value) =>
              setState(() => row.fields['category'] = value))),
        ])),
      const SizedBox(height: 12),
      FilledButton(onPressed: busy || invalid > 0 ? null : _publish,
        child: Text(submitted ? 'Thử lại cùng lô' : 'Xác nhận đăng ${rows.length} tin')),
    ]);
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
    setState(() { busy = true; progress = 'Đang đọc bảng…'; readError = null; });
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
      if (mounted) _loadSource(json);
    } on FormatException catch (error) {
      if (mounted) setState(() => readError = error.message);
    } catch (_) {
      if (mounted) setState(() {
        readError = fromGoogle
          ? privateSheet
            ? 'Không đọc được bảng riêng tư. Kiểm tra quyền xem, Client ID và giới hạn 50 dòng.'
            : 'Không đọc được bảng. Kiểm tra link đúng tab, quyền “Bất kỳ ai có đường liên kết” và giới hạn 50 dòng.'
          : 'Không đọc được tệp. Hãy chọn XLSX hoặc CSV tối đa 5 MB và 50 dòng.';
      });
    } finally {
      if (mounted) setState(() { busy = false; progress = ''; });
    }
  }

  Future<Uint8List> _download(Uri uri) async {
    if (uri.host == 'drive.google.com') {
      final id = RegExp(r'^/file/d/([a-zA-Z0-9_-]+)(?:/|$)').firstMatch(uri.path)?.group(1)
          ?? uri.queryParameters['id'];
      if (id != null && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
        uri = Uri.https('lh3.googleusercontent.com', '/d/$id', {
          if (uri.queryParameters['resourcekey'] case final key?) 'resourcekey': key,
        });
      }
    }
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
    if (busy || rows.isEmpty || rows.any((row) => row.issues.isNotEmpty) || ownerId == null) return;
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
        for (var index = row.paths.length; index < row.photoCount; index++) {
          if (!mounted || db.auth.currentUser?.id != ownerId) return;
          setState(() => progress = 'Dòng ${row.line} · Đang tải ảnh ${index + 1}/${row.photoCount}');
          try {
            final bytes = row.localImages.isEmpty ? await _download(row.imageLinks[index]!)
                : await row.localImages[index].readAsBytes();
            if (bytes.length > 5 * 1024 * 1024) throw const FormatException('Ảnh vượt 5 MB.');
            final mime = _listingImageMime(bytes);
            if (mime == null) throw const FormatException('Ảnh phải là JPG, PNG hoặc WebP.');
            final ext = {'image/png': 'png', 'image/webp': 'webp'}[mime] ?? 'jpg';
            final path = '$ownerId/${DateTime.now().microsecondsSinceEpoch}-$index.$ext';
            if (!mounted || db.auth.currentUser?.id != ownerId) return;
            await db.storage.from('listing-images').uploadBinary(path, bytes,
              fileOptions: FileOptions(contentType: mime));
            row.paths.add(path);
          } catch (_) {
            throw FormatException('Dòng ${row.line}, ảnh ${index + 1} · Passy không đọc được ảnh. Hãy mở quyền xem ảnh Drive hoặc chọn ảnh từ thiết bị trong bản xem trước. Nhận JPG, PNG hoặc WebP tối đa 5 MB.');
          }
        }
      }
      if (!mounted || db.auth.currentUser?.id != ownerId) return;
      setState(() { submitted = true; progress = 'Đang đăng cả lô…'; });
      final count = await db.rpc('owner_import_listings', params: {
        'batch': batchId,
        'listings': [for (final row in rows) row.payload],
      });
      if (mounted) setState(() {
        posted = count as int;
        rows.clear();
        source = [];
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
      if (readError != null)
        ListTile(leading: const Icon(Icons.error_outline), title: Text(readError!)),
      if (source.isNotEmpty) ...[
        const SizedBox(height: 16),
        if (showMapping)
          _columnMapping(source.fold<int>(0, (width, row) => row.length > width ? row.length : width))
        else
          _preview(),
      ],
    ]),
  ));
}
