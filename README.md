# Chợ Gần V1 — bản thử nội bộ

## Mở và cài
- Web đang chạy: https://ngockhanhyp.github.io/cho-gan/
- Tên miền dự kiến: https://passy.id.vn (đang chờ cấu hình DNS CNAME).
- Web trên máy phát triển: http://127.0.0.1:8788
- APK: outputs/ChoGan-v1-android-arm64.apk (sau khi build).
- GitHub Actions tự build và deploy web khi cập nhật code liên quan.
- Trang GitHub Pages hiện công khai; đăng ký/email xác nhận cần URL redirect và SMTP Supabase được cấu hình phù hợp.
- Android kết nối cùng Supabase với web, cần Internet.

## Có trong V1
- Tài khoản email/mật khẩu; xác nhận email của Supabase.
- Tin đăng có ảnh thật (tối đa 5 MB), khu vực, danh mục, giá, mô tả; sửa nội dung, đặt trạng thái đang bán/đang hẹn/đã bán/ẩn.
- Tìm kiếm và lọc; yêu thích đồng bộ tài khoản.
- Hội thoại riêng theo món hàng; kiểm tra tin mới mỗi 3 giây khi mở hội thoại.
- Lịch hẹn: đề xuất, bên kia chấp nhận, hủy, hai bên xác nhận hoàn tất.
- Đánh giá chỉ sau giao dịch đã được cả hai bên xác nhận; hồ sơ phản hồi.
- Chặn liên hệ mới, báo cáo tin; quản trị viên ẩn tin và đóng báo cáo; nhật ký quản trị trong DB.
- Cộng đồng bằng mã mời, bảng tin chỉ thành viên đọc/đăng; mã mời không đồng nghĩa xác minh cư trú.
- Web và Android dùng chung mã nguồn, tài khoản và dữ liệu.

## Chạy / build
SDK hiện tại: C:/Users/vanma/dev/flutter (Flutter 3.47 / Dart 3.13).

```powershell
flutter pub get
flutter test
flutter analyze
flutter build web --no-web-resources-cdn --no-wasm-dry-run
node tool/serve.cjs
flutter build apk --release --target-platform android-arm64
```

Điểm vào mặc định lib/main.dart là bản trực tuyến. lib/demo_main.dart là bản mẫu cục bộ tách riêng. Không đưa dữ liệu mẫu vào DB thật.

## Máy chủ
Supabase project yfqvfkmbvaaujheiivuz, Singapore, gói Free. Migration trong supabase/ đã áp dụng qua SQL Editor. Không chạy lại các migration đã áp dụng. Khóa publishable được phép nằm trong ứng dụng; không đưa service-role key hoặc mật khẩu DB vào mã nguồn.

Quản trị dùng bảng admin_emails riêng với RLS. Email cấu hình phải được Supabase xác nhận. Không sử dụng user_metadata để cấp quyền quản trị. Chưa có cơ chế mời thêm quản trị trong app.

## Kiểm chứng 26/11/2026
- 5 bài Flutter test: định dạng giá, feed điện thoại, yêu cầu đăng nhập trước đăng tin, validation email/mật khẩu, cộng đồng yêu cầu đăng nhập, liên kết tin không tồn tại và bản demo (một số bài gộp nhiều assertion).
- Kiểm thử transaction/rollback trực tiếp trên Supabase: quyền sửa tin, người ngoài không đọc/chèn chat, không tự chấp nhận lời hẹn, đánh giá sớm bị từ chối, hai bên hoàn tất thì đã bán, chặn gửi tin mới.
- Kiểm thử cộng đồng: người ngoài không xem/đăng, mã mời đúng cho phép tham gia; tài khoản thường không thể gọi quản trị.
- Dữ liệu kiểm thử DB đã rollback.
- Web đã được mở trên Chrome và kiểm tra trang feed/đăng nhập. Chưa xác nhận end-to-end bằng hai thiết bị thật.
- Commit `4e83e94` đã được build và deploy qua GitHub Actions. Trang Pages và `flutter_bootstrap.js` đều trả HTTP 200; chưa kiểm tra đăng nhập/email trên domain tùy chỉnh.

## Giới hạn trước khi mời đông người
- Chưa GPS, chưa xác thực cư trú/doanh nghiệp, không có huy hiệu/điểm tin cậy giả.
- Chưa push khi đóng app, chat tải 100 tin gần nhất, feed 200 tin gần nhất; cần phân trang cho quy mô lớn.
- Tin hiện một ảnh; chưa đổi ảnh trên tin đã đăng. Cộng đồng chưa bình luận, xóa bài/rời nhóm/đổi mã mời.
- Luồng quên/reset mật khẩu web đã được thêm; cần xác nhận redirect URL và email thật. Chưa có xóa tài khoản tự phục vụ, rate-limit nghiệp vụ và chống spam nâng cao.
- Email xác nhận dùng cấu hình Supabase hiện tại. Cần SMTP riêng và URL sản phẩm trước khi mở đăng ký đại trà.
- Chưa phát hành Google Play/App Store; APK ký khóa thử, chỉ dùng pilot. iOS chưa build.
- Chưa có analytics/monitoring vận hành đầy đủ, chính sách pháp lý hoàn chỉnh hay kiểm định an toàn sản phẩm thương mại.
- `passy.id.vn` chưa nối DNS; cần CNAME trỏ tới `ngockhanhyp.github.io`, rồi cập nhật GitHub Pages và Supabase Auth URLs.

## Benchmark 당근
Bám theo cốt lõi địa phương, giao dịch trực tiếp miễn phí, tin dạng danh sách ảnh/giá, chat gắn món, lịch hẹn và phản hồi. Sử dụng tên/biểu tượng/mã nguồn riêng. Chưa đạt tương đương toàn bộ tính năng, chất lượng và quy mô của 당근.
