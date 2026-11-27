part of 'cloud_app.dart';

class MarketMapPage extends StatefulWidget {
  const MarketMapPage({
    super.key, required this.center, required this.areaLabel, required this.nearby,
  });

  final LatLng center;
  final String areaLabel;
  final List<Map<String, dynamic>> nearby;
  @override
  State<MarketMapPage> createState() => _MarketMapPageState();
}

class _MarketMapPageState extends State<MarketMapPage> {
  List<Map<String, dynamic>> pins = [];
  bool loading = true, saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await db.from('seller_map_locations').select();
      final active = await db
          .from('listings')
          .select('id,owner_id,title,price,area,image_path,created_at')
          .eq('status', 'available')
          .order('created_at', ascending: false)
          .limit(500);
      final byOwner = <String, Map<String, dynamic>>{};
      for (final listing in active) {
        byOwner.putIfAbsent('${listing['owner_id']}', () => listing);
      }
      final results = <Map<String, dynamic>>[];
      for (final raw in data) {
        final listing = byOwner['${raw['owner_id']}'];
        if (listing != null) results.add({...raw, 'listing': listing});
      }
      if (mounted) {
        setState(() {
          pins = results;
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

  Future<void> shareApproximateLocation() async {
    if (db.auth.currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
      );
      if (db.auth.currentUser == null || !mounted) return;
    }
    setState(() => saving = true);
    try {
      if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
        throw Exception(
          'Hãy bật dịch vụ vị trí hoặc chọn khu vực trên trang tin.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Chưa được cấp quyền vị trí. Bạn vẫn có thể dùng Passy mà không chia sẻ vị trí.',
        );
      }
      final point = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (point.latitude < 20.4 ||
          point.latitude > 21.8 ||
          point.longitude < 105 ||
          point.longitude > 106) {
        throw Exception('Vị trí hiện tại ngoài phạm vi Hà Nội.');
      }
      // Two decimal places intentionally blur the point to around 1 km.
      final lat = (point.latitude * 100).round() / 100;
      final lon = (point.longitude * 100).round() / 100;
      await db.from('seller_map_locations').upsert({
        'owner_id': db.auth.currentUser!.id,
        'latitude': lat,
        'longitude': lon,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      await load();
      if (mounted) {
        notice(
          context,
          'Đã chia sẻ vị trí gần đúng. Bạn có thể gỡ vị trí bất cứ lúc nào.',
        );
      }
    } catch (e) {
      if (mounted) {
        notice(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> removeLocation() async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) return;
    await db.from('seller_map_locations').delete().eq('owner_id', uid);
    await load();
    if (mounted) notice(context, 'Đã gỡ vị trí khỏi bản đồ.');
  }

  String imageUrl(Map<String, dynamic> listing) => db.storage
      .from('listing-images')
      .getPublicUrl('${listing['image_path']}');

  void showListing(Map<String, dynamic> pin) {
    final listing = pin['listing'] as Map<String, dynamic>;
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              imageUrl(listing),
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported),
            ),
          ),
          title: Text(
            '${listing['title']}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${money(listing['price'])} · ${listing['area']} · vị trí gần đúng',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pop(c);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => Detail(item: listing)),
            );
          },
        ),
      ),
    );
  }

  void showNearby() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          children: [
            ListTile(title: Text('Tin đang bán · ${widget.areaLabel}')),
            if (widget.nearby.isEmpty)
              const ListTile(subtitle: Text('Chưa có tin đang bán ở khu vực này.')),
            for (final item in widget.nearby)
              ListTile(
                leading: ListingImage(path: item['image_path'] ?? '', size: 48),
                title: Text(item['title'] ?? ''),
                subtitle: Text('${money(item['price'])} · ${item['area']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheet);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => Detail(item: item)));
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = db.auth.currentUser?.id;
    final sharing = uid != null && pins.any((p) => p['owner_id'] == uid);
    return Scaffold(
      appBar: AppBar(
        title: Text('Bản đồ · ${widget.areaLabel}'),
        actions: [
          IconButton(
            onPressed: load,
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Khám phá món đồ và người bán gần bạn',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Chỉ người bán tự nguyện chia sẻ mới hiện trên bản đồ. Vị trí được làm mờ khoảng 1 km; không hiển thị địa chỉ nhà.',
                  style: TextStyle(color: muted, height: 1.35),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: showNearby,
                      icon: const Icon(Icons.storefront_outlined),
                      label: Text('Tin đang bán (${widget.nearby.length})'),
                    ),
                    OutlinedButton.icon(
                      onPressed: saving || error != null ? null : shareApproximateLocation,
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.location_searching),
                      label: Text(
                        sharing
                            ? 'Cập nhật vị trí gần đúng'
                            : 'Tự nguyện hiện trên bản đồ',
                      ),
                    ),
                    if (sharing)
                      OutlinedButton.icon(
                        onPressed: removeLocation,
                        icon: const Icon(Icons.location_off_outlined),
                        label: const Text('Gỡ vị trí'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (error != null) const Padding(padding: EdgeInsets.all(8), child: Text('Chưa tải được vị trí người bán. Bạn vẫn có thể mở danh sách tin theo khu vực.')),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: widget.center,
                      initialZoom: widget.areaLabel == 'Tất cả Hà Nội' ? 10.5 : 13,
                      minZoom: 8,
                      maxZoom: 18,
                    ),
                    children: [
                      marketTiles(),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            '© OpenStreetMap contributors',
                            onTap: () => launchUrl(
                              Uri.parse(
                                'https://www.openstreetmap.org/copyright',
                              ),
                            ),
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          for (final pin in pins)
                            Marker(
                              point: LatLng(
                                (pin['latitude'] as num).toDouble(),
                                (pin['longitude'] as num).toDouble(),
                              ),
                              width: 68,
                              height: 76,
                              child: GestureDetector(
                                onTap: () => showListing(pin),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 58,
                                      height: 58,
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(11),
                                        child: Image.network(
                                          imageUrl(pin['listing']),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const Icon(Icons.storefront),
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.place,
                                      color: brand,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
          if (!loading && error == null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                pins.isEmpty
                    ? 'Chưa có người bán chia sẻ vị trí. Tin đăng vẫn xem được theo phường/xã.'
                    : '${pins.length} người bán đang chia sẻ vị trí gần đúng',
                style: const TextStyle(color: muted),
              ),
            ),
        ],
      ),
    );
  }
}
