import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/token_manager.dart';
import '../../utils/user_manager.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../services/base_service.dart';
import 'auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasNavigated = false;
  Timer? _safetyValveTimer;
  final BaseService _baseService = BaseService();

  @override
  void initState() {
    super.initState();
    _safetyValveTimer = Timer(const Duration(seconds: 20), () {
      if (!_hasNavigated && mounted) {
        debugPrint("SPLASH: 🚨 Safety Valve kích hoạt -> Ép về Login");
        _navigateToLogin(message: "Phản hồi quá lâu, vui lòng đăng nhập lại.");
      }
    });

    _checkAppState();
  }

  @override
  void dispose() {
    _safetyValveTimer?.cancel();
    super.dispose();
  }

  void _navigateToLogin({String? message}) {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _safetyValveTimer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(
          initialErrorMessage: message,
          onLoginSuccess: (bool isSuccess) {
            if (isSuccess) Navigator.pushReplacementNamed(context, '/home');
          },
        ),
      ),
    );
  }

  void _navigateToHome() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _safetyValveTimer?.cancel();

    debugPrint("SPLASH: ✅ Mọi thứ OK -> Vào Home");
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _checkAppState() async {
    try {
      debugPrint("SPLASH: 1. Đang lấy token...");
      final accessToken = await TokenManager.instance.getAccessToken();

      await Future.delayed(const Duration(seconds: 1));

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint("SPLASH: Không có token -> Login");
        _navigateToLogin();
        return;
      }

      debugPrint("SPLASH: 2. Gọi API (Dùng BaseService để tự Retry nếu mất mạng)...");

      await _baseService.safeExecution(() async {
        return await Future.wait([
          UserService.instance.getUserProfile(),
          UserManager.instance.checkSessionValidity(),
        ]).timeout(const Duration(seconds: 15));
      });

      _navigateToHome();

    } catch (e) {
      if (_hasNavigated) return;

      String errorMsg = e.toString();
      debugPrint("SPLASH: ❌ Lỗi (Không phải lỗi mạng hoặc User hủy Retry): $errorMsg");

      if (errorMsg.contains("đăng nhập trên thiết bị khác") || errorMsg.contains("bị khóa")) {
        await AuthService.instance.logout();
        _navigateToLogin(message: errorMsg);
        return;
      }

      try {
        debugPrint("SPLASH: 3. Có thể do Token hết hạn -> Thử Refresh...");

        final recovered = await _baseService.safeExecution(() async {
          return await AuthService.instance.recoverSession();
        });

        if (recovered) {
          await _baseService.safeExecution(() async {
            await UserManager.instance.checkSessionValidity();
          });

          _navigateToHome();
          return;
        }
      } catch (refreshErr) {
        debugPrint("SPLASH: Refresh thất bại hẳn -> $refreshErr");
      }

      debugPrint("SPLASH: Token không thể cứu vãn -> Logout");
      await AuthService.instance.logout();
      _navigateToLogin(message: "Phiên đăng nhập hết hạn.");
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
                "KARAOKE PLUS",
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