import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../models/comment.dart';

class CommentProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  final Map<String, List<Comment>> _commentsByPost = {};
  bool _isLoading = false;
  String? _errorMessage;

  List<Comment> commentsFor(String postId) => _commentsByPost[postId] ?? [];
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchComments(String postId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _supabase
          .from('comments')
          .select('*, comment_images(image_url, position)')
          .eq('post_id', postId)
          .order('created_at');

      _commentsByPost[postId] =
          (data as List<dynamic>)
              .map((item) => Comment.fromMap(item as Map<String, dynamic>))
              .toList();
    } catch (e) {
      _errorMessage = 'Failed to load comments';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> addComment({
    required String postId,
    required String content,
    required List<File> images,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'You must be logged in to comment';

      final commentData =
          await _supabase
              .from('comments')
              .insert({
                'post_id': postId,
                'user_id': userId,
                'content': content,
              })
              .select()
              .single();

      final commentId = commentData['id'] as String;

      const uuid = Uuid();
      for (var i = 0; i < images.length; i++) {
        final file = images[i];
        final ext = file.path.split('.').last;
        final fileName = '$userId/${uuid.v4()}.$ext';

        await _supabase.storage.from('post-images').upload(fileName, file);
        final publicUrl = _supabase.storage
            .from('post-images')
            .getPublicUrl(fileName);

        await _supabase.from('comment_images').insert({
          'comment_id': commentId,
          'image_url': publicUrl,
          'position': i,
        });
      }

      await fetchComments(postId);
      return null;
    } catch (e) {
      return 'Failed to add comment: $e';
    }
  }

  Future<String?> updateComment({
    required String commentId,
    required String postId,
    required String content,
  }) async {
    try {
      await _supabase
          .from('comments')
          .update({'content': content})
          .eq('id', commentId);
      await fetchComments(postId);
      return null;
    } catch (e) {
      return 'Failed to update comment';
    }
  }

  Future<String?> deleteComment(String commentId, String postId) async {
    try {
      await _supabase.from('comments').delete().eq('id', commentId);
      await fetchComments(postId);
      return null;
    } catch (e) {
      return 'Failed to delete comment';
    }
  }

  Future<String?> deleteCommentImage(
    String imageId,
    String imageUrl,
    String postId,
  ) async {
    try {
      final path = imageUrl.split('post-images/').last;
      await _supabase.storage.from('post-images').remove([path]);
      await _supabase.from('comment_images').delete().eq('id', imageId);
      await fetchComments(postId);
      return null;
    } catch (e) {
      return 'Failed to delete image';
    }
  }

  Future<String?> addImageToComment({
    required String commentId,
    required String postId,
    required File image,
    required int position,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final ext = image.path.split('.').last;
      final fileName = '$userId/${const Uuid().v4()}.$ext';

      await _supabase.storage.from('post-images').upload(fileName, image);
      final publicUrl = _supabase.storage
          .from('post-images')
          .getPublicUrl(fileName);

      await _supabase.from('comment_images').insert({
        'comment_id': commentId,
        'image_url': publicUrl,
        'position': position,
      });

      await fetchComments(postId);
      return null;
    } catch (e) {
      return 'Failed to add image';
    }
  }
}
