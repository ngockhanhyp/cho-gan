import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'trust.dart';
part 'community.dart';
part 'listing_edit.dart';

const brand = Color(0xFFFF6F32);
final db = Supabase.instance.client;
String money(dynamic value) => value == 0
    ? 'Cho tặng'
    : '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
String friendly(Object e) {
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'Email hoặc mật khẩu chưa đúng.';
    if (m.contains('email not confirmed')) {
      return 'Bạn cần xác nhận email trước khi đăng nhập.';
    }
    if (m.contains('rate limit')) {
      return 'Đã gửi quá nhiều yêu cầu. Vui lòng đợi vài phút.';
    }
    if (m.contains('email address') || m.contains('sending confirmation')) {
      return 'Chưa gửi được email xác nhận. Vui lòng liên hệ quản trị để kiểm tra dịch vụ email.';
    }
    return e.message;
  }
  if (e is PostgrestException) {
    return e.code == 'P0001'
        ? e.message
        : e.code == '23505'
        ? 'Bạn đã thực hiện thao tác này rồi.'
        : e.code == '42501'
        ? 'Thao tác không được phép. Kiểm tra quyền hoặc trạng thái chặn.'
        : 'Không thể cập nhật dữ liệu. Vui lòng thử lại (${e.code}).';
  }
  return 'Không kết nối được. Kiểm tra mạng và thử lại.';
}

void notice(BuildContext c, String text) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(text)));

class ChoGan extends StatelessWidget {
  const ChoGan({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
    title: 'Chợ Gần',
    locale: const Locale('vi'),
    supportedLocales: const [Locale('vi')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: brand),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(18),
        ),
      ),
    ),
    builder: (context, child) => Container(
      color: const Color(0xFFF5F5F5),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: child!,
        ),
      ),
    ),
    onGenerateRoute: (settings) {
      final n = settings.name ?? '';
      if (n.startsWith('/listing/')) {
        return MaterialPageRoute(
          builder: (_) => ListingLink(id: n.substring(9)),
          settings: settings,
        );
      }
      return null;
    },
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _Home();
}

class _Home extends State<Home> {
  int page = 0;
  String area = 'Cầu Giấy', category = 'Tất cả', search = '';
  List<Map<String, dynamic>> listings = [], threads = [];
  Set<String> favorites = {};
  bool loading = true;
  String? error;
  StreamSubscription<AuthState>? auth;
  final categories = [
    'Tất cả',
    'Nội thất',
    'Điện tử',
    'Gia dụng',
    'Sách',
    'Thời trang',
    'Cho tặng',
  ];
  @override
  void initState() {
    super.initState();
    refresh();
    auth = db.auth.onAuthStateChange.listen((_) {
      refresh();
    });
  }

