# Quy trình đóng góp

Dự án **Recipe Sharing Mobile** áp dụng GitHub Flow. Mọi chức năng hoặc sửa lỗi nên có Issue tương ứng.

## Quy trình phát triển
1. Tạo Issue mô tả mục tiêu, công việc và tiêu chí hoàn thành.
2. Tạo nhánh mới từ `main` theo dạng `feat/<ten-tinh-nang>`, `fix/<ten-loi>`, `chore/<cong-viec>` hoặc `docs/<noi-dung>`.
3. Thực hiện những thay đổi liên quan đến Issue; không đưa thông tin bí mật vào repository.
4. Trước khi mở Pull Request, chạy `flutter pub get`, `flutter analyze`, `flutter test`.
5. Tạo Pull Request tới `main`, mô tả thay đổi và gắn Issue bằng `Closes #<so-issue>` khi thích hợp.
6. Kiểm tra diff, kết quả kiểm thử và hợp nhất khi đạt yêu cầu. Xóa nhánh tính năng sau khi merge.

## Quy ước commit

Sử dụng [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) với **mô tả bằng tiếng Việt**, giữ nguyên tên loại commit bằng tiếng Anh:

```text
<type>(<scope>): <mô tả tiếng Việt>
```

Các loại thường dùng:
- `feat`: Thêm tính năng mới.
- `fix`: Sửa lỗi.
- `docs`: Cập nhật tài liệu.
- `refactor`: Tái cấu trúc không thay đổi hành vi.
- `test`: Bổ sung hoặc sửa kiểm thử.
- `ci`: Cập nhật kiểm thử tự động.
- `chore`: Công việc bảo trì hoặc thiết lập.

Ví dụ:
```text
feat(recipe): Hiển thị danh sách công thức từ API
fix(auth): Sửa lỗi duy trì phiên đăng nhập
docs: Bổ sung hướng dẫn chạy Android Emulator
chore: Chuẩn hóa cấu trúc dự án Flutter
```

Viết tiêu đề commit ngắn, thể hiện chính xác thay đổi; không dùng các thông điệp mơ hồ như `update`, `fix bug`, `sửa code`. Tách commit theo thay đổi logic, không trộn nhiều chức năng.

## Phạm vi repository
Repository này chỉ chứa mã nguồn **Flutter Mobile**. Backend Node.js/Express và cơ sở dữ liệu MySQL thuộc dự án Web riêng. Mobile giao tiếp với Backend qua REST API, không kết nối MySQL trực tiếp.

Không commit file `.env`, token, khóa riêng, mật khẩu, keystore ký ứng dụng hoặc các tệp được sinh ra khi build.
