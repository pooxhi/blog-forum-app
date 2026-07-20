class Post {
  final String id;
  final String userId;
  final String title;
  final String content;
  final DateTime createdAt;
  final List<String> imageUrls;

  Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.imageUrls,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    final images =
        (map['post_images'] as List<dynamic>? ?? [])
            .map((img) => img['image_url'] as String)
            .toList();

    return Post(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      imageUrls: images,
    );
  }
}
