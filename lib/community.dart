part of 'cloud_app.dart';

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
                    'Chuyện quanh mình',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Hỏi đáp, chia sẻ tin hữu ích với đồng nghiệp, bạn bè và hàng xóm. '
                    'Bài viết trong cộng đồng chỉ dành cho thành viên.',
                    style: TextStyle(color: muted, height: 1.6),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            Icon(Icons.groups_rounded, size: 64, color: Color(0xFF2E9E6B)),
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
            leading: Avatar(name: '${g['name']}', size: 48),
            title: Text(g['name']),
            subtitle: const Text('Nhóm có mã mời · không xác minh cư trú'),
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
            if (posts.isEmpty)
              const EmptyState(
                icon: Icons.waving_hand_outlined,
                title: 'Chưa có bài viết',
                text: 'Hãy chào cộng đồng của bạn!',
              ),
            ...posts.map(
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
                      Text(
                        p['body'],
                        style: const TextStyle(fontSize: 16, height: 1.5),
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
