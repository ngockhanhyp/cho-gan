import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

const orange = Color(0xFFFF6F32);
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(Market(prefs: prefs));
}

class Market extends StatefulWidget {
  final SharedPreferences prefs;
  const Market({super.key, required this.prefs});
  @override
  State<Market> createState() => MarketState();
}

class MarketState extends State<Market> {
  List<Map<String, dynamic>> items = [];
  Set<String> saved = {};
  Map<String, List<String>> chats = {};
  int tab = 0;
  String query = '', category = 'Tất cả', area = 'Cầu Giấy';
  final cats = [
    'Tất cả',
    'Nội thất',
    'Điện tử',
    'Gia dụng',
    'Sách',
    'Cho tặng',
  ];
  @override
  void initState() {
    super.initState();
    final raw = widget.prefs.getString('items');
    items = raw == null
        ? List.generate(
            6,
            (i) => {
              'id': 'seed$i',
              'title': [
                'Ghế gỗ tựa lưng, còn rất mới',
                'Máy ảnh cho những chuyến đi',
                'Bộ cốc gốm màu kem',
                'Sách đọc cuối tuần',
                'Đèn bàn góc làm việc',
                'Tặng cây xanh cho nhà mới',
              ][i],
              'price': [
                '350000',
                '1800000',
                '120000',
                '60000',
                '190000',
                '0',
              ][i],
              'cat': [
                'Nội thất',
                'Điện tử',
                'Gia dụng',
                'Sách',
                'Gia dụng',
                'Cho tặng',
              ][i],
              'icon': i,
              'owner': ['Linh', 'Minh', 'Hà', 'An', 'Trang', 'Nam'][i],
              'area': 'Cầu Giấy',
              'desc': 'Tin minh họa để trải nghiệm giao diện. Bạn có thể đăng món đồ thật của mình bằng nút Đăng tin.',
              'sold': false,
              'mine': false,
              'image': '',
            },
          )
        : List<Map<String, dynamic>>.from(jsonDecode(raw));
    saved = (widget.prefs.getStringList('saved') ?? []).toSet();
    final c = widget.prefs.getString('chats');
    if (c != null) {
      chats = (jsonDecode(c) as Map).map(
        (k, v) => MapEntry(k.toString(), List<String>.from(v)),
      );
    }
  }

  Future<void> persist() async {
    await widget.prefs.setString('items', jsonEncode(items));
    await widget.prefs.setStringList('saved', saved.toList());
    await widget.prefs.setString('chats', jsonEncode(chats));
  }

  void change(VoidCallback action) {
    setState(action);
    persist();
  }

  String price(dynamic n) {
    final v = int.tryParse('$n') ?? 0;
    if (v == 0) return 'Cho tặng';
    return '${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
  }

