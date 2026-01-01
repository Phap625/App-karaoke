import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart'; // Bắt buộc import cái này
import '../services/auth_service.dart';
import '../main.dart';

class UserManager {
  static final UserManager instance = UserManager._internal();
  UserManager._internal();

  // --- VARIABLES ---
  Timer? _idleTimer;
  StreamSubscription? _userDbSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  // Thời gian chờ cho phép (5 phút) trước khi gửi heartbeat
  final Duration _idleThreshold = const Duration(minutes: 5);

  // Key lưu Session ID của máy này
  static const String _kSessionIdKey = 'my_current_session_id';

  // Biến Cache ID trong RAM để so sánh nhanh hơn
  String? _cachedLocalSessionId;

  // ============================================================
  // PHẦN 1: INIT & DISPOSE
  // ============================================================
  Future<void> init() async {
    await Future.delayed(const Duration(seconds: 5));

    // 2. Tự động đồng bộ Session ID từ Token hiện tại
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await syncSessionFromToken(session.accessToken);
    }

    print("🛡️ User Manager: Đã khởi động (Heartbeat + Session ID Guard)");

    // 3. Bắt đầu các logic bảo vệ
    notifyApiActivity();
    _setupAuthListener();
    _setupAccountListener();
  }

  void dispose() {
    _idleTimer?.cancel();
    _userDbSubscription?.cancel();
    _authSubscription?.cancel();
    _cachedLocalSessionId = null;
    print("🛡️ User Manager: Đã dừng.");
  }

  // ============================================================
  // PHẦN 2: HELPER (Đồng bộ ID từ Token)
  // ============================================================

  // GỌI HÀM NÀY NGAY KHI LOGIN THÀNH CÔNG
  Future<String> syncSessionFromToken(String accessToken) async {
    try {
      // Giải mã Token để lấy session_id gốc của Supabase
      Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken);
      String sessionId = decodedToken['session_id'];

      // Lưu vào RAM và Disk
      _cachedLocalSessionId = sessionId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSessionIdKey, sessionId);

      print("✅ Local Session Synced: $sessionId");
      return sessionId;
    } catch (e) {
      print("❌ Lỗi decode token: $e");
      return "";
    }
  }

  Future<String?> _getLocalSessionId() async {
    if (_cachedLocalSessionId != null) return _cachedLocalSessionId;
    final prefs = await SharedPreferences.getInstance();
    _cachedLocalSessionId = prefs.getString(_kSessionIdKey);
    return _cachedLocalSessionId;
  }

  // ============================================================
  // PHẦN 3: LOGIC CHECK TỪ SPLASH SCREEN
  // ============================================================

  Future<void> checkSessionValidity() async {
    if (AuthService.instance.isGuest) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final localId = await _getLocalSessionId();

    // Lấy thông tin mới nhất từ Server
    final data = await Supabase.instance.client
        .from('users')
        .select('current_session_id, locked_until')
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      throw "Tài khoản không tồn tại!";
    }

    // 1. Check bị khóa
    final lockedUntilStr = data['locked_until'];
    if (lockedUntilStr != null) {
      DateTime lockedTime = DateTime.parse(lockedUntilStr).toLocal();
      if (lockedTime.isAfter(DateTime.now())) {
        throw "Tài khoản bị khóa đến ${lockedTime.toString()}";
      }
    }

    // 2. Check Session ID (Logic đá thiết bị)
    final serverSessionId = data['current_session_id'];

    if (serverSessionId != null && localId != null) {
      if (serverSessionId != localId) {
        throw "Tài khoản của bạn đã được đăng nhập trên thiết bị khác.";
      }
    }
  }

  // ============================================================
  // PHẦN 4: HEARTBEAT (Giữ kết nối)
  // ============================================================

  void notifyApiActivity() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleThreshold, () {
      _sendKeepAliveHeartbeat();
    });
  }

  Future<void> _sendKeepAliveHeartbeat() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      print("💓 Heartbeat: Update last_active_at");
      await Supabase.instance.client
          .from('users')
          .update({
        'last_active_at': DateTime.now().toUtc().toIso8601String(),
      })
          .eq('id', user.id);

      notifyApiActivity();
    } catch (e) {
      print("💓 Heartbeat Error: $e");
    }
  }

  // ============================================================
  // PHẦN 5: REALTIME LISTENER
  // ============================================================

  void _setupAccountListener() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || AuthService.instance.isGuest) return;

    // Đảm bảo đã có Local ID trước khi nghe
    String? localId = await _getLocalSessionId();
    if (localId == null) {
      // Cố gắng lấy lại từ session hiện tại nếu biến null
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        localId = await syncSessionFromToken(session.accessToken);
      }
    }

    print("🛡️ Realtime: Bắt đầu lắng nghe thay đổi của User...");

    _userDbSubscription = Supabase.instance.client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .handleError((err) {
      print("🔥 Realtime Error: $err");
    })
        .listen((List<Map<String, dynamic>> data) async {

      if (data.isEmpty) {
        _showForceLogoutDialog("Tài khoản lỗi", "Dữ liệu người dùng không tồn tại.");
        return;
      }

      final userData = data.first;
      final serverSessionId = userData['current_session_id'] as String?;

      // Lấy lại localId mới nhất
      localId = await _getLocalSessionId();

      // CASE A: KIỂM TRA SESSION ID
      if (localId != null && serverSessionId != null) {
        if (localId != serverSessionId) {
          print("🚨 KICK DEVICE: Local($localId) != Server($serverSessionId)");
          _showForceLogoutDialog(
              "Kết thúc phiên",
              "Tài khoản đã được đăng nhập trên thiết bị khác!"
          );
          return;
        }
      }

      // CASE B: KIỂM TRA BỊ KHÓA
      final lockedUntilStr = userData['locked_until'];
      if (lockedUntilStr != null) {
        DateTime lockedTime = DateTime.parse(lockedUntilStr).toLocal();
        if (lockedTime.isAfter(DateTime.now())) {
          _showForceLogoutDialog(
              "Tài khoản bị khóa",
              "Tài khoản bị khóa đến ${lockedTime.toString()}"
          );
        }
      }
    });
  }

  // ============================================================
  // PHẦN 6: AUTH LISTENER & UI HANDLING
  // ============================================================

  void _setupAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        dispose();
      }
    });
  }

  Future<void> _showForceLogoutDialog(String title, String message) async {
    dispose();

    // Xóa Local Session ID
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionIdKey);
    _cachedLocalSessionId = null;

    // Logout Supabase
    try { await AuthService.instance.logout(); } catch (_) {}

    final context = navigatorKey.currentContext;

    if (context != null && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Chuyển về màn Login
                  navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
                },
                child: const Text("Đồng ý", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      );
    } else {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}