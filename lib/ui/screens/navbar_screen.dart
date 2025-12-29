import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/song_model.dart';
import '../../services/auth_service.dart';
import 'home/home_screen.dart';
import 'me/me_screen.dart';
import 'songs/songs_screen.dart';
import 'moments/moments_screen.dart';
import 'message/message_screen.dart';

class NavbarScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final Function(SongModel) onSongClick;

  const NavbarScreen({
    Key? key,
    required this.onLogout,
    required this.onSongClick,
  }) : super(key: key);

  @override
  State<NavbarScreen> createState() => _NavbarScreenState();
}

class _NavbarScreenState extends State<NavbarScreen> {
  int _selectedIndex = 0;

  // Subscription lắng nghe thay đổi User (Khóa / Xóa) từ Database
  StreamSubscription? _userDbSubscription;

  // Subscription lắng nghe trạng thái Auth (Token, SignOut...)
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // 1. Kiểm tra ngay khi màn hình này vừa hiện lên
    _checkInitialSession();

    // 2. Lắng nghe sự kiện đăng xuất/hết hạn token từ Supabase SDK
    _setupAuthListener();

    // 3. Lắng nghe Realtime từ Database (Khóa & Xóa)
    _setupAccountListener();
  }

  @override
  void dispose() {
    _userDbSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  // --- 1. KIỂM TRA SESSION BAN ĐẦU ---
  void _checkInitialSession() async {
    final bool hasSession = AuthService.instance.isLoggedIn;

    if (!hasSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AuthService.instance.handleTokenExpired(context);
        }
      });
    }
  }

  // --- 2. LẮNG NGHE SỰ KIỆN AUTH (SDK) ---
  void _setupAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;

      // Các sự kiện cho thấy phiên đăng nhập đã kết thúc
      if (event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.userDeleted ||
          (event == AuthChangeEvent.tokenRefreshed && data.session == null)) {

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      }
    });
  }

  // --- 3. LOGIC LẮNG NGHE REALTIME DB (KHÓA & XÓA) ---
  void _setupAccountListener() {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    _userDbSubscription = Supabase.instance.client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .listen((List<Map<String, dynamic>> data) {

      // [CASE 1]: BỊ XÓA
      if (data.isEmpty) {
        print("🔥 REALTIME: Tài khoản (User/Guest) đã bị xóa -> Force Logout");
        _forceLogout(isDeleted: true);
        return;
      }

      if (AuthService.instance.isGuest) return;

      // [CASE 2]: BỊ KHÓA (Chỉ User thường mới chạy xuống đây)
      if (data.isNotEmpty) {
        final userData = data.first;
        final lockedUntilStr = userData['locked_until'];
        if (lockedUntilStr != null) {
          DateTime lockedTime = DateTime.parse(lockedUntilStr);
          if (lockedTime.isAfter(DateTime.now())) {
            print("🔒 REALTIME: User bị khóa -> Force Logout");
            _forceLogout(isDeleted: false);
          }
        }
      }
    });
  }

  // Hàm xử lý Logout bắt buộc (Dùng chung cho Xóa và Khóa)
  Future<void> _forceLogout({required bool isDeleted}) async {
    // 1. Hủy lắng nghe để tránh loop
    _userDbSubscription?.cancel();
    _authSubscription?.cancel();

    // 2. Logout khỏi hệ thống
    await AuthService.instance.logout();

    if (!mounted) return;

    // 3. Hiển thị Dialog thông báo
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(isDeleted ? "Tài khoản không tồn tại" : "Tài khoản bị khóa"),
        content: Text(isDeleted
            ? "Tài khoản của bạn đã bị xóa khỏi hệ thống."
            : "Tài khoản của bạn đã bị khóa do vi phạm quy định."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Chuyển thẳng về Login và xóa stack
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: const Text("Đồng ý", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- UI CHÍNH ---
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const MomentsScreen();
      case 2:
        return SongsScreen(
          onSongClick: (song) {
            widget.onSongClick(song);
          },
        );
      case 3:
        return const MessageScreen();
      case 4:
        return MeScreen(
          onLogoutClick: widget.onLogout,
        );
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFF00CC);

    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildBody(),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: Colors.transparent,
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black);
            }
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.black);
          }),
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: primaryColor),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.access_time_outlined),
              selectedIcon: Icon(Icons.access_time_filled, color: primaryColor),
              label: 'Khoảnh khắc',
            ),
            NavigationDestination(
              icon: Icon(Icons.mic_none),
              selectedIcon: Icon(Icons.mic, color: primaryColor),
              label: 'Hát',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble, color: primaryColor),
              label: 'Tin nhắn',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: primaryColor),
              label: 'Tôi',
            ),
          ],
        ),
      ),
    );
  }
}