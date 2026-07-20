import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post.dart';

class PostProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  static const int pageSize = 10;

  final List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _errorMessage;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;

  Future<void> fetchInitialPosts() async {
    _posts.clear();
    _currentPage = 0;
    _hasMore = true;
    _errorMessage = null;
    notifyListeners();
    await fetchNextPage();
  }

  Future<void> fetchNextPage() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final from = _currentPage * pageSize;
      final to = from + pageSize - 1;

      final data = await _supabase
          .from('posts')
          .select('*, post_images(image_url, position)')
          .order('created_at', ascending: false)
          .range(from, to);

      final newPosts =
          (data as List<dynamic>)
              .map((item) => Post.fromMap(item as Map<String, dynamic>))
              .toList();

      if (newPosts.length < pageSize) {
        _hasMore = false;
      }

      _posts.addAll(newPosts);
      _currentPage++;
    } catch (e) {
      _errorMessage = 'Failed to load posts';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> deletePost(String postId) async {
    try {
      await _supabase.from('posts').delete().eq('id', postId);
      _posts.removeWhere((p) => p.id == postId);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to delete post';
    }
  }

  Future<String?> createPost({
    required String title,
    required String content,
    required List<File> images,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'You must be logged in to post';

      // 1. Insert the post row first to get its id
      final postData =
          await _supabase
              .from('posts')
              .insert({'user_id': userId, 'title': title, 'content': content})
              .select()
              .single();

      final postId = postData['id'] as String;

      // 2. Upload each image to Storage, then insert a post_images row
      const uuid = Uuid();
      for (var i = 0; i < images.length; i++) {
        final file = images[i];
        final ext = file.path.split('.').last;
        final fileName = '$userId/${uuid.v4()}.$ext';

        await _supabase.storage.from('post-images').upload(fileName, file);
        final publicUrl = _supabase.storage
            .from('post-images')
            .getPublicUrl(fileName);

        await _supabase.from('post_images').insert({
          'post_id': postId,
          'image_url': publicUrl,
          'position': i,
        });
      }

      // 3. Refresh the list so the new post shows up
      await fetchInitialPosts();
      return null;
    } catch (e) {
      return 'Failed to create post: $e';
    }
  }

  Future<Post?> fetchPostById(String postId) async {
    try {
      final data =
          await _supabase
              .from('posts')
              .select('*, post_images(image_url, position)')
              .eq('id', postId)
              .single();
      return Post.fromMap(data);
    } catch (e) {
      return null;
    }
  }

  // Get existing images (with their row IDs, needed to delete individually)
  Future<List<Map<String, dynamic>>> fetchPostImages(String postId) async {
    final data = await _supabase
        .from('post_images')
        .select('id, image_url, position')
        .eq('post_id', postId)
        .order('position');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<String?> deletePostImage(String imageId, String imageUrl) async {
    try {
      // Extract the storage path from the public URL
      final path = imageUrl.split('post-images/').last;
      await _supabase.storage.from('post-images').remove([path]);
      await _supabase.from('post_images').delete().eq('id', imageId);
      return null;
    } catch (e) {
      return 'Failed to delete image';
    }
  }

  Future<String?> updatePost({
    required String postId,
    required String title,
    required String content,
    required List<File> newImages,
    required int existingImageCount,
  }) async {
    try {
      await _supabase
          .from('posts')
          .update({'title': title, 'content': content})
          .eq('id', postId);

      final userId = _supabase.auth.currentUser?.id;
      const uuid = Uuid();
      for (var i = 0; i < newImages.length; i++) {
        final file = newImages[i];
        final ext = file.path.split('.').last;
        final fileName = '$userId/${uuid.v4()}.$ext';

        await _supabase.storage.from('post-images').upload(fileName, file);
        final publicUrl = _supabase.storage
            .from('post-images')
            .getPublicUrl(fileName);

        await _supabase.from('post_images').insert({
          'post_id': postId,
          'image_url': publicUrl,
          'position': existingImageCount + i,
        });
      }

      await fetchInitialPosts();
      return null;
    } catch (e) {
      return 'Failed to update post: $e';
    }
  }
}
