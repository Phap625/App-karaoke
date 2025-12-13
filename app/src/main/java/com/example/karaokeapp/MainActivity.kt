package com.example.karaokeapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.example.karaokeapp.models.LogoutRequest
import com.example.karaokeapp.network.RetrofitClient
import com.example.karaokeapp.ui.screen.HomeScreen
import com.example.karaokeapp.ui.screen.LoginScreen
import com.example.karaokeapp.ui.screen.RegisterScreen
import com.example.karaokeapp.ui.screen.ResetPasswordScreen
import com.example.karaokeapp.ui.screens.MeScreen
import com.example.karaokeapp.utils.TokenManager
import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 1. Khởi tạo TokenManager và Auth
        val tokenManager = TokenManager(this)
        val auth = FirebaseAuth.getInstance()

        val accessToken = tokenManager.getAccessToken()
        val role = tokenManager.getUserRole()

        // 2. Logic Kiểm tra trạng thái đăng nhập
        val isLoggedIn = if (accessToken != null) {
            if (role == "guest") {
                true
            } else {
                auth.currentUser != null
            }
        } else {
            false
        }

        // 3. Xác định màn hình bắt đầu
        val startDest = if (isLoggedIn) "home" else "login"

        setContent {
            val navController = rememberNavController()

            // --- HÀM XỬ LÝ ĐĂNG XUẤT DÙNG CHUNG ---
            fun handleLogout() {
                // Bước 1: Lấy Refresh Token đang lưu để gửi lên server
                val refreshToken = tokenManager.getRefreshToken()

                // Bước 2: Gọi API xóa token trên Server
                if (refreshToken != null) {
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            // Gọi API logout, không cần chờ kết quả trả về
                            RetrofitClient.api.logout(LogoutRequest(refreshToken))
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }

                // Bước 3: Xóa dữ liệu local & Firebase ngay lập tức
                tokenManager.clearAuth()
                auth.signOut()

                // Bước 4: Chuyển về màn hình đăng nhập và xóa lịch sử back
                navController.navigate("login") {
                    popUpTo(0) { inclusive = true }
                }
            }
            // ----------------------------------------

            NavHost(navController = navController, startDestination = startDest) {

                // Màn hình Login
                composable("login") {
                    LoginScreen(
                        onLoginSuccess = { isSuccess ->
                            // isSuccess = true (User thật/Guest) -> Vào Home
                            if (isSuccess) {
                                navController.navigate("home") {
                                    popUpTo("login") { inclusive = true }
                                }
                            }
                        },
                        onNavigateToRegister = {
                            navController.navigate("register")
                        },
                        onNavigateToResetPassword = {
                            navController.navigate("reset_password")
                        }
                    )
                }

                // Màn hình Home
                composable("home") {
                    HomeScreen(
                        onLogout = {
                            val currentRole = tokenManager.getUserRole()

                            if (currentRole == "guest") {
                                navController.navigate("login")
                            } else {
                                handleLogout()
                            }
                        }
                    )
                }

                // Màn hình Register
                composable("register") {
                    RegisterScreen(
                        onRegisterSuccess = {
                            navController.navigate("login") {
                                popUpTo("register") { inclusive = true }
                            }
                        },
                        onBackClick = {
                            navController.popBackStack()
                        }
                    )
                }

                // Màn hình Reset Password
                composable("reset_password") {
                    ResetPasswordScreen(
                        onBackClick = {
                            navController.popBackStack()
                        }
                    )
                }

                // Màn hình Me (Cá nhân)

                composable("me_screen") {
                    MeScreen(
                        onLogoutClick = {
                            // Lấy role hiện tại của người dùng
                            val currentRole = tokenManager.getUserRole()

                            if (currentRole == "guest") {
                                navController.navigate("login")
                            } else {
                                handleLogout()
                            }
                        }
                    )
                }
            }
        }
    }
}