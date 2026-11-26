import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

part 'trust.dart';
part 'community.dart';
part 'listing_edit.dart';

const brand = Color(0xFFFF6F32);
final db = Supabase.instance.client;
String? authRedirectUrl() =>
    kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : null;
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
          constraints: const BoxConstraints(maxWidth: 1440),
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
    auth = db.auth.onAuthStateChange.listen((state) {
      refresh();
      if (state.event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PasswordRecoveryPage()),
          );
        });
      }
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

  static const areas = [
    'Cầu Giấy',
    'Nam Từ Liêm',
    'Ba Đình',
    'Thanh Xuân',
    'Tất cả Hà Nội',
  ];

  Future<void> pickArea() => showModalBottomSheet(
    context: context,
    builder: (s) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Chọn khu vực của bạn',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          ...areas.map(
            (a) => ListTile(
              title: Text(a),
              trailing: a == area ? const Icon(Icons.check, color: brand) : null,
              onTap: () {
                setState(() => area = a);
                Navigator.pop(s);
              },
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> compose() async {
    if (!await login() || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            Compose(area: area == 'Tất cả Hà Nội' ? 'Cầu Giấy' : area),
      ),
    );
    refresh();
  }

  void go(int i) {
    setState(() => page = i);
    refresh();
  }

  void browse(String cat) => setState(() {
    page = 0;
    category = cat;
  });

  void safetyTips() => showDialog(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Giao dịch an toàn'),
      content: const Text(
        '• Hẹn gặp ở nơi công cộng, đông người.\n'
        '• Kiểm tra kỹ món đồ trước khi trả tiền.\n'
        '• Không chuyển khoản đặt cọc cho người lạ.\n'
        '• Không bấm link thanh toán lạ gửi qua tin nhắn.\n'
        '• Báo cáo ngay tin đăng hoặc tài khoản đáng ngờ.',
        style: TextStyle(height: 1.7),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Đã hiểu')),
      ],
    ),
  );

  @override
  Widget build(BuildContext c) {
    final wide = MediaQuery.sizeOf(c).width >= 900;
    final Widget content = loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!),
                TextButton(onPressed: refresh, child: const Text('Thử lại')),
              ],
            ),
          )
        : page == 0
        ? feed(wide)
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: page == 1
                  ? const CommunitiesPage()
                  : page == 2
                  ? inbox()
                  : profile(),
            ),
          );
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(wide ? 76 : 60),
        child: header(wide),
      ),
      body: content,
      floatingActionButton: !wide && page == 0
          ? FloatingActionButton.extended(
              backgroundColor: brand,
              foregroundColor: Colors.white,
              onPressed: compose,
              icon: const Icon(Icons.add),
              label: const Text('Đăng tin'),
            )
          : null,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: page,
              onDestinationSelected: go,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFFFE5D5),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Gần bạn',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'Khu phố',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble),
                  label: 'Trò chuyện',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Của tôi',
                ),
              ],
            ),
    );
  }

  Widget logo({double size = 34}) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () => browse('Tất cả'),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: brand,
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Icon(Icons.home_rounded, color: Colors.white, size: size * 0.66),
        ),
        const SizedBox(width: 8),
        Text(
          'Chợ Gần',
          style: TextStyle(
            fontSize: size * 0.62,
            fontWeight: FontWeight.w900,
            color: brand,
            letterSpacing: -0.5,
          ),
        ),
      ],
    ),
  );

  Widget searchBox({bool compact = false}) => TextField(
    onChanged: (v) => setState(() {
      search = v;
      page = 0;
    }),
    decoration: InputDecoration(
      isDense: compact,
      prefixIcon: const Icon(Icons.search),
      hintText: 'Tìm món đồ ở $area',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget areaButton() => TextButton.icon(
    onPressed: pickArea,
    icon: const Icon(Icons.location_on, color: brand, size: 20),
    label: Text(
      '$area ▾',
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: Colors.black87,
      ),
    ),
  );

  Widget navLink(String label, int i) => TextButton(
    onPressed: () => go(i),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 15,
        fontWeight: page == i ? FontWeight.w800 : FontWeight.w500,
        color: page == i ? brand : Colors.black87,
      ),
    ),
  );

  Widget header(bool wide) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
    ),
    child: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 12),
            child: Row(
              children: wide
                  ? [
                      logo(),
                      const SizedBox(width: 28),
                      Expanded(child: searchBox(compact: true)),
                      const SizedBox(width: 12),
                      areaButton(),
                      const SizedBox(width: 8),
                      navLink('Khu phố', 1),
                      navLink('Trò chuyện', 2),
                      navLink(
                        db.auth.currentUser == null ? 'Đăng nhập' : 'Của tôi',
                        3,
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: brand,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        onPressed: compose,
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text(
                          'Đăng tin',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]
                  : [
                      logo(size: 30),
                      const Spacer(),
                      areaButton(),
                      IconButton(
                        tooltip: 'Tải lại',
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget feed(bool wide) {
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
    final pad = wide ? 24.0 : 16.0;
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, wide ? 28 : 12, pad, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!wide) ...[searchBox(), const SizedBox(height: 16)],
                    if (search.isEmpty) ...[
                      hero(wide),
                      SizedBox(height: wide ? 36 : 24),
                      services(wide),
                      SizedBox(height: wide ? 44 : 28),
                    ],
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: listingSection(shown, wide)),
                          const SizedBox(width: 32),
                          SizedBox(width: 300, child: sidebar()),
                        ],
                      )
                    else ...[
                      listingSection(shown, wide),
                      const SizedBox(height: 32),
                      sidebar(),
                    ],
                  ],
                ),
              ),
            ),
          ),
          footer(wide),
          if (!wide) const SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget hero(bool wide) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(wide ? 40 : 22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFF3EA), Color(0xFFFFE3D1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, color: brand, size: 15),
                    SizedBox(width: 4),
                    Text(
                      'Chợ đồ cũ của hàng xóm Hà Nội',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: brand,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Mua bán đồ cũ\nvới người ngay gần bạn',
                style: TextStyle(
                  fontSize: wide ? 40 : 26,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Đăng tin miễn phí, nhắn tin trực tiếp, hẹn gặp ở chỗ thuận tiện. '
                'Món đồ bạn không dùng nữa có thể là thứ hàng xóm đang cần.',
                style: TextStyle(
                  fontSize: wide ? 17 : 15,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: brand,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 16,
                      ),
                    ),
                    onPressed: compose,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                    label: const Text(
                      'Đăng tin miễn phí',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 16,
                      ),
                    ),
                    onPressed: pickArea,
                    icon: const Icon(Icons.location_on_outlined, size: 20),
                    label: Text('Đổi khu vực · $area'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (wide) ...[const SizedBox(width: 32), heroArt()],
      ],
    ),
  );

  Widget heroArt() {
    Widget bubble(IconData icon, Color bg, double s) => Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(s * 0.28),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: s * 0.5),
    );
    return SizedBox(
      width: 300,
      height: 230,
      child: Stack(
        children: [
          Positioned(left: 70, top: 30, child: bubble(Icons.chair_alt_rounded, brand, 140)),
          Positioned(left: 0, top: 0, child: bubble(Icons.menu_book_rounded, const Color(0xFF2E9E6B), 80)),
          Positioned(right: 0, top: 10, child: bubble(Icons.headphones_rounded, const Color(0xFF3B6FE0), 76)),
          Positioned(left: 10, bottom: 0, child: bubble(Icons.local_florist_rounded, const Color(0xFFE2A23B), 70)),
          Positioned(right: 20, bottom: 6, child: bubble(Icons.checkroom_rounded, const Color(0xFF9B5DE5), 64)),
        ],
      ),
    );
  }

  Widget services(bool wide) {
    final items = <(IconData, Color, String, VoidCallback)>[
      (Icons.shopping_bag_rounded, brand, 'Mua bán đồ cũ', () => browse('Tất cả')),
      (Icons.volunteer_activism_rounded, const Color(0xFFE5484D), 'Cho tặng', () => browse('Cho tặng')),
      (Icons.chair_rounded, const Color(0xFF8D6E63), 'Nội thất', () => browse('Nội thất')),
      (Icons.devices_rounded, const Color(0xFF3B6FE0), 'Điện tử', () => browse('Điện tử')),
      (Icons.groups_rounded, const Color(0xFF2E9E6B), 'Khu phố', () => go(1)),
      (Icons.chat_bubble_rounded, const Color(0xFF0EA5E9), 'Trò chuyện', () => go(2)),
      (Icons.favorite_rounded, const Color(0xFFDB2777), 'Đồ đã lưu', () => go(3)),
      (Icons.verified_user_rounded, const Color(0xFF6B7280), 'Giao dịch an toàn', safetyTips),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Khám phá Chợ Gần',
          style: TextStyle(fontSize: wide ? 22 : 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: wide ? 12 : 4,
          crossAxisSpacing: wide ? 12 : 4,
          childAspectRatio: wide ? 3.4 : 0.9,
          children: items.map((e) {
            final (icon, color, label, onTap) = e;
            final badge = Container(
              width: wide ? 40 : 48,
              height: wide ? 40 : 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: wide ? 22 : 26),
            );
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: wide
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          badge,
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.black26),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        badge,
                        const SizedBox(height: 6),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget listingSection(List<Map<String, dynamic>> shown, bool wide) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              search.isNotEmpty
                  ? 'Kết quả cho “$search”'
                  : area == 'Tất cả Hà Nội'
                  ? 'Đồ cũ mới đăng ở Hà Nội'
                  : 'Đồ cũ mới đăng ở $area',
              style: TextStyle(fontSize: wide ? 22 : 19, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '${shown.length} món',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: categories
              .map(
                (v) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(v),
                    selected: category == v,
                    showCheckmark: false,
                    selectedColor: const Color(0xFF222222),
                    labelStyle: TextStyle(
                      color: category == v ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: const StadiumBorder(
                      side: BorderSide(color: Color(0xFFE5E5E5)),
                    ),
                    backgroundColor: Colors.white,
                    onSelected: (_) => setState(() => category = v),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 20),
      if (shown.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(Icons.storefront_outlined, size: 56, color: brand),
              const SizedBox(height: 14),
              const Text(
                'Chưa có món nào ở đây',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hãy là người đầu tiên đăng món đồ bạn không còn dùng.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: compose, child: const Text('Đăng tin ngay')),
            ],
          ),
        )
      else
        LayoutBuilder(
          builder: (_, box) {
            final cols = (box.maxWidth / 210).floor().clamp(2, 4);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: shown.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: wide ? 20 : 12,
                mainAxisSpacing: wide ? 28 : 20,
                mainAxisExtent: box.maxWidth / cols + 104,
              ),
              itemBuilder: (_, i) => card(shown[i]),
            );
          },
        ),
    ],
  );

  String ago(dynamic iso) {
    final t = DateTime.tryParse('${iso ?? ''}');
    if (t == null) return '';
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 1) return 'vừa xong';
    if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
    if (d.inHours < 24) return '${d.inHours} giờ trước';
    if (d.inDays < 30) return '${d.inDays} ngày trước';
    return '${t.day}/${t.month}/${t.year}';
  }

  Widget card(Map<String, dynamic> x) {
    final saved = favorites.contains(x['id']);
    final status = x['status'] == 'sold'
        ? 'Đã bán'
        : x['status'] == 'reserved'
        ? 'Đang hẹn'
        : null;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => Detail(item: x)),
        );
        refresh();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: status == 'Đã bán' ? 0.55 : 1,
                  child: ListingImage(path: x['image_path'] ?? '', size: double.infinity),
                ),
                if (status != null)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'Đã bán' ? Colors.black87 : const Color(0xFF2E9E6B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 1,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => favorite(x),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Icon(
                          saved ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: saved ? brand : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            x['title'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, height: 1.35),
          ),
          const SizedBox(height: 4),
          Text(
            money(x['price']),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            [x['area'], ago(x['created_at'])].where((s) => '${s ?? ''}'.isNotEmpty).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget sideCard(String title, Widget child) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F7F8),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget sidebar() {
    final live = listings.where((x) => x['status'] == 'available').toList();
    return Column(
      children: [
        sideCard(
          'Khu vực sôi động',
          Column(
            children: areas.where((a) => a != 'Tất cả Hà Nội').map((a) {
              final n = live.where((x) => x['area'] == a).length;
              return InkWell(
                onTap: () => setState(() => area = a),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 18,
                        color: a == area ? brand : Colors.black38,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          a,
                          style: TextStyle(
                            fontWeight: a == area ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ),
                      Text('$n món', style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        sideCard(
          'Danh mục',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories
                .where((v) => v != 'Tất cả')
                .map(
                  (v) => ActionChip(
                    label: Text(v),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE5E5E5)),
                    shape: const StadiumBorder(),
                    onPressed: () => browse(v),
                  ),
                )
                .toList(),
          ),
        ),
        sideCard(
          'Giao dịch an toàn',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final tip in const [
                'Gặp ở nơi công cộng, đông người',
                'Kiểm tra hàng trước khi trả tiền',
                'Không chuyển khoản đặt cọc',
                'Báo cáo tin đáng ngờ',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 18, color: Color(0xFF2E9E6B)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(tip)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget footer(bool wide) {
    Widget link(String text, VoidCallback onTap) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text(text, style: const TextStyle(color: Colors.black54)),
      ),
    );
    Widget col(String title, List<Widget> items) => SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...items,
        ],
      ),
    );
    void open(String path) => launchUrl(Uri.base.resolve(path), webOnlyWindowName: '_self');
    return Container(
      color: const Color(0xFFF7F7F8),
      padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 40,
                runSpacing: 28,
                children: [
                  SizedBox(
                    width: 280,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        logo(size: 28),
                        const SizedBox(height: 12),
                        const Text(
                          'Chợ đồ cũ của hàng xóm. Mua bán miễn phí, gặp nhau trực tiếp.',
                          style: TextStyle(color: Colors.black54, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  col('Khám phá', [
                    link('Mua bán đồ cũ', () => browse('Tất cả')),
                    link('Đồ cho tặng', () => browse('Cho tặng')),
                    link('Khu phố', () => go(1)),
                    link('Trò chuyện', () => go(2)),
                  ]),
                  col('Hỗ trợ', [
                    link('Giao dịch an toàn', safetyTips),
                    link('Điều khoản sử dụng', () => open('/terms.html')),
                    link('Chính sách quyền riêng tư', () => open('/privacy.html')),
                  ]),
                ],
              ),
              const SizedBox(height: 28),
              const Divider(color: Color(0xFFE5E5E5)),
              const SizedBox(height: 12),
              const Text(
                '© 2026 Chợ Gần · Dự án cộng đồng thử nghiệm tại Hà Nội',
                style: TextStyle(color: Colors.black45, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
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
          emailRedirectTo: authRedirectUrl(),
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

  Future<void> sendPasswordReset() async {
    final address = email.text.trim();
    if (!address.contains('@') ||
        address.startsWith('@') ||
        address.endsWith('@')) {
      setState(
        () => message =
            'Nhập email đã đăng ký để nhận liên kết đặt lại mật khẩu.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await db.auth.resetPasswordForEmail(
        address,
        redirectTo: authRedirectUrl(),
      );
      if (mounted) {
        setState(
          () => message = 'Nếu email này có tài khoản, hướng dẫn đặt lại mật khẩu sẽ được gửi đến hộp thư.',
        );
      }
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
              if (!signup)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: busy ? null : sendPasswordReset,
                    child: const Text('Quên mật khẩu?'),
                  ),
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

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({super.key});
  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? message;

  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await db.auth.updateUser(UserAttributes(password: password.text));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Mật khẩu đã được cập nhật.')),
      );
    } catch (e) {
      if (mounted) setState(() => message = friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đặt lại mật khẩu')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Tạo mật khẩu mới cho tài khoản của bạn.',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
                validator: (value) => value == null || value.length < 8
                    ? 'Mật khẩu cần ít nhất 8 ký tự'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmation,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nhập lại mật khẩu',
                ),
                validator: (value) =>
                    value != password.text ? 'Hai mật khẩu chưa khớp' : null,
              ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    message!,
                    style: const TextStyle(color: Colors.deepOrange),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Đang cập nhật…' : 'Lưu mật khẩu mới'),
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
