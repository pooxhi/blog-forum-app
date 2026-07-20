class Comment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final List<String> imageUrls;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.imageUrls,
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    final images =
        (map['comment_images'] as List<dynamic>? ?? [])
            .map((img) => img['image_url'] as String)
            .toList();

    return Comment(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      userId: map['user_id'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      imageUrls: images,
    );
  }
}
