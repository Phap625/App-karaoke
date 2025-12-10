package com.example.karaokeapp.network

import com.example.karaokeapp.models.LoginRequest
import com.example.karaokeapp.models.LoginResponse
import com.example.karaokeapp.models.RegisterRequest
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.Body
import retrofit2.http.POST

// 1. Định nghĩa các hàm gọi API
interface ApiService {
    @POST("api/login")
    suspend fun login(@Body request: LoginRequest): Response<LoginResponse>

    @POST("api/register")
    suspend fun register(@Body request: RegisterRequest): Response<LoginResponse>
}

// 2. Tạo đối tượng kết nối
object RetrofitClient {
    private const val BASE_URL = "https://karaoke-server-paan.onrender.com/"

    val api: ApiService by lazy {
        Retrofit.Builder()
            .baseUrl(BASE_URL)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(ApiService::class.java)
    }
}