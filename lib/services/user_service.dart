import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'base_service.dart';


class BlockStatus {
  final bool blockedByMe;
  final bool blockedByThem;

  BlockStatus({this.blockedByMe = false, this.blockedByThem = false});
}

class UserService extends BaseService{
  static final UserService instance = UserService._internal();
  UserService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // --- Lấy thông tin user ---
  Future<UserModel> getUserProfile() async {
    return await safeExecution(() async {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("Chưa đăng nhập");

      try {
        final data = await _supabase
            .from('users')
            .select()
            .eq('id', user.id)
            .single();

        return UserModel.fromJson(data);
      } catch (e) {
        debugPrint(" Lỗi lấy profile từ Supabase: $e");
        if (e.toString().contains("PGRST116") ||
            e.toString().contains("Row not found")) {
          throw Exception(
              "Không tìm thấy dữ liệu user. Hãy kiểm tra Policy RLS!");
        }
        rethrow;
      }
    });
  }

  // --- Lấy thông tin user bằng ID ---
  Future<UserModel?> getUserById(String userId) async {
    return await safeExecution(() async {
      try {
        final data = await _supabase
            .from('users')
            .select()
            .eq('id', userId)
            .single();

        return UserModel.fromJson(data);
      } catch (e) {
        debugPrint("Lỗi lấy user detail ($userId): $e");
        return null;
      }
    });
  }

  // --- Lấy danh sách bạn bè ---
  Future<List<UserModel>> getFriendsList() async {
    return await safeExecution(() async {
      try {
        final userId = _supabase.auth.currentUser?.id;
        if (userId == null) return [];

        final response = await _supabase
            .from('friends_view')
            .select()
            .eq('user_id', userId);
        
        final List<dynamic> data = response as List;
        return data.map((json) => UserModel.fromFriendView(json)).toList();
      } catch (e) {
        debugPrint(" Lỗi lấy danh sách bạn bè: $e");
        return [];
      }
    });
  }

  // --- Kiểm tra trạng thái chặn ---
  Future<BlockStatus> checkBlockStatus(String myId, String otherId) async {
    try {
      final response = await _supabase
          .from('blocked_users')
          .select()
          .or('and(blocker_id.eq.$myId,blocked_id.eq.$otherId),and(blocker_id.eq.$otherId,blocked_id.eq.$myId)');

      bool byMe = false;
      bool byThem = false;
      final List data = response as List;

      for (var row in data) {
        if (row['blocker_id'] == myId) {
          byMe = true;
        } else if (row['blocker_id'] == otherId) {
          byThem = true;
        }
      }
      return BlockStatus(blockedByMe: byMe, blockedByThem: byThem);
    } catch (e) {
      debugPrint("UserService - checkBlockStatus error: $e");
      return BlockStatus();
    }
  }

