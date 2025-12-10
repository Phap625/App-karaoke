package com.example.karaokeapp.models

// 1. Dữ liệu gửi đi khi đăng nhập
data class LoginRequest(
    val phone: String,
    val password: String
)

// 2. Dữ liệu User nhận về (Thông tin người dùng)
data class User(
    val user_id: String,
    val full_name: String?,
    val role: String?
)

// 3. Dữ liệu phản hồi tổng quát từ Server
data class LoginResponse(
    val status: String,  // "success" hoặc "error"
    val message: String, // Thông báo lỗi hoặc thành công
    val user: User?      // Có thể null nếu đăng nhập thất bại
)

// Dữ liệu gửi đi khi Đăng ký
data class RegisterRequest(
    val phone: String,
    val password: String,
    val full_name: String
)