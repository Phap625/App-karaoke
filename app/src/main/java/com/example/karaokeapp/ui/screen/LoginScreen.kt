package com.example.karaokeapp.ui.screen

import android.widget.Toast
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.karaokeapp.models.LoginRequest
import com.example.karaokeapp.network.RetrofitClient
import kotlinx.coroutines.launch

@Composable
fun LoginScreen(
    onLoginSuccess: () -> Unit,
    onNavigateToRegister: () -> Unit,
    onNavigateToResetPassword: () -> Unit // 1. Thêm callback chuyển trang quên mật khẩu
) {
    var phone by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }

    // 2. Biến trạng thái để hiện nút Quên mật khẩu
    var showForgotPassword by remember { mutableStateOf(false) }

    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "KARAOKE APP",
            fontSize = 32.sp,
            fontWeight = FontWeight.Bold,
            color = Color(0xFFFF00CC)
        )

        Spacer(modifier = Modifier.height(40.dp))

        OutlinedTextField(
            value = phone,
            onValueChange = {
                phone = it
                showForgotPassword = false // Ẩn nút quên pass khi user sửa lại sđt
            },
            label = { Text("Số điện thoại") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = password,
            onValueChange = {
                password = it
                showForgotPassword = false // Ẩn nút quên pass khi user sửa lại pass
            },
            label = { Text("Mật khẩu") },
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        // 3. Hiển thị nút Quên mật khẩu nếu nhập sai pass
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
                if (phone.isNotEmpty() && password.isNotEmpty()) {
                    scope.launch {
                        isLoading = true
                        try {
                            val response = RetrofitClient.api.login(LoginRequest(phone, password))

                            if (response.isSuccessful && response.body()?.status == "success") {
                                Toast.makeText(context, "Đăng nhập thành công!", Toast.LENGTH_SHORT).show()
                                onLoginSuccess()
                            } else {
                                val errorJsonString = response.errorBody()?.string()
                                val message = try {
                                    JSONObject(errorJsonString).getString("message")
                                } catch (e: Exception) {
                                    "Lỗi không xác định"
                                }

                                // 2. So sánh chuỗi message trả về từ server
                                if (message.contains("Sai mật khẩu", ignoreCase = true)) {
                                    // -> Hiện nút Quên mật khẩu
                                    Toast.makeText(context, "Mật khẩu không đúng!", Toast.LENGTH_SHORT).show()
                                    showForgotPassword = true

                                } else if (message.contains("không tồn tại", ignoreCase = true)) {
                                    // -> SĐT chưa đăng ký -> Ẩn nút quên pass
                                    Toast.makeText(context, "Số điện thoại chưa đăng ký tài khoản", Toast.LENGTH_SHORT).show()
                                    showForgotPassword = false

                                } else {
                                    // -> Lỗi khác
                                    Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
                                }
                            }
                        } catch (e: Exception) {
                            Toast.makeText(context, "Không thể kết nối Server!", Toast.LENGTH_LONG).show()
                            e.printStackTrace()
                        } finally {
                            isLoading = false
                        }
                    }
                } else {
                    Toast.makeText(context, "Vui lòng nhập đủ thông tin", Toast.LENGTH_SHORT).show()
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(50.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFF00CC)),
            enabled = !isLoading
        ) {
            if (isLoading) {
                CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
            } else {
                Text(text = "ĐĂNG NHẬP", fontSize = 16.sp, fontWeight = FontWeight.Bold)
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Text(text = "Chưa có tài khoản? ")
            TextButton(onClick = {
                onNavigateToRegister()
            }) {
                Text(text = "Đăng ký ngay", color = Color(0xFFFF00CC), fontWeight = FontWeight.Bold)
            }
        }
    }
}