  @override
  void dispose() {
    auth?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final data = await db
          .from('listings')
          .select('*,profiles!owner_id(name)')
          .order('created_at', ascending: false)
          .limit(200);
      List<Map<String, dynamic>> t = [];
      Set<String> f = {};
      if (db.auth.currentUser != null) {
        final rows = await db.from('favorites').select('listing_id');
        f = rows.map((e) => e['listing_id'] as String).toSet();
        t = await db
            .from('conversations')
            .select('*,listings(title,price,image_path)')
            .order('created_at', ascending: false);
      }
      if (mounted) {
        setState(() {
          listings = data;
          threads = t
              .map(
                (row) => {
                  ...row,
                  'listings':
                      row['listings'] ??
                      {
                        'title': 'Tin không còn hiển thị',
                        'price': 0,
                        'image_path': '',
                      },
                },
              )
              .toList();
          favorites = f;
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

  Future<bool> login() async {
    if (db.auth.currentUser != null) return true;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const Login()),
    );
    return db.auth.currentUser != null;
  }

  Future<void> favorite(Map<String, dynamic> x) async {
    if (!await login()) return;
    try {
      if (favorites.contains(x['id'])) {
        await db
            .from('favorites')
            .delete()
            .eq('user_id', db.auth.currentUser!.id)
            .eq('listing_id', x['id']);
      } else {
        await db.from('favorites').insert({
          'user_id': db.auth.currentUser!.id,
          'listing_id': x['id'],
        });
      }
      await refresh();
    } catch (e) {
      if (mounted) notice(context, friendly(e));
    }
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(
        title: TextButton.icon(
          onPressed: () => showModalBottomSheet(
            context: c,
            builder: (s) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    [
                          'Cầu Giấy',
                          'Nam Từ Liêm',
                          'Ba Đình',
                          'Thanh Xuân',
                          'Tất cả Hà Nội',
                        ]
                        .map(
                          (a) => ListTile(
                            title: Text(a),
                            trailing: a == area
                                ? const Icon(Icons.check, color: brand)
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
          ),
          icon: const Icon(Icons.location_on_outlined, color: brand),
          label: Text(
            '$area ▾',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.black,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!),
                      TextButton(
                        onPressed: refresh,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : page == 0
              ? feed()
              : page == 1
              ? const CommunitiesPage()
              : page == 2
              ? inbox()
              : profile(),
        ),
      ),
      floatingActionButton: page == 0
          ? FloatingActionButton.extended(
              backgroundColor: brand,
              foregroundColor: Colors.white,
              onPressed: () async {
                if (!await login() || !mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Compose(
                      area: area == 'Tất cả Hà Nội' ? 'Cầu Giấy' : area,
                    ),
                  ),
                );
                refresh();
              },
              icon: const Icon(Icons.add),
              label: const Text('Đăng tin'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (i) {
          setState(() => page = i);
          refresh();
        },
        indicatorColor: const Color(0xFFFFE5D5),
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
    );
  }

  Widget feed() {
    final shown = listings
        .where(
          (x) =>
              (area == 'Tất cả Hà Nội' || x['area'] == area) &&
              (category == 'Tất cả' || x['category'] == category) &&
              x['title'].toString().toLowerCase().contains(
                search.toLowerCase(),
              ) &&
              x['status'] != 'hidden',
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TextField(
            onChanged: (v) => setState(() => search = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Tìm món đồ bạn cần ở gần đây',
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: categories
                .map(
                  (v) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(v),
                      selected: category == v,
                      onSelected: (_) => setState(() => category = v),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
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
                        'Gặp người gần bạn. Trao món đồ còn giá trị.\nMua bán trực tiếp, hoàn toàn miễn phí.',
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
                if (shown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(
                      children: [
                        Icon(Icons.storefront_outlined, size: 64, color: brand),
                        SizedBox(height: 16),
                        Text(
                          'Khu phố đang chờ món đồ đầu tiên!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Đăng món bạn không còn dùng để người gần bạn tìm thấy.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ...shown.map(tile),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget tile(Map<String, dynamic> x) => InkWell(
    onTap: () async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => Detail(item: x)),
      );
      refresh();
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListingImage(path: x['image_path'], size: 100),
          const SizedBox(width: 16),
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
                  '${x['area']} · ${x['profiles']?['name'] ?? 'Thành viên'}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  '${x['status'] == 'sold'
                      ? 'Đã bán · '
                      : x['status'] == 'reserved'
                      ? 'Đang hẹn · '
                      : ''}${money(x['price'])}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => favorite(x),
            icon: Icon(
              favorites.contains(x['id'])
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: favorites.contains(x['id']) ? brand : Colors.grey,
            ),
          ),
        ],
      ),
    ),
  );
  Widget neighborhood() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Gần nhau hơn mỗi ngày',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      Text('Cộng đồng $area', style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 16),
      const Text(
        'Bắt đầu từ đồng nghiệp, bạn bè và những người ở gần. Chọn nơi công cộng để gặp, kiểm tra hàng và thống nhất giá trước khi trao đổi.',
        style: TextStyle(fontSize: 17, height: 1.6),
      ),
      const SizedBox(height: 24),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Khu vực hiện do thành viên tự chọn. Chợ Gần chưa xác minh cư trú hoặc bảo đảm chất lượng món đồ.',
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        '${listings.where((x) => x['area'] == area && x['status'] == 'available').length} món đang tìm chủ mới',
      ),
      TextButton(
        onPressed: () => setState(() => page = 0),
        child: const Text('Khám phá món đồ'),
      ),
    ],
  );
  Widget inbox() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Trò chuyện',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 20),
      if (db.auth.currentUser == null)
        FilledButton(
          onPressed: login,
          child: const Text('Đăng nhập để trò chuyện'),
        )
      else if (threads.isEmpty)
        const Text('Mở món đồ bạn thích và nhắn người bán để bắt đầu.'),
      ...threads.map(
        (t) => ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: ListingImage(path: t['listings']['image_path'], size: 60),
          title: Text(t['listings']['title']),
          subtitle: Text(money(t['listings']['price'])),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => Chat(thread: t)),
          ),
        ),
      ),
    ],
  );
  Widget profile() {
    final user = db.auth.currentUser;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFFFE5D5),
            child: Icon(Icons.person_outline, color: brand),
          ),
          title: Text(
            user?.userMetadata?['name'] ?? 'Chào hàng xóm!',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            user == null
                ? 'Đăng nhập để mua bán cùng cộng đồng'
                : 'Thành viên · chưa xác minh khu vực',
          ),
        ),
        const SizedBox(height: 20),
        if (user == null)
          FilledButton(
            onPressed: login,
            child: const Text('Đăng nhập / Tạo tài khoản'),
          )
        else ...[
          const Text(
            'Tin của tôi',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          ...listings.where((x) => x['owner_id'] == user.id).map(tile),
          const SizedBox(height: 20),
          const Text(
            'Món đã lưu',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          ...listings.where((x) => favorites.contains(x['id'])).map(tile),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Quản trị'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ModerationPage()),
            ),
          ),
          TextButton(
            onPressed: () async {
              await db.auth.signOut();
              refresh();
            },
            child: const Text('Đăng xuất'),
          ),
        ],
        const SizedBox(height: 30),
        const Text(
          'Chợ Gần · V1\nMua bán miễn phí. Gặp nhau trực tiếp.\nKhông yêu cầu đặt cọc để mở khóa giao dịch.',
          style: TextStyle(color: Colors.grey, height: 1.6),
        ),
      ],
    );
  }
}

