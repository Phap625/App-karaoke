package com.example.karaokeapp.models

data class RegisterRequest(
    val email: String,
    val username: String,
    val password: String,
    val fullName: String
)

data class LoginRequest(
    val identifier: String,
    val password: String
)

data class LoginResponse(
    val status: String,      // "success" hoặc "error"
    val message: String,     // Thông báo lỗi hoặc thành công
    val user: UserData? = null // Thông tin user (null nếu đăng nhập lỗi)
)

data class UserData(
    val id: Int,
    val email: String,
    val username: String,
    val full_name: String
)

data class CheckEmailRequest(
    val email: String
)

data class CheckEmailResponse(
    val exists: Boolean
)