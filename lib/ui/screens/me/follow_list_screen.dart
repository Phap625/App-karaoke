import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/user_model.dart';
import '../../widgets/user_list_tile.dart';

class FollowListScreen extends StatefulWidget {
  final UserModel targetUser; // Người mà chúng ta đang xem danh sách của họ
  final int initialTabIndex;

  const FollowListScreen({
    super.key,
    required this.targetUser,
    this.initialTabIndex = 0
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Khởi tạo TabController với index được truyền vào (0: Following, 1: Follower, 2: Suggestion)
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("@${widget.targetUser.username}"),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF00CC),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF00CC),
          tabs: const [
            Tab(text: "Đang follow"),
            Tab(text: "Follower"),
            Tab(text: "Đề xuất"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(type: 'following'),
          _buildUserList(type: 'follower'),
          _buildSuggestedList(),
        ],
      ),
    );
  }

  // --- 1. WIDGET HIỂN THỊ DANH SÁCH FOLLOWING/FOLLOWER (ĐÃ SỬA) ---
  Widget _buildUserList({required String type}) {
    return FutureBuilder<List<UserModel>>(
      future: _fetchFollowData(type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text("Lỗi: ${snapshot.error}"));

        final users = snapshot.data ?? [];
        if (users.isEmpty) return const Center(child: Text("Chưa có danh sách."));

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            // SỬA TẠI ĐÂY: Bật nút Follow cho cả danh sách Follower/Following
            return UserListTile(
              user: users[index],
              showFollowButton: true, // <--- Thêm dòng này để hiện nút
            );
          },
        );
      },
    );
  }

  // --- 2. WIDGET HIỂN THỊ DANH SÁCH ĐỀ XUẤT ---
  Widget _buildSuggestedList() {
    return FutureBuilder<List<UserModel>>(
      future: _fetchSuggestions(currentProfileViewingId: widget.targetUser.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) return const Center(child: Text("Không có đề xuất phù hợp."));

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) => UserListTile(
              user: users[index],
              showFollowButton: true // Đề xuất thì mặc định luôn hiện
          ),
        );
      },
    );
  }

  // --- 3. LOGIC LẤY FOLLOWING/FOLLOWER TỪ SUPABASE ---
  Future<List<UserModel>> _fetchFollowData(String type) async {
    String foreignKey;
    String columnToFilter;

    if (type == 'following') {
      // Lấy danh sách người mà TargetUser đang theo dõi
      foreignKey = 'follows_following_id_fkey';
      columnToFilter = 'follower_id';
    } else {
      // Lấy danh sách người đang theo dõi TargetUser
      foreignKey = 'follows_follower_id_fkey';
      columnToFilter = 'following_id';
    }

    try {
      final response = await _supabase
          .from('follows')
          .select('users!$foreignKey(*)')
          .eq(columnToFilter, widget.targetUser.id);

      final dataList = response as List;
      return dataList.map((e) => UserModel.fromJson(e['users'])).toList();
    } catch (e) {
      debugPrint("Lỗi fetch follow data: $e");
      return [];
    }
  }

  // --- 4. LOGIC LẤY ĐỀ XUẤT THÔNG MINH ---
  Future<List<UserModel>> _fetchSuggestions({String? currentProfileViewingId}) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return [];

    try {
      // 1. Lấy Region của bản thân
      final viewerRes = await _supabase
          .from('users')
          .select('region')
          .eq('id', currentUser.id)
          .single();
      final String? viewerRegion = viewerRes['region'];

      // 2. Lấy danh sách những người MÌNH ĐÃ FOLLOW để loại trừ
      final followingRes = await _supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUser.id);

      // 3. Tạo danh sách đen (Excluded IDs)
      final List<String> excludedIds = [];
      excludedIds.add(currentUser.id); // Trừ chính mình
      if (currentProfileViewingId != null) {
        excludedIds.add(currentProfileViewingId);
      }
      if (followingRes != null) {
        final List followingList = followingRes as List;
        for (var item in followingList) {
          excludedIds.add(item['following_id']);
        }
      }

      List<UserModel> finalSuggestions = [];

      // BƯỚC 1: ƯU TIÊN CÙNG TỈNH
      if (viewerRegion != null && viewerRegion.isNotEmpty) {
        var query1 = _supabase.from('users').select();
        query1 = query1.neq('role', 'admin');
        query1 = query1.neq('role', 'own');
        query1 = query1.eq('region', viewerRegion);

        if (excludedIds.isNotEmpty) {
          final filterString = '(${excludedIds.join(',')})';
          query1 = query1.filter('id', 'not.in', filterString);
        }

        final res1 = await query1.limit(20);
        final List<UserModel> list1 = (res1 as List).map((e) => UserModel.fromJson(e)).toList();
        finalSuggestions.addAll(list1);
      }

      // BƯỚC 2: BÙ ĐẮP NẾU THIẾU
      if (finalSuggestions.length < 20) {
        int remaining = 20 - finalSuggestions.length;
        var query2 = _supabase.from('users').select();
        query2 = query2.neq('role', 'admin');
        query2 = query2.neq('role', 'own');
        query2 = query2.neq('role', 'guest');

        List<String> currentFetchedIds = finalSuggestions.map((e) => e.id).toList();
        List<String> allExcludedIds = [...excludedIds, ...currentFetchedIds];

        if (allExcludedIds.isNotEmpty) {
          final filterString = '(${allExcludedIds.join(',')})';
          query2 = query2.filter('id', 'not.in', filterString);
        }
        final res2 = await query2.order('created_at', ascending: false).limit(remaining);
        final List<UserModel> list2 = (res2 as List).map((e) => UserModel.fromJson(e)).toList();
        finalSuggestions.addAll(list2);
      }

      finalSuggestions.shuffle();
      return finalSuggestions;

    } catch (e) {
      debugPrint("Lỗi fetch suggestions: $e");
      return [];
    }
  }
}