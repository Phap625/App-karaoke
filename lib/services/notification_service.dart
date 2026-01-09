import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_client.dart';

class NotificationService {
  // Singleton pattern
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  // Lấy dio từ ApiClient đã cấu hình sẵn (Token, Interceptor...)
  final Dio _dio = ApiClient.instance.dio;

  /// Gọi API Follow user và gửi thông báo
  Future<bool> followUser({required String targetUserId}) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      debugPrint("❌ Chưa đăng nhập");
      return false;
    }

    try {
      // Gọi API Node.js: POST /api/notifications/follow
      final response = await _dio.post(
        '/api/user/notifications/follow',
        data: {
          'follower_id': currentUser.id,
          'following_id': targetUserId,
        },
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Follow thành công: ${response.data}");
        return true;
      }
      return false;
    } catch (e) {
      // ApiClient đã xử lý lỗi mạng (Retry Dialog) rồi
      // Ở đây ta chỉ log logic error (400, 500)
      debugPrint("❌ Lỗi Follow API: $e");
      return false;
    }
  }

  // Gọi API Unfollow và thu hồi thông báo
  Future<bool> unfollowUser({required String targetUserId}) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return false;

    try {
      // Gọi API Node.js: POST /api/notifications/unfollow
      final response = await _dio.post(
        '/api/user/notifications/unfollow',
        data: {
          'follower_id': currentUser.id,
          'following_id': targetUserId,
        },
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Unfollow thành công: ${response.data}");
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Lỗi Unfollow API: $e");
      return false;
    }
  }
}