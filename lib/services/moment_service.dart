import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/moment_model.dart';

class MomentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static final MomentService _instance = MomentService._internal();
  factory MomentService() => _instance;
  MomentService._internal();

  //--- Lấy danh sách Moments (Feed) Bao gồm: Public + Friends + Của tôi ---
  Future<List<Moment>> getPublicFeed({int limit = 20, int offset = 0}) async {
    return _callFeedRpc('get_public_feed', limit, offset);
  }

  // --- HÀM 2: Lấy Feed Following ---
  Future<List<Moment>> getFollowingFeed({int limit = 20, int offset = 0}) async {
    return _callFeedRpc('get_following_feed', limit, offset);
  }

  //--- Hàm phụ trợ để tái sử dụng code gọi RPC ---
  Future<List<Moment>> _callFeedRpc(String rpcName, int limit, int offset) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final List<dynamic> response = await _supabase.rpc(
        rpcName,
        params: {
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      return response.map((item) {
        return Moment(
          id: item['moment_id'],
          userId: item['user_id'],
          audioUrl: item['audio_url'],
          description: item['description'],
          createdAt: DateTime.parse(item['created_at']),
          visibility: item['visibility'],
          userName: item['user_full_name'] ?? 'Người dùng',
          userAvatar: item['user_avatar_url'],
        );
      }).toList();
    } catch (e) {
      debugPrint("🔴 Lỗi RPC $rpcName: $e");
      return [];
    }
  }

  // --- Hàm like/ bỏ like ---
  Future<void> toggleLike(int momentId, bool shouldLike) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (shouldLike) {
      await _supabase
          .from('moment_likes')
          .upsert({'user_id': userId, 'moment_id': momentId});
    } else {
      await _supabase
          .from('moment_likes')
          .delete()
          .match({'user_id': userId, 'moment_id': momentId});
    }
  }

  // --- Hàm lấy danh sách comment của 1 moment ---
  Stream<List<Map<String, dynamic>>> getCommentsStream(int momentId) {
    return _supabase
        .from('moment_comments')
        .stream(primaryKey: ['id'])
        .eq('moment_id', momentId)
        .order('created_at', ascending: true)
        .map((event) => event);
  }

  // --- Hỗ trợ lấy thông tin user cho comment ---
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      return await _supabase.from('users').select('full_name, avatar_url').eq('id', userId).single();
    } catch(e) { return null; }
  }

  // --- Gửi Comment ---
  Future<void> sendComment(int momentId, String content) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('moment_comments').insert({
      'user_id': userId,
      'moment_id': momentId,
      'content': content,
    });
  }

  // --- Lấy số liệu mới nhất của 1 moment cụ thể ---
  Future<Map<String, dynamic>?> getMomentStats(int momentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final resLikes = await _supabase
          .from('moment_likes')
          .count(CountOption.exact)
          .eq('moment_id', momentId);

      final resComments = await _supabase
          .from('moment_comments')
          .count(CountOption.exact)
          .eq('moment_id', momentId);

      // Check xem mình có like không
      bool isLiked = false;
      if (userId != null) {
        final checkLike = await _supabase
            .from('moment_likes')
            .select('user_id')
            .eq('moment_id', momentId)
            .eq('user_id', userId)
            .maybeSingle();
        isLiked = checkLike != null;
      }

      return {
        'likes_count': resLikes,
        'comments_count': resComments,
        'is_liked': isLiked
      };
    } catch (e) {
      debugPrint("Lỗi getMomentStats: $e");
      return null;
    }
  }

  // --- Lấy Avatar của user hiện tại (Để hiển thị ở ô đăng bài)---
  Future<String?> getCurrentUserAvatar() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final data = await _supabase
          .from('users')
          .select('avatar_url')
          .eq('id', userId)
          .single();

      return data['avatar_url'] as String?;
    } catch (e) {
      debugPrint("🔴 Lỗi lấy avatar user: $e");
      return null;
    }
  }
}