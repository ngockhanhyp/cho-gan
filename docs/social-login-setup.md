# Google và Facebook Login cho Passy

Nhánh `codex/google-facebook-login`, dựa trên `codex/location-free-auth`.
Giữ giao diện gốc, vị trí và email/mật khẩu. Không bật đăng ký SĐT, không có SMS hay billing mới.

## Đã thực hiện trong code

- Hai nút đăng nhập/đăng ký Google và Facebook, không bắt người dùng điền form email trước.
- Supabase OAuth PKCE; web quay lại cùng origin/path, không chuyển tiếp code/token/fragment cũ.
- Android mở trình duyệt hệ thống và nhận callback bằng app_links; Flutter route parser không giành callback.
- Dùng tên provider, scope cơ bản; Facebook yêu cầu `email`, Google không xin Gmail/Contacts/Drive.
- Kiểm tra cờ provider bằng `/auth/v1/settings` trước khi rời trang. Provider tắt hoặc lỗi mạng có thông báo và giữ email hoạt động.
- Không coi việc mở trình duyệt là thành công: chờ session/signedIn. Chặn bấm lặp, có quay lại chọn cách đăng nhập nếu đóng trình duyệt.
- Không đưa Client Secret, App Secret hoặc admin token vào Flutter/Git. File `supabase_config.dart` chỉ chứa URL và publishable key công khai đã có từ trước.
- Cập nhật mô tả dữ liệu OAuth trong privacy.html.

## Kiểm tra không cần bí mật

Chạy `dart tool/check_social_auth.dart`. Công cụ chỉ in trạng thái boolean Google/Facebook.
Tại lúc bắt đầu 26/11/2026: cả hai chưa bật. Ngày 27/11/2026 đã xác nhận Google và Facebook đều Enabled trong Supabase Dashboard. Lần chạy công cụ sau khi bật Facebook không truy cập được public Auth settings do lỗi mạng; chưa có kết quả boolean mới từ công cụ.

## Các URL chính xác

| Mục | Giá trị |
| --- | --- |
| Supabase callback — điền ở Google và Facebook | `https://yfqvfkmbvaaujheiivuz.supabase.co/auth/v1/callback` |
| Supabase Site URL | `https://passy.id.vn/` |
| Supabase Redirect allowlist: web | `https://passy.id.vn/` |
| Supabase Redirect allowlist: preview | `http://127.0.0.1:8788/` |
| Supabase Redirect allowlist: preview localhost | `http://localhost:8788/` |
| Supabase Redirect allowlist: Android | `vn.passy.app://login-callback/` |
| Google authorized JavaScript origin | `https://passy.id.vn` |
| Google preview origins | `http://127.0.0.1:8788`, `http://localhost:8788` |
| Meta App Domain | `passy.id.vn` |
| Privacy URL | `https://passy.id.vn/privacy.html` |
| Terms URL | `https://passy.id.vn/terms.html` |

Giữ các URL email recovery đang dùng; bổ sung các URL trên thay vì ghi đè toàn bộ danh sách.
Không đăng ký `passy.id.vn` làm OAuth provider callback: provider luôn trả về Supabase trước.

## Google — bước cần chủ tài khoản

1. Mở Google Auth Platform / Google Cloud Console bằng tài khoản quản trị.
2. Chọn/tạo project cho Passy; cấu hình Branding (tên, support email, domain), Audience và Data Access.
3. Chỉ cần `openid`, `email`, `profile`. Không bật billing hoặc API dữ liệu khác để làm OAuth cơ bản.
4. Tạo OAuth client kiểu Web application với origin/callback ở bảng trên. Luồng Android hiện dùng OAuth qua trình duyệt, không thêm native Google SDK.
5. Chủ tài khoản sao chép Client ID và Client Secret trực tiếp vào Supabase → Authentication → Sign In / Providers → Google. Không gửi secret qua chat hoặc lưu trong repo.
6. Khi ở chế độ Testing, thêm tài khoản thử; kiểm tra điều kiện chuyển Production/branding verification hiện trên console trước khi mở đại trà.

## Facebook — bước cần chủ tài khoản

1. Mở Meta for Developers, chọn/tạo ứng dụng cho Passy với use case Facebook Login/authentication.
2. Điền domain, privacy và terms URL, cấu hình Website và Valid OAuth Redirect URI ở bảng trên.
3. Yêu cầu quyền cơ bản và email; không yêu cầu quyền Pages, quảng cáo hay đăng nội dung.
4. Chủ tài khoản nhập App ID/App Secret vào Supabase Facebook provider. Không lưu App Secret trong Flutter.
5. Development mode chỉ cho admin/developer/tester. Kiểm tra yêu cầu Live, permissions review/business verification trên app cụ thể; không mặc định nút hoạt động cho mọi người khi chưa hoàn tất.
6. Trước khi Live cần hoàn thiện cơ chế tiếp nhận yêu cầu xóa dữ liệu với thông tin liên hệ thật hoặc callback được Meta chấp nhận. Trang privacy hiện vẫn thiếu email hỗ trợ thực tế; không điền email giả để vượt bước này.

## Tài khoản cũ và quyền quản trị

