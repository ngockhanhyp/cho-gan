import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Current Hanoi units (2025 administrative arrangement): 51 wards and 75 communes.
/// Kept as plain labels so existing listing.area text remains searchable.
const hanoiWards = <String>[
  'Ba Đình',
  'Ngọc Hà',
  'Giảng Võ',
  'Hoàn Kiếm',
  'Cửa Nam',
  'Phú Thượng',
  'Hồng Hà',
  'Tây Hồ',
  'Bồ Đề',
  'Việt Hưng',
  'Phúc Lợi',
  'Long Biên',
  'Nghĩa Đô',
  'Cầu Giấy',
  'Yên Hòa',
  'Ô Chợ Dừa',
  'Láng',
  'Văn Miếu - Quốc Tử Giám',
  'Kim Liên',
  'Đống Đa',
  'Hai Bà Trưng',
  'Vĩnh Tuy',
  'Bạch Mai',
  'Vĩnh Hưng',
  'Định Công',
  'Tương Mai',
  'Lĩnh Nam',
  'Hoàng Mai',
  'Hoàng Liệt',
  'Yên Sở',
  'Phương Liệt',
  'Khương Đình',
  'Thanh Xuân',
  'Từ Liêm',
  'Thượng Cát',
  'Đông Ngạc',
  'Xuân Đỉnh',
  'Tây Tựu',
  'Phú Diễn',
  'Xuân Phương',
  'Tây Mỗ',
  'Đại Mỗ',
  'Thanh Liệt',
  'Kiến Hưng',
  'Hà Đông',
  'Yên Nghĩa',
  'Phú Lương',
  'Sơn Tây',
  'Tùng Thiện',
  'Dương Nội',
  'Chương Mỹ',
];

const hanoiCommunes = <String>[
  'Sóc Sơn',
  'Kim Anh',
  'Trung Giã',
  'Đa Phúc',
  'Nội Bài',
  'Đông Anh',
  'Phúc Thịnh',
  'Thư Lâm',
  'Thiên Lộc',
  'Vĩnh Thanh',
  'Phù Đổng',
  'Thuận An',
  'Gia Lâm',
  'Bát Tràng',
  'Thanh Trì',
  'Đại Thanh',
  'Ngọc Hồi',
  'Nam Phù',
  'Yên Xuân',
  'Quang Minh',
  'Yên Lãng',
  'Tiến Thắng',
  'Mê Linh',
  'Đoài Phương',
  'Quảng Oai',
  'Cổ Đô',
  'Minh Châu',
  'Vật Lại',
  'Bất Bạt',
  'Suối Hai',
  'Ba Vì',
  'Yên Bài',
  'Phúc Thọ',
  'Phúc Lộc',
  'Hát Môn',
  'Đan Phượng',
  'Liên Minh',
  'Ô Diên',
  'Hoài Đức',
  'Dương Hòa',
  'Sơn Đồng',
  'An Khánh',
  'Quốc Oai',
  'Kiều Phú',
  'Hưng Đạo',
  'Phú Cát',
  'Thạch Thất',
  'Hạ Bằng',
  'Hòa Lạc',
  'Tây Phương',
  'Phú Nghĩa',
  'Xuân Mai',
  'Quảng Bị',
  'Trần Phú',
  'Hòa Phú',
  'Thanh Oai',
  'Bình Minh',
  'Tam Hưng',
  'Dân Hòa',
  'Thường Tín',
  'Hồng Vân',
  'Thượng Phúc',
  'Chương Dương',
  'Phú Xuyên',
  'Phượng Dực',
  'Chuyên Mỹ',
  'Đại Xuyên',
  'Vân Đình',
  'Ứng Thiên',
  'Ứng Hòa',
  'Hòa Xá',
  'Mỹ Đức',
  'Phúc Sơn',
  'Hồng Sơn',
  'Hương Sơn',
];

/// Legacy labels remain available for records created before ward-level areas.
/// They must not be treated as a current ward or converted to one automatically.
const legacyPassyAreas = ['Nam Từ Liêm'];

const passyAreas = [
  ...hanoiWards,
  ...hanoiCommunes,
  ...legacyPassyAreas,
  'Tất cả Hà Nội',
];

const _preferredAreaKey = 'passy.preferred_market_area';

