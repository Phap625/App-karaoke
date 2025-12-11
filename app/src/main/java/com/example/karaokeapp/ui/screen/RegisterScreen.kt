package com.example.karaokeapp.ui.screen

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.widget.Toast
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
    // 1. Khai báo biến
    var email by remember { mutableStateOf("") }
    var username by remember { mutableStateOf("") }
    var fullName by remember { mutableStateOf(TextFieldValue("")) } // Dùng TextFieldValue fix lỗi tiếng Việt
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }

    // Firebase & Context
    val auth = FirebaseAuth.getInstance()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // Scroll state
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

        // --- FORM NHẬP LIỆU ---

        // 1. Email
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("Email") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            modifier = Modifier.fillMaxWidth(),
            enabled = !isLoading
        )
        Spacer(modifier = Modifier.height(12.dp))

        // 2. Tên đăng nhập
        OutlinedTextField(
            value = username,
            onValueChange = { username = it },
            label = { Text("Tên đăng nhập (viết liền)") },
            modifier = Modifier.fillMaxWidth(),
            enabled = !isLoading
        )
        Spacer(modifier = Modifier.height(12.dp))

        // 3. Họ tên
        OutlinedTextField(
            value = fullName,
            onValueChange = { fullName = it },
            label = { Text("Họ và tên") },
            modifier = Modifier.fillMaxWidth(),
            enabled = !isLoading
        )
        Spacer(modifier = Modifier.height(12.dp))

        // 4. Mật khẩu
        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Mật khẩu") },
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth(),
            enabled = !isLoading
        )
        Spacer(modifier = Modifier.height(12.dp))

        // 5. Xác nhận mật khẩu
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

        // --- NÚT ĐĂNG KÝ ---
        Button(
            onClick = {
                // Validate cơ bản
                if (password != confirmPassword) {
                    Toast.makeText(context, "Mật khẩu xác nhận không khớp!", Toast.LENGTH_SHORT).show()
                    return@Button
                }

                if (email.isNotEmpty() && username.isNotEmpty() && password.isNotEmpty() && fullName.text.isNotEmpty()) {
                    isLoading = true

                    // BƯỚC 1: Tạo User trên Firebase
                    auth.createUserWithEmailAndPassword(email, password)
                        .addOnCompleteListener { task ->
                            if (task.isSuccessful) {
                                val user = auth.currentUser

                                // BƯỚC 2: Gửi Email xác thực
                                user?.sendEmailVerification()
                                    ?.addOnCompleteListener { verifyTask ->
                                        if (verifyTask.isSuccessful) {
                                            Toast.makeText(context, "Đã gửi link xác thực đến ${user.email}", Toast.LENGTH_LONG).show()
                                        }
                                    }

                                // BƯỚC 3: Gọi API lưu vào Database (Supabase)
                                scope.launch {
                                    try {
                                        val request = RegisterRequest(email, username, password, fullName.text)
                                        val res = RetrofitClient.api.register(request)

                                        if (res.isSuccessful && res.body()?.status == "success") {
                                            Toast.makeText(context, "Đăng ký thành công! Vui lòng kiểm tra Email.", Toast.LENGTH_LONG).show()
                                            onRegisterSuccess()
                                        } else {
                                            // QUAN TRỌNG: Nếu Server lỗi (VD trùng username), XÓA user trên Firebase ngay
                                            // để người dùng không bị kẹt (có Firebase mà không có Supabase)
                                            user?.delete()
                                            Toast.makeText(context, "Lỗi: ${res.body()?.message}", Toast.LENGTH_SHORT).show()
                                        }
                                    } catch (e: Exception) {
                                        // Lỗi mạng -> Cũng xóa Firebase đi làm lại
                                        user?.delete()
                                        Toast.makeText(context, "Lỗi kết nối Server!", Toast.LENGTH_SHORT).show()
                                    } finally {
                                        isLoading = false
                                    }
                                }
                            } else {
                                // Lỗi Firebase (Email đã tồn tại, pass yếu...)
                                Toast.makeText(context, "Lỗi: ${task.exception?.message}", Toast.LENGTH_SHORT).show()
                                isLoading = false
                            }
                        }
                } else {
                    Toast.makeText(context, "Vui lòng nhập đầy đủ thông tin", Toast.LENGTH_SHORT).show()
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
                Text("ĐĂNG KÝ")
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        TextButton(onClick = { onBackClick() }) {
            Text("Quay lại Đăng nhập", color = Color.Gray)
        }
    }
}