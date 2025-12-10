package com.example.karaokeapp.ui.screen

import android.app.Activity
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
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
import com.example.karaokeapp.models.RegisterRequest
import com.example.karaokeapp.network.RetrofitClient
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.PhoneAuthOptions
import com.google.firebase.FirebaseException
import com.google.firebase.auth.PhoneAuthCredential
import com.google.firebase.auth.PhoneAuthProvider
import kotlinx.coroutines.launch
import java.util.concurrent.TimeUnit

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RegisterScreen(
    onRegisterSuccess: () -> Unit,
    onBackClick: () -> Unit
) {
    // Biến nhập liệu
    var phone by remember { mutableStateOf("") }
    var otpInput by remember { mutableStateOf("") }
    var fullName by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }

    // Trạng thái màn hình
    var isOtpSent by remember { mutableStateOf(false) }
    var isVerified by remember { mutableStateOf(false) }
    var isLoading by remember { mutableStateOf(false) }

    // Firebase
    val auth = FirebaseAuth.getInstance()
    var verificationId by remember { mutableStateOf("") }
    val context = LocalContext.current
    val activity = LocalContext.current as Activity
    val scope = rememberCoroutineScope()

    val callbacks = remember {
        object : PhoneAuthProvider.OnVerificationStateChangedCallbacks() {
            override fun onVerificationCompleted(credential: PhoneAuthCredential) {}

            override fun onVerificationFailed(e: FirebaseException) {
                isLoading = false
                Toast.makeText(context, "Lỗi gửi tin: ${e.message}", Toast.LENGTH_LONG).show()
            }

            override fun onCodeSent(vId: String, token: PhoneAuthProvider.ForceResendingToken) {
                verificationId = vId
                isOtpSent = true
                isLoading = false
                Toast.makeText(context, "Đã gửi mã OTP!", Toast.LENGTH_SHORT).show()
            }
        }
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp).background(Color.White),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("ĐĂNG KÝ", fontSize = 28.sp, fontWeight = FontWeight.Bold, color = Color(0xFFFF00CC))
        Spacer(modifier = Modifier.height(24.dp))

        if (!isVerified) {
            OutlinedTextField(
                value = phone,
                onValueChange = { phone = it },
                label = { Text("Số điện thoại") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                modifier = Modifier.fillMaxWidth(),
                enabled = !isOtpSent && !isLoading
            )
            Spacer(modifier = Modifier.height(12.dp))

            if (isOtpSent) {
                OutlinedTextField(
                    value = otpInput,
                    onValueChange = { otpInput = it },
                    label = { Text("Nhập mã 6 số") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.height(12.dp))

                Button(
                    onClick = {
                        if (verificationId.isNotEmpty() && otpInput.isNotEmpty()) {
                            val credential = PhoneAuthProvider.getCredential(verificationId, otpInput)
                            auth.signInWithCredential(credential)
                                .addOnCompleteListener(activity) { task ->
                                    if (task.isSuccessful) {
                                        isVerified = true
                                        Toast.makeText(context, "Xác thực thành công!", Toast.LENGTH_SHORT).show()
                                    } else {
                                        Toast.makeText(context, "Mã OTP sai rồi!", Toast.LENGTH_SHORT).show()
                                    }
                                }
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFF00CC))
                ) { Text("XÁC NHẬN MÃ OTP") }

            } else {
                Button(
                    onClick = {
                        if (phone.isNotEmpty()) {
                            isLoading = true
                            var formattedPhone = phone
                            if (phone.startsWith("0")) {
                                formattedPhone = "+84" + phone.substring(1)
                            }

                            val options = PhoneAuthOptions.newBuilder(auth)
                                .setPhoneNumber(formattedPhone)
                                .setTimeout(60L, TimeUnit.SECONDS)
                                .setActivity(activity)
                                .setCallbacks(callbacks)
                                .build()
                            PhoneAuthProvider.verifyPhoneNumber(options)
                        } else {
                            Toast.makeText(context, "Nhập số điện thoại trước!", Toast.LENGTH_SHORT).show()
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFF00CC)),
                    enabled = !isLoading
                ) {
                    if (isLoading) CircularProgressIndicator(color = Color.White, modifier = Modifier.size(20.dp))
                    else Text("GỬI MÃ OTP (MIỄN PHÍ)")
                }
            }
        }

        if (isVerified) {
            Text("✅ SĐT đã xác minh: $phone", color = Color(0xFF00AA00), fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(value = fullName, onValueChange = { fullName = it }, label = { Text("Họ và tên") }, modifier = Modifier.fillMaxWidth())
            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(value = password, onValueChange = { password = it }, label = { Text("Tạo mật khẩu") }, visualTransformation = PasswordVisualTransformation(), modifier = Modifier.fillMaxWidth())
            Spacer(modifier = Modifier.height(24.dp))

            Button(
                onClick = {
                    scope.launch {
                        try {
                            val res = RetrofitClient.api.register(RegisterRequest(phone, password, fullName))
                            if (res.isSuccessful && res.body()?.status == "success") {
                                Toast.makeText(context, "Tạo tài khoản thành công!", Toast.LENGTH_LONG).show()
                                onRegisterSuccess()

                            } else {
                                Toast.makeText(context, "Lỗi: ${res.body()?.message}", Toast.LENGTH_SHORT).show()
                            }
                        } catch (e: Exception) {
                            Toast.makeText(context, "Lỗi kết nối Server!", Toast.LENGTH_SHORT).show()
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth().height(50.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFF00CC))
            ) { Text("HOÀN TẤT ĐĂNG KÝ") }
        }

        Spacer(modifier = Modifier.height(16.dp))


        TextButton(onClick = {
            onBackClick()
        }) {
            Text("Quay lại Đăng nhập", color = Color.Gray)
        }
    }
}