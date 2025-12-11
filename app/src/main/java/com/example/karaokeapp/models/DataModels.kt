package com.example.karaokeapp.models

// 1. Dữ liệu gửi đi khi đăng nhập
data class LoginRequest(
    val phone: String,
    val password: String
)

// 2. Dữ liệu User nhận về
data class User(
    val user_id: String,
    val full_name: String?,
    val role: String?
)

// 3. Dữ liệu phản hồi tổng quát từ Server
data class LoginResponse(
    val status: String,
    val message: String,
    val user: User?
)

// Dữ liệu gửi đi khi Đăng ký
data class RegisterRequest(
    val phone: String,
    val password: String,
    val full_name: String
)