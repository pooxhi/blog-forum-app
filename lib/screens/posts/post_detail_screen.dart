import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/comment_provider.dart';
import '../../models/post.dart';
import '../../models/comment.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _ImageViewer extends StatefulWidget {
  final List<dynamic> images;
  final int initialPage;

  const _ImageViewer({required this.images, this.initialPage = 0});

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _controller = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildImage(dynamic src) {
    if (src is String) {
      return InteractiveViewer(child: Image.network(src, fit: BoxFit.contain));
    }
    if (src is Uint8List) {
      return InteractiveViewer(child: Image.memory(src, fit: BoxFit.contain));
    }
    if (src is File) {
      return InteractiveViewer(child: Image.file(src, fit: BoxFit.contain));
    }
    return const Center(child: Icon(Icons.broken_image));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.images.length,
                  onPageChanged: (p) => setState(() => _page = p),
                  itemBuilder:
                      (context, i) =>
                          Center(child: _buildImage(widget.images[i])),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_page + 1} / ${widget.images.length}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  bool _isLoading = true;
  bool _notFound = false;
  final PageController _imagePageController = PageController();
  int _currentImageIndex = 0;

  final _commentController = TextEditingController();
  final List<dynamic> _commentImages = [];
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _loadPost();
    context.read<CommentProvider>().fetchComments(widget.postId);
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    final postProvider = context.read<PostProvider>();
    final cached = postProvider.posts.where((p) => p.id == widget.postId);
    if (cached.isNotEmpty) {
      setState(() {
        _post = cached.first;
        _isLoading = false;
      });
      return;
    }
    final fetched = await postProvider.fetchPostById(widget.postId);
    if (!mounted) return;
    setState(() {
      _post = fetched;
      _isLoading = false;
      _notFound = fetched == null;
    });
  }

  Future<void> _confirmDeletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete post?'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    final error = await context.read<PostProvider>().deletePost(widget.postId);
    if (!mounted) return;
    if (error == null) {
      context.go('/');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _pickCommentImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      if (kIsWeb) {
        final bytesList = <Uint8List>[];
        for (final x in picked) {
          final b = await x.readAsBytes();
          bytesList.add(b);
        }
        setState(() => _commentImages.addAll(bytesList));
      } else {
        setState(() => _commentImages.addAll(picked.map((x) => File(x.path))));
      }
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSubmittingComment = true);

    final error = await context.read<CommentProvider>().addComment(
      postId: widget.postId,
      content: _commentController.text.trim(),
      images: _commentImages,
    );

    if (!mounted) return;
    setState(() => _isSubmittingComment = false);

    if (error == null) {
      _commentController.clear();
      setState(() => _commentImages.clear());
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.45),
      ),
      child: IconButton(
        icon: Icon(icon, color: color ?? Colors.white, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isOwner = _post != null && _post!.userId == authProvider.user?.id;
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_notFound || _post == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: const Center(child: Text('Post not found.')),
      );
    }

    final post = _post!;
    final imageHeight = MediaQuery.sizeOf(context).width > 900 ? 420.0 : 340.0;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero image with overlaid controls + title
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(28),
                                bottomRight: Radius.circular(28),
                              ),
                              child: SizedBox(
                                height: imageHeight,
                                width: double.infinity,
                                child:
                                    post.imageUrls.isNotEmpty
                                        ? Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            PageView.builder(
                                              controller: _imagePageController,
                                              itemCount: post.imageUrls.length,
                                              onPageChanged: (index) {
                                                setState(() {
                                                  _currentImageIndex = index;
                                                });
                                              },
                                              itemBuilder:
                                                  (context, i) => Image.network(
                                                    post.imageUrls[i],
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) => const Center(
                                                          child: Icon(
                                                            Icons.broken_image,
                                                          ),
                                                        ),
                                                  ),
                                            ),
                                            if (post.imageUrls.length > 1)
                                              Positioned(
                                                left: 12,
                                                right: 12,
                                                top: imageHeight / 2 - 24,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Material(
                                                      color: Colors.black54,
                                                      shape:
                                                          const CircleBorder(),
                                                      child: MouseRegion(
                                                        cursor:
                                                            SystemMouseCursors
                                                                .click,
                                                        child: IconButton(
                                                          icon: const Icon(
                                                            Icons.chevron_left,
                                                            color: Colors.white,
                                                            size: 24,
                                                          ),
                                                          onPressed: () {
                                                            if (_currentImageIndex >
                                                                0) {
                                                              _imagePageController.animateToPage(
                                                                _currentImageIndex -
                                                                    1,
                                                                duration:
                                                                    const Duration(
                                                                      milliseconds:
                                                                          250,
                                                                    ),
                                                                curve:
                                                                    Curves
                                                                        .easeInOut,
                                                              );
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                    Material(
                                                      color: Colors.black54,
                                                      shape:
                                                          const CircleBorder(),
                                                      child: MouseRegion(
                                                        cursor:
                                                            SystemMouseCursors
                                                                .click,
                                                        child: IconButton(
                                                          icon: const Icon(
                                                            Icons.chevron_right,
                                                            color: Colors.white,
                                                            size: 24,
                                                          ),
                                                          onPressed: () {
                                                            if (_currentImageIndex <
                                                                post
                                                                        .imageUrls
                                                                        .length -
                                                                    1) {
                                                              _imagePageController.animateToPage(
                                                                _currentImageIndex +
                                                                    1,
                                                                duration:
                                                                    const Duration(
                                                                      milliseconds:
                                                                          250,
                                                                    ),
                                                                curve:
                                                                    Curves
                                                                        .easeInOut,
                                                              );
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (post.imageUrls.length > 1)
                                              Positioned(
                                                bottom: 16,
                                                left: 0,
                                                right: 0,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: List.generate(
                                                    post.imageUrls.length,
                                                    (index) => Container(
                                                      width: 8,
                                                      height: 8,
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 3,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color:
                                                            index ==
                                                                    _currentImageIndex
                                                                ? Colors.white
                                                                : Colors.white
                                                                    .withOpacity(
                                                                      0.45,
                                                                    ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            IgnorePointer(
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    stops: const [0.5, 1.0],
                                                    colors: [
                                                      Colors.transparent,
                                                      Colors.black.withOpacity(
                                                        0.8,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                        : Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                theme.colorScheme.primary
                                                    .withOpacity(0.85),
                                                theme.colorScheme.secondary
                                                    .withOpacity(0.65),
                                              ],
                                            ),
                                          ),
                                        ),
                              ),
                            ),
                            // Floating back/edit/delete buttons over the hero
                            Positioned(
                              top: MediaQuery.of(context).padding.top + 8,
                              left: 16,
                              right: 16,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _circleIconButton(
                                    icon: Icons.arrow_back,
                                    onPressed: () => context.pop(),
                                  ),
                                  if (isOwner)
                                    Row(
                                      children: [
                                        _circleIconButton(
                                          icon: Icons.edit,
                                          onPressed: () async {
                                            await context.push(
                                              '/edit-post/${widget.postId}',
                                            );
                                            _loadPost();
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        _circleIconButton(
                                          icon: Icons.delete,
                                          color: Colors.redAccent.shade100,
                                          onPressed: _confirmDeletePost,
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            // Title overlaid at the bottom of the hero
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: 20,
                              child: Text(
                                post.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.content,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Row(
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Comments',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildCommentsList(authProvider),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (authProvider.isAuthenticated) _buildCommentInput(theme),
            ],
          ),
        ),
      ),
    );
  }

  void _openImageViewer(List<dynamic> images, int initialPage) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.transparent,
          child: _ImageViewer(images: images, initialPage: initialPage),
        );
      },
    );
  }

  Widget _buildCommentsList(AuthProvider authProvider) {
    final commentProvider = context.watch<CommentProvider>();
    final comments = commentProvider.commentsFor(widget.postId);

    if (commentProvider.isLoading && comments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (comments.isEmpty) {
      return Text(
        'No comments yet — be the first.',
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      );
    }

    return Column(
      children:
          comments
              .map(
                (c) => _CommentTile(
                  comment: c,
                  isOwner: c.userId == authProvider.user?.id,
                  postId: widget.postId,
                ),
              )
              .toList(),
    );
  }

  Widget _buildCommentInput(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isSubmittingComment)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (_commentImages.isNotEmpty)
              SizedBox(
                height: 56,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _commentImages.length,
                  itemBuilder:
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: GestureDetector(
                                onTap:
                                    () =>
                                        _openImageViewer(_commentImages, index),
                                child:
                                    _commentImages[index] is Uint8List
                                        ? Image.memory(
                                          _commentImages[index] as Uint8List,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        )
                                        : Image.file(
                                          _commentImages[index] as File,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap:
                                    () => setState(
                                      () => _commentImages.removeAt(index),
                                    ),
                                child: const CircleAvatar(
                                  radius: 8,
                                  backgroundColor: Colors.black54,
                                  child: Icon(
                                    Icons.close,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                ),
              ),
            Row(
              children: [
                _isSubmittingComment
                    ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    )
                    : IconButton(
                      icon: Icon(
                        Icons.image_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: _pickCommentImages,
                    ),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      isDense: true,
                      fillColor:
                          theme.brightness == Brightness.dark
                              ? theme.colorScheme.surfaceContainerHighest
                              : theme.colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                  child: IconButton(
                    icon:
                        _isSubmittingComment
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(
                              Icons.arrow_upward,
                              color: Colors.white,
                              size: 18,
                            ),
                    onPressed: _isSubmittingComment ? null : _submitComment,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatefulWidget {
  final Comment comment;
  final bool isOwner;
  final String postId;

  const _CommentTile({
    required this.comment,
    required this.isOwner,
    required this.postId,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.comment.content);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _saveEdit() async {
    final error = await context.read<CommentProvider>().updateComment(
      commentId: widget.comment.id,
      postId: widget.postId,
      content: _editController.text.trim(),
    );
    if (!mounted) return;
    if (error == null) {
      setState(() => _isEditing = false);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _deleteComment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete comment?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<CommentProvider>().deleteComment(
      widget.comment.id,
      widget.postId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final theme = Theme.of(context);
    final tileColor =
        theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surfaceContainerLow;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isEditing)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _editController,
                  decoration: const InputDecoration(isDense: true),
                  maxLines: 3,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _isEditing = false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(onPressed: _saveEdit, child: const Text('Save')),
                  ],
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                  child: Icon(
                    Icons.person,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    comment.content,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                if (widget.isOwner) ...[
                  GestureDetector(
                    onTap: () => setState(() => _isEditing = true),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.edit,
                        size: 16,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _deleteComment,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.delete,
                        size: 16,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          if (comment.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: comment.imageUrls.length,
                itemBuilder:
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(right: 6, left: 38),
                      child: GestureDetector(
                        onTap: () => _openImageViewer(comment.imageUrls, index),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            comment.imageUrls[index],
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => Icon(
                                  Icons.broken_image,
                                  size: 24,
                                  color: theme.colorScheme.outline,
                                ),
                          ),
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
