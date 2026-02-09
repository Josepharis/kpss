class AiMaterial {
  final String title;
  final String content; // Plain text / markdown-like
  final int createdAtMillis;

  const AiMaterial({
    required this.title,
    required this.content,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'createdAtMillis': createdAtMillis,
    };
  }

  factory AiMaterial.fromMap(Map<String, dynamic> map) {
    return AiMaterial(
      title: (map['title'] ?? '') as String,
      content: (map['content'] ?? '') as String,
      createdAtMillis: (map['createdAtMillis'] ?? 0) as int,
    );
  }
}

