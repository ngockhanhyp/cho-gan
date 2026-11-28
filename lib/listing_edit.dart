part of 'cloud_app.dart';

class EditListing extends StatefulWidget {
  final Map<String, dynamic> item;
  const EditListing({super.key, required this.item});
  @override
  State<EditListing> createState() => _EditListing();
}

class _EditListing extends State<EditListing> {
  late final TextEditingController title, description, price;
  final form = GlobalKey<FormState>();
  bool busy = false;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.item['title']);
    description = TextEditingController(text: widget.item['description']);
    price = TextEditingController(text: '${widget.item['price']}');
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
      await db.from('listings').update(values).eq('id', widget.item['id']);
      widget.item.addAll(values);
      if (mounted) Navigator.pop(context);
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
    listing = db
        .from('listings')
        .select('*,profiles!owner_id(name)')
        .eq('id', widget.id)
        .maybeSingle();
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
