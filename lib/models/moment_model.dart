class Moment {
  final int id;
  final String userId;
  final String audioUrl;
  final String? description;
  final DateTime createdAt;
  final String visibility;
  final String? userName;
  final String? userAvatar;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;

  Moment({
    required this.id,
    required this.userId,
    required this.audioUrl,
    this.description,
    required this.createdAt,
    required this.visibility,
    this.userName,
    this.userAvatar,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
  });

  factory Moment.fromJson(Map<String, dynamic> json) {
    return Moment(
      id: json['moment_id'],
      userId: json['user_id'],
      audioUrl: json['audio_url'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
      visibility: json['visibility'] ?? 'public',
      userName: json['users'] != null ? json['users']['full_name'] : 'Người dùng',
      userAvatar: json['users'] != null ? json['users']['avatar_url'] : null,
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
    );
  }

  Moment copyWith({bool? isLiked, int? likesCount, int? commentsCount}) {
    return Moment(
      id: id, userId: userId, audioUrl: audioUrl, description: description,
      createdAt: createdAt, visibility: visibility, userName: userName, userAvatar: userAvatar,
      isLiked: isLiked ?? this.isLiked,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }
}