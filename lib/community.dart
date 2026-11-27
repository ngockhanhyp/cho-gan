part of 'cloud_app.dart';

class CommunityReplies extends StatefulWidget {
  const CommunityReplies({super.key, required this.post});
  final Map<String, dynamic> post;

  @override
  State<CommunityReplies> createState() => _CommunityRepliesState();
}

class _CommunityRepliesState extends State<CommunityReplies> {
  final input = TextEditingController();
  List<Map<String, dynamic>> replies = [];
  bool busy = false;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  @override
  void dispose() { input.dispose(); super.dispose(); }

  Future<void> load() async {
    try {
      final rows = await db.from('community_replies').select('*,profiles!author_id(name)')
          .eq('post_id', widget.post['id']).order('created_at').limit(200);
      if (mounted) setState(() { replies = rows; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = friendly(e));
    }
  }

  Future<void> send() async {
    final uid = db.auth.currentUser?.id;
    final body = input.text.trim();
    if (busy || uid == null || body.isEmpty) return;
    setState(() => busy = true);
    try {
      await db.from('community_replies').insert({
        'post_id': widget.post['id'], 'author_id': uid, 'body': body,
      });
      if (!mounted) return;
      if (input.text.trim() == body) input.clear();
      await load();
    } catch (e) {
      if (mounted) notice(context, friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thảo luận'), actions: [
      IconButton(onPressed: load, icon: const Icon(Icons.refresh), tooltip: 'Tải lại'),
    ]),
    body: PageBody(maxWidth: 720, children: [
      Card(child: ListTile(title: Text(widget.post['body'] ?? ''))),
      const SizedBox(height: 16),
      const SectionTitle('Bình luận'),
      if (error != null) Text(error!),
      for (final reply in replies)
        ListTile(title: Text(reply['profiles']?['name'] ?? 'Cư dân'), subtitle: Text(reply['body'] ?? '')),
      TextField(controller: input, maxLength: 1000, maxLines: 3,
        decoration: const InputDecoration(labelText: 'Viết bình luận')),
      FilledButton.icon(onPressed: busy ? null : send, icon: const Icon(Icons.send_outlined), label: const Text('Gửi bình luận')),
    ]),
  );
}

class CommunitiesPage extends StatefulWidget {
  const CommunitiesPage({super.key});
  @override
  State<CommunitiesPage> createState() => _CommunitiesPage();
}

class _CommunitiesPage extends State<CommunitiesPage> {
  List<Map<String, dynamic>> groups = [];
  bool loading = true, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (db.auth.currentUser == null) {
      setState(() => loading = false);
      return;
    }
    try {
      final rows = await db.from('communities').select().order('created_at');
      if (mounted) {
        setState(() {
          groups = rows;
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = friendly(e);
          loading = false;
        });
      }
    }
  }

  Future<void> edit(bool create) async {
    if (db.auth.currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
      );
      if (db.auth.currentUser == null || !mounted) return;
    }
    final input = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(create ? 'Tạo cộng đồng' : 'Tham gia bằng mã mời'),
        content: TextField(
          controller: input,
          maxLength: create ? 80 : 32,
          decoration: InputDecoration(
            hintText: create
                ? 'Đồng nghiệp, cư dân, nhóm bạn…'
                : 'Dán mã do thành viên chia sẻ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (input.text.trim().length >= 3) {
                Navigator.pop(c, input.text.trim());
              }
            },
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
    input.dispose();
    if (text == null) return;
    setState(() => busy = true);
    try {
      await db.rpc(
        create ? 'create_community' : 'join_community',
        params: create ? {'group_name': text} : {'code': text},
      );
      await load();
    } catch (e) {
      if (mounted) notice(context, friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> createApartment() async {
    if (db.auth.currentUser == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const Login()));
      if (db.auth.currentUser == null || !mounted) return;
    }
    final building = TextEditingController();
    final location = TextEditingController();
    final values = await showDialog<(String, String)>(context: context, builder: (c) => AlertDialog(
      title: const Text('Tạo cộng đồng chung cư'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: building, maxLength: 80, decoration: const InputDecoration(labelText: 'Tên tòa nhà / khu chung cư')),
        TextField(controller: location, maxLength: 160, decoration: const InputDecoration(labelText: 'Phường, quận hoặc địa chỉ')),
        const SizedBox(height: 8),
        const Text('Cộng đồng dùng mã mời riêng. Passy chưa xác minh người tham gia có cư trú tại đây.', style: TextStyle(color: muted)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')), FilledButton(onPressed: () {
        if (building.text.trim().length >= 3 && location.text.trim().length >= 3) Navigator.pop(c, (building.text.trim(), location.text.trim()));
      }, child: const Text('Tạo nhóm'))],
    ));
    building.dispose(); location.dispose();
    if (values == null) return;
    setState(() => busy = true);
    try {
      await db.rpc('create_apartment_community', params: {'building_name': values.$1, 'building_location': values.$2});
      await load();
    } catch (e) { if (mounted) notice(context, friendly(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext c) => PageBody(
    maxWidth: 820,
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFEAF7F0), Color(0xFFD9F0E4)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cộng đồng quanh bạn',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Kết nối với cư dân cùng tòa hoặc cùng khu: hỏi đáp, thông báo, nhờ giúp đỡ và rủ nhau gặp mặt. '
                    'Bài viết trong cộng đồng chỉ dành cho thành viên.',
                    style: TextStyle(color: muted, height: 1.6),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            Icon(Icons.apartment_rounded, size: 56, color: Color(0xFF2E9E6B)),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: busy ? null : () => edit(false),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Nhập mã mời'),
          ),
          OutlinedButton(
            onPressed: busy ? null : () => edit(true),
            child: const Text('Tạo cộng đồng'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : createApartment,
            icon: const Icon(Icons.apartment_outlined),
            label: const Text('Tạo nhóm chung cư'),
          ),
        ],
      ),
      const SizedBox(height: 24),
      if (loading) const Center(child: CircularProgressIndicator()),
      if (error != null) Text(error!),
      if (groups.isEmpty && !loading)
        const EmptyState(
          icon: Icons.groups_outlined,
          title: 'Chưa tham gia cộng đồng nào',
          text: 'Nhập mã mời từ người quen, hoặc tạo cộng đồng cho khu nhà, cơ quan của bạn.',
        ),
      if (groups.isNotEmpty) const SectionTitle('Cộng đồng của bạn'),
      ...groups.map(
        (g) => Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: g['community_type'] == 'apartment' ? const CircleAvatar(child: Icon(Icons.apartment)) : Avatar(name: '${g['name']}', size: 48),
            title: Text(g['name']),
            subtitle: Text(g['community_type'] == 'apartment'
                ? '${g['building_location'] ?? ''} · Nhóm riêng bằng mã mời, chưa xác minh cư trú'
                : 'Nhóm có mã mời · không xác minh cư trú'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CommunityBoard(group: g)),
            ),
          ),
        ),
      ),
    ],
  );
}

