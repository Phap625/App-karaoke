package com.example.karaokeapp.ui.screens

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.karaokeapp.utils.TokenManager

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MeScreen(
    onLogoutClick: () -> Unit
) {
    val context = LocalContext.current
    // TokenManager khởi tạo ở đây là ổn
    val tokenManager = remember { TokenManager(context) }

    // --- SỬA ĐỔI QUAN TRỌNG TẠI ĐÂY ---
    // Không dùng remember { ... } cho role vì nếu user đăng nhập xong quay lại,
    // role cần được cập nhật ngay lập tức.
    // Lấy trực tiếp từ SharedPreferences mỗi lần vẽ lại UI.
    val role = tokenManager.getUserRole() ?: "guest"
    val isGuest = role == "guest"
    // -----------------------------------

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Tài khoản", fontWeight = FontWeight.Bold) },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .background(MaterialTheme.colorScheme.background)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // --- PHẦN 1: HEADER PROFILE ---
            Spacer(modifier = Modifier.height(20.dp))

            // Avatar
            Icon(
                imageVector = if (isGuest) Icons.Default.PersonOutline else Icons.Default.AccountCircle,
                contentDescription = "Avatar",
                modifier = Modifier
                    .size(100.dp)
                    .clip(CircleShape)
                    .background(if (isGuest) Color.LightGray else MaterialTheme.colorScheme.primaryContainer),
                tint = if (isGuest) Color.Gray else MaterialTheme.colorScheme.primary
            )
            Spacer(modifier = Modifier.height(16.dp))

            // Tên hiển thị
            Text(
                text = if (isGuest) "Chào bạn mới!" else "Thành viên Karaoke",
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onBackground
            )

            // Trạng thái tài khoản
            Text(
                text = if (isGuest) "Đang dùng chế độ Khách" else "Vai trò: ${role.uppercase()}",
                fontSize = 14.sp,
                color = if (isGuest) Color.Gray else MaterialTheme.colorScheme.primary
            )

            // Gợi ý cho khách
            if (isGuest) {
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Đăng ký để lưu bài hát yêu thích vĩnh viễn!",
                    fontSize = 12.sp,
                    color = Color(0xFFFF00CC),
                    fontWeight = FontWeight.Medium
                )
            }

            Spacer(modifier = Modifier.height(32.dp))

            // --- PHẦN 2: MENU CHỨC NĂNG ---
            Card(
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column {
                    ProfileMenuItem(
                        icon = Icons.Default.Favorite,
                        title = "Bài hát yêu thích",
                        onClick = {
                            if (isGuest) Toast.makeText(context, "Đăng nhập để lưu bài hát yêu thích!", Toast.LENGTH_SHORT).show()
                            else { /* TODO */ }
                        }
                    )
                    Divider(color = Color.LightGray.copy(alpha = 0.3f))

                    ProfileMenuItem(
                        icon = Icons.Default.History,
                        title = "Lịch sử hát",
                        onClick = {
                            if (isGuest) Toast.makeText(context, "Đăng nhập để xem lại lịch sử!", Toast.LENGTH_SHORT).show()
                            else { /* TODO */ }
                        }
                    )
                    Divider(color = Color.LightGray.copy(alpha = 0.3f))

                    ProfileMenuItem(
                        icon = Icons.Default.Settings,
                        title = "Cài đặt ứng dụng",
                        onClick = { /* TODO */ }
                    )

                    if (!isGuest) {
                        Divider(color = Color.LightGray.copy(alpha = 0.3f))
                        ProfileMenuItem(
                            icon = Icons.Default.Lock,
                            title = "Đổi mật khẩu",
                            onClick = { /* TODO */ }
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            // --- PHẦN 3: NÚT HÀNH ĐỘNG ---
            // Quan trọng: Nút này gọi hàm onLogoutClick được truyền từ MainActivity.
            // MainActivity chịu trách nhiệm quyết định: Xóa token hay chỉ chuyển màn hình.
            Button(
                onClick = onLogoutClick,
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (isGuest) Color(0xFFFF00CC) else MaterialTheme.colorScheme.error
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(
                    imageVector = if (isGuest) Icons.Default.Login else Icons.Default.ExitToApp,
                    contentDescription = null
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = if (isGuest) "Đăng ký / Đăng nhập ngay" else "Đăng xuất",
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp
                )
            }

            Spacer(modifier = Modifier.height(20.dp))
        }
    }
}

// Widget con
@Composable
fun ProfileMenuItem(icon: ImageVector, title: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(vertical = 16.dp, horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(imageVector = icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
        Spacer(modifier = Modifier.width(16.dp))
        Text(text = title, modifier = Modifier.weight(1f), fontSize = 16.sp)
        Icon(imageVector = Icons.Default.KeyboardArrowRight, contentDescription = null, tint = Color.Gray)
    }
}