package com.example.karaokeapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.example.karaokeapp.ui.screen.HomeScreen
import com.example.karaokeapp.ui.screen.LoginScreen
import com.example.karaokeapp.ui.screen.RegisterScreen
import com.example.karaokeapp.ui.screen.ResetPasswordScreen
import com.example.karaokeapp.ui.screens.MeScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val navController = rememberNavController()

            NavHost(navController = navController, startDestination = "login") {
                // Màn hình Login
                composable("login") {
                    LoginScreen(
                        onLoginSuccess = {
                            navController.navigate("home") {
                                popUpTo("login") { inclusive = true }
                            }
                        },
                        onNavigateToRegister = {
                            navController.navigate("register")
                        },
                        onNavigateToResetPassword = {
                            navController.navigate("reset_password")
                        }
                    )
                }

                // Màn hình Home
                composable("home") {
                    HomeScreen(
                        onLogout = {
                            navController.navigate("login") {
                                popUpTo("home") { inclusive = true }
                            }
                        }
                    )
                }

                // Màn hình Register
                composable("register") {
                    RegisterScreen(
                        onRegisterSuccess = {
                            navController.navigate("login") {
                                popUpTo("register") { inclusive = true }
                            }
                        },
                        onBackClick = {
                            navController.popBackStack()
                        }
                    )
                }

                //Màn hình reset password
                composable("reset_password") {
                    ResetPasswordScreen(
                        onBackClick = {
                            navController.popBackStack()
                        }
                    )
                }

                composable("me_screen") {
                    MeScreen(
                        onLogoutClick = {
                            // 1. Xử lý logic xóa token/dữ liệu người dùng (nếu có)
                            // Example: userPreferences.clear()

                            navController.navigate("login") {
                                popUpTo(0) { inclusive = true }
                            }
                        }
                    )
                }


            }
        }
    }
}