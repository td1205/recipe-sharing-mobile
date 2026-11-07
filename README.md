# Recipe Sharing Mobile

Ứng dụng Flutter (Dart) chia sẻ và khám phá công thức nấu ăn, ưu tiên Android.
Hiện mới có ứng dụng mẫu; chưa triển khai chức năng nghiệp vụ hoặc kết nối API.

## Công nghệ và phạm vi

- Flutter, Dart SDK `^3.13.0` (xem [pubspec.yaml](pubspec.yaml)).
- Dự kiến dùng chung Backend Node.js/Express, MySQL và tài khoản với [Recipe Sharing Web](https://github.com/td1205/recipe-sharing-web).
- Flutter gọi REST API JSON; chỉ Backend truy cập MySQL. Hai repository có lịch sử Git độc lập.
- Kế hoạch: danh sách/tìm kiếm → chi tiết → tài khoản → yêu thích/đánh giá/bình luận → đăng công thức → gợi ý.

## Chạy và kiểm tra

Cài Flutter SDK tương thích, Android Studio/Android SDK và tạo Android Emulator
(hoặc kết nối điện thoại bật USB debugging).

```powershell
git clone https://github.com/td1205/recipe-sharing-mobile.git
cd recipe-sharing-mobile
flutter doctor
flutter doctor --android-licenses
flutter pub get
flutter devices
flutter run -d <device-id>
```

```powershell
flutter analyze
flutter test
```

Khi tích hợp API: Android Emulator dùng `http://10.0.2.2:3000`, điện thoại thật
dùng IP LAN của máy chạy Backend hoặc URL triển khai. Backend cần lắng nghe trên
địa chỉ phù hợp và được firewall cho phép. Hiện ứng dụng chưa có cấu hình API;
bản phát hành dùng HTTPS.

## Quy ước Git

- Tạo nhánh từ `main`: `feat/...`, `fix/...`, `docs/...`, `chore/...`.
- Commit theo Conventional Commits: `<type>(<scope>): <mô tả tiếng Việt>`;
  scope tùy chọn. Ví dụ: `feat(recipe): Hiển thị danh sách công thức`.
- Mỗi commit tập trung một thay đổi; mở PR về `main`, xem diff và kiểm tra phù hợp
  trước khi merge. Với thay đổi mã Flutter, chạy analyze và test ở trên.
- Issue dùng khi cần ghi nhớ công việc; không bắt buộc template hay Project.
- Không commit mật khẩu, token, `.env`, khóa ký ứng dụng hoặc file build.
  Giữ [pubspec.lock](pubspec.lock) để cố định dependency của ứng dụng.