- Dùng Supabase user ID hiện tại, không tạo tài khoản ở cơ sở dữ liệu thứ hai. Không tự gộp theo tên hoặc theo email không được xác minh.
- Supabase có thể tự liên kết identity theo email đáp ứng điều kiện của họ. Cần thử tài khoản email cũ cùng email Google và kiểm tra tin/chat vẫn thuộc cùng user ID.
- Nếu provider không trả email hoặc email khác, đó có thể là tài khoản mới; không tự chuyển tin/chat từ tài khoản cũ.
- Trigger on_signup hiện có đọc metadata `name` và fallback Thành viên nên không bắt buộc email.
- Giữ quy tắc admin email đã xác nhận; không cấp quyền bằng metadata Google/Facebook.
- Nếu cần liên kết thủ công hai identity, làm luồng đăng nhập tài khoản cũ rồi linkIdentity riêng, không suy đoán người dùng là cùng một người.

## Xác nhận sau khi cấu hình

Build web release thành công; analyze không có vấn đề; 19 kiểm thử qua. Đã kiểm tra form desktop và mobile 390×844, thông báo khi provider tắt hoạt động trên backend thật. Bộ test bao gồm session thành công đóng màn đăng nhập, hủy chờ, lỗi khởi chạy, provider tắt, callback và các luồng email/vị trí cũ.

### Tiến độ cấu hình thực tế — 27/11/2026

- Google Cloud project `Passy`, ID `inspired-data-515916-v6`; OAuth client `Passy Web` đã tạo. Client Secret chỉ nhập vào Supabase qua giao diện quản trị, không lưu trong repo.
- Google provider đã lưu và bật; Skip nonce checks và Allow users without an email vẫn tắt.
- Đã bổ sung ba redirect localhost, loopback và Android ở bảng trên, giữ hai URL cũ. Tổng allowlist hiện có 5 URL.
- Tài khoản chủ dự án đã thêm vào Test users. Google vẫn ở chế độ Testing, chưa mở cho công chúng.
- Đã lưu homepage, privacy URL và terms URL trong Google Branding. Không bật billing.
- Kiểm thử thật: từ nút Google trên `http://127.0.0.1:8788/` → chọn tài khoản → đồng ý chia sẻ hồ sơ/email → Supabase callback → về Passy; URL callback được dọn về `/`; mở được Của tôi với tên Google và vẫn thấy một tin đăng cũ. Đây là bằng chứng UI tài khoản được giữ, chưa kiểm độc lập user ID trong DB.
- Chưa kiểm APK Android hoặc tài khoản Google mới khác.
- Facebook: đã tạo Meta App `Passy`, App ID `1087185907614223`. Đã lưu domain, privacy/terms URL và category Mua sắm. Đã lưu Supabase callback trong Valid OAuth Redirect URI; Web/Client OAuth bật, HTTPS và strict redirect bật; embedded OAuth/JS SDK vẫn tắt.
- Quyền `email` và `public_profile` đã hiện Sẵn sàng thử nghiệm. Không thêm quyền dữ liệu khác.
- App Secret được chuyển trực tiếp từ trường hiển thị của Meta vào Supabase, không lưu trong repo. Facebook provider đã Save và xác nhận Enabled; Allow users without an email vẫn tắt. Trang Meta được tải lại để ẩn secret.
- Thử nút Facebook trên preview đã rời Passy tới `www.facebook.com/dialog/oauth`, nhưng trang Facebook bị `ERR_CONNECTION_TIMED_OUT`; chưa xác nhận consent, callback hay session Facebook thành công.
- Meta chưa phát hành: trang Go live chặn bởi URL hướng dẫn xóa dữ liệu và Xác minh doanh nghiệp. Bắt đầu xác minh mở hộp thoại Kết nối với Meta Business Suite, hiện chỉ có Tạo tài khoản mới; chưa tạo Business Suite hoặc gửi thông tin pháp lý.

1. Công cụ trạng thái trả true cho cả hai.
2. Trên web: Google/Facebook tài khoản mới → callback → session → hồ sơ, đăng xuất và đăng nhập lại.
3. Thử hủy quyền, đóng cửa sổ, mạng lỗi; thử email/password và quên mật khẩu cũ.
4. Thử tài khoản email cũ cùng email Google; xác minh user ID và dữ liệu.
5. Android: install build, trình duyệt ngoài → callback app → session. Không bật emulator khi chưa được người dùng đồng ý.
6. Facebook thử người có role và người ngoài role sau khi Live; không coi Development mode là phát hành xong.

Giữ thay đổi trên nhánh riêng; chưa merge `main` hoặc deploy website chính. Cấu hình kỹ thuật hai provider đã lưu, nhưng chưa sẵn sàng phát hành công khai. Tiếp tục kiểm thử Facebook khi kết nối phục hồi; hoàn thiện cơ chế xóa dữ liệu thật và xác minh Meta bằng thông tin chủ dự án. Khi mở Google cho công chúng, kiểm tra lại Branding/Audience và các yêu cầu xác minh của Google trước khi chuyển Production.

## Tài liệu chính thức

- https://supabase.com/docs/guides/auth/social-sign-in/auth-google
- https://supabase.com/docs/guides/auth/social-sign-in/auth-facebook
- https://supabase.com/docs/reference/dart/auth-signinwithoauth
- https://supabase.com/docs/guides/auth/native-mobile-deep-linking
- https://supabase.com/docs/guides/auth/auth-identity-linking