class CommunityBoard extends StatefulWidget {
  final Map<String, dynamic> group;
  const CommunityBoard({super.key, required this.group});
  @override
  State<CommunityBoard> createState() => _CommunityBoard();
}

class _CommunityBoard extends State<CommunityBoard> {
  List<Map<String, dynamic>> posts = [];
  final input = TextEditingController();
  bool busy = false;
  String topic = 'discussion', filter = 'all';
  static const topics = {
    'discussion': 'Hỏi đáp',
    'notice': 'Thông báo',
    'help': 'Nhờ giúp đỡ',
    'meetup': 'Rủ gặp mặt',
  };
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final rows = await db
          .from('community_posts')
          .select('*,profiles!author_id(name)')
          .eq('community_id', widget.group['id'])
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() {
          posts = rows;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = friendly(e));
    }
  }

  Future<void> post() async {
    if (input.text.trim().length < 5) {
      notice(context, 'Nhập nội dung ít nhất 5 ký tự.');
      return;
    }
    setState(() => busy = true);
    try {
      await db.from('community_posts').insert({
        'community_id': widget.group['id'],
        'author_id': db.auth.currentUser!.id,
        'body': input.text.trim(),
        'topic': topic,
      });
      input.clear();
      await load();
    } catch (e) {
      if (mounted) notice(context, friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(widget.group['name']),
      actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
    ),
    body: PageBody(
          children: [
            ExpansionTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: line),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: line),
              ),
              leading: const Icon(Icons.vpn_key_outlined, color: brand),
              title: const Text('Mời người bạn quen'),
              subtitle: const Text(
                'Ai có mã đều có thể tham gia. Chia sẻ có chọn lọc.',
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(widget.group['invite_code']),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: widget.group['invite_code']),
                    );
                    if (c.mounted) notice(c, 'Đã sao chép mã mời.');
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Sao chép mã'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: topic,
              decoration: const InputDecoration(labelText: 'Chủ đề bài viết'),
              items: topics.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
              onChanged: busy ? null : (value) => setState(() => topic = value ?? 'discussion'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: input,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'Hỏi hàng xóm, chia sẻ tin hữu ích…',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
                onPressed: busy ? null : post,
                child: Text(busy ? 'Đang đăng…' : 'Chia sẻ'),
              ),
            ),
            const SizedBox(height: 24),
            if (error != null) Text(error!),
            Wrap(
              spacing: 8,
              children: {'all': 'Tất cả', ...topics}.entries.map((entry) => ChoiceChip(
                label: Text(entry.value),
                selected: filter == entry.key,
                onSelected: (_) => setState(() => filter = entry.key),
              )).toList(),
            ),
            const SizedBox(height: 12),
            if (!posts.any((post) => filter == 'all' || (post['topic'] ?? 'discussion') == filter))
              const EmptyState(
                icon: Icons.waving_hand_outlined,
                title: 'Chưa có bài viết',
                text: 'Hãy chào cộng đồng của bạn!',
              ),
            ...posts.where((post) => filter == 'all' || (post['topic'] ?? 'discussion') == filter).map(
              (p) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Avatar(name: p['profiles']?['name'] ?? 'Thành viên', size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p['profiles']?['name'] ?? 'Thành viên',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(timeAgo(p['created_at']), style: const TextStyle(color: muted, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(topics[p['topic']] ?? 'Hỏi đáp', style: const TextStyle(fontWeight: FontWeight.w700, color: muted)),
                      Text(
                        p['body'],
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => CommunityReplies(post: p))),
                        icon: const Icon(Icons.comment_outlined),
                        label: const Text('Bình luận'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
    ),
  );
}
