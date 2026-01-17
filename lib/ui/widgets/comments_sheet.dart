import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../services/moment_service.dart';

class CommentsSheet extends StatefulWidget {
  final int momentId;

  const CommentsSheet({super.key, required this.momentId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final MomentService _service = MomentService();
  final _supabase = Supabase.instance.client;
  bool _isSending = false;

  void _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    if (_isSending) return;
    setState(() => _isSending = true);
    FocusScope.of(context).unfocus();

    try {
      await _service.sendComment(widget.momentId, text);
      _commentController.clear();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Chiều cao bottom sheet = 80% màn hình
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ],
            ),
          ),
          const Text("Bình luận", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),

          // List Comments (Realtime)
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.getCommentsStream(widget.momentId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final comments = snapshot.data!;
                if (comments.isEmpty) {
                  return const Center(child: Text("Chưa có bình luận nào.", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return _CommentItem(
                      userId: comment['user_id'],
                      content: comment['content'],
                      createdAt: DateTime.parse(comment['created_at']),
                    );
                  },
                );
              },
            ),
          ),

          // Input Box
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16, // Đẩy lên khi có phím
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(_supabase.auth.currentUser?.userMetadata?['avatar_url'] ?? ''),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: "Thêm bình luận...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isSending ? null : _sendComment,
                  icon: const Icon(Icons.send, color: Color(0xFFFF00CC)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget con hiển thị từng dòng comment (Cần fetch user info)
class _CommentItem extends StatefulWidget {
  final String userId;
  final String content;
  final DateTime createdAt;

  const _CommentItem({required this.userId, required this.content, required this.createdAt});

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> {
  String _name = '...';
  String? _avatar;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final data = await MomentService().getUserProfile(widget.userId);
    if (mounted && data != null) {
      setState(() {
        _name = data['full_name'] ?? 'Ẩn danh';
        _avatar = data['avatar_url'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: _avatar != null ? NetworkImage(_avatar!) : null,
            child: _avatar == null ? const Icon(Icons.person, size: 16) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(timeago.format(widget.createdAt, locale: 'vi'),
                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(widget.content, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}