class ListingImage extends StatelessWidget {
  final String path;
  final double size;
  const ListingImage({super.key, required this.path, required this.size});
  @override
  Widget build(BuildContext c) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: path.isEmpty
        ? Container(
            width: size,
            height: size,
            color: const Color(0xFFF1ECE6),
            child: const Icon(Icons.image_outlined),
          )
        : Image.network(
            db.storage.from('listing-images').getPublicUrl(path),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, e, s) => Container(
              width: size,
              height: size,
              color: const Color(0xFFF1ECE6),
              child: const Icon(Icons.image_outlined, color: Colors.grey),
            ),
          ),
  );
}

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _Login();
}

class _Login extends State<Login> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  final form = GlobalKey<FormState>();
  bool signup = false, busy = false;
  String? message;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      if (signup) {
        final r = await db.auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {'name': name.text.trim()},
        );
        if (r.session == null) {
          setState(
            () => message = 'Kiểm tra email để xác nhận tài khoản, sau đó quay lại đăng nhập.',
          );
          return;
        }
      } else {
        await db.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => message = friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(signup ? 'Tạo tài khoản' : 'Chào hàng xóm!')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.waving_hand_outlined, size: 64, color: brand),
              const SizedBox(height: 24),
              const Text(
                'Món đồ cũ. Kết nối mới.',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              if (signup) ...[
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Tên hiển thị'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty || v.length > 80
                      ? 'Nhập tên từ 1–80 ký tự'
                      : null,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    v == null || !v.contains('@') ? 'Nhập email hợp lệ' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
                validator: (v) =>
                    v == null || v.length < 8 ? 'Ít nhất 8 ký tự' : null,
              ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    message!,
                    style: const TextStyle(color: Colors.deepOrange),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(
                  busy
                      ? 'Đang xử lý…'
                      : signup
                      ? 'Tạo tài khoản miễn phí'
                      : 'Đăng nhập',
                ),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        signup = !signup;
                        message = null;
                      }),
                child: Text(
                  signup
                      ? 'Đã có tài khoản? Đăng nhập'
                      : 'Chưa có tài khoản? Đăng ký',
                ),
              ),
              const Text(
                'Tên hiển thị và tin đăng của bạn được công khai. Email không hiển thị trên hồ sơ.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class Compose extends StatefulWidget {
  final String area;
  const Compose({super.key, required this.area});
  @override
  State<Compose> createState() => _Compose();
}

