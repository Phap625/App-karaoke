import 'package:flutter/material.dart';



class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cài đặt")),
      body: const Center(child: Text("Màn hình cài đặt")),
    );
  }
}
