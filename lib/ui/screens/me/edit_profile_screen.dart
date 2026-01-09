import 'package:flutter/material.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chỉnh sửa trang cá nhân")),
      body: const Center(child: Text("Màn hình chỉnh sửa thông tin")),
    );
  }
}