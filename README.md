# Recipe Sharing Mobile

Ứng dụng chia sẻ và khám phá công thức nấu ăn trên Android, phát triển bằng **Flutter (Dart)** cho đồ án môn **Lập trình cho thiết bị di động**.

> **Trạng thái:** Đã khởi tạo dự án Flutter; các chức năng nghiệp vụ và kết nối API **chưa triển khai**.

## Mục tiêu

- Xem và tìm kiếm công thức nấu ăn.
- Xem nguyên liệu và các bước chế biến.
- Hỗ trợ tài khoản và đăng công thức khi tích hợp Backend.
- Mở rộng về yêu thích, đánh giá và gợi ý công thức sau khi hoàn thiện các chức năng cốt lõi.

Các mục tiêu trên là **kế hoạch**, không phải danh sách tính năng đã hoàn thành.

## Công nghệ và kiến trúc

- **Mobile:** Flutter, Dart; ưu tiên Android.
- **Backend dự kiến dùng chung:** Node.js / Express của dự án Recipe Sharing Web.
- **Cơ sở dữ liệu:** MySQL do Backend quản lý; ứng dụng Flutter không truy cập MySQL trực tiếp.
- **Trao đổi dữ liệu:** REST API trả về JSON, cần kiểm tra và xây dựng các endpoint phù hợp.

```text
recipe-sharing-mobile (Flutter) --HTTP/JSON--> recipe-sharing-web (Express) --> MySQL
```

Repository Mobile và Web có lịch sử Git độc lập. Mã Backend không thuộc repository này.

## Yêu cầu môi trường

- Flutter SDK và Dart tương thích với `pubspec.yaml`.
- Android Studio với Android SDK, Android Emulator (hoặc điện thoại Android).
- VS Code với extension Flutter và Dart hoặc Android Studio.

Kiểm tra công cụ:

```powershell
flutter doctor
flutter doctor --android-licenses
```

## Chạy dự án

```powershell
git clone https://github.com/td1205/recipe-sharing-mobile.git
cd recipe-sharing-mobile
flutter pub get
flutter run
```

Để kiểm tra chất lượng:

```powershell
flutter analyze
flutter test
```

> Khi Backend được tích hợp trong các giai đoạn sau: Android Emulator thường truy cập Backend chạy trên máy chủ phát triển qua `http://10.0.2.2:3000` nếu máy chủ lắng nghe phù hợp; điện thoại thật dùng địa chỉ IP mạng LAN hoặc địa chỉ máy chủ triển khai. Hiện tại chưa cấu hình API này trong ứng dụng.

## Quy trình phát triển

Dự án sử dụng **GitHub Flow**:

1. Tạo GitHub Issue ghi nhận yêu cầu.
2. Tạo branch riêng từ `main` (`feat/...`, `fix/...`, `docs/...`).
3. Phát triển, kiểm thử, commit theo **Conventional Commits** với mô tả tiếng Việt.
4. Tạo Pull Request, kiểm tra thay đổi và merge vào `main`.

Chi tiết: [CONTRIBUTING.md](CONTRIBUTING.md).

## Tài liệu

- [Flutter Documentation](https://docs.flutter.dev/)
- [GitHub Flow](https://docs.github.com/en/get-started/using-github/github-flow)
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