class _Compose extends State<Compose> {
  final title = TextEditingController(),
      price = TextEditingController(),
      description = TextEditingController();
  final form = GlobalKey<FormState>();
  String category = 'Gia dụng';
  Uint8List? photo;
  String mime = 'image/jpeg';
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    price.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) notice(context, 'Ảnh tối đa 5 MB.');
        return;
      }
      if (mounted) {
        setState(() {
          photo = bytes;
          mime =
              f.mimeType ??
              (f.name.toLowerCase().endsWith('.png')
                  ? 'image/png'
                  : 'image/jpeg');
        });
      }
    } catch (e) {
      if (mounted) notice(context, friendly(e));
    }
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (photo == null) {
      notice(context, 'Hãy thêm ảnh thật của món đồ.');
      return;
    }
    setState(() => busy = true);
    String? path;
    try {
      final uid = db.auth.currentUser!.id;
      path =
          '$uid/${DateTime.now().microsecondsSinceEpoch}.${mime == 'image/png'
              ? 'png'
              : mime == 'image/webp'
              ? 'webp'
              : 'jpg'}';
      await db.storage
          .from('listing-images')
          .uploadBinary(
            path,
            photo!,
            fileOptions: FileOptions(contentType: mime),
          );
      await db.from('listings').insert({
        'owner_id': uid,
        'title': title.text.trim(),
        'description': description.text.trim(),
        'price': int.parse(price.text),
        'category': category,
        'area': widget.area,
        'image_path': path,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (path != null) {
        try {
          await db.storage.from('listing-images').remove([path]);
        } catch (_) {}
      }
      if (mounted) notice(context, friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Đăng món đồ')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : pick,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(photo == null ? 'Thêm ảnh thật' : 'Chọn ảnh khác'),
              ),
              if (photo != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.memory(photo!, height: 200),
                ),
              const SizedBox(height: 20),
              TextFormField(
                controller: title,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Tên món đồ'),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 4 ? 'Nhập ít nhất 4 ký tự' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Danh mục'),
                items:
                    [
                          'Nội thất',
                          'Điện tử',
                          'Gia dụng',
                          'Sách',
                          'Thời trang',
                          'Cho tặng',
                        ]
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged: (v) => category = v!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Giá (đồng) · 0 nếu cho tặng',
                ),
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
                maxLines: 5,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Tình trạng, khuyết điểm, nơi hẹn nhận',
                ),
                validator: (v) => (v?.trim().length ?? 0) < 10
                    ? 'Mô tả ít nhất 10 ký tự'
                    : null,
              ),
              const SizedBox(height: 16),
              Text('Khu vực: ${widget.area} · không đăng địa chỉ nhà chi tiết'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(busy ? 'Đang đăng…' : 'Đăng miễn phí'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class Detail extends StatefulWidget {
  final Map<String, dynamic> item;
  const Detail({super.key, required this.item});
  @override
  State<Detail> createState() => _Detail();
}

class _Detail extends State<Detail> {
  bool busy = false;
  Future<void> contact() async {
    if (db.auth.currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
      );
      if (db.auth.currentUser == null) return;
    }
    setState(() => busy = true);
    try {
      final uid = db.auth.currentUser!.id;
      var t = await db
          .from('conversations')
          .select('*,listings(title,price,image_path)')
          .eq('listing_id', widget.item['id'])
          .eq('buyer_id', uid)
          .maybeSingle();
      t ??= await db
          .from('conversations')
          .insert({
            'listing_id': widget.item['id'],
            'buyer_id': uid,
            'seller_id': widget.item['owner_id'],
          })
          .select('*,listings(title,price,image_path)')
          .single();
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => Chat(thread: t!)),
        );
      }
    } catch (e) {
      if (mounted) notice(context, friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> report() async {
    if (db.auth.currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
      );
      if (db.auth.currentUser == null || !mounted) return;
    }
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Báo cáo tin'),
        content: TextField(
          controller: controller,
          maxLength: 2000,
          decoration: const InputDecoration(
            hintText: 'Nêu lý do (ít nhất 5 ký tự)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().length >= 5) {
                Navigator.pop(c, controller.text.trim());
              }
            },
            child: const Text('Gửi báo cáo'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    try {
      await db.from('reports').insert({
        'reporter_id': db.auth.currentUser!.id,
        'listing_id': widget.item['id'],
        'reason': reason,
      });
      if (mounted) notice(context, 'Đã gửi báo cáo.');
    } catch (e) {
      if (mounted) notice(context, friendly(e));
    }
  }

  Future<void> status(String v) async {
    setState(() => busy = true);
    try {
      await db
          .from('listings')
          .update({'status': v})
          .eq('id', widget.item['id']);
      setState(() => widget.item['status'] = v);
    } catch (e) {
      if (mounted) notice(context, friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final x = widget.item;
    final mine = db.auth.currentUser?.id == x['owner_id'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết món đồ'),
        actions: [
          IconButton(
            tooltip: 'Báo cáo',
            onPressed: report,
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(child: ListingImage(path: x['image_path'], size: 300)),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberPage(
                      id: x['owner_id'],
                      name: x['profiles']?['name'] ?? 'Thành viên',
                    ),
                  ),
                ),
                title: Text(x['profiles']?['name'] ?? 'Thành viên'),
                subtitle: Text('${x['area']} · Chưa xác minh khu vực'),
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
                money(x['price']),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                x['description'],
                style: const TextStyle(fontSize: 17, height: 1.6),
              ),
              const SizedBox(height: 24),
              const Text(
                'Gặp ở nơi công cộng, kiểm tra hàng trước khi thanh toán.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              if (x['moderated'] == true)
                const Text(
                  'Tin đã bị quản trị ẩn. Vui lòng liên hệ quản trị viên.',
                  style: TextStyle(color: Colors.red),
                ),
              if (mine && x['moderated'] != true) ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EditListing(item: x)),
                    );
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Chỉnh sửa tin'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: x['status'],
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: const [
                    DropdownMenuItem(
                      value: 'available',
                      child: Text('Đang bán'),
                    ),
                    DropdownMenuItem(
                      value: 'reserved',
                      child: Text('Đang hẹn'),
                    ),
                    DropdownMenuItem(value: 'sold', child: Text('Đã bán')),
                    DropdownMenuItem(value: 'hidden', child: Text('Ẩn tin')),
                  ],
                  onChanged: busy ? null : (v) => status(v!),
                ),
              ] else
                FilledButton.icon(
                  onPressed: busy || x['status'] != 'available'
                      ? null
                      : contact,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(
                    x['status'] == 'sold'
                        ? 'Đã bán'
                        : x['status'] == 'reserved'
                        ? 'Đang hẹn'
                        : busy
                        ? 'Đang mở…'
                        : 'Nhắn tin hỏi mua',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class Chat extends StatefulWidget {
  final Map<String, dynamic> thread;
  const Chat({super.key, required this.thread});
  @override
  State<Chat> createState() => _Chat();
}

class _Chat extends State<Chat> {
  final input = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  Timer? timer;
  bool sending = false, fetching = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => load());
  }

  @override
  void dispose() {
    timer?.cancel();
    input.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (fetching) return;
    fetching = true;
    try {
      final rows = await db
          .from('messages')
          .select()
          .eq('conversation_id', widget.thread['id'])
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() {
          messages = rows;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = friendly(e));
    } finally {
      fetching = false;
    }
  }

  Future<void> send() async {
    final body = input.text.trim();
    if (body.isEmpty || body.length > 2000) return;
    setState(() => sending = true);
    try {
      await db.from('messages').insert({
        'conversation_id': widget.thread['id'],
        'sender_id': db.auth.currentUser!.id,
        'body': body,
      });
      input.clear();
      await load();
    } catch (e) {
      if (mounted) notice(context, friendly(e));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(widget.thread['listings']?['title'] ?? 'Trò chuyện'),
      actions: [
        IconButton(
          tooltip: 'Lịch hẹn',
          icon: const Icon(Icons.event_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MeetingPage(thread: widget.thread),
            ),
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        ListTile(
          leading: ListingImage(
            path: widget.thread['listings']['image_path'],
            size: 48,
          ),
          title: Text(money(widget.thread['listings']['price'])),
          subtitle: const Text('Thống nhất địa điểm và giờ gặp trong tin nhắn'),
        ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        Expanded(
          child: ListView(
            reverse: true,
            padding: const EdgeInsets.all(20),
            children: messages
                .map(
                  (m) => Align(
                    alignment: m['sender_id'] == db.auth.currentUser?.id
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 480),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: m['sender_id'] == db.auth.currentUser?.id
                            ? const Color(0xFFFFE5D5)
                            : const Color(0xFFF1F2F3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(m['body']),
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
                    controller: input,
                    maxLength: 2000,
                    maxLines: 3,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Nhắn người hàng xóm…',
                      counterText: '',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: sending ? null : send,
                  icon: const Icon(Icons.send, color: brand),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
