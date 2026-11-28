part of 'cloud_app.dart';

class EditListing extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool asOwner;
  const EditListing({super.key, required this.item, this.asOwner = false});
  @override
  State<EditListing> createState() => _EditListing();
}

class _EditListing extends State<EditListing> {
  late final TextEditingController title, description, price;
  late String category, area, status;
  late bool acceptsOffers;
  String reason = '';
  final form = GlobalKey<FormState>();
  bool busy = false;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.item['title']);
    description = TextEditingController(text: widget.item['description']);
    price = TextEditingController(text: '${widget.item['price']}');
    category = widget.item['category'] as String;
    area = widget.item['area'] as String;
    status = widget.item['status'] as String;
    acceptsOffers = widget.item['accepts_offers'] == true;
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final values = {
        'title': title.text.trim(),
        'description': description.text.trim(),
        'price': int.parse(price.text),
      };
      if (widget.asOwner) {
        values.addAll({'category': category.trim(), 'area': area.trim(),
          'status': status, 'accepts_offers': acceptsOffers});
        await db.rpc('owner_data', params: {
          'resource': 'listings', 'operation': 'update',
          'record_key': {'id': widget.item['id']}, 'changes': values,
          'version': widget.item['_version'], 'reason': reason,
        });
      } else {
        await db.from('listings').update(values).eq('id', widget.item['id']);
      }
      widget.item.addAll(values);
      if (mounted) Navigator.pop(context, values);
    } catch (e) {
      if (mounted) notice(context, friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const PassyText('Chỉnh sửa tin')),
    body: Form(
      key: form,
      child: PageBody(
        maxWidth: 680,
        children: [
              const PassyText(
                'Cập nhật tin đăng',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const PassyText(
                'Giá và mô tả rõ ràng giúp hàng xóm quyết định nhanh hơn.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: title,
                maxLength: 160,
                decoration:  InputDecoration(labelText: tr('Tên món đồ')),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 4 ? tr('Nhập ít nhất 4 ký tự') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration:  InputDecoration(labelText: tr('Giá (đồng)')),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 0 || n > 100000000000
                      ? tr('Nhập giá hợp lệ')
                      : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: description,
                maxLength: 4000,
                maxLines: 6,
                decoration:  InputDecoration(labelText: tr('Mô tả')),
                validator: (v) => (v?.trim().length ?? 0) < 10
                    ? tr('Mô tả ít nhất 10 ký tự')
                    : null,
              ),
              if (widget.asOwner) ...[
                TextFormField(initialValue: category, maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Danh mục'),
                  onChanged: (value) => category = value,
                  validator: (value) => value!.trim().isEmpty ? 'Nhập danh mục' : null),
                TextFormField(initialValue: area, maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Khu vực'),
                  onChanged: (value) => area = value,
                  validator: (value) => value!.trim().isEmpty ? 'Nhập khu vực' : null),
                DropdownButtonFormField<String>(initialValue: status,
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: const [
                    DropdownMenuItem(value: 'available', child: Text('Đang bán')),
                    DropdownMenuItem(value: 'reserved', child: Text('Đang hẹn')),
                    DropdownMenuItem(value: 'sold', child: Text('Đã bán')),
                    DropdownMenuItem(value: 'hidden', child: Text('Ẩn tin')),
                  ],
                  onChanged: (value) => status = value!),
                SwitchListTile(title: const Text('Cho phép trả giá'), value: acceptsOffers,
                  onChanged: (value) => setState(() => acceptsOffers = value)),
                TextFormField(maxLength: 300,
                  decoration: const InputDecoration(labelText: 'Lý do quản trị'),
                  onChanged: (value) => reason = value.trim(),
                  validator: (value) => reason.length < 5 ? 'Nhập ít nhất 5 ký tự' : null),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : save,
                child: PassyText(busy ? 'Đang lưu…' : 'Lưu thay đổi'),
              ),
        ],
      ),
    ),
  );
}

class ListingLink extends StatefulWidget {
  final String id;
  const ListingLink({super.key, required this.id});
  @override
  State<ListingLink> createState() => _ListingLink();
}

class _ListingLink extends State<ListingLink> {
  late final Future<Map<String, dynamic>?> listing;
  @override
  void initState() {
    super.initState();
    listing = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    final visible = await db.from('listings')
        .select('*,profiles!owner_id(name)').eq('id', widget.id).maybeSingle();
    if (visible != null || db.auth.currentUser == null) return visible;
    if (await db.rpc('is_passy_owner') != true) return null;
    final row = await db.rpc('owner_listing', params: {'target': widget.id});
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<Map<String, dynamic>?>(
    future: listing,
    builder: (c, s) {
      if (s.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (s.hasError || s.data == null) {
        return Scaffold(
          appBar: AppBar(title: const PassyText('Passy')),
          body: const PageBody(
            children: [
              EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Không tìm thấy tin',
                text: 'Tin không còn hiển thị hoặc liên kết không hợp lệ.',
              ),
            ],
          ),
        );
      }
      return Detail(item: s.data!);
    },
  );
}
