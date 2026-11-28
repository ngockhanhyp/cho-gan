part of 'cloud_app.dart';

class MeetingPage extends StatefulWidget {
  final Map<String, dynamic> thread;
  const MeetingPage({super.key, required this.thread});
  @override
  State<MeetingPage> createState() => _MeetingPage();
}

class _MeetingPage extends State<MeetingPage> {
  List<Map<String, dynamic>> meetings = [];
  Set<String> reviewed = {};
  bool loading = true, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final rows = await db
          .from('appointments')
          .select()
          .eq('conversation_id', widget.thread['id'])
          .order('created_at', ascending: false);
      final reviews = await db
          .from('reviews')
          .select('appointment_id')
          .eq('reviewer_id', db.auth.currentUser!.id);
      if (mounted) {
        setState(() {
          meetings = rows;
          reviewed = reviews.map((r) => r['appointment_id'] as String).toSet();
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

  Future<void> act(String id, String action) async {
    setState(() => busy = true);
    try {
      await db.rpc(
        'respond_meeting',
        params: {'meeting': id, 'action': action},
      );
      await load();
    } catch (e) {
      if (mounted) notice(context, friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> propose() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 89)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (time == null || !mounted) return;
    final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (!at.isAfter(DateTime.now())) {
      notice(context, 'Chọn giờ trong tương lai.');
      return;
    }
    final listingDescription = widget.thread['listings']?['description'] as String? ?? '';
    final location = TextEditingController(
      text: _suggestedPickup(listingDescription),
    );
    final place = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const PassyText('Địa điểm gặp'),
        content: TextField(
          controller: location,
          maxLength: 200,
          decoration:  InputDecoration(
            hintText: tr('Ví dụ: sảnh tòa nhà, quán cà phê…'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const PassyText('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (location.text.trim().length >= 3) {
                Navigator.pop(c, location.text.trim());
              }
            },
            child: const PassyText('Gửi lời hẹn'),
          ),
        ],
      ),
    );
    location.dispose();
    if (place == null || !mounted) return;
    setState(() => busy = true);
    try {
      await db.rpc(
        'propose_meeting',
        params: {
          'thread': widget.thread['id'],
          'location': place,
          'meeting_time': at.toUtc().toIso8601String(),
        },
      );
      await load();
    } catch (e) {
      if (mounted) notice(context, friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> review(String id) async {
    int stars = 5;
    final comment = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const PassyText('Trải nghiệm giao dịch'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                children: List.generate(
                  5,
                  (i) => IconButton(
                    onPressed: () => set(() => stars = i + 1),
                    icon: Icon(
                      i < stars ? Icons.star : Icons.star_border,
                      color: brand,
                    ),
                  ),
                ),
              ),
              TextField(
                controller: comment,
                maxLength: 1000,
                maxLines: 3,
                decoration:  InputDecoration(
                  hintText: tr('Chia sẻ lịch sự và đúng trải nghiệm'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const PassyText('Để sau'),
            ),
            FilledButton(
              onPressed: () {
                if (comment.text.trim().length >= 3) Navigator.pop(c, true);
              },
              child: const PassyText('Gửi đánh giá'),
            ),
          ],
        ),
      ),
    );
    final body = comment.text.trim();
    comment.dispose();
    if (result != true) return;
    setState(() => busy = true);
    try {
      await db.rpc(
        'leave_review',
        params: {'meeting': id, 'stars': stars, 'comment': body},
      );
      await load();
    } catch (e) {
      if (mounted) notice(context, friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final uid = db.auth.currentUser!.id;
    final active = meetings.any(
      (m) => ['proposed', 'accepted'].contains(m['status']),
    );
    return Scaffold(
      appBar: AppBar(title: const PassyText('Lịch hẹn giao dịch')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      widget.thread['listings']?['title'] ?? tr('Món đồ'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const PassyText(
                      'Hẹn gặp tại nơi công cộng. Chỉ xác nhận hoàn tất khi bạn đã nhận hàng hoặc bàn giao xong.',
                    ),
                    if (error != null)
                      PassyText(error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 20),
                    if (!active)
                      FilledButton.icon(
                        onPressed: busy ? null : propose,
                        icon: const Icon(Icons.event_available),
                        label: const PassyText('Đề xuất lịch hẹn'),
                      ),
                    ...meetings.map((m) {
                      final at = DateTime.parse(m['meet_at']).toLocal();
                      final status = m['status'];
                      final done = uid == widget.thread['buyer_id']
                          ? m['buyer_done']
                          : m['seller_done'];
                      return Card(
                        margin: const EdgeInsets.only(top: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.schedule, color: brand),
                                title: const PassyText('Thời gian'),
                                subtitle: Text(
                                  '${at.day}/${at.month}/${at.year} · ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                                ),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.place_outlined, color: brand),
                                title: const PassyText('Địa điểm gặp'),
                                subtitle: Text(m['place']),
                              ),
                              const SizedBox(height: 8),
                              PassyText(
                                {
                                      'proposed': 'Đang chờ xác nhận',
                                      'accepted': 'Hai bên đã đồng ý',
                                      'cancelled': 'Đã hủy',
                                      'completed': 'Hai bên đã hoàn tất',
                                    }[status] ??
                                    status,
                                style: const TextStyle(color: brand),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (status == 'proposed' &&
                                      m['proposer_id'] != uid)
                                    FilledButton(
                                      onPressed: busy
                                          ? null
                                          : () => act(m['id'], 'accept'),
                                      child: const PassyText('Đồng ý lịch hẹn'),
                                    ),
                                  if (status == 'accepted')
                                    FilledButton(
                                      onPressed: busy || done
                                          ? null
                                          : () => act(m['id'], 'complete'),
                                      child: PassyText(
                                        done
                                            ? 'Đã xác nhận · chờ bên kia'
                                            : 'Tôi đã giao dịch xong',
                                      ),
                                    ),
                                  if (['proposed', 'accepted'].contains(status))
                                    TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => act(m['id'], 'cancel'),
                                      child: const PassyText('Hủy hẹn'),
                                    ),
                                  if (status == 'completed' &&
                                      !reviewed.contains(m['id']))
                                    FilledButton(
                                      onPressed: busy
                                          ? null
                                          : () => review(m['id']),
                                      child: const PassyText('Đánh giá'),
                                    ),
                                  if (reviewed.contains(m['id']))
                                    const PassyText(
                                      'Bạn đã đánh giá giao dịch này.',
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
        ),
      ),
    );
  }
}

class MemberPage extends StatefulWidget {
  final String id, name;
  const MemberPage({super.key, required this.id, required this.name});
  @override
  State<MemberPage> createState() => _MemberPage();
}

class _MemberPage extends State<MemberPage> {
  List<Map<String, dynamic>> reviews = [];
  bool blocked = false, loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await db
          .from('reviews')
          .select('*,profiles!reviewer_id(name)')
          .eq('reviewee_id', widget.id)
          .order('created_at', ascending: false);
      bool b = false;
      if (db.auth.currentUser != null) {
        b =
            await db
                .from('blocks')
                .select()
                .eq('blocker_id', db.auth.currentUser!.id)
                .eq('blocked_id', widget.id)
                .maybeSingle() !=
            null;
      }
      if (mounted) {
        setState(() {
          reviews = r;
          blocked = b;
          loading = false;
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

  Future<void> toggle() async {
    if (db.auth.currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
      );
      if (db.auth.currentUser == null) return;
    }
    try {
      if (blocked) {
        await db
            .from('blocks')
            .delete()
            .eq('blocker_id', db.auth.currentUser!.id)
            .eq('blocked_id', widget.id);
      } else {
        await db.from('blocks').insert({
          'blocker_id': db.auth.currentUser!.id,
          'blocked_id': widget.id,
        });
      }
      await load();
    } catch (e) {
      if (mounted) notice(context, friendly(e));
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(widget.name)),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const CircleAvatar(
          radius: 40,
          child: Icon(Icons.person_outline, size: 40),
        ),
        const SizedBox(height: 20),
        Text(
          widget.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          reviews.isEmpty
              ? tr('Chưa có đánh giá')
              : '${(reviews.fold<int>(0, (s, r) => s + (r['rating'] as int)) / reviews.length).toStringAsFixed(1)} / 5 · ${reviews.length} đánh giá',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        const PassyText(
          'Đánh giá đến từ giao dịch hai bên đã xác nhận. Đây là phản hồi cộng đồng, không phải bảo đảm chất lượng hàng.',
        ),
        if (db.auth.currentUser?.id != widget.id)
          TextButton.icon(
            onPressed: toggle,
            icon: Icon(blocked ? Icons.lock_open : Icons.block),
            label: PassyText(blocked ? 'Bỏ chặn người này' : 'Chặn liên hệ mới'),
          ),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (error != null) PassyText(error!),
        ...reviews.map(
          (r) => ListTile(
            title: Text(
              '${r['rating']} ★ · ${r['profiles']?['name'] ?? 'Thành viên'}',
            ),
            subtitle: Text(r['body']),
          ),
        ),
      ],
    ),
  );
}

class ModerationPage extends StatefulWidget {
  const ModerationPage({super.key});
  @override
  State<ModerationPage> createState() => _ModerationPage();
}

class _ModerationPage extends State<ModerationPage> {
  List<Map<String, dynamic>> reports = [];
  String? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      if (await db.rpc('is_moderator') != true) {
        throw const AuthException('Tài khoản chưa được cấp quyền quản trị.');
      }
      final r = await db
          .from('reports')
          .select('*,listings(title)')
          .eq('resolved', false)
          .order('created_at');
      if (mounted) {
        setState(() {
          reports = r;
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

  Future<void> resolve(String id, bool hide) async {
    try {
      await db.rpc(
        'resolve_report',
        params: {'report': id, 'hide_listing': hide},
      );
      await load();
    } catch (e) {
      if (mounted) notice(context, friendly(e));
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const PassyText('Quản trị báo cáo')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (error != null) PassyText(error!),
              if (reports.isEmpty && error == null)
                const PassyText('Không có báo cáo chờ xử lý.'),
              ...reports.map(
                (r) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['listings']?['title'] ?? tr('Tin đã ẩn'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(r['reason']),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(
                              onPressed: () => resolve(r['id'], true),
                              child: const PassyText('Ẩn tin vi phạm'),
                            ),
                            TextButton(
                              onPressed: () => resolve(r['id'], false),
                              child: const PassyText('Đóng báo cáo'),
                            ),
                          ],
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
