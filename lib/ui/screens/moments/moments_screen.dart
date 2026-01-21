import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:shimmer/shimmer.dart';
import '../../../models/moment_model.dart';
import '../../../services/moment_service.dart';
import '../../../services/user_service.dart';
import '../../../services/auth_service.dart';
import '../../widgets/moment_item.dart';
import '../me/me_recordings_screen.dart';

class MomentsScreen extends StatefulWidget {
  const MomentsScreen({super.key});

  @override
  State<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends State<MomentsScreen> {
  final _supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();

  List<Moment> _moments = [];
  final Set<int> _pendingViewIds = {};
  Timer? _viewTimer;
  String? _myDbAvatar;
  bool _isGuest = false;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  int _currentLimit = 10;
  final int _pageSize = 10;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _isGuest = AuthService.instance.isGuest;
    _loadData();
    _viewTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _flushViewsToServer();
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMoreData &&
          !_isInitialLoading) {
        _loadMoreData();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _viewTimer?.cancel();
    _flushViewsToServer();
    super.dispose();
  }

  // --- Hàm xử lý khi xoá Moment ---
  void _handleDeleteMoment(int momentId) {
    setState(() {
      _moments.removeWhere((m) => m.id == momentId);
    });
  }

  // -- Hàm đẩy dữ liệu view lên server ---
  void _flushViewsToServer() {
    if (_pendingViewIds.isEmpty) return;
    final listToSend = _pendingViewIds.toList();
    _pendingViewIds.clear();
    MomentService.instance.markMomentsAsViewed(listToSend);
  }

  // --- Hàm xử lý khi 1 item xuất hiện ---
  void _onItemVisible(int momentId) {
    _pendingViewIds.add(momentId);
    if (_pendingViewIds.length >= 10) {
      _flushViewsToServer();
    }
  }

  // --- Hiện thông báo với Guest ---
  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yêu cầu đăng nhập"),
        content: const Text("Bạn cần đăng nhập để chia sẻ khoảnh khắc của mình."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Đóng", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.instance.logout();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: const Text("Đăng nhập", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Hàm load dữ liệu ban đầu (Đồng bộ avatar + feed)
  Future<void> _loadData() async {
    setState(() => _isInitialLoading = true);
    _currentLimit = _pageSize;
    _hasMoreData = true;

    try {
      final results = await Future.wait([
        MomentService.instance.getPublicFeed(limit: _currentLimit, offset: 0),
        UserService.instance.getCurrentUserAvatar(),
      ]);

      if (mounted) {
        setState(() {
          _moments = results[0] as List<Moment>;
          _myDbAvatar = results[1] as String?;
          if (_moments.length < _currentLimit) _hasMoreData = false;
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Lỗi load feed: $e");
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  // Hàm load thêm dữ liệu (Lazy Loading)
  Future<void> _loadMoreData() async {
    setState(() => _isLoadingMore = true);

    try {
      final newOffset = _moments.length;
      final newMoments = await MomentService.instance.getPublicFeed(
          limit: _pageSize,
          offset: newOffset
      );

      if (mounted) {
        setState(() {
          if (newMoments.isEmpty) {
            _hasMoreData = false;
          } else {
            _moments.addAll(newMoments);
            if (newMoments.length < _pageSize) _hasMoreData = false;
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // Refresh chỉ feed
  Future<void> _refreshFeedOnly() async {
    _currentLimit = _pageSize;
    _hasMoreData = true;
    final moments = await MomentService.instance.getPublicFeed(limit: _currentLimit, offset: 0);
    if (mounted) {
      setState(() {
        _moments = moments;
      });
    }
  }

  void _onUploadPressed() async {
    if (_isGuest) {
      _showLoginDialog();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MeRecordingsScreen(isPickingMode: true),
      ),
    );
    if (mounted) {
      setState(() => _isInitialLoading = true);
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        await _refreshFeedOnly();
      } catch (e) {
        debugPrint("Lỗi refresh sau khi upload: $e");
      } finally {
        if (mounted) {
          setState(() => _isInitialLoading = false);
        }
      }
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
        color: const Color(0xFFA66BFF),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // PHẦN 1: HEADER (Đăng bài)
            SliverToBoxAdapter(
              child: _isInitialLoading
                  ? _buildHeaderSkeleton()
                  : _buildCreatePostArea(),
            ),

            // PHẦN 2: DANH SÁCH MOMENTS
            _isInitialLoading
                ? SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildMomentItemSkeleton(),
                childCount: 5,
              ),
            )
                : _moments.isEmpty
                ? const SliverFillRemaining(
              child: Center(
                child: Text("Chưa có khoảnh khắc nào.\nHãy là người đầu tiên chia sẻ!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)
                ),
              ),
            )
                : SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final moment = _moments[index];
                  return VisibilityDetector(
                    key: Key('moment-view-${moment.id}'),
                    onVisibilityChanged: (visibilityInfo) {
                      if (visibilityInfo.visibleFraction > 0.85) {
                        _onItemVisible(moment.id);
                      }
                    },
                    child: MomentItem(
                      moment: moment,
                      onDeleted: () => _handleDeleteMoment(moment.id),
                    ),
                  );
                },
                childCount: _moments.length,
              ),
            ),

            // PHẦN 3: SKELETON KHI LAZY LOAD
            if (_isLoadingMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _buildMomentItemSkeleton(),
                ),
              ),

            // Padding bottom
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatePostArea() {
    final displayAvatar = _myDbAvatar ?? _supabase.auth.currentUser?.userMetadata?['avatar_url'];

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

  Widget _buildHeaderSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 8)),
        ),
        child: Row(
          children: [
            const CircleAvatar(radius: 20, backgroundColor: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMomentItemSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 22, backgroundColor: Colors.white),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 14, color: Colors.white),
                    const SizedBox(height: 6),
                    Container(width: 80, height: 10, color: Colors.white),
                  ],
                )
              ],
            ),
            const SizedBox(height: 12),
            Container(width: double.infinity, height: 12, color: Colors.white),
            const SizedBox(height: 6),
            Container(width: 200, height: 12, color: Colors.white),
            const SizedBox(height: 12),
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 60, height: 20, color: Colors.white),
                Container(width: 60, height: 20, color: Colors.white),
                Container(width: 60, height: 20, color: Colors.white),
              ],
            )
          ],
        ),
      ),
    );
  }
}