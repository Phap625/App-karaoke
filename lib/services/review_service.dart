import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review_model.dart';

class ReviewService {
  static final ReviewService instance = ReviewService._internal();
  ReviewService._internal();

  final _supabase = Supabase.instance.client;

  Future<List<ReviewModel>> fetchReviews({int limit = 10, int offset = 0}) async {
    try {
      final response = await _supabase
          .from('app_reviews')
          .select('*, users(full_name, avatar_url, username)')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((e) => ReviewModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error fetching reviews: $e");
      rethrow;
    }
  }

  // Gửi đánh giá mới
  Future<void> addReview(int rating, String comment) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("Bạn cần đăng nhập để đánh giá");

    try {
      await _supabase.from('app_reviews').insert({
        'user_id': user.id,
        'rating': rating,
        'comment': comment,
      });
    } catch (e) {
      debugPrint("Error adding review: $e");
      throw Exception("Không thể gửi đánh giá: $e");
    }
  }
}