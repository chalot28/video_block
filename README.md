# Video Block

## Giới thiệu

Video Block là một ứng dụng đa nền tảng được phát triển bằng Flutter, tập trung tối ưu hóa trải nghiệm người dùng trên hệ điều hành Windows. Ứng dụng kết hợp một trình phát video mạnh mẽ và một trình duyệt web tích hợp, cung cấp giải pháp toàn diện cho việc tiêu thụ nội dung số mà không bị làm phiền bởi quảng cáo.

## Tính năng

### Trình phát Video
*   **Hỗ trợ đa nguồn:** Khả năng phát video từ các đường dẫn mạng (URL) hỗ trợ các định dạng phổ biến như MP4, HLS, cũng như phát các tập tin video được lưu trữ cục bộ trên thiết bị.
*   **Hệ thống chặn quảng cáo:** Tích hợp bộ lọc quảng cáo tự động, đảm bảo trải nghiệm xem video liền mạch.
*   **Chế độ Picture-in-Picture (PiP):** Cho phép người dùng xem video trong một cửa sổ thu nhỏ riêng biệt, hỗ trợ đa nhiệm hiệu quả.
*   **Điều khiển toàn diện:** Cung cấp đầy đủ các chức năng điều khiển như phát/tạm dừng, điều chỉnh âm lượng, tua video và chế độ toàn màn hình.

### Trình duyệt Web
*   **Công nghệ lõi:** Sử dụng nhân Microsoft Edge WebView2 (trên Windows) thông qua thư viện `flutter_inappwebview`, mang lại hiệu suất duyệt web cao và độ tương thích tốt với các tiêu chuẩn web hiện đại.
*   **Quản lý thẻ (Tab):** Giao diện duyệt web theo thẻ, cho phép mở và quản lý nhiều trang web đồng thời.
*   **Thanh địa chỉ thông minh:** Tự động nhận diện URL hoặc thực hiện tìm kiếm thông qua các công cụ tìm kiếm phổ biến (Google, Bing, DuckDuckGo).
*   **Tiện ích mở rộng:** Tích hợp sẵn tính năng chặn quảng cáo và công cụ dịch thuật trang web.

## Yêu cầu hệ thống

*   **Hệ điều hành:** Windows 10 hoặc Windows 11 (Yêu cầu Microsoft Edge WebView2 Runtime).
*   **Flutter SDK:** Phiên bản 3.10.1 trở lên.

## Cài đặt và Triển khai

### Thiết lập môi trường

1.  Đảm bảo Flutter SDK đã được cài đặt và cấu hình biến môi trường.
2.  Tại thư mục gốc của dự án, cài đặt các gói phụ thuộc:
   ```bash
   flutter pub get
   ```

### Chạy ứng dụng (Debug)

Để khởi chạy ứng dụng trong quá trình phát triển:
   ```bash
   flutter run -d windows
   ```

### Xây dựng bản phát hành (Release)

Để tạo tập tin thực thi cho Windows:
   ```bash
   flutter build windows --release
   ```

### Tạo bộ cài đặt (Installer)

Dự án bao gồm kịch bản tự động để tạo bộ cài đặt EXE (yêu cầu cài đặt Inno Setup):
   ```powershell
   .\scripts\build_exe_installer.ps1
   ```

## Cấu trúc dự án

*   **lib/main.dart:** Điểm khởi chạy của ứng dụng, chịu trách nhiệm khởi tạo môi trường WebView2 và giao diện chính.
*   **lib/browser/**: Chứa mã nguồn liên quan đến trình duyệt web, bao gồm quản lý tab và giao diện người dùng.
*   **lib/player/**: Chứa mã nguồn của trình phát video, các nút điều khiển và logic xử lý PiP.
*   **lib/services/**: Các dịch vụ nền tảng như `AdBlockService` và `VideoService`.
*   **scripts/**: Các kịch bản hỗ trợ xây dựng và đóng gói ứng dụng.

## Thư viện chính

*   `flutter_inappwebview`: Cung cấp khả năng nhúng trình duyệt web.
*   `video_player`: Hỗ trợ phát lại video.
*   `file_picker`: Cho phép chọn tập tin từ hệ thống.
*   `window_manager`: Quản lý kích thước và trạng thái cửa sổ ứng dụng trên Desktop.
*   `path_provider`: Cung cấp quyền truy cập vào các đường dẫn thư mục hệ thống.

## Khắc phục sự cố

### Lỗi hiển thị màn hình trắng hoặc đen
*   **Nguyên nhân:** Môi trường Microsoft Edge WebView2 Runtime chưa được cài đặt hoặc phiên bản hiện tại đã lỗi thời.
*   **Giải pháp:** Tải xuống và cài đặt "WebView2 Evergreen Bootstrapper" từ trang chủ Microsoft Developer. Khởi động lại ứng dụng sau khi cài đặt.

### Video không phát được hoặc báo lỗi tải
*   **Nguyên nhân:** Định dạng video không được hỗ trợ (codec không tương thích) hoặc đường dẫn (URL) bị chặn bởi cơ chế CORS hoặc Ad-block.
*   **Giải pháp:**
    1. Kiểm tra định dạng video (Khuyến nghị sử dụng MP4 H.264).
    2. Tắt tạm thời tính năng chặn quảng cáo trong giao diện trình phát.
    3. Kiểm tra kết nối mạng.

## Quy trình phát triển

Dự án tuân thủ nghiêm ngặt các quy chuẩn lập trình của Flutter. Trước khi gửi yêu cầu gộp mã (Pull Request), vui lòng thực hiện các bước kiểm tra sau:

1.  **Phân tích tĩnh:** Đảm bảo không có lỗi hoặc cảnh báo từ bộ linter.
    ```bash
    flutter analyze
    ```
2.  **Định dạng mã nguồn:** Tự động định dạng lại mã nguồn theo chuẩn Dart.
    ```bash
    dart format .
    ```
