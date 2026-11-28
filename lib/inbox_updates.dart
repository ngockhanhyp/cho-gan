part of 'cloud_app.dart';

class InboxUpdates {
  InboxUpdates(this.home);
  final _Home home;
  Timer? timer;
  String? account;
  bool loading = false;
  SharedPreferences? prefs;
  Map<String, Map<String, dynamic>> latest = {};
  final read = <String, String>{};

  void start() {
    load();
    timer = Timer.periodic(const Duration(seconds: 8), (_) => load());
  }

  void dispose() => timer?.cancel();

  String timestamp(Map<String, dynamic> thread) =>
      '${latest[thread['id']]?['created_at'] ?? thread['created_at'] ?? ''}';

  String? preview(Map<String, dynamic> thread) {
    final message = latest[thread['id']];
    if (message == null) return null;
    final prefix = message['sender_id'] == account ? tr('Bạn: ') : '';
    return "$prefix${message['body']}";
  }

  bool isUnread(dynamic id) {
    final message = latest[id];
    return account == db.auth.currentUser?.id &&
        message != null && message['sender_id'] != account &&
        read[id] != message['id'];
  }

  int get unreadCount => latest.keys.where(isUnread).length;

  void markRead(String thread) {
    final id = latest[thread]?['id'] as String?;
    if (id == null || account != db.auth.currentUser?.id || read[thread] == id) return;
    read[thread] = id;
    prefs?.setString('passy.inbox.$account.$thread', id);
    if (home.mounted) home.setState(() {});
  }

  Future<void> load() async {
    if (loading || !home.mounted) return;
    final uid = db.auth.currentUser?.id;
    if (uid == null) {
      if (account != null) {
        home.setState(() { account = null; latest = {}; read.clear(); });
      }
      return;
    }
    loading = true;
    try {
      prefs ??= await SharedPreferences.getInstance();
      final rows = await db.from('conversations')
          .select('id,buyer_id,seller_id,created_at,listings(title,price,image_path),messages(id,sender_id,body,created_at)')
          .order('created_at', ascending: false, referencedTable: 'messages')
          .limit(1, referencedTable: 'messages');
      if (!home.mounted || db.auth.currentUser?.id != uid) return;
      final previous = account == uid ? latest : null;
      if (account != uid) read.clear();
      final next = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final id = row['id'] as String;
        final messages = row['messages'] as List;
        if (messages.isNotEmpty) next[id] = Map<String, dynamic>.from(messages.first as Map);
        final saved = prefs?.getString('passy.inbox.$uid.$id');
        if (saved != null) read.putIfAbsent(id, () => saved);
      }
      home.setState(() {
        account = uid;
        latest = next;
        home.threads = rows.map((row) => {
          ...row,
          'listings': row['listings'] ?? {'title': 'Tin không còn hiển thị', 'image_path': '', 'price': 0},
        }).toList();
      });
      if (previous != null && (ModalRoute.of(home.context)?.isCurrent ?? false) &&
          next.entries.any((entry) => isUnread(entry.key) &&
              previous[entry.key]?['id'] != entry.value['id'])) {
        notice(home.context, 'Bạn có tin nhắn mới trong Trò chuyện.');
      }
    } catch (_) {
      // Keep the last known inbox during a network interruption.
    } finally {
      loading = false;
    }
  }
}
