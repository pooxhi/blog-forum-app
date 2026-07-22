import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'dart:typed_data';
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
    required List<dynamic> images,
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
        final img = images[i];
        final fileName = () {
          final ext = img is File ? img.path.split('.').last : 'png';
          return '$userId/${uuid.v4()}.$ext';
        }();

        if (kIsWeb) {
          Uint8List bytes;
          if (img is Uint8List) {
            bytes = img;
          } else {
            bytes = await (img as XFile).readAsBytes();
          }
          await _supabase.storage
              .from('post-images')
              .uploadBinary(fileName, bytes);
        } else {
          await _supabase.storage
              .from('post-images')
              .upload(fileName, img as File);
        }

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
      final images = await _supabase
          .from('comment_images')
          .select('image_url')
          .eq('comment_id', commentId);
      final paths =
          (images as List)
              .map((e) => (e['image_url'] as String).split('post-images/').last)
              .toList();

      if (paths.isNotEmpty) {
        await _supabase.storage.from('post-images').remove(paths);
      }

      await _supabase.from('comments').delete().eq('id', commentId);
      await fetchComments(postId);
      return null;
    } catch (e) {
      return 'Failed to delete comment';
    }
  }

  Future<String?> addImageToComment({
    required String commentId,
    required String postId,
    required dynamic image,
    required int position,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final fileName = () {
        final ext =
            image is File
                ? image.path.split('.').last
                : (image is Uint8List ? 'png' : 'png');
        return '$userId/${const Uuid().v4()}.$ext';
      }();

      if (kIsWeb) {
        Uint8List bytes;
        if (image is Uint8List) {
          bytes = image;
        } else if (image is XFile) {
          bytes = await image.readAsBytes();
        } else {
          throw Exception('Unsupported image type for web');
        }
        await _supabase.storage
            .from('post-images')
            .uploadBinary(fileName, bytes);
      } else {
        await _supabase.storage
            .from('post-images')
            .upload(fileName, image as File);
      }

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
