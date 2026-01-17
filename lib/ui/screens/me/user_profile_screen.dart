import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../mailbox/chat_screen.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/user_service.dart';
import '../../../services/report_service.dart';
import '../../widgets/report_dialog.dart';
import 'follow_list_screen.dart';
import 'me_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final UserModel user;

  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;

  late UserModel _displayUser;

  bool _isFollowing = false;
  bool _isFollowedByTarget = false;
  bool _isFriend = false;
  bool _isLoadingFollow = false;
  bool _blockedByMe = false;

  // Biến kiểm tra trạng thái khóa
  bool _isLocked = false;

  // Stats
  int _followerCount = 0;
  int _followingCount = 0;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _displayUser = widget.user;

    _followerCount = widget.user.followersCount;
    _followingCount = widget.user.followingCount;
    _likeCount = widget.user.likesCount;

    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _fetchUserDetails(),
      _checkFollowStatus(),
      _fetchStats(),
      _fetchBlockStatus(),
    ]);
  }

  // --- Kiểm tra trạng thái chặn ---
  Future<void> _fetchBlockStatus() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final status = await UserService.instance.checkBlockStatus(currentUserId, widget.user.id);

    if (mounted) {
      setState(() {
        _blockedByMe = status.blockedByMe;
      });
    }
  }

  // --- Xử lý Chặn ---
  Future<void> _confirmBlockUser() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Chặn ${_displayUser.fullName}?"),
        content: const Text("Họ sẽ không thể nhắn tin hoặc tìm thấy bạn."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Huỷ")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Chặn", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await UserService.instance.blockUser(currentUserId, widget.user.id);

        setState(() {
          _blockedByMe = true;
          _isFollowing = false;
          _isFriend = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Đã chặn người dùng")),
          );
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi chặn người dùng!")));
      }
    }
  }

  // --- Xử lý Bỏ chặn ---
  Future<void> _handleUnblockAction() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Bỏ chặn người dùng?"),
        content: const Text("Bạn sẽ có thể nhận tin nhắn từ họ trở lại."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Huỷ")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Bỏ chặn", style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await UserService.instance.unblockUser(currentUserId, widget.user.id);

        setState(() {
          _blockedByMe = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Đã bỏ chặn")),
          );
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi kết nối!")));
      }
    }
  }

  // --- Xử lý Báo cáo ---
  void _handleReportUser() {
    ReportModal.show(
      context,
      targetType: ReportTargetType.user,
      targetId: widget.user.id,
      contentTitle: _displayUser.fullName ?? "Người dùng này",
    );
  }

  // 1. LẤY CHI TIẾT USER (Cập nhật check khóa)
  Future<void> _fetchUserDetails() async {
    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('id', widget.user.id)
          .single();

      if (mounted) {
        setState(() {
          _displayUser = UserModel.fromJson(data);

          // Kiểm tra logic khóa
          if (data['locked_until'] != null) {
            final lockedUntil = DateTime.parse(data['locked_until']);
            if (lockedUntil.isAfter(DateTime.now())) {
              _isLocked = true;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Lỗi lấy user detail: $e");
    }
  }

  // 2. Kiểm tra follow
  Future<void> _checkFollowStatus() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;
    try {
      final results = await Future.wait([
        _supabase.from('follows').count().eq('follower_id', currentUserId).eq('following_id', widget.user.id),
        _supabase.from('follows').count().eq('follower_id', widget.user.id).eq('following_id', currentUserId),
      ]);
      if (mounted) {
        setState(() {
          _isFollowing = results[0] > 0;
          _isFollowedByTarget = results[1] > 0;
          _isFriend = _isFollowing && _isFollowedByTarget;
        });
      }
    } catch (e) {
      debugPrint("Lỗi check follow: $e");
    }
  }

  // 3. Lấy số liệu
  Future<void> _fetchStats() async {
    if (_isLocked) return; // Nếu bị khóa thì không cần fetch stats
    try {
      final followers = await _supabase.from('follows').count().eq('following_id', widget.user.id);
      final following = await _supabase.from('follows').count().eq('follower_id', widget.user.id);
      if (mounted) setState(() { _followerCount = followers; _followingCount = following; });
    } catch (e) {
      debugPrint("Lỗi lấy stats: $e");
    }
  }

  // 4. Xử lý nút Follow
  Future<void> _handleFollowAction() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null || _isLoadingFollow) return;

    if (_isFollowing) {
      // UNFOLLOW LOGIC
      final String dialogTitle = _isFriend
          ? "Huỷ kết bạn với ${_displayUser.fullName}?"
          : "Huỷ theo dõi ${_displayUser.fullName}?";
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(dialogTitle),
          content: const Text("Bạn sẽ không nhận được thông báo mới từ họ nữa."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Huỷ")),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Đồng ý", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        setState(() { _isLoadingFollow = true; _isFollowing = false; _isFriend = false; _followerCount--; });
        bool success = await NotificationService.instance.unfollowUser(targetUserId: widget.user.id);
        if (!success && mounted) {
          setState(() { _isFollowing = true; _isFriend = _isFollowedByTarget; _followerCount++; _isLoadingFollow = false; });
        } else {
          if(mounted) setState(() => _isLoadingFollow = false);
        }
      }
    } else {
      // FOLLOW LOGIC (Chỉ chạy nếu không bị khóa)
      if (_isLocked) return;

      setState(() { _isLoadingFollow = true; _isFollowing = true; if (_isFollowedByTarget) _isFriend = true; _followerCount++; });
      bool success = await NotificationService.instance.followUser(targetUserId: widget.user.id);
      if (!success && mounted) {
        setState(() { _isFollowing = false; _isFriend = false; _followerCount--; _isLoadingFollow = false; });
      } else {
        if(mounted) setState(() => _isLoadingFollow = false);
      }
    }
  }

  void _navigateToFollowList(int initialTab) {
    if (_isLocked) return; // Không cho xem danh sách follow nếu bị khóa
    Navigator.push(context, MaterialPageRoute(builder: (context) => FollowListScreen(targetUser: _displayUser, initialTabIndex: initialTab)));
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _supabase.auth.currentUser?.id;

    if (currentUserId != null && widget.user.id == currentUserId) {
      return MeScreen(
        onLogoutClick: () async {
          await AuthService.instance.logout();
          if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Nếu bị khóa, ẩn menu action (block/report)
          if (!_isLocked)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onSelected: (value) {
                if (value == 'block') {
                  _confirmBlockUser();
                } else if (value == 'report') {
                  _handleReportUser();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                if (!_blockedByMe)
                  const PopupMenuItem<String>(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(Icons.block, color: Colors.red, size: 20),
                        SizedBox(width: 10),
                        Text('Chặn người dùng', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                const PopupMenuItem<String>(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag, color: Colors.black87, size: 20),
                      SizedBox(width: 10),
                      Text('Báo cáo'),
                    ],
                  ),
                ),
              ],
            )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Avatar
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200, width: 2)),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey.shade200,
                // Nếu bị khóa thì không hiện ảnh, chỉ hiện placeholder
                backgroundImage: (!_isLocked && _displayUser.avatarUrl != null && _displayUser.avatarUrl!.isNotEmpty)
                    ? NetworkImage(_displayUser.avatarUrl!)
                    : null,
                child: (_isLocked || _displayUser.avatarUrl == null || _displayUser.avatarUrl!.isEmpty)
                    ? Icon(Icons.person, size: 50, color: Colors.grey.shade400) // Avatar trắng/icon khi bị khóa
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // Tên và Username
            Text(_displayUser.fullName ?? "Người dùng", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 4),
            Text("@${_displayUser.username ?? 'unknown'}", style: TextStyle(fontSize: 15, color: Colors.grey[600])),
            const SizedBox(height: 12),

            // --- NỘI DUNG KHI BỊ KHÓA ---
            if (_isLocked) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      "Tài khoản này đang bị tạm khoá",
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ]
            // --- NỘI DUNG BÌNH THƯỜNG ---
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_displayUser.gender != null) ...[
                    Icon(_displayUser.gender == 'male' ? Icons.male : Icons.female, size: 16, color: _displayUser.gender == 'male' ? Colors.blue : Colors.pink),
                    const SizedBox(width: 4),
                    Text(_displayUser.gender == 'male' ? "Nam" : "Nữ"),
                    const SizedBox(width: 15),
                  ],
                  if (_displayUser.region != null && _displayUser.region!.isNotEmpty) ...[
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(_displayUser.region!),
                  ]
                ],
              ),
              if (_displayUser.bio != null && _displayUser.bio!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(_displayUser.bio!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
                ),
              ],
              const SizedBox(height: 24),
              // Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem("Đang follow", _followingCount, () => _navigateToFollowList(0)),
                    Container(width: 1, height: 30, color: Colors.grey.shade300),
                    _buildStatItem("Follower", _followerCount, () => _navigateToFollowList(1)),
                    Container(width: 1, height: 30, color: Colors.grey.shade300),
                    _buildStatItem("Thích", _likeCount, () {}),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // --- BUTTONS ---
            if (!(_isLocked && !_isFollowing))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: _blockedByMe
                            ? ElevatedButton(
                          onPressed: _handleUnblockAction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("Bỏ chặn", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        )
                            : ElevatedButton(
                          onPressed: _isLoadingFollow ? null : _handleFollowAction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_isFriend || _isFollowing) ? Colors.grey[200] : const Color(0xFFFF00CC),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isLoadingFollow
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isFriend ? Icons.people_alt_rounded : (_isFollowing ? Icons.check : Icons.add),
                                color: (_isFriend || _isFollowing) ? Colors.black87 : Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isFriend ? "Bạn bè" : (_isFollowing ? "Đang follow" : "Follow"),
                                style: TextStyle(color: (_isFriend || _isFollowing) ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Nếu KHÔNG bị khóa thì mới hiện nút chat
                    if (!_isLocked) ...[
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 45,
                        width: 45,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(targetUser: _displayUser)));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Icon(Icons.chat_bubble_outline, color: Colors.black87),
                        ),
                      ),
                    ]
                  ],
                ),
              ),

            // --- MOMENTS (Chỉ hiện khi không khóa) ---
            if (!_isLocked) ...[
              const SizedBox(height: 30),
              const Divider(thickness: 1, height: 1),
              // Moments
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Khoảnh khắc", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.image_not_supported_outlined, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          Text("${_displayUser.fullName} chưa có khoảnh khắc nào.", style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  ],
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Text("$value", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}