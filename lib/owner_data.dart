part of 'cloud_app.dart';

const _resources = {
  'profiles': 'Hồ sơ thành viên',
  'listings': 'Bài đăng',
  'appointments': 'Lịch hẹn giao dịch',
  'consignment_requests': 'Đơn ký gửi',
  'communities': 'Cộng đồng',
  'community_members': 'Thành viên cộng đồng',
  'community_posts': 'Bài trong cộng đồng',
  'community_replies': 'Bình luận cộng đồng',
  'reports': 'Báo cáo vi phạm',
  'reviews': 'Đánh giá',
  'seller_map_locations': 'Vị trí người bán',
  'conversations': 'Hồ sơ hội thoại',
  'favorites': 'Tin đã lưu',
  'blocks': 'Danh sách chặn',
  'moderators': 'Kiểm duyệt viên',
  'moderation_log': 'Nhật ký quản trị',
};

const _fieldLabels = {
  'name': 'Tên', 'area': 'Khu vực', 'title': 'Tiêu đề', 'description': 'Mô tả',
  'price': 'Giá', 'category': 'Danh mục', 'status': 'Trạng thái',
  'place': 'Địa điểm hẹn', 'meet_at': 'Giờ hẹn (ISO 8601)',
  'buyer_done': 'Người mua đã hoàn tất', 'seller_done': 'Người bán đã hoàn tất',
  'accepts_offers': 'Cho phép trả giá', 'asking_price': 'Giá đề nghị',
  'warehouse': 'Kho', 'agreed_sale_price': 'Giá bán đã chốt',
  'commission_amount': 'Phí hoa hồng', 'staff_note': 'Ghi chú nội bộ',
  'contact': 'Thông tin liên hệ', 'community_type': 'Loại cộng đồng',
  'building_location': 'Địa chỉ tòa nhà', 'body': 'Nội dung', 'topic': 'Chủ đề',
  'resolved': 'Đã xử lý', 'rating': 'Điểm đánh giá', 'user_id': 'Mã thành viên',
};

String _fieldLabel(String field) => _fieldLabels[field] ?? field;
String _ownerCell(Object? value) => value?.toString() ?? '';

String _ownerCsvCell(String value) {
  final text = RegExp(r'^[\s\uFEFF]*[=+@-]|^[\t\r\n]').hasMatch(value)
      ? "'$value"
      : value;
  return '"${text.replaceAll('"', '""')}"';
}

class OwnerDataPage extends StatefulWidget {
  const OwnerDataPage({super.key});

  @override
  State<OwnerDataPage> createState() => _OwnerDataPageState();
}

class _OwnerDataPageState extends State<OwnerDataPage> {
  String resource = _resources.keys.first;
  String search = '';
  int page = 0;
  bool busy = false;
  String? ownerId;
  late Future<Map<String, dynamic>> data;
  late final StreamSubscription<AuthState> auth;

  Future<Map<String, dynamic>> _rpc(String operation, [Map<String, dynamic> args = const {}]) async {
    return Map<String, dynamic>.from(await db.rpc('owner_data', params: {
      'resource': resource, 'operation': operation, 'page_no': page,
      'search_term': search, ...args,
    }));
  }

