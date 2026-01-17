class NotificationModel {
  final int id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String type; // 'like', 'comment', 'follow', 'system'
  final String category; // 'personal' hoặc 'system'
  final String? actorId;
  final String? actorAvatarUrl;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    required this.type,
    required this.category,
    this.actorId,
    this.actorAvatarUrl,

  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      isRead: json['is_read'] ?? false,
      type: json['type'] ?? 'system',
      category: json['category'] ?? 'personal',
      actorId: json['actor_id'],
      actorAvatarUrl: json['actor_avatar_url'],
    );
  }
}