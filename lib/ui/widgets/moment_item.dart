import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:async';
import '../../models/moment_model.dart';
import '../screens/me/user_profile_screen.dart';
import '../../models/user_model.dart';
import '../../services/moment_service.dart';
import 'comments_sheet.dart';

class MomentItem extends StatefulWidget {
  final Moment moment;

  const MomentItem({super.key, required this.moment});

  @override
  State<MomentItem> createState() => _MomentItemState();
}

class _MomentItemState extends State<MomentItem> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  late bool _isLiked;
  late int _likesCount;
  late int _commentsCount;
  RealtimeChannel? _subscription;
  Timer? _debounce;
  final MomentService _service = MomentService();

  @override
  void initState() {
    super.initState();
    _setupAudio();
    _isLiked = widget.moment.isLiked;
    _likesCount = widget.moment.likesCount;
    _commentsCount = widget.moment.commentsCount;
    _subscribeToRealtimeChanges();
  }

  void _setupAudio() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.onPlayerComplete.listen((event) {
      if(mounted) setState(() => _position = Duration.zero);
    });
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 900), () async {
      try {
        await _service.toggleLike(widget.moment.id, _isLiked);

      } catch (e) {
        debugPrint("Lỗi sync like: $e");
        if (mounted) {
          setState(() {
            _isLiked = !_isLiked;
            _likesCount += _isLiked ? 1 : -1;
          });
        }
      }
    });
  }

  void _showComments() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(momentId: widget.moment.id),
    );
    _refreshStats();
  }

  void _subscribeToRealtimeChanges() {
    final momentId = widget.moment.id;

    // Tạo kênh lắng nghe riêng cho Moment này
    _subscription = Supabase.instance.client
        .channel('moment_changes_$momentId')
    // Lắng nghe bảng Likes
        .onPostgresChanges(
      event: PostgresChangeEvent.all, // Insert, Update, Delete
      schema: 'public',
      table: 'moment_likes',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'moment_id',
        value: momentId,
      ),
      callback: (payload) => _refreshStats(), // Có thay đổi -> Load lại số liệu
    )
    // Lắng nghe bảng Comments
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'moment_comments',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'moment_id',
        value: momentId,
      ),
      callback: (payload) => _refreshStats(),
    )
        .subscribe();
  }

  Future<void> _refreshStats() async {
    final stats = await MomentService().getMomentStats(widget.moment.id);
    if (stats != null && mounted) {
      setState(() {
        _likesCount = stats['likes_count'];
        _commentsCount = stats['comments_count'];

        // Lưu ý: is_liked có thể bị xung đột với Optimistic UI (nút bấm local)
        // Nên ta chỉ update is_liked nếu user KHÔNG đang bấm liên tục
        // Hoặc đơn giản là chỉ update count thôi.
        // Ở đây mình update luôn để đồng bộ 100%.
        _isLiked = stats['is_liked'];
      });
    }
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_subscription!);
    _audioPlayer.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _navigateToUserProfile() {
    final targetUser = UserModel(
      id: widget.moment.userId,
      fullName: widget.moment.userName,
      avatarUrl: widget.moment.userAvatar,
      role: 'user',
      email: null,
      username: null,
      bio: null,
      gender: null,
      region: null,
      lastActiveAt: null,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(user: targetUser),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeAgo = timeago.format(widget.moment.createdAt, locale: 'vi');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar + Tên + Thời gian
          Row(
            children: [
              // Bọc Avatar trong GestureDetector
              GestureDetector(
                onTap: _navigateToUserProfile,
                child: CircleAvatar(
                  radius: 22,
                  backgroundImage: widget.moment.userAvatar != null
                      ? NetworkImage(widget.moment.userAvatar!)
                      : null,
                  child: widget.moment.userAvatar == null
                      ? Text(widget.moment.userName?[0] ?? "?") : null,
                ),
              ),
              const SizedBox(width: 12),

              // Bọc phần tên trong GestureDetector (hoặc Expanded nếu muốn ấn cả vùng trống)
              Expanded(
                child: GestureDetector(
                  onTap: _navigateToUserProfile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.moment.userName ?? "Ẩn danh",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Row(
                        children: [
                          Text(
                            "$timeAgo • ",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          Icon(
                            widget.moment.visibility == 'public' ? Icons.public : Icons.people,
                            size: 12, color: Colors.grey.shade600,
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Description
          if (widget.moment.description != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.moment.description!,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),

          // --- AUDIO PLAYER UI (MÀU TÍM) ---
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFE6D6FC), // Màu tím nhạt nền
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Thời gian hiện tại
                Text(
                  _formatTime(_position),
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),

                // Thanh trượt
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      min: 0,
                      max: _duration.inSeconds.toDouble(),
                      value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
                      activeColor: Colors.white,
                      inactiveColor: Colors.white.withOpacity(0.5),
                      onChanged: (value) async {
                        final position = Duration(seconds: value.toInt());
                        await _audioPlayer.seek(position);
                      },
                    ),
                  ),
                ),

                // Nút Play/Pause
                GestureDetector(
                  onTap: () async {
                    if (_isPlaying) {
                      await _audioPlayer.pause();
                    } else {
                      await _audioPlayer.play(UrlSource(widget.moment.audioUrl));
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFA66BFF), // Màu tím đậm nút bấm
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // --- FOOTER: LIKE, COMMENT, SHARE ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _toggleLike,
                style: TextButton.styleFrom(
                  foregroundColor: _isLiked ? Colors.red : Colors.grey.shade600,
                ),
                icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, size: 20),
                label: Text("$_likesCount", style: const TextStyle(fontSize: 13)),
              ),

              // NÚT COMMENT
              TextButton.icon(
                onPressed: _showComments,
                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                icon: const Icon(Icons.comment_outlined, size: 20),
                label: Text("$_commentsCount", style: const TextStyle(fontSize: 13)),
              ),
              _buildActionBtn(Icons.share_outlined, "Chia sẻ"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label) {
    return TextButton.icon(
      onPressed: () {},
      style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}