part of 'cloud_app.dart';

const districtWards = <String, List<String>>{
  'Cầu Giấy': ['Cầu Giấy', 'Nghĩa Đô', 'Yên Hòa'],
  'Ba Đình': ['Ba Đình', 'Ngọc Hà', 'Giảng Võ'],
  'Hoàn Kiếm': ['Hoàn Kiếm', 'Cửa Nam'],
  'Đống Đa': ['Đống Đa', 'Láng', 'Ô Chợ Dừa', 'Kim Liên', 'Văn Miếu - Quốc Tử Giám'],
  'Tây Hồ': ['Tây Hồ', 'Phú Thượng'],
  'Hai Bà Trưng': ['Hai Bà Trưng', 'Vĩnh Tuy', 'Bạch Mai'],
  'Long Biên': ['Long Biên', 'Bồ Đề', 'Việt Hưng', 'Phúc Lợi'],
  'Hoàng Mai': ['Hoàng Mai', 'Hoàng Liệt', 'Định Công', 'Tương Mai', 'Yên Sở'],
  'Thanh Xuân': ['Thanh Xuân', 'Khương Đình', 'Phương Liệt'],
};

const nearbyCenters = <String, LatLng>{
  'Cầu Giấy': LatLng(21.034, 105.792),
  'Ba Đình': LatLng(21.035, 105.821),
  'Hoàn Kiếm': LatLng(21.029, 105.854),
  'Đống Đa': LatLng(21.020, 105.829),
  'Tây Hồ': LatLng(21.070, 105.826),
  'Hai Bà Trưng': LatLng(21.004, 105.852),
  'Long Biên': LatLng(21.046, 105.898),
  'Hoàng Mai': LatLng(20.978, 105.851),
  'Thanh Xuân': LatLng(20.998, 105.807),
};

String marketDistrict(String area) {
  for (final group in districtWards.entries) {
    if (group.value.contains(area)) return group.key;
  }
  return area;
}

TileLayer marketTiles() => TileLayer(
  urlTemplate: const String.fromEnvironment(
    'PASSY_MAP_TILE_URL', defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  ),
  userAgentPackageName: 'vn.id.passy',
);

extension MarketHome on _Home {
  Widget nearbyMap() {
    final district = marketDistrict(area);
    final center = nearbyCenters[district] ?? const LatLng(21.0285, 105.8542);
    final nearby = listings.where((item) => item['status'] == 'available' &&
        !listingIsGift(item) &&
        (area == 'Tất cả Hà Nội' || marketDistrict('${item['area']}') == district)).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => MarketMapPage(center: center, areaLabel: area, nearby: nearby),
          )),
          child: Column(
            children: [
              SizedBox(
                height: 140,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(child: FlutterMap(
                      key: ValueKey(center),
                      options: MapOptions(initialCenter: center, initialZoom: area == 'Tất cả Hà Nội' ? 10.5 : 13,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
                      children: [marketTiles()],
                    )),
                    const Center(child: Icon(Icons.location_pin, color: brand, size: 36)),
                    const Positioned(right: 4, bottom: 2, child: ColoredBox(
                      color: Colors.white, child: Text('© OpenStreetMap', style: TextStyle(fontSize: 10)),
                    )),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined, color: brand),
                title: const Text('Bản đồ quanh bạn'),
                subtitle: Text('${nearby.length} tin đang bán · $area'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget districtDirectory() => sideCard('Khu vực Hà Nội', Column(
    children: [
      for (final group in districtWards.entries.take(showAllDistricts ? districtWards.length : 4))
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(left: 12),
          title: Text(group.key),
          children: [
            for (final ward in group.value)
              ListTile(
                dense: true,
                title: Text('Phường $ward'),
                selected: area == ward,
                onTap: () => setState(() => area = ward),
              ),
          ],
        ),
      TextButton.icon(
        onPressed: () => setState(() => showAllDistricts = !showAllDistricts),
        icon: Icon(showAllDistricts ? Icons.expand_less : Icons.expand_more),
        label: Text(showAllDistricts ? 'Thu gọn' : 'Xem thêm quận'),
      ),
      TextButton(onPressed: pickArea, child: const Text('Tất cả phường, xã')),
    ],
  ));
}