/// Stores only the coarse label chosen by the user, never device coordinates.
Future<String?> loadPreferredPassyArea() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final area = prefs.getString(_preferredAreaKey);
    return passyAreas.contains(area) ? area : null;
  } catch (_) {
    return null;
  }
}

/// Approximate reference points used only to order nearby market suggestions.
/// Never use these points as district polygons or a listing's coordinates.
const _areaReferencePoints = <String, (double, double)>{
  'Cầu Giấy': (21.0369, 105.7826),
  'Nam Từ Liêm': (21.0167, 105.7570),
  'Ba Đình': (21.0364, 105.8284),
  'Thanh Xuân': (20.9940, 105.8110),
};

class NearbyAreaSuggestion {
  final String area;
  final double referenceDistanceKm;
  const NearbyAreaSuggestion(this.area, this.referenceDistanceKm);
}

/// Returns suggestions, not a reverse-geocoded address. A low-accuracy fix or
/// a point far from all supported market areas must not silently select Hanoi.
List<NearbyAreaSuggestion> nearbyPassyAreas(
  double latitude,
  double longitude, {
  required double accuracyMeters,
}) {
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude.abs() > 90 ||
      longitude.abs() > 180 ||
      !accuracyMeters.isFinite ||
      accuracyMeters < 0 ||
      accuracyMeters > 3000) {
    return [];
  }
  double radians(double degrees) => degrees * math.pi / 180;
  final results = _areaReferencePoints.entries
      .map((entry) {
        final latDelta = radians(entry.value.$1 - latitude);
        final lonDelta = radians(entry.value.$2 - longitude);
        final a =
            math.pow(math.sin(latDelta / 2), 2) +
            math.cos(radians(latitude)) *
                math.cos(radians(entry.value.$1)) *
                math.pow(math.sin(lonDelta / 2), 2);
        final km = 6371 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
        return NearbyAreaSuggestion(entry.key, km);
      })
      .where((entry) => entry.referenceDistanceKm <= 6)
      .toList();
  results.sort(
    (a, b) => a.referenceDistanceKm.compareTo(b.referenceDistanceKm),
  );
  return results;
}

/// The only persisted result is an existing coarse market-area label. Device
/// coordinates remain in this sheet and are not sent to a geocoding provider.
Future<String?> showLocationPicker(
  BuildContext context, {
  required String currentArea,
}) async {
  final area = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _LocationPicker(currentArea: currentArea),
  );
  if (area != null && passyAreas.contains(area)) {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferredAreaKey, area);
    } catch (_) {
      // Storage may be unavailable in private browsing; selection still works.
    }
  }
  return area;
}

class _LocationPicker extends StatefulWidget {
  final String currentArea;
  const _LocationPicker({required this.currentArea});

  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  bool locating = false;
  String? message;
  bool canOpenSettings = false;
  List<NearbyAreaSuggestion> suggestions = [];
  String query = '';

