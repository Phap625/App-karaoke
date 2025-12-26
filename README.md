# **Karaoke Entertainment Plus**

## Yêu cầu môi trường (Prerequisites)
Để chạy dự án này, máy tính của bạn BẮT BUỘC phải có:
1. **Flutter SDK:** Phiên bản Stable mới nhất (>= 3.24.x).
    - Kiểm tra bằng lệnh: `flutter --version`
2. **Java JDK:** Phiên bản 17 (Bắt buộc cho Android Gradle Plugin mới).
    - Kiểm tra bằng lệnh: `java -version`
    - Nếu chưa có, hãy cài đặt OpenJDK 17.

## Cách chạy dự án (Quick Start)
Dự án đã được cấu hình sẵn script tự động.

1. Clone dự án về máy:

        git clone https://github.com/Phap625/App-karaoke.git
2. Chạy máy ảo.

3. Chạy file `setup.bat` (trên Windows) để cài đặt và khởi động bằng lệnh:

        .\setup.bat

4. Fix lỗi(nếu có) bằng lệnh:

        https://gemini.google.com


%% Định nghĩa các Style %%
classDef actor fill:#f9f,stroke:#333,stroke-width:2px;
classDef frontend fill:#d4edda,stroke:#28a745,stroke-width:2px;
classDef backend fill:#cce5ff,stroke:#007bff,stroke-width:2px;
classDef db fill:#fff3cd,stroke:#ffc107,stroke-width:2px;
classDef storage fill:#e2e3e5,stroke:#6c757d,stroke-width:2px;

    %% Subgraph: Người dùng %%
    subgraph Users [Người dùng]
        AdminUser(🧑‍💼 Admin):::actor
        EndUser(👤 User / Người nghe):::actor
    end

    %% Subgraph: Phía Client/Frontend %%
    subgraph FrontendApp [Frontend Applications]
        AdminPanel[🖥️ Admin Web Panel\n(Quản lý nhạc, users)]:::frontend
        PublicPages[📄 Public Pages\n(Welcome, Policy, Support)]:::frontend
        MobileApp[📱 Mobile App (Flutter)]:::frontend
    end

    %% Subgraph: Backend %%
    subgraph BackendServer [Backend Server (Node.js/Express)]
        API[⚙️ RESTful API\n(Xử lý logic, xác thực)]:::backend
        WebServer[🕸️ Web Server Route\n(Phục vụ trang tĩnh)]:::backend
    end

    %% Subgraph: Dịch vụ bên ngoài %%
    subgraph ExternalServices [Dịch vụ Lưu trữ & DB]
        Supabase[(🗄️ Supabase\nDatabase & Auth)]:::db
        Cloudflare[☁️ Cloudflare R2\n(Lưu MP3, Ảnh)]:::storage
    end

    %% --- Các luồng kết nối --- %%

    %% Luồng Admin
    AdminUser -->|Đăng nhập & Quản lý| AdminPanel
    AdminPanel -->|Gọi API (Thêm/Sửa/Xóa)| API
    API -->|Xác thực Admin & Ghi dữ liệu| Supabase
    API -->|Upload file MP3/Ảnh| Cloudflare

    %% Luồng Public Pages (User truy cập web)
    EndUser -->|Truy cập trình duyệt| PublicPages
    PublicPages -->|Request nội dung HTML| WebServer
    WebServer -.->|Lấy dữ liệu nếu cần| Supabase

    %% Luồng Mobile App (User dùng app)
    EndUser -->|Sử dụng App nghe nhạc| MobileApp
    MobileApp -->|Gọi API (Lấy danh sách, Login)| API
    API -->|Xác thực User & Đọc dữ liệu| Supabase
    
    %% Luồng tải file media (Quan trọng)
    MobileApp -.->|Tải file MP3/Ảnh trực tiếp qua URL| Cloudflare
    AdminPanel -.->|Hiển thị ảnh preview| Cloudflare

    %% Chú thích
    linkStyle 11,12 stroke:orange,stroke-width:2px,fill:none;
