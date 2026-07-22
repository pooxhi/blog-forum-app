import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/post_provider.dart';

class CreatePostScreen extends StatefulWidget {
  final String? postId;

  const CreatePostScreen({super.key, this.postId});

  bool get isEditMode => postId != null;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<XFile> _newImages = [];
  List<Map<String, dynamic>> _existingImages = [];
  bool _isSubmitting = false;
  bool _isLoadingPost = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode) {
      _loadExistingPost();
    }
  }

  Future<void> _loadExistingPost() async {
    setState(() => _isLoadingPost = true);
    final postProvider = context.read<PostProvider>();

    final post = await postProvider.fetchPostById(widget.postId!);
    final images = await postProvider.fetchPostImages(widget.postId!);

    if (!mounted) return;
    setState(() {
      if (post != null) {
        _titleController.text = post.title;
        _contentController.text = post.content;
      }
      _existingImages = images;
      _isLoadingPost = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();

    try {
      final picked = await picker.pickMultiImage();
      if (picked.isNotEmpty) {
        setState(() => _newImages.addAll(picked));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to pick images right now: $e')),
      );
    }
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  Future<void> _removeExistingImage(int index) async {
    final image = _existingImages[index];
    final error = await context.read<PostProvider>().deletePostImage(
      image['id'] as String,
      image['image_url'] as String,
    );

    if (!mounted) return;

    if (error == null) {
      setState(() => _existingImages.removeAt(index));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final postProvider = context.read<PostProvider>();
    final String? error;

    if (widget.isEditMode) {
      error = await postProvider.updatePost(
        postId: widget.postId!,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        newImages: _newImages,
        existingImageCount: _existingImages.length,
      );
    } else {
      error = await postProvider.createPost(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        images: _newImages,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error == null) {
      if (widget.isEditMode) {
        context.pop();
      } else {
        context.go('/');
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Post' : 'Create Post'),
      ),
      body:
          _isLoadingPost
              ? const Center(child: CircularProgressIndicator())
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              border: OutlineInputBorder(),
                            ),
                            validator:
                                (v) =>
                                    (v == null || v.isEmpty)
                                        ? 'Title is required'
                                        : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _contentController,
                            decoration: const InputDecoration(
                              labelText: 'Content',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 6,
                            validator:
                                (v) =>
                                    (v == null || v.isEmpty)
                                        ? 'Content is required'
                                        : null,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.image),
                            label: const Text('Add Images'),
                          ),
                          if (_existingImages.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Current images',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(
                                _existingImages.length,
                                (index) => _ImageThumb(
                                  imageUrl:
                                      _existingImages[index]['image_url']
                                          as String,
                                  onRemove: () => _removeExistingImage(index),
                                ),
                              ),
                            ),
                          ],
                          if (_newImages.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'New images',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(
                                _newImages.length,
                                (index) => _ImageThumb(
                                  xFile: _newImages[index],
                                  onRemove: () => _removeNewImage(index),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _handleSubmit,
                              child:
                                  _isSubmitting
                                      ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Text(
                                        widget.isEditMode
                                            ? 'Save Changes'
                                            : 'Post',
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final XFile? xFile;
  final String? imageUrl;
  final VoidCallback onRemove;

  const _ImageThumb({this.xFile, this.imageUrl, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (xFile != null) {
      if (kIsWeb) {
        imageWidget = FutureBuilder<Uint8List>(
          future: xFile!.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Icon(Icons.broken_image, size: 40);
            }

            return Image.memory(
              snapshot.data!,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            );
          },
        );
      } else {
        imageWidget = Image.file(
          File(xFile!.path),
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        );
      }
    } else {
      imageWidget = Image.network(
        imageUrl!,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, _) => const Icon(Icons.broken_image, size: 40),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 100, height: 100, child: imageWidget),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
