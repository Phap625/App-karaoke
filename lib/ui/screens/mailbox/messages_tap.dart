import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../../models/user_model.dart';
import '../me/user_profile_screen.dart';
import '../auth/login_screen.dart';
import 'chat_screen.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  // Dữ liệu
  List<UserModel> _allFriends = [];
  List<UserModel> _localSearchResults = [];
  List<UserModel> _globalSearchResults = [];

  // Trạng thái UI
  bool _isLoadingFriends = true;
  bool _isSearching = false;
  bool _isGlobalLoading = false;
  bool _showGlobalResults = false;

  // Trạng thái Guest
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _checkGuestAndFetchData();
  }

  // --- 0. KIỂM TRA GUEST VÀ TẢI DỮ LIỆU ---
  void _checkGuestAndFetchData() {
    final currentUser = _supabase.auth.currentUser;
    final isGuest = currentUser == null || currentUser.userMetadata?['role'] == 'guest';

    if (isGuest) {
      setState(() {
        _isGuest = true;
        _isLoadingFriends = false;
      });
    } else {
      setState(() {
        _isGuest = false;
      });
      _fetchFriends();
    }
  }

  // 1. TẢI DANH SÁCH BẠN BÈ (Local Cache)
  Future<void> _fetchFriends() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('friends_view')
          .select()
          .eq('user_id', userId);

      final List<UserModel> loadedFriends = (response as List)
          .map((data) => UserModel.fromFriendView(data))
          .toList();

      if (mounted) {
        setState(() {
          _allFriends = loadedFriends;
          _localSearchResults = loadedFriends;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      debugPrint("Lỗi tải bạn bè: $e");
      if (mounted) setState(() => _isLoadingFriends = false);
    }
  }

  // 2. XỬ LÝ KHI GÕ TEXT
  void _onSearchChanged(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      _showGlobalResults = false;
      _globalSearchResults = [];

      if (query.isEmpty) {
        _localSearchResults = _allFriends;
      } else {
        final lowerQuery = query.toLowerCase();
        _localSearchResults = _allFriends.where((user) {
          return user.fullName!.toLowerCase().contains(lowerQuery) ||
              user.username!.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
  }

  // 3. TÌM NGƯỜI LẠ (API Global)
  Future<void> _searchGlobal() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isGlobalLoading = true;
      _showGlobalResults = true;
    });

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      final response = await _supabase
          .from('users')
          .select()
          .or('username.ilike.%$query%, email.eq.$query, full_name.ilike.%$query%')
          .neq('id', currentUserId!)
          .neq('role', 'admin')
          .neq('role', 'own')
          .neq('role', 'guest')
          .limit(10);

      final List<UserModel> results = (response as List)
          .map((data) => UserModel.fromSearch(data, isFriend: false))
          .toList();

      final friendIds = _allFriends.map((e) => e.id).toSet();
      final filteredResults = results.where((u) => !friendIds.contains(u.id)).toList();

      if (mounted) {
        setState(() {
          _globalSearchResults = filteredResults;
          _isGlobalLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Lỗi tìm người lạ: $e");
      if (mounted) {
        setState(() {
          _isGlobalLoading = false;
          _globalSearchResults = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi tìm kiếm: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isGuest) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded, size: 60, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              const Text(
                "Tính năng dành cho thành viên",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Vui lòng đăng nhập để nhắn tin và trò chuyện cùng bạn bè trên Karaoke Plus.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginScreen(
                          onLoginSuccess: (bool isSuccess) {
                            if (isSuccess) {
                              Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/home',
                                      (route) => false
                              );
                            }
                          },
                          initialErrorMessage: null,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF00CC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Đăng nhập / Đăng ký",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- NẾU LÀ USER: HIỆN GIAO DIỆN CHAT BÌNH THƯỜNG ---
    return Column(
      children: [
        // Thanh tìm kiếm
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchGlobal(),
            decoration: InputDecoration(
              hintText: "Tìm bạn bè, username...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                  FocusScope.of(context).unfocus();
                },
              )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),

        // Danh sách
        Expanded(
          child: _isLoadingFriends
              ? const Center(child: CircularProgressIndicator())
              : ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              // Kết quả local
              if (!_showGlobalResults && _localSearchResults.isEmpty && _isSearching)
                const SizedBox.shrink()
              else if (!_showGlobalResults)
                ..._localSearchResults.map((user) => _buildUserItem(user)),

              // Nút tìm Global
              if (_isSearching && !_showGlobalResults)
                InkWell(
                  onTap: _searchGlobal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    margin: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.public, color: Colors.blue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                                  children: [
                                    const TextSpan(text: "Tìm người lạ: "),
                                    TextSpan(
                                      text: '"${_searchController.text}"',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Tìm kiếm trên toàn hệ thống",
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

              // Kết quả Global
              if (_isGlobalLoading)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: CircularProgressIndicator()),
                ),

              if (_showGlobalResults) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text("Kết quả từ hệ thống", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),

                if (_globalSearchResults.isEmpty && !_isGlobalLoading)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text("Không tìm thấy người dùng này.", style: TextStyle(color: Colors.grey))),
                  ),

                ..._globalSearchResults.map((user) => _buildUserItem(user)),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserItem(UserModel user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[200],
        backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
            ? NetworkImage(user.avatarUrl!)
            : null,
        child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
            ? Text(
          (user.fullName != null && user.fullName!.isNotEmpty)
              ? user.fullName![0].toUpperCase()
              : (user.username != null && user.username!.isNotEmpty)
              ? user.username![0].toUpperCase()
              : "?",
          style: const TextStyle(fontWeight: FontWeight.bold),
        )
            : null,
      ),
      title: Text(
          user.fullName ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold)
      ),
      subtitle: Text(
        user.isFriend
            ? "@${user.username ?? ''} • Bạn bè"
            : "@${user.username ?? ''} • Người lạ",
      ),
      trailing: user.isFriend
          ? const Icon(Icons.chat_bubble_outline, color: Color(0xFFFF00CC))
          : OutlinedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(targetUser: user),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          side: const BorderSide(color: Color(0xFFFF00CC)),
        ),
        child: const Text("Nhắn tin", style: TextStyle(fontSize: 12, color: Color(0xFFFF00CC))),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(user: user),
          ),
        );
      },
    );
  }
}