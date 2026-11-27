part of 'cloud_app.dart';

class ConsignmentPage extends StatefulWidget {
  const ConsignmentPage({super.key});
  @override
  State<ConsignmentPage> createState() => _ConsignmentPageState();
}

class _ConsignmentPageState extends State<ConsignmentPage> {
  final title = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final contact = TextEditingController();
  static const statuses = {
    'pending': 'Chờ tiếp nhận', 'reviewing': 'Đang xem xét',
    'accepted': 'Đã thống nhất', 'received': 'Đã nhận đồ',
    'listed': 'Đang bán', 'sold': 'Đã bán', 'paid': 'Đã thanh toán',
    'rejected': 'Không nhận', 'returned': 'Đã trả lại',
  };
  String warehouse = 'Tòa Vinacomin, Hà Nội';
  bool staff = false;
  List<Map<String, dynamic>> requests = [];
  bool busy = false;

  @override
  void initState() { super.initState(); _loadStaff(); }

  Future<void> _loadStaff() async {
    if (db.auth.currentUser == null) return;
    try {
      final allowed = await db.rpc('is_moderator') as bool;
      if (!mounted) return;
      final rows = await db.from('consignment_requests').select().order('created_at', ascending: false).limit(100);
      if (mounted) setState(() { staff = allowed; requests = rows; });
    } catch (_) { /* Seller flow remains available if staff access is not configured. */ }
  }

