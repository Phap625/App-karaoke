package com.example.karaokeapp.ui.screen

import android.widget.Toast
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.karaokeapp.models.CheckEmailRequest
import com.example.karaokeapp.network.RetrofitClient
import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.launch

@Composable
fun ResetPasswordScreen(
    onBackClick: () -> Unit
) {
    var email by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var isEmailSent by remember { mutableStateOf(false) }

    val context = LocalContext.current
    val auth = FirebaseAuth.getInstance()
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("QUÊN MẬT KHẨU", fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Color(0xFFFF00CC))

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = if (isEmailSent) "✅ Đã gửi link! Vui lòng kiểm tra hộp thư." else "Nhập email để đặt lại mật khẩu.",
            color = if (isEmailSent) Color(0xFF00AA00) else Color.Gray,
            fontSize = 14.sp,
            modifier = Modifier.padding(horizontal = 16.dp)
        )

        Spacer(modifier = Modifier.height(32.dp))

        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("Email") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Done),
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            enabled = !isLoading && !isEmailSent
        )

        Spacer(modifier = Modifier.height(24.dp))

        Button(
            onClick = {
                if (email.isNotEmpty()) {
                    isLoading = true
                    scope.launch {
                        try {
                            // Gọi API Backend kiểm tra Email có tồn tại trong hệ thống không
                            val response = RetrofitClient.api.checkEmail(CheckEmailRequest(email))

                            // Kiểm tra response
                            if (response.isSuccessful && response.body()?.status == "success") {
                                val exists = response.body()?.exists == true
                                val role = response.body()?.role ?: "user";

                                if (exists) {
                                    if (role == "admin" || role == "own") {
                                        isLoading = false
                                        Toast.makeText(context, "Tài khoản Quản trị không được reset ở đây! Vui lòng vào trang Admin.", Toast.LENGTH_LONG).show()
                                        return@launch // Dừng ngay, không gửi email
                                    }
                                    // Gửi yêu cầu qua Firebase
                                    auth.sendPasswordResetEmail(email)
                                        .addOnCompleteListener { task ->
                                            isLoading = false
                                            if (task.isSuccessful) {
                                                isEmailSent = true
                                                Toast.makeText(context, "Đã gửi link khôi phục! Kiểm tra email.", Toast.LENGTH_LONG).show()
                                            } else {
                                                Toast.makeText(context, "Lỗi Firebase: ${task.exception?.message}", Toast.LENGTH_SHORT).show()
                                            }
                                        }
                                } else {
                                    // 2. Email không tồn tại trong Database
                                    isLoading = false
                                    Toast.makeText(context, "Email này chưa đăng ký tài khoản!", Toast.LENGTH_LONG).show()
                                }
                            } else {
                                // Lỗi API trả về (khác success)
                                isLoading = false
                                Toast.makeText(context, "Lỗi: ${response.body()?.message ?: "Server Error"}", Toast.LENGTH_SHORT).show()
                            }
                        } catch (e: Exception) {
                            // Lỗi mạng
                            isLoading = false
                            e.printStackTrace()
                            Toast.makeText(context, "Lỗi kết nối Server!", Toast.LENGTH_SHORT).show()
                        }
                    }

                } else {
                    Toast.makeText(context, "Vui lòng nhập email!", Toast.LENGTH_SHORT).show()
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(50.dp),
            colors = ButtonDefaults.buttonColors(containerColor = if (isEmailSent) Color.Gray else Color(0xFFFF00CC)),
            enabled = !isLoading && !isEmailSent
        ) {
            if (isLoading) {
                CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
            } else {
                Text(text = if (isEmailSent) "ĐÃ GỬI LIÊN KẾT" else "GỬI LINK KHÔI PHỤC", fontWeight = FontWeight.Bold)
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        TextButton(onClick = { onBackClick() }) {
            Text("Quay lại Đăng nhập", color = Color.Gray)
        }
    }
}