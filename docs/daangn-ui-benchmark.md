# Passy: benchmark giao diện 당근

Ngày khảo sát: 26/11/2026. Nhánh: `codex/daangn-ui-benchmark`.
Mốc trước thay đổi: `2cb493a` trên `main`.

## Nguồn tham chiếu và phạm vi

- [Trang chủ 당근](https://www.daangn.com/kr/): xem trực tiếp trên desktop.
- [Mua bán đồ cũ](https://www.daangn.com/kr/search/buy-sell/): xem desktop 1280×720 và web mobile 390×844; mở bộ lọc và một tin thật.
- Đây là benchmark website hiện tại, không phải tái dựng ứng dụng Android/iOS hoặc phiên bản những năm đầu.
- Giữ logo, tên và SVG của Passy; không sao chép mã, logo, ảnh hàng hay dữ liệu của 당근.

## Quan sát → áp dụng

| Quan sát trực tiếp | Thực hiện trong Passy |
| --- | --- |
| Nền xám nhạt, các cụm nội dung trắng bo góc; ít bóng | Canvas #F3F4F5, lưới và sidebar trắng, góc 20px |
| Khung nội dung nằm giữa, khoảng trắng hai bên | Giới hạn khung 1080px, padding desktop 24px/mobile 16px |
| Logo cạnh tìm kiếm dài dạng viên thuốc | Tìm kiếm nền trắng, bo tròn, nút xóa hoạt động |
| Thanh dịch vụ dạng viên thuốc, mục hiện tại màu than | Mua bán / Khu phố / Trò chuyện trên desktop; giữ thanh dưới cho mobile |
| Tiêu đề gắn khu vực, nút lọc và chọn khu vực ngay trên kết quả | Đưa các điều khiển lên trước lưới; bỏ banner lớn và dãy ô khám phá khỏi feed |
| Lưới desktop ba cột trong khối chính; web mobile hai cột | Lưới 3 cột khi đủ rộng, 2 cột ở màn nhỏ; tính chiều cao theo ảnh thực |
| Ảnh vuông, tên chữ thường, giá đậm, khu vực/thời gian nhỏ | Giữ thông tin thật và định dạng tiền Việt, giới hạn tên hai dòng |
| Bộ lọc có trạng thái và danh mục, có đặt lại/áp dụng | Draft độc lập: đang bán, danh mục, sắp giá/mới nhất; chỉ áp dụng khi bấm |
| Mở món hàng thành panel bên phải trên desktop | Dialog bên phải, nền feed vẫn thấy; mobile mở màn chi tiết, giữ chia sẻ/hồ sơ/chat |
| Sidebar tìm kiếm phổ biến | Passy chưa có số liệu tìm kiếm, dùng danh mục có thể bấm, đăng tin và hướng dẫn giao dịch thật |

## Điều chỉnh có chủ đích

- Không tạo số lượt xem, độ tin cậy, danh sách phổ biến hoặc khoảng cách giả.
- Web mobile của 당근 có khối từ khóa trước sản phẩm; Passy đưa sản phẩm lên sớm và giữ bottom navigation hiện có.
- Không sao chép các mục ngành nghề khác; benchmark tập trung vào visual hierarchy của màn mua bán.
- Tính năng, quyền DB, tài khoản và quy trình giao dịch giữ nguyên. OTP điện thoại chỉ được nghiên cứu, chưa kích hoạt.

## Vị trí

- Chọn khu vực bằng tay hoặc bấm “Dùng vị trí hiện tại” để xin quyền một lần.
- Dùng geolocator, Android chỉ xin vị trí gần đúng, không có quyền theo dõi nền.
- So vị trí với mốc tham khảo offline để sắp gợi ý; người dùng phải tự xác nhận khu vực. Không xác định ranh giới hành chính.
- Ngoài phạm vi hoặc độ chính xác kém: chọn tay. Từ chối quyền không chặn sử dụng.
- Chỉ lưu tên khu vực trên thiết bị; không ghi tọa độ vào DB hoặc gửi tới dịch vụ geocoding.
- Chưa có tọa độ từng tin nên không hiển thị khoảng cách hay bản đồ hàng hóa.

## Xem lại và hoàn tác

- Nhánh thử nghiệm không tự deploy: workflow hiện chỉ deploy khi push `main`.
- Bản cũ nằm nguyên tại `main`/`2cb493a`; chưa merge nên không cần reset hay xóa dữ liệu để quay lại.
- `git switch main` để trở về bản cũ khi working tree sạch.
- `git switch codex/daangn-ui-benchmark` để mở lại bản thử.
- Sau khi đổi nhánh phải build/chạy lại preview để trình duyệt hiển thị đúng source.

## Kiểm chứng

- `flutter analyze`: không có vấn đề.
- `flutter test`: 12 kiểm thử qua, gồm feed mobile, yêu cầu đăng nhập, bộ lọc áp dụng/hủy, tìm kiếm, panel desktop, chọn khu vực và từ chối GPS.
- Build web release thành công.
- Đã xem bản build trong trình duyệt ở desktop 1280×720 và mobile 390×844: tin hiển thị trong màn đầu; panel chi tiết và bảng chọn khu vực mở được.
- GPS thật trên thiết bị, Android APK và luồng gửi SMS chưa được kiểm chứng trong lần này.
