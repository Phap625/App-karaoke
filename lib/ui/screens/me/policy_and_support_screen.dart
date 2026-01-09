import 'package:flutter/material.dart';


class PolicyAndSupportScreen extends StatelessWidget {
  const PolicyAndSupportScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chính sách & Hỗ trợ")),
      body: const Center(child: Text("Nội dung chính sách và hỗ trợ")),
    );
  }
}

