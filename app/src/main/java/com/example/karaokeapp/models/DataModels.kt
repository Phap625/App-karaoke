package com.example.karaokeapp.models

import com.google.gson.annotations.SerializedName

data class RegisterRequest(
    val email: String,
    val username: String,
    val password: String,
    @SerializedName("full_name") val fullName: String
)

data class LoginRequest(
    val identifier: String,
    val password: String
)

data class CheckEmailRequest(
    val email: String
)

data class LoginResponse(
    val status: String,
    val message: String,
    val user: UserData? = null,

    // Thêm 2 cái này để hứng Token
    @SerializedName("access_token") val accessToken: String? = null,
    @SerializedName("refresh_token") val refreshToken: String? = null
)

data class UserData(
    val id: Int,
    val email: String,
    val username: String,

    @SerializedName("full_name") val fullName: String,
    val role: String,
    @SerializedName("avatar_url") val avatarUrl: String? = null,
    val bio: String? = null
)

data class CheckEmailResponse(
    val status: String,
    val message: String,
    val exists: Boolean,
    val role: String? = null
)

data class LogoutRequest(
    @SerializedName("refresh_token") val refreshToken: String
)