package com.example.karaokeapp.ui.screen

import android.util.Log
import android.widget.Toast
import org.json.JSONObject
import androidx.compose.foundation.BorderStroke
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

    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val auth = FirebaseAuth.getInstance()


    fun handleSyncPassword(realEmail: String, pass: String) {
        scope.launch {
            try {
                val syncRes = RetrofitClient.api.syncPassword(LoginRequest(realEmail, pass))

                if (syncRes.isSuccessful && syncRes.body()?.status == "success") {
                    Toast.makeText(context, "Đã cập nhật mật khẩu mới!", Toast.LENGTH_SHORT).show()
                    onLoginSuccess(true)
                } else {
                    val errorJson = syncRes.errorBody()?.string()
                    Toast.makeText(context, "Lỗi đồng bộ dữ liệu", Toast.LENGTH_SHORT).show()
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
                            val response = RetrofitClient.api.login(LoginRequest(identifier, password))

                            if (response.isSuccessful && response.body()?.status == "success") {
                                val realEmail = response.body()?.user?.email ?: ""

                                if (realEmail.isNotEmpty()) {
                                    auth.signInWithEmailAndPassword(realEmail, password)
                                        .addOnCompleteListener { task ->
                                            if (task.isSuccessful) {
                                                val user = auth.currentUser
                                                if (user?.isEmailVerified == true) {
                                                    Toast.makeText(context, "Đăng nhập thành công!", Toast.LENGTH_SHORT).show()
                                                    onLoginSuccess(true)
                                                } else {
                                                    auth.signOut()
                                                    Toast.makeText(context, "Email chưa xác thực!", Toast.LENGTH_LONG).show()
                                                    user?.sendEmailVerification()
                                                }
                                            } else {
                                                auth.signOut()
                                                Toast.makeText(context, "Mật khẩu này đã bị đổi! Vui lòng nhập mật khẩu mới.", Toast.LENGTH_LONG).show()
                                            }
                                            isLoading = false
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

                                    val emailToTest = if (identifier.contains("@")) identifier else hintEmail

                                    if (emailToTest.isNotEmpty()) {

                                        auth.signInWithEmailAndPassword(emailToTest, password)
                                            .addOnCompleteListener { fbTask ->
                                                if (fbTask.isSuccessful) {
                                                    Toast.makeText(context, "Phát hiện mật khẩu mới, đang đồng bộ...", Toast.LENGTH_SHORT).show()
                                                    handleSyncPassword(emailToTest, password)
                                                } else {
                                                    Toast.makeText(context, "Mật khẩu không đúng!", Toast.LENGTH_SHORT).show()
                                                    showForgotPassword = true
                                                    isLoading = false
                                                }
                                            }
                                    } else {
                                        Toast.makeText(context, "Mật khẩu không đúng!", Toast.LENGTH_SHORT).show()
                                        showForgotPassword = true
                                        isLoading = false
                                    }

                                } else if (message.contains("không tồn tại", ignoreCase = true)) {
                                    Toast.makeText(context, "Tài khoản không tồn tại", Toast.LENGTH_SHORT).show()
                                    showForgotPassword = false
                                    isLoading = false
                                } else {
                                    Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
                                    isLoading = false
                                }
                            }
                        } catch (e: Exception) {
                            Toast.makeText(context, "Không thể kết nối Server!", Toast.LENGTH_LONG).show()
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
                Toast.makeText(context, "Đang vào chế độ Khách...", Toast.LENGTH_SHORT).show()
                onLoginSuccess(false)
            },
            modifier = Modifier.fillMaxWidth().height(50.dp),
            border = BorderStroke(1.dp, Color(0xFFFF00CC)),
            colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFFFF00CC)),
            enabled = !isLoading
        ) {
            Text("HÁT THỬ NGAY (KHÔNG CẦN TÀI KHOẢN)", fontWeight = FontWeight.Bold)
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