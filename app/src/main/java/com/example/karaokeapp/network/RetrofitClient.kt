package com.example.karaokeapp.network

import com.example.karaokeapp.models.CheckEmailRequest
import com.example.karaokeapp.models.CheckEmailResponse
import com.example.karaokeapp.models.LoginRequest
import com.example.karaokeapp.models.LoginResponse
import com.example.karaokeapp.models.LogoutRequest
import com.example.karaokeapp.models.RegisterRequest
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.Header
import retrofit2.http.POST

// 1. Định nghĩa các hàm gọi API
interface ApiService {
    @POST("api/auth/login")
    suspend fun login(@Body request: LoginRequest): Response<LoginResponse>

    @POST("api/auth/register")
    suspend fun register(@Body request: RegisterRequest): Response<LoginResponse>

    @POST("api/auth/sync-password")
    suspend fun syncPassword(@Body request: LoginRequest): Response<LoginResponse>

    @POST("api/auth/check-email")
    suspend fun checkEmail(@Body request: CheckEmailRequest): Response<CheckEmailResponse>

    @POST("api/auth/guest-login")
    suspend fun guestLogin(): Response<LoginResponse>

    @POST("api/auth/logout")
    suspend fun logout(@Body request: LogoutRequest): Response<Any>

    @DELETE("api/auth/delete-guest")
    suspend fun deleteGuestAccount(@Header("Authorization") token: String): Response<Any>
}

// 2. Tạo đối tượng kết nối
object RetrofitClient {
    private const val BASE_URL = "https://karaoke-server-paan.onrender.com/"
//    private const val BASE_URL = "http://10.0.2.2:3000/"

    val api: ApiService by lazy {
        Retrofit.Builder()
            .baseUrl(BASE_URL)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(ApiService::class.java)
    }
}