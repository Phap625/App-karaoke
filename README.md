# 🎤 Karaoke App Backend Server 

## **🚀 Thông tin Server (Deployment)**

Server hiện tại đã được deploy lên Render và Database được host trên Supabase.

**Base URL (Dùng cho Retrofit/App):**
    
https://karaoke-server-paan.onrender.com/
    
**Trạng thái Server:**  Server chạy trên gói Free của Render.
    
⚠️ Lưu ý quan trọng: Nếu sau 15 phút không có request nào, server sẽ rơi vào trạng thái "Ngủ đông" (Spin down). Lần gọi API đầu tiên sau đó có thể bị lỗi server, phải gọi 2-3 lần để server khởi động lại. Các request sau sẽ nhanh bình thường.

## 🗄️ Cấu trúc Database (Supabase)

Dưới đây là thiết kế các bảng dữ liệu (Tables) trong PostgreSQL.
### 1. Bảng users

   Lưu trữ thông tin tài khoản sau khi xác thực OTP thành công.

        Tên cột      Kiểu dữ liệu        Ràng buộc                   Mô tả
        id           SERIAL (Int)        PRIMARY KEY                 ID tự tăng
        phone        VARCHAR(15)         UNIQUE, NOT NULL            Số điện thoại (dùng làm định danh chính)
        full_name    VARCHAR(100)        NOT NULL                    Họ và tên hiển thị
        password     VARCHAR(255)        NOT NULL                    Mật khẩu đăng nhập (Đã hash)
        created_at   TIMESTAMP           DEFAULT NOW()               Thời gian tạo tài khoản
### 2. Bảng songs (Dự kiến)

   Danh sách các bài hát Karaoke.

        Tên cột          Kiểu dữ liệu            Mô tả
        id               SERIAL                  ID bài hát
        title            VARCHAR(255)            Tên bài hát
        artist           VARCHAR(255)            Tên ca sĩ
        image_url        TEXT                    Link ảnh bìa bài hát
        video_url        TEXT                    Link video Karaoke (Youtube/Mp4)
        lyrics           TEXT                    Lời bài hát (nếu cần)

## 🔌 API Documentation (Danh sách API)

Dưới đây là các Endpoints mà Mobile App cần gọi. Header mặc định: Content-Type: application/json

### 1. Đăng ký tài khoản (Register)

Được gọi sau khi người dùng đã xác thực OTP thành công trên App.

Endpoint: **POST /register**

Body (Request):

    {
    "phone": "0987654321",
    "password": "matkhau123",
    "fullName": "Nguyen Van A"
    }

### 2. Đăng nhập (Login)

Dùng để vào App sau khi đã có tài khoản.

Endpoint: **POST /login**

Body (Request):

    {
    "phone": "0987654321",
    "password": "matkhau123"
    }