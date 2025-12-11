package com.example.karaokeapp.ui.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun ResetPasswordScreen(onBackClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("KHÔI PHỤC MẬT KHẨU", fontSize = 24.sp, color = Color(0xFFFF00CC))

        Spacer(modifier = Modifier.height(20.dp))

        Text("Chức năng đang phát triển...")
        Text("Quy trình: Nhập SĐT -> OTP -> Mật khẩu mới")

        Spacer(modifier = Modifier.height(20.dp))

        TextButton(onClick = onBackClick) {
            Text("Quay lại Đăng nhập")
        }
    }
}