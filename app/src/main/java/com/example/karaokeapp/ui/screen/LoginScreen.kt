package com.example.karaokeapp.ui.screen

import android.widget.Toast
import androidx.compose.foundation.BorderStroke
import org.json.JSONObject
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.karaokeapp.models.LoginRequest
import com.example.karaokeapp.network.RetrofitClient
import com.example.karaokeapp.utils.TokenManager
import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.launch

@Composable
fun LoginScreen(
    onLoginSuccess: (Boolean) -> Unit,
    onNavigateToRegister: () -> Unit,
    onNavigateToResetPassword: () -> Unit
) {
    var identifier by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var showForgotPassword by remember { mutableStateOf(false) }

    // --- KHAI BÁO BIẾN ---
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val auth = FirebaseAuth.getInstance()
    val tokenManager = remember { TokenManager(context) }

    // Hàm đồng bộ mật khẩu
    fun handleSyncPassword(realEmail: String, pass: String) {
        scope.launch {
            try {
                Toast.makeText(context, "Đang đồng bộ mật khẩu mới...", Toast.LENGTH_SHORT).show()
                val syncRes = RetrofitClient.api.syncPassword(LoginRequest(realEmail, pass))

                if (syncRes.isSuccessful && syncRes.body()?.status == "success") {
                    val body = syncRes.body()
                    val accessToken = body?.accessToken ?: ""
                    val refreshToken = body?.refreshToken ?: ""
                    val role = body?.user?.role ?: "user"

                    if (accessToken.isNotEmpty() && refreshToken.isNotEmpty()) {
                        tokenManager.saveAuthInfo(accessToken, refreshToken, role)
                    }

                    Toast.makeText(context, "Đồng bộ thành công! Đang đăng nhập...", Toast.LENGTH_SHORT).show()
                    onLoginSuccess(true)
                } else {
                    Toast.makeText(context, "Lỗi đồng bộ: ${syncRes.body()?.message}", Toast.LENGTH_SHORT).show()
                    isLoading = false
                }
            } catch (e: Exception) {
                Toast.makeText(context, "Lỗi mạng khi đồng bộ!", Toast.LENGTH_SHORT).show()
                isLoading = false
            }
        }
    }

    Column(
        modifier = Modifier.fillMaxSize().background(Color.White).padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("KARAOKE APP", fontSize = 32.sp, fontWeight = FontWeight.Bold, color = Color(0xFFFF00CC))
        Spacer(modifier = Modifier.height(40.dp))

        OutlinedTextField(
            value = identifier,
            onValueChange = { identifier = it; showForgotPassword = false },
            label = { Text("Email hoặc Tên đăng nhập") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            enabled = !isLoading
        )

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = password,
            onValueChange = { password = it; showForgotPassword = false },
            label = { Text("Mật khẩu") },
            visualTransformation = PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            enabled = !isLoading
        )

        if (showForgotPassword) {
            Spacer(modifier = Modifier.height(8.dp))
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterEnd) {
                TextButton(onClick = { onNavigateToResetPassword() }) {
                    Text("Bạn quên mật khẩu?", color = Color.Red, fontStyle = androidx.compose.ui.text.font.FontStyle.Italic)
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        Button(
            onClick = {
                if (identifier.isNotEmpty() && password.isNotEmpty()) {
                    scope.launch {
                        isLoading = true
                        try {
                            // 1. Gọi Backend
                            val response = RetrofitClient.api.login(LoginRequest(identifier, password))

                            if (response.isSuccessful && response.body()?.status == "success") {
                                val body = response.body()
                                val userResponse = body?.user
                                val role = userResponse?.role ?: "user"
                                val realEmail = userResponse?.email ?: ""

                                val accessToken = body?.accessToken ?: ""
                                val refreshToken = body?.refreshToken ?: ""

                                if (role == "admin" || role == "own") {
                                    Toast.makeText(context, "Vui lòng dùng App Admin!", Toast.LENGTH_LONG).show()
                                    isLoading = false
                                    return@launch
                                }

                                if (realEmail.isNotEmpty()) {
                                    auth.signInWithEmailAndPassword(realEmail, password)
                                        .addOnCompleteListener { task ->
                                            if (task.isSuccessful) {
                                                val user = auth.currentUser
                                                if (user?.isEmailVerified == true) {

                                                    // ===============================================
                                                    // [BẮT ĐẦU] CHÈN LOGIC DỌN DẸP GUEST TẠI ĐÂY
                                                    // ===============================================

                                                    // Lấy thông tin hiện tại (đang là Guest) TRƯỚC khi lưu cái mới
                                                    val currentRole = tokenManager.getUserRole()
                                                    val currentToken = tokenManager.getAccessToken()

                                                    if (currentRole == "guest" && !currentToken.isNullOrEmpty()) {
                                                        // Chạy scope mới để không ảnh hưởng luồng chính
                                                        scope.launch {
                                                            try {
                                                                // Gọi API xóa Guest cũ (Dùng token cũ để xác thực)
                                                                // Lưu ý: Đảm bảo RetrofitClient đã có hàm deleteGuestAccount
                                                                RetrofitClient.api.deleteGuestAccount("Bearer $currentToken")
                                                                android.util.Log.d("CLEANUP", "Đã xóa Guest cũ thành công")
                                                            } catch (e: Exception) {
                                                                e.printStackTrace()
                                                            }
                                                        }
                                                    }
                                                    // ===============================================
                                                    // [KẾT THÚC]
                                                    // ===============================================

                                                    // === SAU ĐÓ MỚI LƯU TOKEN USER MỚI ===
                                                    if (accessToken.isNotEmpty() && refreshToken.isNotEmpty()) {
                                                        tokenManager.saveAuthInfo(accessToken, refreshToken, role)
                                                    }

                                                    Toast.makeText(context, "Đăng nhập thành công!", Toast.LENGTH_SHORT).show()
                                                    onLoginSuccess(true)
                                                } else {
                                                    auth.signOut()
                                                    Toast.makeText(context, "Email chưa xác thực!", Toast.LENGTH_LONG).show()
                                                    user?.sendEmailVerification()
                                                }
                                                isLoading = false
                                            } else {
                                                auth.signOut()
                                                Toast.makeText(context, "Mật khẩu cũ không còn hiệu lực! Vui lòng nhập mật khẩu mới.", Toast.LENGTH_LONG).show()
                                                isLoading = false
                                            }
                                        }
                                } else {
                                    isLoading = false
                                }

                            } else {
                                val errorJsonString = response.errorBody()?.string()
                                val jsonObject = try { JSONObject(errorJsonString) } catch (e: Exception) { JSONObject() }
                                val message = jsonObject.optString("message", "Lỗi")
                                val hintEmail = jsonObject.optString("email", "")

                                if (message.contains("Sai mật khẩu", ignoreCase = true)) {
                                    val emailToCheck = if (identifier.contains("@")) identifier else hintEmail

                                    if (emailToCheck.isNotEmpty()) {
                                        auth.signInWithEmailAndPassword(emailToCheck, password)
                                            .addOnCompleteListener { fbTask ->
                                                if (fbTask.isSuccessful) {
                                                    handleSyncPassword(emailToCheck, password)
                                                } else {
                                                    Toast.makeText(context, "Mật khẩu không đúng!", Toast.LENGTH_SHORT).show()
                                                    showForgotPassword = true
                                                    isLoading = false
                                                }
                                            }
                                    } else {
                                        Toast.makeText(context, "Mật khẩu không đúng!", Toast.LENGTH_SHORT).show()
                                        isLoading = false
                                    }
                                } else if (message.contains("không tồn tại", ignoreCase = true)) {
                                    Toast.makeText(context, "Tài khoản không tồn tại", Toast.LENGTH_SHORT).show()
                                    isLoading = false
                                } else {
                                    Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
                                    isLoading = false
                                }
                            }
                        } catch (e: Exception) {
                            Toast.makeText(context, "Lỗi kết nối Server!", Toast.LENGTH_LONG).show()
                            e.printStackTrace()
                            isLoading = false
                        }
                    }
                } else {
                    Toast.makeText(context, "Vui lòng nhập đủ thông tin", Toast.LENGTH_SHORT).show()
                }
            },
            modifier = Modifier.fillMaxWidth().height(50.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFF00CC)),
            enabled = !isLoading
        ) {
            if (isLoading) CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
            else Text("ĐĂNG NHẬP", fontSize = 16.sp, fontWeight = FontWeight.Bold)
        }

        Spacer(modifier = Modifier.height(12.dp))
        OutlinedButton(
            onClick = {
                scope.launch {
                    val savedToken = tokenManager.getAccessToken()
                    val savedRole = tokenManager.getUserRole()

                    if (!savedToken.isNullOrEmpty() && savedRole == "guest") {
                        Toast.makeText(context, "Dùng lại tài khoản khách cũ", Toast.LENGTH_SHORT).show()
                        onLoginSuccess(true)
                        return@launch
                    }

                    isLoading = true
                    try {
                        Toast.makeText(context, "Đang tạo tài khoản khách mới...", Toast.LENGTH_SHORT).show()
                        val response = RetrofitClient.api.guestLogin()

                        if (response.isSuccessful && response.body()?.status == "success") {
                            val body = response.body()
                            val accessToken = body?.accessToken ?: ""
                            val refreshToken = body?.refreshToken ?: ""
                            val role = "guest"

                            if (accessToken.isNotEmpty() && refreshToken.isNotEmpty()) {
                                tokenManager.saveAuthInfo(accessToken, refreshToken, role)
                            }

                            Toast.makeText(context, "Xin chào Khách mới!", Toast.LENGTH_SHORT).show()
                            onLoginSuccess(true)
                        } else {
                            Toast.makeText(context, "Lỗi: ${response.body()?.message}", Toast.LENGTH_SHORT).show()
                        }
                    } catch (e: Exception) {
                        Toast.makeText(context, "Lỗi kết nối!", Toast.LENGTH_SHORT).show()
                        e.printStackTrace()
                    } finally {
                        isLoading = false
                    }
                }
            },
            modifier = Modifier.fillMaxWidth().height(50.dp),
            border = BorderStroke(1.dp, Color(0xFFFF00CC)),
            colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFFFF00CC)),
            enabled = !isLoading
        ) {
            if (isLoading) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), color = Color(0xFFFF00CC))
            } else {
                Text("HÁT THỬ NGAY (KHÔNG CẦN TÀI KHOẢN)", fontWeight = FontWeight.Bold)
            }
        }
        Spacer(modifier = Modifier.height(24.dp))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
            Text("Chưa có tài khoản? ")
            TextButton(onClick = { onNavigateToRegister() }) {
                Text("Đăng ký ngay", color = Color(0xFFFF00CC), fontWeight = FontWeight.Bold)
            }
        }
    }
}