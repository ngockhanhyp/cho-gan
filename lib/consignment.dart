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
      if (!allowed || !mounted) return;
      final rows = await db.from('consignment_requests').select().order('created_at', ascending: false).limit(100);
      if (mounted) setState(() { staff = true; requests = rows; });
    } catch (_) { /* Seller flow remains available if staff access is not configured. */ }
  }

  Future<void> _editRequest(Map<String, dynamic> row) async {
    const statuses = ['pending','reviewing','accepted','received','listed','sold','paid','rejected','returned'];
    var status = '${row['status']}';
    final sale = TextEditingController(text: '${row['agreed_sale_price'] ?? ''}');
    final commission = TextEditingController(text: '${row['commission_amount'] ?? ''}');
    final note = TextEditingController(text: '${row['staff_note'] ?? ''}');
    final values = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, refresh) => AlertDialog(
      title: Text('Cập nhật: ${row['title']}'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'Trạng thái'), items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) { if (v != null) refresh(() => status = v); }),
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
    title.dispose(); description.dispose(); price.dispose(); super.dispose();
  }

  Future<void> submit() async {
    if (db.auth.currentUser == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const Login()));
      if (db.auth.currentUser == null || !mounted) return;
    }
    if (title.text.trim().length < 3 || description.text.trim().length < 10) {
      notice(context, 'Nhập tên món đồ và mô tả ít nhất 10 ký tự.'); return;
    }
    final suggestedPrice = int.tryParse(price.text.replaceAll(RegExp(r'[^0-9]'), ''));
    setState(() => busy = true);
    try {
      await db.from('consignment_requests').insert({
        'owner_id': db.auth.currentUser!.id,
        'title': title.text.trim(), 'description': description.text.trim(),
        'asking_price': suggestedPrice, 'warehouse': warehouse,
      });
      if (mounted) {
        notice(context, 'Đã gửi yêu cầu. Passy sẽ trao đổi giá và hoa hồng trước khi nhận đồ.');
        Navigator.pop(context);
      }
    } catch (e) { if (mounted) notice(context, friendly(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ký gửi tại Passy')),
    body: PageBody(maxWidth: 720, children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: brandSoft, borderRadius: BorderRadius.circular(18)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Passy thay bạn bán món đồ', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
        SizedBox(height: 8), Text('Gửi thông tin món đồ và điểm tiếp nhận mong muốn. Passy sẽ kiểm tra, thống nhất giá bán, mức hoa hồng và điều kiện bằng tin nhắn trước khi bạn bàn giao đồ.', style: TextStyle(height: 1.55, color: muted)),
      ])),
      const SizedBox(height: 20),
      TextField(controller: title, decoration: const InputDecoration(labelText: 'Tên món đồ', hintText: 'Ví dụ: Ghế ăn gỗ còn tốt')),
      const SizedBox(height: 12),
      TextField(controller: description, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Mô tả tình trạng', hintText: 'Tuổi sử dụng, lỗi, phụ kiện đi kèm…')),
      const SizedBox(height: 12),
      TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá mong muốn (không bắt buộc)', suffixText: 'đ')),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: warehouse, decoration: const InputDecoration(labelText: 'Điểm tiếp nhận dự kiến'), items: const [DropdownMenuItem(value: 'Tòa Vinacomin, Hà Nội', child: Text('Tòa Vinacomin, Hà Nội')), DropdownMenuItem(value: '530 Nguyễn Trãi, Bắc Ninh', child: Text('530 Nguyễn Trãi, Bắc Ninh'))], onChanged: (v) { if (v != null) setState(() => warehouse = v); }),
      const SizedBox(height: 12),
      const Text('Chưa phát sinh bàn giao khi gửi biểu mẫu. Phí hoa hồng, giá bán và cách nhận lại đồ sẽ được xác nhận trước khi Passy nhận món đồ.', style: TextStyle(color: muted, height: 1.5)),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: busy ? null : submit, icon: const Icon(Icons.send_outlined), label: Text(busy ? 'Đang gửi…' : 'Gửi yêu cầu ký gửi')),
      if (staff) ...[
        const SizedBox(height: 30),
        const SectionTitle('Yêu cầu ký gửi cần xử lý'),
        if (requests.isEmpty) const Text('Chưa có yêu cầu.'),
        ...requests.map((r) => Card(child: ListTile(
          title: Text('${r['title']} · ${r['status']}'),
          subtitle: Text('${r['warehouse']}\nGiá mong muốn: ${r['asking_price'] == null ? 'Chưa nhập' : money(r['asking_price'])}'),
          isThreeLine: true,
          trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editRequest(r)),
        ))),
      ],
    ]),
  );
}
