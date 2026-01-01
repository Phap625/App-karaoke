import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final Function(bool) onLoginSuccess;
  final String? initialErrorMessage;

  const LoginScreen({
    Key? key,
    required this.onLoginSuccess,
    this.initialErrorMessage,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialErrorMessage != null && widget.initialErrorMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showToast(widget.initialErrorMessage!, isError: true);
      });
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.black87,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      _showToast("Vui lòng nhập tài khoản và mật khẩu");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.instance
          .login(identifier: identifier, password: password);
      _showToast("Đăng nhập thành công!");

      widget.onLoginSuccess(true);
    } catch (e) {
      String msg = e.toString();
      if (msg.contains("Exception:"))
        msg = msg.replaceAll("Exception:", "").trim();
      _showToast(msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFF00CC);

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ],
                      gradient: const LinearGradient(
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
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- INPUT FIELDS ---
                  TextField(
                    controller: _identifierController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: "Email hoặc Tên đăng nhập",
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.person_outline, color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _passwordController,
                    enabled: !_isLoading,
                    obscureText: _obscurePassword,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: "Mật khẩu",
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey[600],
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/reset_password');
                      },
                      child: Text("Quên mật khẩu?",
                          style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        elevation: 3,
                        shadowColor: primaryColor.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white))
                          : const Text("ĐĂNG NHẬP",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () async {
                      try {
                        await AuthService.instance.loginAsGuest();
                        if (mounted)
                          Navigator.pushReplacementNamed(context, '/home');
                      } catch (e) {
                        _showToast("Lỗi đăng nhập khách");
                      }
                    },
                    child: const Text("Đăng nhập bằng tài khoản khách", style: TextStyle(color: Colors.black54)),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Chưa có tài khoản? ", style: TextStyle(color: Colors.black54)),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: const Text("Đăng ký ngay",
                            style: TextStyle(
                                color: Color(0xFFFF00CC),
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}