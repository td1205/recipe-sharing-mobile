# Recipe Sharing Mobile

Ứng dụng Flutter dành cho Android để khám phá, tìm kiếm, lưu và chia sẻ công
thức nấu ăn. Mobile dùng chung REST API, tài khoản và dữ liệu với
[Recipe Sharing Web](https://github.com/td1205/recipe-sharing-web); chỉ Backend
truy cập MySQL.

## Chức năng hiện có

- Trang chủ, danh mục, tìm kiếm, bộ lọc, phân trang và chi tiết công thức.
- Tài khoản: đăng ký, đăng nhập Bearer token, hồ sơ và khôi phục mật khẩu OTP.
- Lưu công thức, đánh giá, bình luận, tag, báo cáo nội dung và CRUD công thức
  theo quyền Backend trả về.
- Gợi ý cá nhân hóa, nấu với nguyên liệu sẵn có, Cooking Mode đồng bộ Socket.IO.
- Tìm kiếm bằng ảnh: chụp/chọn ảnh, gửi Gemini qua Backend, rồi mở Explore với
  từ khóa được nhận diện.

Khả dụng của một tính năng phụ thuộc vào API và cấu hình Backend đang chạy.

## Công nghệ

- Flutter/Dart (`sdk: ^3.13.0`), Material 3.
- Riverpod cho state và dependency injection; GoRouter cho điều hướng.
- Dio cho REST, `flutter_secure_storage` cho Bearer token.
- Camera, Image Picker, Photo Manager, Socket.IO Client.

## Yêu cầu môi trường

- Flutter SDK tương thích với `pubspec.yaml`.
- Android Studio/Android SDK, hoặc một thiết bị Android bật USB debugging.
- Recipe Sharing Web/Backend đang chạy nếu cần dữ liệu thật.

## Cài đặt và chạy

```powershell
git clone https://github.com/td1205/recipe-sharing-mobile.git
cd recipe-sharing-mobile
flutter doctor
flutter pub get
flutter devices
flutter run -d <device-id>
```

Mặc định Android Emulator gọi `http://10.0.2.2:3000`. Với điện thoại thật,
truyền IP LAN có thể truy cập của máy chạy Backend; production phải dùng HTTPS.

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
flutter build apk --debug --dart-define=API_BASE_URL=https://api.example.com
```

Nếu muốn tải ảnh trực tiếp lên Cloudinary, cấu hình cloud name và unsigned upload
preset bằng dart define. Không truyền hoặc commit Cloudinary API secret, Gemini
API key, token hay thông tin database vào ứng dụng.

```powershell
flutter run `
  --dart-define=CLOUDINARY_CLOUD_NAME=<cloud-name> `
  --dart-define=CLOUDINARY_UPLOAD_PRESET=<unsigned-preset>
```

Gemini được gọi từ Backend qua endpoint scan ảnh; Mobile không giữ Gemini API key.

## Kiểm thử và build

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

## Cấu trúc thư mục

```text
lib/
  app/                 # App shell, theme và GoRouter
  core/                # API client, config, token storage, shared providers
  features/
    auth/              # Data, domain và presentation cho tài khoản
    recipes/           # Data, domain, presentation và Cooking Sync
test/                  # Unit và widget tests
```

Chi tiết hệ thống giao diện và kiến trúc được ghi trong [DESIGN.md](DESIGN.md).

## Quy ước Git

- Tạo nhánh từ `main`: `feat/...`, `fix/...`, `docs/...`, `chore/...`.
- Commit theo Conventional Commits: `<type>(<scope>): <mô tả tiếng Việt>`.
- Mỗi PR phải chạy `flutter analyze` và `flutter test` trước khi merge.
- Không commit `.env`, khóa ký, token, cache, build output hoặc screenshot thử nghiệm.
- Giữ [pubspec.lock](pubspec.lock) để cố định dependency của ứng dụng Flutter.
