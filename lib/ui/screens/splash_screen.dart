import 'package:flutter/material.dart';
import '../../utils/token_manager.dart';
import '../../services/user_service.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAppState();
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(
          onLoginSuccess: (bool isSuccess) {
            if (isSuccess) {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
        ),
      ),
    );
  }

  Future<void> _checkAppState() async {
    // 1. Lấy token từ bộ nhớ máy
    final accessToken = await TokenManager.instance.getAccessToken();
    final hasToken = accessToken != null && accessToken.isNotEmpty;

    await Future.delayed(const Duration(seconds: 1));

    // === TRƯỜNG HỢP 1: KHÔNG CÓ TOKEN ===
    if (!hasToken) {
      debugPrint("SPLASH: Không tìm thấy token -> Chuyển sang màn hình Đăng nhập");
      _navigateToLogin();
      return;
    }

    // === TRƯỜNG HỢP 2: CÓ TOKEN (Cần kiểm tra xem còn hạn không) ===
    try {
      debugPrint("SPLASH: Tìm thấy token -> Đang kiểm tra với Server...");
      await UserService.instance.getUserProfile();
      debugPrint("SPLASH: Token hợp lệ -> Vào Home (User)");
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      // === TRƯỜNG HỢP 3: TOKEN HẾT HẠN HOẶC KHÔNG HỢP LỆ ===
      debugPrint("SPLASH: Token lỗi hoặc hết hạn: $e");
      await TokenManager.instance.clearAuth();
      _navigateToLogin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Phiên đăng nhập hết hạn, vui lòng đăng nhập lại."),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A0E7E),
              Color(0xE7500488),
              Color(0xFFB51196),
              Color(0xFF2D145C),
              Color(0xFF0A0527),
            ],
            stops: [0.0, 0.28, 0.46, 0.76, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.png',
                width: 280,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 20),

              const Text(
                "KARAOKE ENTERTAINMENT PLUS",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                  fontFamily: 'Roboto',
                ),
              ),

              const SizedBox(height: 50),

              // Loading indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF00CC)),
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}