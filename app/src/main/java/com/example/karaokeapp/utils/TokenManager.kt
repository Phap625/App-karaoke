package com.example.karaokeapp.utils

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys

class TokenManager(context: Context) {

    private val prefs: SharedPreferences by lazy {
        // 1. Tạo hoặc lấy Master Key (Chìa khóa tổng)
        // MasterKeys.AES256_GCM_SPEC là chuẩn bảo mật cao nhất hiện tại
        val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)

        // 2. Khởi tạo EncryptedSharedPreferences
        EncryptedSharedPreferences.create(
            "karaoke_secure_prefs", // Tên file lưu trữ
            masterKeyAlias,
            context,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV, // Mã hóa tên biến (Key)
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM  // Mã hóa giá trị (Value)
        )
    }

    companion object {
        const val KEY_ACCESS_TOKEN = "access_token"
        const val KEY_REFRESH_TOKEN = "refresh_token"
        const val KEY_USER_ROLE = "user_role"
    }

    // --- CÁC HÀM LƯU / LẤY / XÓA ---

    // 1. Lưu thông tin đăng nhập
    fun saveAuthInfo(accessToken: String, refreshToken: String, role: String) {
        val editor = prefs.edit()
        editor.putString(KEY_ACCESS_TOKEN, accessToken)
        editor.putString(KEY_REFRESH_TOKEN, refreshToken)
        editor.putString(KEY_USER_ROLE, role)
        editor.apply() // Lưu bất đồng bộ (nhanh hơn commit)
    }

    // 2. Lấy Access Token
    fun getAccessToken(): String? {
        return prefs.getString(KEY_ACCESS_TOKEN, null)
    }

    // 3. Lấy Refresh Token
    fun getRefreshToken(): String? {
        return prefs.getString(KEY_REFRESH_TOKEN, null)
    }

    // 4. Lấy Role (admin/user/own)
    fun getUserRole(): String? {
        return prefs.getString(KEY_USER_ROLE, null)
    }

    // 5. Xóa hết (Dùng khi Đăng xuất)
    fun clearAuth() {
        val editor = prefs.edit()
        editor.clear()
        editor.apply()
    }
}