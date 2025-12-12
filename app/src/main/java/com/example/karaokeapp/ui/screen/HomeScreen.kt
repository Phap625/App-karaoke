package com.example.karaokeapp.ui.screen

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.example.karaokeapp.ui.screens.MeScreen

@Composable
fun HomeScreen(onLogout: () -> Unit) {
    var selectedTab by remember { mutableIntStateOf(0) }

    Scaffold(
        bottomBar = {
            NavigationBar(
                containerColor = Color.White
            ) {
                val items = listOf("Trang chủ", "Khoảnh khắc", "Hát", "Trò chuyện", "Tôi")
                val icons = listOf(
                    Icons.Default.Home,
                    Icons.Default.AccessTime,
                    Icons.Default.Mic,
                    Icons.Default.Chat,
                    Icons.Default.Person
                )

                items.forEachIndexed { index, item ->
                    NavigationBarItem(
                        icon = { Icon(icons[index], contentDescription = item) },
                        label = { Text(item) },
                        selected = selectedTab == index,
                        onClick = { selectedTab = index },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = Color(0xFFFF00CC),
                            indicatorColor = Color.Transparent
                        )
                    )
                }
            }
        }
    ) { innerPadding ->
        // Nội dung chính thay đổi theo tab
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            when (selectedTab) {
                0 -> CenteredText("Nội dung Trang Chủ (List nhạc)")
                1 -> CenteredText("Nội dung Khoảnh Khắc")
                2 -> CenteredText("Màn hình Hát")
                3 -> CenteredText("Màn hình Chat")

                // --- THAY ĐỔI QUAN TRỌNG Ở ĐÂY ---
                4 -> MeScreen(onLogoutClick = onLogout)
            }
        }
    }
}

// Hàm phụ để hiển thị text ở giữa (cho các tab chưa code xong)
@Composable
fun CenteredText(text: String) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Text(text = text)
    }
}