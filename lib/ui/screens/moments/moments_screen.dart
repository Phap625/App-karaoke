import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/moment_model.dart';
import '../../../services/moment_service.dart';
import '../../widgets/moment_item.dart';
import '../me/me_recordings_screen.dart';

class MomentsScreen extends StatefulWidget {
  const MomentsScreen({super.key});

  @override
  State<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends State<MomentsScreen> {
  // Khởi tạo Service
  final MomentService _momentService = MomentService();
  final _supabase = Supabase.instance.client;

  List<Moment> _moments = [];
  bool _isLoading = true;
  String? _myDbAvatar;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Hàm load chung cho cả Pull-to-refresh
  Future<void> _loadData() async {
    // Chạy song song 2 tác vụ để tiết kiệm thời gian
    final results = await Future.wait([
      _momentService.getPublicFeed(),
      _momentService.getCurrentUserAvatar(),
    ]);

    if (mounted) {
      setState(() {
        _moments = results[0] as List<Moment>;
        _myDbAvatar = results[1] as String?;
        _isLoading = false;
      });
    }
  }

  // Hàm gọi riêng nếu chỉ muốn refresh list (ví dụ sau khi đăng bài)
  Future<void> _refreshFeedOnly() async {
    final moments = await _momentService.getPublicFeed();
    if (mounted) {
      setState(() {
        _moments = moments;
      });
    }
  }

  void _onUploadPressed() async {
    // Chờ người dùng chọn file và đăng bài bên kia xong
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MeRecordingsScreen(isPickingMode: true),
      ),
    );

    // Khi quay về, hiện loading nhẹ và refresh lại list
    if (mounted) {
      setState(() => _isLoading = true);
      // Delay nhỏ để đảm bảo server kịp lưu dữ liệu
      await Future.delayed(const Duration(milliseconds: 500));
      await _refreshFeedOnly();
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Khoảnh khắc", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // Phần 1: Khu vực đăng bài (Header)
            SliverToBoxAdapter(
              child: _buildCreatePostArea(),
            ),

            // Phần 2: Danh sách Moments
            _isLoading
                ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                : _moments.isEmpty
                ? const SliverFillRemaining(
              child: Center(
                child: Text("Chưa có khoảnh khắc nào.\nHãy là người đầu tiên chia sẻ!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ),
            )
                : SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  return MomentItem(moment: _moments[index]);
                },
                childCount: _moments.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatePostArea() {
    final metaAvatar = _supabase.auth.currentUser?.userMetadata?['avatar_url'];
    // Ưu tiên ảnh từ DB lấy qua Service, sau đó đến Meta
    final displayAvatar = _myDbAvatar ?? metaAvatar;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 8)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[200],
            backgroundImage: (displayAvatar != null && displayAvatar.isNotEmpty)
                ? NetworkImage(displayAvatar)
                : null,
            child: (displayAvatar == null || displayAvatar.isEmpty)
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: _onUploadPressed,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  "Chia sẻ bản thu âm của bạn...",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}