  Widget art(Map<String, dynamic> x, {double size = 100}) {
    final icons = [
      Icons.chair_outlined,
      Icons.camera_alt_outlined,
      Icons.coffee_outlined,
      Icons.menu_book,
      Icons.light_outlined,
      Icons.yard_outlined,
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: x['image'] != ''
          ? Image.memory(
              base64Decode(x['image']),
              width: size,
              height: size,
              fit: BoxFit.cover,
            )
          : Container(
              width: size,
              height: size,
              color: [
                const Color(0xFFEDE5D9),
                const Color(0xFFDDE6E5),
                const Color(0xFFF3E5DC),
              ][(x['icon'] as int) % 3],
              child: Icon(
                icons[(x['icon'] as int) % 6],
                size: size * .48,
                color: const Color(0xFF716B61),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Passy',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: orange),
      scaffoldBackgroundColor: Colors.white,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: Builder(
      builder: (ctx) => Scaffold(
        appBar: AppBar(
          title: TextButton.icon(
            onPressed: () => chooseArea(ctx),
            icon: const Icon(Icons.location_on_outlined, color: orange),
            label: Text(
              '$area ▾',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Chip(
                label: const Text('V1 • trải nghiệm cục bộ'),
                backgroundColor: Colors.orange.shade50,
                side: BorderSide.none,
              ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: tab == 0
                ? feed(ctx)
                : tab == 1
                ? community()
                : tab == 2
                ? chatList(ctx)
                : profile(ctx),
          ),
        ),
        floatingActionButton: tab == 0
            ? FloatingActionButton.extended(
                backgroundColor: orange,
                foregroundColor: Colors.white,
                onPressed: () => compose(ctx),
                icon: const Icon(Icons.add),
                label: const Text('Đăng tin'),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (v) => setState(() => tab = v),
          indicatorColor: const Color(0xFFFFE8DB),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Gần bạn',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              label: 'Khu phố',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Trò chuyện',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Của tôi',
            ),
          ],
        ),
      ),
    ),
  );
  Widget feed(BuildContext ctx) {
    final filtered = items
        .where(
          (x) =>
              x['area'] == area &&
              (category == 'Tất cả' || x['cat'] == category) &&
              x['title'].toString().toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              hintText: 'Tìm món đồ bạn cần ở gần đây',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: cats
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: category == c,
                      onSelected: (_) => setState(() => category = c),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đồ cũ, niềm vui mới.',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Gặp người gần bạn. Trao món đồ còn giá trị.\nĐăng bán và mua hoàn toàn miễn phí.',
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Khám phá quanh bạn',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text(
                    'Chưa có món phù hợp. Hãy thử danh mục khác hoặc đăng món đầu tiên.',
                  ),
                ),
              ...filtered.map((x) => tile(ctx, x)),
            ],
          ),
        ),
      ],
    );
  }

  Widget tile(BuildContext ctx, Map<String, dynamic> x) => InkWell(
    onTap: () => detail(ctx, x),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          art(x),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  x['title'],
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${x['area']} · ${x['mine'] == true ? 'Tin của bạn' : 'Tin mẫu'}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  x['sold'] == true ? 'Đã bán' : price(x['price']),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => change(
              () => saved.contains(x['id'])
                  ? saved.remove(x['id'])
                  : saved.add(x['id']),
            ),
            icon: Icon(
              saved.contains(x['id']) ? Icons.favorite : Icons.favorite_border,
              color: saved.contains(x['id']) ? orange : Colors.grey,
            ),
          ),
        ],
      ),
    ),
  );
  void detail(BuildContext ctx, Map<String, dynamic> x) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (c) => StatefulBuilder(
          builder: (c, refresh) => Scaffold(
            appBar: AppBar(
              title: const Text('Chi tiết món đồ'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () {
                    ScaffoldMessenger.of(c).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Đã ghi nhận báo cáo trên thiết bị này. Chưa gửi đến máy chủ.',
                        ),
                      ),
                    );
                    widget.prefs.setString(
                      'report_${x['id']}',
                      DateTime.now().toIso8601String(),
                    );
                  },
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(child: art(x, size: 260)),
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(x['owner']),
                  subtitle: Text('${x['area']} · Chưa xác minh'),
                  trailing: const Text(
                    'Thành viên mới',
                    style: TextStyle(color: orange),
                  ),
                ),
                const Divider(),
                Text(
                  x['title'],
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  price(x['price']),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  x['desc'],
                  style: const TextStyle(fontSize: 17, height: 1.6),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Hẹn ở nơi công cộng, kiểm tra món đồ trước khi thanh toán.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                if (x['mine'] == true)
                  FilledButton(
                    onPressed: () {
                      change(() => x['sold'] = !x['sold']);
                      refresh(() {});
                    },
                    child: Text(
                      x['sold'] == true ? 'Đăng bán lại' : 'Đánh dấu đã bán',
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => chat(c, x),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Nhắn tin hỏi mua'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void chat(BuildContext ctx, Map<String, dynamic> x) {
    final controller = TextEditingController();
    change(() => chats.putIfAbsent(x['id'], () => []));
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (c) => StatefulBuilder(
          builder: (c, refresh) => Scaffold(
            appBar: AppBar(title: Text(x['owner'])),
            body: Column(
              children: [
                ListTile(
                  leading: art(x, size: 48),
                  title: Text(x['title']),
                  subtitle: Text(price(x['price'])),
                ),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Bản cục bộ: tin nhắn chỉ lưu trên thiết bị, chưa gửi đến người bán.',
                    style: TextStyle(color: Colors.deepOrange),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: chats[x['id']]!
                        .map(
                          (m) => Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE6D6),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(m),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: 'Món này còn không bạn?',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: orange),
                          onPressed: () {
                            if (controller.text.trim().isEmpty) return;
                            change(
                              () => chats[x['id']]!.add(controller.text.trim()),
                            );
                            controller.clear();
                            refresh(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget chatList(BuildContext c) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Trò chuyện',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 20),
      if (chats.isEmpty)
        const Text('Hãy mở một món đồ và nhắn tin để bắt đầu.'),
      ...items
          .where((x) => chats.containsKey(x['id']))
          .map(
            (x) => ListTile(
              leading: art(x, size: 56),
              title: Text(x['owner']),
              subtitle: Text(
                chats[x['id']]!.isEmpty ? x['title'] : chats[x['id']]!.last,
              ),
              onTap: () => chat(c, x),
            ),
          ),
    ],
  );
  Widget community() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Chuyện quanh mình',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      const Text('Một cộng đồng bắt đầu từ những người quen.'),
      const SizedBox(height: 24),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cộng đồng $area',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'V1 đang thử trải nghiệm mua bán. Xác thực cộng đồng và bảng tin cư dân sẽ hoạt động khi kết nối máy chủ. Không có huy hiệu xác minh giả trong bản thử.',
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Widget profile(BuildContext c) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const ListTile(
        leading: CircleAvatar(radius: 28, child: Icon(Icons.person)),
        title: Text(
          'Bạn',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Hồ sơ thử nghiệm trên thiết bị này'),
      ),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.sell_outlined),
        title: const Text('Tin của tôi'),
        subtitle: Text('${items.where((x) => x['mine'] == true).length} tin'),
      ),
      ...items.where((x) => x['mine'] == true).map((x) => tile(c, x)),
      const SizedBox(height: 20),
      const Text(
        'Đã lưu',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      ...items.where((x) => saved.contains(x['id'])).map((x) => tile(c, x)),
      const SizedBox(height: 20),
      const Text(
        'Passy · V1\nDữ liệu lưu trên thiết bị. Chưa có tài khoản trực tuyến hoặc đồng bộ giữa web và app.',
        style: TextStyle(color: Colors.grey),
      ),
    ],
  );
  void chooseArea(BuildContext c) => showModalBottomSheet(
    context: c,
    builder: (s) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: ['Cầu Giấy', 'Nam Từ Liêm', 'Ba Đình', 'Thanh Xuân']
            .map(
              (a) => ListTile(
                title: Text(a),
                trailing: area == a
                    ? const Icon(Icons.check, color: orange)
                    : null,
                onTap: () {
                  setState(() => area = a);
                  Navigator.pop(s);
                },
              ),
            )
            .toList(),
      ),
    ),
  );
  void compose(BuildContext ctx) {
    final title = TextEditingController(),
        amount = TextEditingController(),
        desc = TextEditingController();
    String cat = 'Gia dụng', photo = '';
    final form = GlobalKey<FormState>();
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (c) => StatefulBuilder(
          builder: (c, refresh) => Scaffold(
            appBar: AppBar(title: const Text('Đăng món đồ')),
            body: Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final f = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1200,
                        imageQuality: 75,
                      );
                      if (f != null) {
                        final b = await f.readAsBytes();
                        refresh(() => photo = base64Encode(b));
                      }
                    },
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      photo.isEmpty
                          ? 'Thêm ảnh thật của món đồ'
                          : 'Đã chọn ảnh • chọn lại',
                    ),
                  ),
                  if (photo.isNotEmpty)
                    Image.memory(base64Decode(photo), height: 160),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Bạn muốn bán gì?',
                    ),
                    validator: (v) => v == null || v.trim().length < 4
                        ? 'Nhập tên ít nhất 4 ký tự'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: cat,
                    items: cats
                        .skip(1)
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (v) => cat = v!,
                    decoration: const InputDecoration(labelText: 'Danh mục'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Giá (đồng) • 0 nếu cho tặng',
                    ),
                    validator: (v) => (int.tryParse(v ?? '') ?? -1) < 0
                        ? 'Nhập giá hợp lệ'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: desc,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Tình trạng, khuyết điểm, nơi hẹn nhận',
                    ),
                    validator: (v) => v == null || v.trim().length < 10
                        ? 'Mô tả ít nhất 10 ký tự'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      if (!form.currentState!.validate()) return;
                      if (photo.isEmpty) {
                        ScaffoldMessenger.of(c).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Hãy thêm ảnh món đồ trước khi đăng.',
                            ),
                          ),
                        );
                        return;
                      }
                      change(
                        () => items.insert(0, {
                          'id': DateTime.now().microsecondsSinceEpoch
                              .toString(),
                          'title': title.text.trim(),
                          'price': amount.text,
                          'desc': desc.text.trim(),
                          'cat': cat,
                          'image': photo,
                          'area': area,
                          'owner': 'Bạn',
                          'mine': true,
                          'sold': false,
                          'icon': 0,
                        }),
                      );
                      Navigator.pop(c);
                    },
                    child: const Text('Đăng miễn phí'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