  // --- Chặn người dùng ---
  Future<void> blockUser(String myId, String targetId) async {
    try {
      await _supabase.from('blocked_users').insert({
        'blocker_id': myId,
        'blocked_id': targetId,
      });
      await _supabase.from('deleted_conversations').upsert({
        'user_id': myId,
        'partner_id': targetId,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id, partner_id');

    } catch (e) {
      debugPrint("UserService - blockUser error: $e");
      rethrow;
    }
  }

  // --- Bỏ chặn người dùng ---
  Future<void> unblockUser(String myId, String targetId) async {
    try {
      await _supabase
          .from('blocked_users')
          .delete()
          .eq('blocker_id', myId)
          .eq('blocked_id', targetId);

      await _supabase
          .from('deleted_conversations')
          .delete()
          .eq('user_id', myId)
          .eq('partner_id', targetId);

    } catch (e) {
      debugPrint("UserService - unblockUser error: $e");
      rethrow;
    }
  }

  // --- Lấy danh sách bị chặn ---
  Future<List<UserModel>> fetchBlockedUsers(String myId) async {
    try {
      final blockedData = await _supabase
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', myId);

      final List<dynamic> blockedIds = blockedData.map((e) => e['blocked_id']).toList();

      if (blockedIds.isEmpty) return [];

      final usersData = await _supabase
          .from('users')
          .select()
          .filter('id', 'in', blockedIds);

      return (usersData as List)
          .map((json) => UserModel.fromSearch(json))
          .toList();
    } catch (e) {
      debugPrint("UserService - fetchBlockedUsers error: $e");
      rethrow;
    }
  }

  // --- Lấy danh sách following/follower ---
  Future<List<UserModel>> fetchFollowList({required String targetUserId, required String type}) async {
    String foreignKey;
    String columnToFilter;

    if (type == 'following') {
      foreignKey = 'follows_following_id_fkey';
      columnToFilter = 'follower_id';
    } else {
      foreignKey = 'follows_follower_id_fkey';
      columnToFilter = 'following_id';
    }

    try {
      final response = await _supabase
          .from('follows')
          .select('users!$foreignKey(*)')
          .eq(columnToFilter, targetUserId);

      final dataList = response as List;
      return dataList.map((e) => UserModel.fromJson(e['users'])).toList();
    } catch (e) {
      debugPrint("UserService - fetchFollowList error: $e");
      return [];
    }
  }

  // --- Lấy đề xuất ---
  Future<List<UserModel>> fetchSuggestions({String? currentProfileViewingId}) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return [];

    try {
      final String now = DateTime.now().toUtc().toIso8601String();

      final results = await Future.wait<dynamic>([
        _supabase.from('users').select('region').eq('id', currentUser.id).single(),
        _supabase.from('follows').select('following_id').eq('follower_id', currentUser.id),
        _supabase.from('blocked_users').select('blocked_id').eq('blocker_id', currentUser.id),
      ]);

      final viewerRes = results[0] as Map<String, dynamic>;
      final followingRes = results[1] as List;
      final blockedRes = results[2] as List;

      final String? viewerRegion = viewerRes['region'];

      // Tạo danh sách loại trừ
      final Set<String> excludedIds = {};
      excludedIds.add(currentUser.id);
      if (currentProfileViewingId != null) excludedIds.add(currentProfileViewingId);
      for (var item in followingRes) excludedIds.add(item['following_id']);
      for (var item in blockedRes) excludedIds.add(item['blocked_id']);

      List<UserModel> finalSuggestions = [];

      // BƯỚC 1: CÙNG TỈNH, KHÔNG KHÓA, CHƯA FOLLOW/BLOCK
      if (viewerRegion != null && viewerRegion.isNotEmpty) {
        var query1 = _supabase.from('users').select();
        query1 = query1.neq('role', 'admin').neq('role', 'own').eq('region', viewerRegion);
        query1 = query1.or('locked_until.is.null,locked_until.lt.$now');

        if (excludedIds.isNotEmpty) {
          query1 = query1.filter('id', 'not.in', '(${excludedIds.join(',')})');
        }

        final res1 = await query1.limit(20);
        finalSuggestions.addAll((res1 as List).map((e) => UserModel.fromJson(e)).toList());
      }

      // BƯỚC 2: BÙ ĐẮP NẾU THIẾU
      if (finalSuggestions.length < 20) {
        int remaining = 20 - finalSuggestions.length;
        var query2 = _supabase.from('users').select();
        query2 = query2.neq('role', 'admin').neq('role', 'own').neq('role', 'guest');
        query2 = query2.or('locked_until.is.null,locked_until.lt.$now');

        Set<String> allExcludedIds = {...excludedIds, ...finalSuggestions.map((e) => e.id)};
        if (allExcludedIds.isNotEmpty) {
          query2 = query2.filter('id', 'not.in', '(${allExcludedIds.join(',')})');
        }

        final res2 = await query2.order('created_at', ascending: false).limit(remaining);
        finalSuggestions.addAll((res2 as List).map((e) => UserModel.fromJson(e)).toList());
      }

      finalSuggestions.shuffle();
      return finalSuggestions;
    } catch (e) {
      debugPrint("UserService - fetchSuggestions error: $e");
      return [];
    }
  }

  // --- Lấy Avatar của user hiện tại---
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