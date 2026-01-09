import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/notification_model.dart';
import '../../widgets/notification_item.dart';
import '../../widgets/system_notification_tile.dart';
import '../../../services/base_service.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({Key? key}) : super(key: key);

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  final _supabase = Supabase.instance.client;
  final _baseService = BaseService(); // 1. Khởi tạo BaseService

  // State chứa dữ liệu
  List<NotificationModel> _notifications = [];
  NotificationModel? _latestSystemNotification;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _setupRealtimeSubscription();
  }

  // Hàm lấy dữ liệu từ VIEW
  Future<void> _fetchNotifications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 2. Dùng safeExecution để tự động bắt lỗi mạng và hiện Dialog Retry
      final List<dynamic> response = await _baseService.safeExecution(() async {
        return await _supabase
            .from('all_notifications_view')
            .select()
            .order('created_at', ascending: false);
      });

      final allData = response.map((json) => NotificationModel.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          // --- LOGIC MỚI: ĐỊNH NGHĨA THẾ NÀO LÀ "SYSTEM/QUAN TRỌNG" ---
          bool isSystemOrAdminMsg(NotificationModel n) {
            // 1. Là thông báo hệ thống (Broadcast)
            if (n.category == 'system') return true;

            // 2. Là tin nhắn cá nhân nhưng do Admin gửi (warning, info, success)
            final type = (n.type ?? '').trim().toLowerCase();
            return ['warning', 'info', 'success'].contains(type);
          }

          // 1. Lấy thông báo Quan Trọng mới nhất
          final systemList = allData.where((e) => isSystemOrAdminMsg(e));
          _latestSystemNotification = systemList.isNotEmpty ? systemList.first : null;

          // 2. Lấy danh sách hoạt động cá nhân (Like, Comment...)
          _notifications = allData.where((e) => !isSystemOrAdminMsg(e)).toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Lỗi tải thông báo (Không phải lỗi mạng hoặc đã cancel): $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Hàm lắng nghe Realtime (Giữ nguyên, Realtime tự có cơ chế reconnect)
  void _setupRealtimeSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _supabase.channel('public:notifications_tab')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        debugPrint("🔔 Change in Notifications: ${payload.eventType}");
        _fetchNotifications();
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'system_notifications',
      callback: (payload) {
        debugPrint("🔔 Change in System Notifications");
        _fetchNotifications();
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'system_read_status',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        _fetchNotifications();
      },
    )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notifications.isEmpty && _latestSystemNotification == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("Chưa có thông báo nào", style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 10),
            // Nút thử lại thủ công (Optional)
            TextButton.icon(
                onPressed: _fetchNotifications,
                icon: const Icon(Icons.refresh),
                label: const Text("Tải lại")
            )
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // --- PHẦN 1: THÔNG BÁO HỆ THỐNG ---
          if (_latestSystemNotification != null) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text("Quan trọng", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            SystemNotificationTile(
              notification: _latestSystemNotification,
              onRefresh: _fetchNotifications,
            ),
            const Divider(height: 30, thickness: 1),
          ],

          // --- PHẦN 2: HOẠT ĐỘNG CÁ NHÂN ---
          if (_notifications.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text("Mới nhất", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ..._notifications.map((noti) => NotificationItem(notification: noti)).toList(),
          ]
        ],
      ),
    );
  }
}