  Future<void> locate() async {
    setState(() {
      locating = true;
      message = null;
      canOpenSettings = false;
      suggestions = [];
    });
    try {
      // On web, getCurrentPosition itself requests permission. Checking the
      // Permissions API first can wrongly reject Safari/unsupported browsers.
      if (!kIsWeb) {
        if (!await Geolocator.isLocationServiceEnabled()) {
          throw const _LocationFailure(
            'Dịch vụ vị trí đang tắt. Bật vị trí trên thiết bị hoặc chọn khu vực bên dưới.',
          );
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) {
          throw const _LocationFailure(
            'Quyền vị trí đã bị chặn. Bạn có thể mở cài đặt hoặc chọn khu vực bằng tay.',
            settings: true,
          );
        }
        if (permission == LocationPermission.denied) {
          throw const _LocationFailure(
            'Bạn chưa cho phép truy cập vị trí. Vẫn có thể chọn khu vực bên dưới.',
          );
        }
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final nearby = nearbyPassyAreas(
        position.latitude,
        position.longitude,
        accuracyMeters: position.accuracy,
      );
      if (!mounted) return;
      setState(() {
        suggestions = nearby;
        message = position.accuracy > 3000
            ? 'Vị trí nhận được chưa đủ chính xác để gợi ý. Hãy chọn khu vực bằng tay.'
            : nearby.isEmpty
            ? 'Chưa có gợi ý gần vị trí này. Passy hiện hỗ trợ một số khu vực Hà Nội; bạn có thể chọn bên dưới.'
            : 'Đã tìm được các khu vực gần bạn. Hãy chọn khu vực muốn xem tin.';
      });
    } on TimeoutException {
      if (mounted) {
        setState(
          () => message = 'Chưa lấy được vị trí sau 20 giây. Bạn có thể thử lại hoặc chọn khu vực bằng tay.',
        );
      }
    } on _LocationFailure catch (e) {
      if (mounted) {
        setState(() {
          message = e.message;
          canOpenSettings = e.settings;
        });
      }
    } on PermissionDeniedException {
      if (mounted) {
        setState(
          () => message = 'Quyền vị trí chưa được cấp. Cho phép vị trí trong cài đặt trình duyệt/thiết bị hoặc chọn khu vực bên dưới.',
        );
      }
    } on LocationServiceDisabledException {
      if (mounted) {
        setState(
          () => message =
              'Dịch vụ vị trí đang tắt. Bạn vẫn có thể chọn khu vực bằng tay.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'Không lấy được vị trí trên thiết bị này. Hãy kiểm tra quyền vị trí hoặc chọn khu vực bên dưới.',
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestedNames = suggestions.map((entry) => entry.area).toSet();
    final normalizedQuery = query.trim().toLowerCase();
    final wards = hanoiWards
        .where((a) => a.toLowerCase().contains(normalizedQuery))
        .toList();
    final communes = hanoiCommunes
        .where((a) => a.toLowerCase().contains(normalizedQuery))
        .toList();
    return SafeArea(
      child: SizedBox(
        height: math.min(MediaQuery.sizeOf(context).height * .82, 720),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Text(
                      'Chọn khu vực',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng chọn khu vực',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Tìm phường, xã…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Chọn phường hoặc xã ở Hà Nội để tìm tin gần khu vực đó.',
                    style: TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: locating ? null : locate,
                    icon: locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, size: 20),
                    label: Text(
                      locating ? 'Đang lấy vị trí…' : 'Dùng vị trí hiện tại',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Chỉ lấy vị trí khi bạn bấm nút. Tọa độ dùng để gợi ý khu vực, không lưu lên Passy và không công khai.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message!,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    ),
                  ],
                  if (canOpenSettings && !kIsWeb)
                    TextButton(
                      onPressed: () async {
                        await Geolocator.openAppSettings();
                      },
                      child: const Text('Mở cài đặt quyền vị trí'),
                    ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Gợi ý gần vị trí của bạn',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Theo mốc khu vực tham khảo, không phải xác minh địa chỉ.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final entry in suggestions)
                      _areaTile(entry.area, suggested: true),
                  ],
                  const SizedBox(height: 24),
                  const SizedBox(height: 16),
                  const Text(
                    'Phường',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (wards.isEmpty) const Text('Không tìm thấy phường.'),
                  for (final area in wards) _areaTile(area),
                  const SizedBox(height: 16),
                  const Text(
                    'Xã',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (communes.isEmpty) const Text('Không tìm thấy xã.'),
                  for (final area in communes) _areaTile(area),
                  const SizedBox(height: 16),
                  const Text(
                    'Khu vực cũ và phạm vi tìm kiếm',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  for (final area in [...legacyPassyAreas, 'Tất cả Hà Nội'])
                    if (!suggestedNames.contains(area) &&
                        area.toLowerCase().contains(normalizedQuery))
                      _areaTile(area),
                  const SizedBox(height: 12),
                  Text(
                    'Tên khu vực dùng để tìm tin đăng, không xác nhận nơi cư trú.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _areaTile(String area, {bool suggested = false}) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      suggested ? Icons.near_me_outlined : Icons.location_on_outlined,
    ),
    title: Text(area),
    trailing: area == widget.currentArea
        ? Icon(
            Icons.check_rounded,
            color: Theme.of(context).colorScheme.primary,
          )
        : const Icon(Icons.chevron_right),
    onTap: () => Navigator.pop(context, area),
  );
}

class _LocationFailure implements Exception {
  final String message;
  final bool settings;
  const _LocationFailure(this.message, {this.settings = false});
}
