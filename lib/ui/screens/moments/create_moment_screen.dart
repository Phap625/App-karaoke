import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;
import '../../../services/api_client.dart';

class CreateMomentScreen extends StatefulWidget {
  final File selectedFile;

  const CreateMomentScreen({super.key, required this.selectedFile});

  @override
  State<CreateMomentScreen> createState() => _CreateMomentScreenState();
}

class _CreateMomentScreenState extends State<CreateMomentScreen> {
  final TextEditingController _contentController = TextEditingController();
  String _visibility = 'public'; // 'public' hoặc 'friends'
  bool _isUploading = false;
  final _supabase = Supabase.instance.client;

  // Hàm upload
  Future<void> _handlePost() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hãy viết gì đó về bản thu này!")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final dio = ApiClient.instance.dio;
      final fileName = widget.selectedFile.path.split('/').last;

      // BƯỚC 1: Xin link upload từ Node.js
      final presignedRes = await dio.post('/api/user/upload-audio/presigned-url', data: {
        "fileName": fileName,
        "fileType": "audio/wav",
      });

      if (presignedRes.data['success'] != true) throw Exception("Lỗi lấy link upload");

      final String uploadUrl = presignedRes.data['uploadUrl'];
      final String publicUrl = presignedRes.data['publicUrl'];

      // BƯỚC 2: Upload trực tiếp lên R2 (Dùng PUT)
      final fileBytes = await widget.selectedFile.readAsBytes();

      await Dio().put(
          uploadUrl,
          data: fileBytes.isNotEmpty ? Stream.fromIterable([fileBytes]) : null,
          options: Options(
              headers: {
                "Content-Type": "audio/wav",
                "Content-Length": fileBytes.length,
              }
          )
      );

      // BƯỚC 3: Báo cho Node.js lưu vào DB
      final saveRes = await dio.post('/api/user/upload-audio/save-metadata', data: {
        "audioUrl": publicUrl,
        "description": _contentController.text.trim(),
        "visibility": _visibility,
      });

      if (saveRes.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đăng thành công!")));
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint("Lỗi đăng bài: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lấy tên file để hiển thị cho đẹp
    final fileName = widget.selectedFile.path.split('/').last;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tạo bài viết"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _handlePost,
            child: _isUploading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("ĐĂNG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFF00CC))),
          )
        ],
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(_supabase.auth.currentUser?.userMetadata?['avatar_url'] ?? ''),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _supabase.auth.currentUser?.userMetadata?['full_name'] ?? "Tôi",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    // Dropdown chọn đối tượng
                    Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _visibility,
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                          onChanged: (String? newValue) {
                            setState(() {
                              _visibility = newValue!;
                            });
                          },
                          items: const [
                            DropdownMenuItem(value: 'public', child: Row(children: [Icon(Icons.public, size: 14, color: Colors.grey), SizedBox(width: 5), Text("Công khai")])),
                            DropdownMenuItem(value: 'friends', child: Row(children: [Icon(Icons.people, size: 14, color: Colors.grey), SizedBox(width: 5), Text("Bạn bè")])),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 20),

            // Ô Nhập nội dung
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                hintText: "Bạn đang nghĩ gì về bản thu này?",
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              maxLines: 5,
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 20),

            // Card hiển thị file đã chọn
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5), // Tím nhạt
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE1BEE7)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.audio_file, color: Color(0xFFFF00CC), size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Bản ghi âm đã chọn", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}