# Đăng ký số điện thoại và OTP cho Passy

Nghiên cứu 26/11/2026; chưa thay đổi mã đăng nhập, cấu hình Auth hay gửi SMS.

## Hướng đề xuất

Giữ Supabase Auth để tạo, hết hạn và kiểm tra OTP; nhà cung cấp SMS chỉ chuyển mã tới máy người dùng. Flutter gọi `signInWithOtp(phone: ...)` rồi `verifyOTP(type: OtpType.sms, ...)` để nhận session.

Khảo sát SMS nội địa (ví dụ eSMS) và nối qua Send SMS Hook ở máy chủ. Cần đăng ký dịch vụ, duyệt mẫu OTP và nhận báo giá thực tế trước khi bật. Không nhúng khóa SMS vào Flutter, không tự sinh/kiểm mã ở client.

Nguồn chính thức:
- [Supabase Phone Login](https://supabase.com/docs/guides/auth/phone-login)
- [Send SMS Hook](https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook)
- [Các gói hỗ trợ Auth Hooks](https://supabase.com/docs/guides/auth/auth-hooks)
- [Flutter gửi OTP](https://supabase.com/docs/reference/dart/auth-signinwithotp)
- [Flutter kiểm OTP](https://supabase.com/docs/reference/dart/auth-verifyotp)
- [eSMS API](https://samplefordevelopers.esms.vn/)

## Chi phí và lựa chọn

Twilio là provider tích hợp sẵn nhưng giá niêm yết gửi Việt Nam tại thời điểm khảo sát là 0,2852 USD/segment: 1.000 SMS một segment tương đương 285,20 USD, chưa phí khác. Việt Nam có yêu cầu đăng ký Sender ID/template. eSMS cần báo giá đúng loại OTP, theo nhà mạng, thuế và phí hồ sơ; không dùng giá SMS quảng cáo thay cho giá OTP.

- [Twilio giá Việt Nam](https://www.twilio.com/en-us/sms/pricing/vn)
- [Twilio quy định Việt Nam](https://www.twilio.com/en-us/guidelines/vn/sms)
- [eSMS giá công khai](https://esms.vn/chinh-sach-gia)

Zalo có mẫu xác thực nhưng cần OA, AppID, tài khoản dịch vụ và template được duyệt; không phải provider Supabase tích hợp sẵn. Có thể khảo sát thêm qua custom hook, cùng SMS dự phòng. Giá công khai/giá chỉ mục chưa thống nhất nên chưa chốt dự toán.

- [Zalo mẫu xác thực](https://zalo.solutions/business-message/guidelines/cach-su-dung-va-ung-dung-cua-mau-xac-thuc)
- [Lộ trình thiết lập Zalo](https://zalo.solutions/business-message/guidelines/lo-trinh-bat-dau)

## Tương thích dữ liệu hiện tại

- `public.profiles` có policy đọc công khai trong `supabase/001_initial.sql`. Không thêm phone vào bảng này; giữ trong Auth hoặc bảng private có RLS.
- Người đã đăng ký email phải đăng nhập tài khoản cũ, thêm phone bằng `updateUser` và xác thực `OtpType.phoneChange` để giữ cùng user ID, tin và chat. Không tự tạo tài khoản phone mới rồi kỳ vọng hệ thống gộp.
- Trigger tạo hồ sơ có fallback tên Thành viên, không bắt buộc email. Quyền admin hiện dựa email đã xác nhận nên giữ email cho admin.
- Chuẩn hóa số VN về E.164 (`09…` → `+849…`), giới hạn gửi lại, OTP hết hạn, CAPTCHA và hạn mức ngân sách SMS.
- Giải thích mục đích lưu số và giữ riêng tư; lựa chọn tiếp thị cần tách khỏi xác thực. OTP xác nhận khả năng nhận mã, không xác minh cư trú.

Nguồn: [updateUser](https://supabase.com/docs/reference/dart/auth-updateuser), [Rate limits](https://supabase.com/docs/guides/auth/rate-limits), [CAPTCHA](https://supabase.com/docs/guides/auth/auth-captcha).

## Bước triển khai tiếp theo

Chọn nhà cung cấp và có thông tin API/mẫu được duyệt; làm hook trên máy chủ, thử test numbers, tích hợp UI phone, luồng liên kết tài khoản email cũ và kiểm tra gửi thật qua các nhà mạng. Chưa có nhà cung cấp thì chưa thể xác nhận OTP SMS hoạt động end-to-end.
