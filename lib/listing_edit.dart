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
    appBar: AppBar(title: const Text('Chỉnh sửa tin')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: title,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Tên món đồ'),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 4 ? 'Nhập ít nhất 4 ký tự' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá (đồng)'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 0 || n > 100000000000
                      ? 'Nhập giá hợp lệ'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: description,
                maxLength: 4000,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Mô tả'),
                validator: (v) => (v?.trim().length ?? 0) < 10
                    ? 'Mô tả ít nhất 10 ký tự'
                    : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Đang lưu…' : 'Lưu thay đổi'),
              ),
            ],
          ),
        ),
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
          appBar: AppBar(title: const Text('Chợ Gần')),
          body: const Center(
            child: Text('Tin không còn hiển thị hoặc liên kết không hợp lệ.'),
          ),
        );
      }
      return Detail(item: s.data!);
    },
  );
}