  @override
  void initState() {
    super.initState();
    data = _rpc('list');
    ownerId = db.auth.currentUser?.id;
    auth = db.auth.onAuthStateChange.listen((_) {
      if (mounted && db.auth.currentUser?.id != ownerId) {
        setState(() => ownerId = null);
        Navigator.of(context).popUntil((route) => route.settings.name == '/admin' || route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    auth.cancel();
    super.dispose();
  }

  void _reload() => setState(() => data = _rpc('list'));

  Future<String?> _ask(String title, {String label = 'Lý do (5–300 ký tự)', int minimum = 5}) async {
    var value = '';
    return showDialog<String>(context: context, builder: (dialog) => StatefulBuilder(
      builder: (context, redraw) => AlertDialog(
        title: Text(title),
        content: TextField(autofocus: true, maxLength: 300,
          decoration: InputDecoration(labelText: label),
          onChanged: (text) => redraw(() => value = text.trim())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Hủy')),
          FilledButton(onPressed: value.length < minimum ? null : () => Navigator.pop(dialog, value),
            child: const Text('Xác nhận')),
        ],
      ),
    ));
  }

  Future<void> _mutate(String operation, Map<String, dynamic> args) async {
    setState(() => busy = true);
    try {
      await _rpc(operation, args);
      if (!mounted) return;
      _reload();
      notice(context, 'Đã lưu và ghi nhật ký.');
    } catch (error) {
      if (mounted) notice(context, friendly(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _record(Map<String, dynamic> row, Map<String, dynamic> schema) async {
    final fields = List<String>.from(schema['editable']);
    final keys = {for (final field in List<String>.from(schema['keys'])) field: row[field]};
    final changes = <String, dynamic>{};
    var reason = '';
    const nullable = {'asking_price','agreed_sale_price','commission_amount','staff_note','building_location'};
    final operation = await showDialog<String>(context: context, builder: (dialog) => StatefulBuilder(
      builder: (context, redraw) => AlertDialog(
        title: Text(_resources[resource]!),
        content: SizedBox(width: 580, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final field in List<String>.from(schema['columns']))
              if (!fields.contains(field)) Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SelectableText('${_fieldLabel(field)} · ${_ownerCell(row[field])}'),
              ) else if (row[field] is bool)
                SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(_fieldLabel(field)),
                  value: (changes[field] ?? row[field]) as bool,
                  onChanged: (value) => redraw(() => changes[field] = value))
              else TextFormField(initialValue: _ownerCell(row[field]),
                minLines: 1, maxLines: 4,
                decoration: InputDecoration(labelText: _fieldLabel(field)),
                onChanged: (value) => redraw(() {
                  changes[field] = value.isEmpty && nullable.contains(field) ? null : value;
                })),
            if (fields.isNotEmpty)
              TextField(decoration: const InputDecoration(labelText: 'Lý do chỉnh sửa'), maxLength: 300,
                onChanged: (text) => redraw(() => reason = text.trim())),
          ],
        ))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Đóng')),
          if (schema['deletable'] == true)
            TextButton(onPressed: () => Navigator.pop(dialog, 'delete'), child: const Text('Xóa bản ghi')),
          if (fields.isNotEmpty)
            FilledButton(
              onPressed: changes.isEmpty || reason.length < 5 ? null : () => Navigator.pop(dialog, 'update'),
              child: const Text('Lưu thay đổi')),
        ],
      ),
    ));
    if (!mounted || operation == null) return;
    if (operation == 'delete') {
      final deleteReason = await _ask('Xác nhận xóa bản ghi');
      if (deleteReason == null || !mounted) return;
      reason = deleteReason;
    }
    await _mutate(operation, {
      'record_key': keys, 'version': row['_version'], 'changes': changes, 'reason': reason,
    });
  }

  Future<void> _addModerator() async {
    final id = await _ask('Thêm kiểm duyệt viên', label: 'Mã thành viên (UUID)', minimum: 36);
    if (!mounted || id == null) return;
    final reason = await _ask('Lý do cấp quyền kiểm duyệt');
    if (!mounted || reason == null) return;
    await _mutate('add_moderator', {'record_key': {'user_id': id}, 'reason': reason});
  }

  Future<void> _export(bool sheets) async {
    final title = 'Passy - ${_resources[resource]}';
    final reason = await _ask(sheets ? 'Xuất dữ liệu sang Google Sheets' : 'Tải dữ liệu CSV');
    if (!mounted || reason == null) return;
    final userId = db.auth.currentUser?.id;
    setState(() => busy = true);
    try {
      final result = await _rpc('export', {'reason': reason});
      if (!mounted || userId != db.auth.currentUser?.id) return;
      final columns = List<String>.from(result['columns']);
      final values = <List<String>>[
        columns,
        for (final row in result['rows'])
          [for (final field in columns) _ownerCell(row[field])],
      ];
      if (sheets) {
        await _sheetsDialog(title, values, userId);
      } else {
        downloadOwnerCsv('passy-$resource.csv',
          '\uFEFF${values.map((row) => row.map(_ownerCsvCell).join(',')).join('\r\n')}');
        notice(context, 'Đã tạo CSV với ${values.length - 1} dòng.');
      }
    } catch (error) {
      if (mounted) notice(context, friendly(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _sheetsDialog(String title, List<List<String>> values, String? userId) async {
    final settings = await SharedPreferences.getInstance();
    if (!mounted || userId != db.auth.currentUser?.id) return;
    const key = 'passy_sheets_oauth_client';
    var clientId = settings.getString(key) ?? '';
    var sending = false;
    String? sheetUrl;
    String? error;
    await showDialog<void>(context: context, builder: (dialog) => StatefulBuilder(
      builder: (context, redraw) => AlertDialog(
        title: const Text('Tạo Google Sheet mới'),
        content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$title · ${values.length - 1} dòng. Google sẽ lưu tệp trong tài khoản bạn chọn.'),
          if (sheetUrl == null)
            TextFormField(initialValue: clientId, enabled: !sending,
              decoration: const InputDecoration(labelText: 'Google OAuth Client ID'),
              onChanged: (input) => redraw(() => clientId = input.trim())),
          if (error != null) Text(error!),
          if (sending) const LinearProgressIndicator(),
        ])),
        actions: [
          TextButton(onPressed: sending ? null : () => Navigator.pop(dialog), child: const Text('Đóng')),
          if (sheetUrl != null)
            FilledButton(onPressed: () => launchUrl(Uri.parse(sheetUrl!)), child: const Text('Mở Google Sheet'))
          else FilledButton(
            onPressed: sending || !clientId.endsWith('.apps.googleusercontent.com') ? null : () async {
              if (userId != db.auth.currentUser?.id) return;
              redraw(() { sending = true; error = null; });
              try {
                final url = await createOwnerSheet(clientId, title, jsonEncode(values));
                await settings.setString(key, clientId);
                if (context.mounted) redraw(() => sheetUrl = url);
              } catch (_) {
                if (context.mounted) redraw(() => error =
                  'Google chưa tạo được tệp. Kiểm tra Client ID, tên miền được phép và Google Sheets API.');
              } finally {
                if (context.mounted) redraw(() => sending = false);
              }
            },
            child: const Text('Chọn tài khoản Google và xuất')),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản trị dữ liệu')),
    body: ownerId == null
      ? const Center(child: Text('Hãy đăng nhập lại bằng tài khoản chủ.'))
      : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(initialValue: resource, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Nhóm dữ liệu'),
          items: [for (final entry in _resources.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value))],
          onChanged: busy ? null : (value) {
            if (value == null) return;
            resource = value;
            page = 0;
            search = '';
            _reload();
          }),
        const SizedBox(height: 12),
        TextFormField(key: ValueKey(resource), initialValue: search, enabled: !busy,
          decoration: const InputDecoration(labelText: 'Tìm theo nội dung hoặc mã', prefixIcon: Icon(Icons.search)),
          textInputAction: TextInputAction.search,
          onFieldSubmitted: (value) { search = value.trim(); page = 0; _reload(); }),
        FutureBuilder<Map<String, dynamic>>(future: data, builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LinearProgressIndicator();
          if (snapshot.hasError) return TextButton(onPressed: _reload,
            child: Text('${friendly(snapshot.error!)} · Thử lại'));
          final schema = snapshot.requireData;
          final rows = List<Map<String, dynamic>>.from(schema['rows']);
          final keys = List<String>.from(schema['keys']);
          return Column(children: [
            if (busy) const LinearProgressIndicator(),
            Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Wrap(spacing: 8, runSpacing: 8, children: [
              if (kIsWeb) ...[
                OutlinedButton.icon(onPressed: busy ? null : () => _export(false),
                  icon: const Icon(Icons.download), label: const Text('Tải CSV')),
                OutlinedButton.icon(onPressed: busy ? null : () => _export(true),
                  icon: const Icon(Icons.table_chart_outlined), label: const Text('Xuất sang Google Sheets')),
              ],
              if (resource == 'moderators')
                FilledButton(onPressed: busy ? null : _addModerator, child: const Text('Thêm kiểm duyệt viên')),
            ])),
            if (rows.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('Chưa có dữ liệu phù hợp')),
            for (final row in rows.take(50))
              ListTile(
                title: Text(_ownerCell(row['name'] ?? row['title'] ?? row['body'] ??
                  row['place'] ?? row['action'] ?? row['reason'] ?? row[keys.first]),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text([row['status'], ...keys.map((key) => row[key])].whereType<Object>().join(' · '),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: busy ? null : () => _record(row, schema)),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(onPressed: busy || page == 0 ? null : () {page--; _reload();},
                icon: const Icon(Icons.chevron_left)),
              Text('Trang ${page + 1}'),
              IconButton(onPressed: busy || rows.length < 51 ? null : () {page++; _reload();},
                icon: const Icon(Icons.chevron_right)),
              IconButton(onPressed: busy ? null : _reload, tooltip: 'Tải lại', icon: const Icon(Icons.refresh)),
            ]),
          ]);
        }),
      ]),
    )),
  );
}
