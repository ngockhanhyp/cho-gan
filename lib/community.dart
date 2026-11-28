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
    appBar: AppBar(title: const PassyText('Thảo luận'), actions: [
      IconButton(onPressed: load, icon: const Icon(Icons.refresh), tooltip: tr('Tải lại')),
    ]),
    body: PageBody(maxWidth: 720, children: [
      Card(child: ListTile(title: Text(widget.post['body'] ?? ''))),
      const SizedBox(height: 16),
      const SectionTitle('Bình luận'),
      if (error != null) PassyText(error!),
      for (final reply in replies)
        ListTile(title: Text(reply['profiles']?['name'] ?? tr('Cư dân')), subtitle: Text(reply['body'] ?? '')),
      TextField(controller: input, maxLength: 1000, maxLines: 3,
        decoration:  InputDecoration(labelText: tr('Viết bình luận'))),
      FilledButton.icon(onPressed: busy ? null : send, icon: const Icon(Icons.send_outlined), label: const PassyText('Gửi bình luận')),
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
  List<Map<String, dynamic>> recent = [];
  String? recentOwner;
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
          recent = [];
          recentOwner = null;
          loading = false;
          error = null;
        });
      }
      if (rows.isNotEmpty) await loadRecent(rows);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = friendly(e);
          loading = false;
        });
      }
    }
  }

  Future<void> loadRecent(List<Map<String, dynamic>> memberGroups) async {
    final uid = db.auth.currentUser?.id;
    try {
      final posts = await db.from('community_posts')
          .select('id,body,topic,created_at,community_id')
          .inFilter('community_id', memberGroups.map((group) => group['id']).toList())
          .order('created_at', ascending: false)
          .limit(4);
      if (mounted && uid != null && db.auth.currentUser?.id == uid) {
        setState(() {
          recent = posts;
          recentOwner = uid;
        });
      }
    } catch (_) {
      // The group directory is still available when the recent feed is offline.
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
        title: PassyText(create ? 'Tạo cộng đồng' : 'Tham gia bằng mã mời'),
        content: TextField(
          controller: input,
          maxLength: create ? 80 : 32,
          decoration: InputDecoration(
            hintText: tr(create ? 'Đồng nghiệp, cư dân, nhóm bạn…' : 'Dán mã do thành viên chia sẻ'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const PassyText('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (input.text.trim().length >= 3) {
                Navigator.pop(c, input.text.trim());
              }
            },
            child: const PassyText('Tiếp tục'),
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
      title: const PassyText('Tạo cộng đồng chung cư'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: building, maxLength: 80, decoration:  InputDecoration(labelText: tr('Tên tòa nhà / khu chung cư'))),
        TextField(controller: location, maxLength: 160, decoration:  InputDecoration(labelText: tr('Phường, quận hoặc địa chỉ'))),
        const SizedBox(height: 8),
        const PassyText('Cộng đồng dùng mã mời riêng. Passy chưa xác minh người tham gia có cư trú tại đây.', style: TextStyle(color: muted)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const PassyText('Hủy')), FilledButton(onPressed: () {
        if (building.text.trim().length >= 3 && location.text.trim().length >= 3) Navigator.pop(c, (building.text.trim(), location.text.trim()));
      }, child: const PassyText('Tạo nhóm'))],
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
      PassyChapterPanel(chapter: passyChapters[3], compact: true),
      const SizedBox(height: 20),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: busy ? null : () => edit(false),
            icon: const Icon(Icons.group_add_outlined),
            label: const PassyText('Nhập mã mời'),
          ),
          OutlinedButton(
            onPressed: busy ? null : () => edit(true),
            child: const PassyText('Tạo cộng đồng'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : createApartment,
            icon: const Icon(Icons.apartment_outlined),
            label: const PassyText('Tạo nhóm chung cư'),
          ),
        ],
      ),
      const SizedBox(height: 24),
      if (loading) const Center(child: CircularProgressIndicator()),
      if (error != null) PassyText(error!),
      if (groups.isEmpty && !loading)
        const EmptyState(
          icon: Icons.groups_outlined,
          title: 'Chưa tham gia cộng đồng nào',
          text: 'Nhập mã mời từ người quen, hoặc tạo cộng đồng cho khu nhà, cơ quan của bạn.',
        ),
      if (recentOwner == db.auth.currentUser?.id && recent.isNotEmpty) ...[
        const SectionTitle('Chuyện mới trong các nhóm'),
        Card(child: Column(children: [
          for (final post in recent)
            ListTile(
              leading: const Icon(Icons.forum_outlined, color: brand),
              title: Text(post['body'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                ...groups.where((g) => g['id'] == post['community_id']).map((g) => g['name']),
                timeAgo(post['created_at']),
              ].join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => CommunityReplies(post: post))),
            ),
        ])),
        const SizedBox(height: 24),
      ],
      if (groups.isNotEmpty) const SectionTitle('Cộng đồng của bạn'),
      ...groups.map(
        (g) => Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: g['community_type'] == 'apartment' ? const CircleAvatar(child: Icon(Icons.apartment)) : Avatar(name: '${g['name']}', size: 48),
            title: Text(g['name']),
            subtitle: Text(g['community_type'] == 'apartment'
                ? '${g['building_location'] ?? ''} · Nhóm riêng bằng mã mời, chưa xác minh cư trú'
                : tr('Nhóm có mã mời · không xác minh cư trú')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CommunityBoard(group: g)),
              );
              if (mounted) await load();
            },
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
              title: const PassyText('Mời người bạn quen'),
              subtitle: const PassyText(
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
                  label: const PassyText('Sao chép mã'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: topic,
              decoration:  InputDecoration(labelText: tr('Chủ đề bài viết')),
              items: topics.entries.map((entry) => DropdownMenuItem(value: entry.key, child: PassyText(entry.value))).toList(),
              onChanged: busy ? null : (value) => setState(() => topic = value ?? 'discussion'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: input,
              maxLines: 4,
              maxLength: 2000,
              decoration:  InputDecoration(
                hintText: tr('Hỏi hàng xóm, chia sẻ tin hữu ích…'),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
                onPressed: busy ? null : post,
                child: PassyText(busy ? 'Đang đăng…' : 'Chia sẻ'),
              ),
            ),
            const SizedBox(height: 24),
            if (error != null) PassyText(error!),
            Wrap(
              spacing: 8,
              children: {'all': 'Tất cả', ...topics}.entries.map((entry) => ChoiceChip(
                label: PassyText(entry.value),
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
                              p['profiles']?['name'] ?? tr('Thành viên'),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(timeAgo(p['created_at']), style: const TextStyle(color: muted, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(topics[p['topic']] ?? tr('Hỏi đáp'), style: const TextStyle(fontWeight: FontWeight.w700, color: muted)),
                      Text(
                        p['body'],
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => CommunityReplies(post: p))),
                        icon: const Icon(Icons.comment_outlined),
                        label: const PassyText('Bình luận'),
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