  Future<void> _editRequest(Map<String, dynamic> row) async {
    var status = '${row['status']}';
    final sale = TextEditingController(text: '${row['agreed_sale_price'] ?? ''}');
    final commission = TextEditingController(text: '${row['commission_amount'] ?? ''}');
    final note = TextEditingController(text: '${row['staff_note'] ?? ''}');
    final values = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, refresh) => AlertDialog(
      title: Text('Cập nhật: ${row['title']}'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${row['description']}'),
        SelectableText('Liên hệ: ${row['contact'] ?? 'Chưa cung cấp'}'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'Trạng thái'), items: statuses.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(), onChanged: (v) { if (v != null) refresh(() => status = v); }),
        TextField(controller: sale, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá bán đã thống nhất (đ)')),
        TextField(controller: commission, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hoa hồng đã thống nhất (đ)')),
        TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Ghi chú trao đổi')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lưu'))],
    )));
    if (values == true) {
      try {
        int? amount(String s) => s.trim().isEmpty ? null : int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''));
        await db.from('consignment_requests').update({'status': status, 'agreed_sale_price': amount(sale.text), 'commission_amount': amount(commission.text), 'staff_note': note.text.trim().isEmpty ? null : note.text.trim()}).eq('id', row['id']);
        await _loadStaff();
      } catch (e) { if (mounted) notice(context, friendly(e)); }
    }
    sale.dispose(); commission.dispose(); note.dispose();
  }

  @override
  void dispose() {
    title.dispose(); description.dispose(); price.dispose(); contact.dispose(); super.dispose();
  }

  Future<void> submit() async {
    if (db.auth.currentUser == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const Login()));
      if (db.auth.currentUser == null || !mounted) return;
    }
    if (title.text.trim().length < 3 || description.text.trim().length < 10) {
      notice(context, 'Nhập tên món đồ và mô tả ít nhất 10 ký tự.'); return;
    }
    if (contact.text.trim().length < 5) {
      notice(context, 'Nhập số điện thoại hoặc email để Passy liên hệ.');
      return;
    }
    final suggestedPrice = int.tryParse(price.text.replaceAll(RegExp(r'[^0-9]'), ''));
    setState(() => busy = true);
    try {
      await db.from('consignment_requests').insert({
        'owner_id': db.auth.currentUser!.id,
        'title': title.text.trim(), 'description': description.text.trim(),
        'asking_price': suggestedPrice, 'warehouse': warehouse,
        'contact': contact.text.trim(),
      });
      if (mounted) {
        notice(context, 'Đã gửi yêu cầu. Passy sẽ trao đổi giá và hoa hồng trước khi nhận đồ.');
        title.clear(); description.clear(); price.clear(); contact.clear();
        await _loadStaff();
      }
    } catch (e) { if (mounted) notice(context, friendly(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ký gửi tại Passy')),
    body: PageBody(maxWidth: 720, children: [
      PassyChapterPanel(chapter: passyChapters[1], compact: true),
      const SizedBox(height: 16),
      const Wrap(spacing: 8, runSpacing: 8, children: [
        Chip(label: Text('Gửi thông tin món đồ')),
        Chip(label: Text('Thống nhất giá và hoa hồng')),
        Chip(label: Text('Hẹn bàn giao tại điểm nhận')),
      ]),
      const SizedBox(height: 20),
      TextField(controller: title, maxLength: 160, decoration: const InputDecoration(labelText: 'Tên món đồ', hintText: 'Ví dụ: Ghế ăn gỗ còn tốt')),
      const SizedBox(height: 12),
      TextField(controller: description, maxLength: 3000, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Mô tả tình trạng', hintText: 'Tuổi sử dụng, lỗi, phụ kiện đi kèm…')),
      const SizedBox(height: 12),
      TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá mong muốn (không bắt buộc)', suffixText: 'đ')),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: warehouse, decoration: const InputDecoration(labelText: 'Điểm tiếp nhận dự kiến'), items: const [DropdownMenuItem(value: 'Tòa Vinacomin, Hà Nội', child: Text('Tòa Vinacomin, Hà Nội')), DropdownMenuItem(value: '530 Nguyễn Trãi, Bắc Ninh', child: Text('530 Nguyễn Trãi, Bắc Ninh'))], onChanged: (v) { if (v != null) setState(() => warehouse = v); }),
      const SizedBox(height: 12),
      TextField(controller: contact, maxLength: 160, decoration: const InputDecoration(
        labelText: 'Số điện thoại hoặc email liên hệ',
        helperText: 'Chỉ bạn và quản trị Passy xem được.',
      )),
      const SizedBox(height: 12),
      const Text('Chưa phát sinh bàn giao khi gửi biểu mẫu. Phí hoa hồng, giá bán và cách nhận lại đồ sẽ được xác nhận trước khi Passy nhận món đồ.', style: TextStyle(color: muted, height: 1.5)),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: busy ? null : submit, icon: const Icon(Icons.send_outlined), label: Text(busy ? 'Đang gửi…' : 'Gửi yêu cầu ký gửi')),
      if (staff || requests.isNotEmpty) ...[
        const SizedBox(height: 30),
        SectionTitle(staff ? 'Yêu cầu ký gửi cần xử lý' : 'Yêu cầu của tôi'),
        if (requests.isEmpty) const Text('Chưa có yêu cầu.'),
        ...requests.map((r) => Card(child: ListTile(
          title: Text('${r['title']} · ${statuses[r['status']] ?? r['status']}'),
          subtitle: Text('${r['warehouse']}\nGiá mong muốn: ${r['asking_price'] == null ? 'Chưa nhập' : money(r['asking_price'])}'),
          isThreeLine: true,
          onTap: staff ? () => _editRequest(r) : () => showDialog<void>(
            context: context,
            builder: (dialog) => AlertDialog(
              title: Text(r['title'] ?? ''),
              content: Text([
                statuses[r['status']] ?? '',
                if (r['agreed_sale_price'] != null) 'Giá bán: ${r['agreed_sale_price']} đ',
                if (r['commission_amount'] != null) 'Hoa hồng: ${r['commission_amount']} đ',
                if (r['staff_note'] != null) r['staff_note'],
              ].join('\n')),
              actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Đóng'))],
            ),
          ),
          trailing: Icon(staff ? Icons.edit_outlined : Icons.chevron_right),
        ))),
      ],
    ]),
  );
}
