part of 'cloud_app.dart';

class OwnerConsole extends StatefulWidget {
  const OwnerConsole({super.key});
  @override
  State<OwnerConsole> createState() => _OwnerConsoleState();
}

class _OwnerConsoleState extends State<OwnerConsole> {
  String section = 'Tin đăng', query = '', reason = '';
  String? thread;
  int page = 0;
  late Future<List<dynamic>> rows;
  String? get uid => db.auth.currentUser?.id;
  late final StreamSubscription<AuthState> auth;

  Future<List<dynamic>> fetch() async {
    if (uid == null) return [];
    return List.from(await db.rpc('owner_console', params: {
      'section': section, 'page_no': page, 'target': thread,
      'reason': reason, 'search_term': query,
    }));
  }

  void refresh() => setState(() => rows = fetch());
  void select(String value) {
    section = value;
    page = 0;
    query = '';
    if (value != 'Tin nhắn') { thread = null; reason = ''; }
    refresh();
  }

  @override
  void initState() {
    super.initState();
    rows = fetch();
    var previous = uid;
    auth = db.auth.onAuthStateChange.listen((_) {
      if (mounted && previous != uid) {
        previous = uid;
        select('Tin đăng');
      }
    });
  }

  @override
  void dispose() { auth.cancel(); super.dispose(); }

  Future<void> perform(String id, String action) async {
    var input = '';
    final result = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: Text('Lý do · $action'),
      content: TextField(maxLength: 300, autofocus: true, onChanged: (v) => input = v.trim()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
        FilledButton(onPressed: () {
          if (input.length >= 5) Navigator.pop(c, input);
        }, child: const Text('Xác nhận và ghi nhật ký')),
      ],
    ));
    if (!mounted || result == null) return;
    if (action != 'Đọc hội thoại') {
      try {
        await db.rpc('owner_console', params: {'section': action, 'target': id, 'reason': result});
        if (mounted) refresh();
      } catch (e) {
        if (mounted) notice(context, friendly(e));
      }
      return;
    }
    thread = id;
    reason = result;
    select('Tin nhắn');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản trị Passy')),
    body: uid == null ? Center(child: FilledButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Login())),
      child: const Text('Đăng nhập quản trị'),
    )) : FutureBuilder<List<dynamic>>(
      future: rows,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: TextButton(
          onPressed: refresh, child: Text('${friendly(snapshot.error!)} · Thử lại'),
        ));
        final entries = snapshot.data ?? [];
        return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Wrap(spacing: 8, runSpacing: 6, children: [
              ActionChip(
                avatar: const Icon(Icons.flag_outlined),
                label: const Text('Báo cáo'),
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ModerationPage())),
              ),
              for (final name in ['Tin đăng','Thành viên','Hội thoại','Nhật ký'])
                ChoiceChip(label: Text(name), selected: section == name,
                  onSelected: (_) => select(name)),
              ActionChip(label: const Text('Báo cáo'), onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ModerationPage()))),
            ]),
            if (thread == null) TextFormField(
              key: ValueKey(section), initialValue: query,
              decoration: const InputDecoration(labelText: 'Tìm kiếm', suffixIcon: Icon(Icons.search)),
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (v) { query = v.trim(); page = 0; refresh(); },
            ),
            if (thread != null) const ListTile(title: Text('Tin nhắn · mới nhất trước')),
            for (final row in entries) ListTile(title: Text(row['label']),
              subtitle: SelectableText(row['detail'] ?? ''),
              trailing: section == 'Tin đăng' ? PopupMenuButton<String>(
                onSelected: (action) => perform(row['row_id'], action),
                itemBuilder: (_) => [
                  for (final name in ['Ẩn tin', 'Gỡ ẩn'])
                    PopupMenuItem(value: name, child: Text(name)),
                ],
              ) : section == 'Hội thoại' ? const Icon(Icons.chevron_right) : null,
              onTap: section == 'Hội thoại' ? () => perform(row['row_id'], 'Đọc hội thoại') : null),
            if (entries.isEmpty) const ListTile(title: Text('Chưa có dữ liệu phù hợp')),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(onPressed: page == 0 ? null : () { page--; refresh(); }, icon: const Icon(Icons.chevron_left)),
              Text('Trang ${page+1}'),
              IconButton(onPressed: entries.length < 50 ? null : () { page++; refresh(); }, icon: const Icon(Icons.chevron_right)),
              IconButton(tooltip: 'Tải lại', onPressed: refresh, icon: const Icon(Icons.refresh)),
            ]),
          ]),
        ));
      },
    ),
  );
}
