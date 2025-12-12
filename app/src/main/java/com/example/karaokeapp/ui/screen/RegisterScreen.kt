package com.example.karaokeapp.ui.screen

import android.widget.Toast
import org.json.JSONObject // Import cái này để parse lỗi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.karaokeapp.models.RegisterRequest
import com.example.karaokeapp.network.RetrofitClient
import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RegisterScreen(
    onRegisterSuccess: () -> Unit,
    onBackClick: () -> Unit
) {
    var email by remember { mutableStateOf("") }
    var username by remember { mutableStateOf("") }
    var fullName by remember { mutableStateOf(TextFieldValue("")) }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }

    val auth = FirebaseAuth.getInstance()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val scrollState = rememberScrollState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
            .padding(24.dp)
            .verticalScroll(scrollState),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("ĐĂNG KÝ TÀI KHOẢN", fontSize = 26.sp, fontWeight = FontWeight.Bold, color = Color(0xFFFF00CC))
        Spacer(modifier = Modifier.height(24.dp))

        // ... (GIỮ NGUYÊN CÁC TEXT FIELD NHƯ CŨ) ...
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("Email") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            modifier = Modifier.fillMaxWidth(),
            enabled = !isLoading
        )
        Spacer(modifier = Modifier.height(12.dp))

        OutlinedTextField(
            value = username,
            onValueChange = { username = it },
            label = { Text("Tên đăng nhập (viết liền)") },
            modifier = Modifier.fillMaxWidth(),
            enabled = !isLoading
        )
        Spacer(modifier = Modifier.height(12.dp))

        OutlinedTextField(
            value = fullName,
            onValueChange = { fullName = it },
            label = { Text("Họ và tên") },
            modifier = Modifier.fillMaxWidth(),
            enabled = !isLoading
        )
        Spacer(modifier = Modifier.height(12.dp))

        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Mật khẩu") },
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth(),
            enabled = !isLoading
        )
        Spacer(modifier = Modifier.height(12.dp))

        OutlinedTextField(
            value = confirmPassword,
            onValueChange = { confirmPassword = it },
            label = { Text("Nhập lại mật khẩu") },
            visualTransformation = PasswordVisualTransformation(),
            isError = (confirmPassword.isNotEmpty() && confirmPassword != password),
            modifier = Modifier.fillMaxWidth(),
            enabled = !isLoading
        )

        Spacer(modifier = Modifier.height(24.dp))

        // --- NÚT ĐĂNG KÝ (LOGIC CHÍNH ĐÃ SỬA) ---
        Button(
            onClick = {
                if (password != confirmPassword) {
                    Toast.makeText(context, "Mật khẩu xác nhận không khớp!", Toast.LENGTH_SHORT).show()
                    return@Button
                }

                if (email.isNotEmpty() && username.isNotEmpty() && password.isNotEmpty() && fullName.text.isNotEmpty()) {
                    isLoading = true

                    // BƯỚC 1: Tạo User Firebase
                    auth.createUserWithEmailAndPassword(email, password)
                        .addOnCompleteListener { task ->
                            if (task.isSuccessful) {
                                val user = auth.currentUser

                                // Gửi email xác thực (chạy ngầm, không cần chờ)
                                user?.sendEmailVerification()

                                // BƯỚC 2: Gọi Backend
                                scope.launch {
                                    try {
                                        // Lưu ý: Đảm bảo DataModels.kt dùng @SerializedName("full_name") cho fullName
                                        val request = RegisterRequest(email, username, password, fullName.text)
                                        val res = RetrofitClient.api.register(request)

                                        if (res.isSuccessful && res.body()?.status == "success") {
                                            // THÀNH CÔNG
                                            Toast.makeText(context, "Đăng ký thành công! Đã gửi mail xác thực.", Toast.LENGTH_LONG).show()
                                            onRegisterSuccess()
                                        } else {
                                            // THẤT BẠI TỪ SERVER (Backend trả về lỗi)
                                            // Xử lý lỗi null: Đọc từ errorBody
                                            val errorJsonString = res.errorBody()?.string()
                                            val message = try {
                                                JSONObject(errorJsonString).getString("message")
                                            } catch (e: Exception) {
                                                "Lỗi máy chủ: ${res.code()}"
                                            }

                                            // Xóa user Firebase để rollback
                                            user?.delete()
                                            Toast.makeText(context, message, Toast.LENGTH_LONG).show()
                                        }
                                    } catch (e: Exception) {
                                        // LỖI MẠNG / CRASH APP
                                        user?.delete()
                                        e.printStackTrace()
                                        Toast.makeText(context, "Lỗi kết nối: ${e.message}", Toast.LENGTH_SHORT).show()
                                    } finally {
                                        isLoading = false
                                    }
                                }
                            } else {
                                // Lỗi từ Firebase (Email trùng, pass yếu...)
                                val errorMsg = task.exception?.message ?: "Lỗi đăng ký Firebase"
                                // Dịch một số lỗi phổ biến
                                val finalMsg = when {
                                    errorMsg.contains("email address is already in use") -> "Email này đã được đăng ký!"
                                    errorMsg.contains("Password should be at least") -> "Mật khẩu phải từ 6 ký tự!"
                                    else -> errorMsg
                                }
                                Toast.makeText(context, finalMsg, Toast.LENGTH_LONG).show()
                                isLoading = false
                            }
                        }
                } else {
                    Toast.makeText(context, "Vui lòng nhập đầy đủ thông tin", Toast.LENGTH_SHORT).show()
                }
            },
            modifier = Modifier.fillMaxWidth().height(50.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFF00CC)),
            enabled = !isLoading
        ) {
            if (isLoading) {
                CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
            } else {
                Text("ĐĂNG KÝ")
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        TextButton(onClick = { onBackClick() }) {
            Text("Quay lại Đăng nhập", color = Color.Gray)
        }
    }
}