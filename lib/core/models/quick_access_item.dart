class QuickAccessItem {
  final String topicId;
  final String lessonId;
  final String topicName;
  final String lessonName;
  final int lastAccessedTimestamp; // Unix timestamp
  final int podcastCount;
  final int videoCount;
  final int flashCardCount;
  final int pdfCount;

  QuickAccessItem({
    required this.topicId,
    required this.lessonId,
    required this.topicName,
    required this.lessonName,
    required this.lastAccessedTimestamp,
    this.podcastCount = 0,
    this.videoCount = 0,
    this.flashCardCount = 0,
    this.pdfCount = 0,
  });

  factory QuickAccessItem.fromMap(Map<String, dynamic> map) {
    return QuickAccessItem(
      topicId: map['topicId'] ?? '',
      lessonId: map['lessonId'] ?? '',
      topicName: map['topicName'] ?? '',
      lessonName: map['lessonName'] ?? '',
      lastAccessedTimestamp: map['lastAccessedTimestamp'] ?? 0,
      podcastCount: map['podcastCount'] ?? 0,
      videoCount: map['videoCount'] ?? 0,
      flashCardCount: map['flashCardCount'] ?? 0,
      pdfCount: map['pdfCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'topicId': topicId,
      'lessonId': lessonId,
      'topicName': topicName,
      'lessonName': lessonName,
      'lastAccessedTimestamp': lastAccessedTimestamp,
      'podcastCount': podcastCount,
      'videoCount': videoCount,
      'flashCardCount': flashCardCount,
      'pdfCount': pdfCount,
    };
  }

  QuickAccessItem copyWith({
    String? topicId,
    String? lessonId,
    String? topicName,
    String? lessonName,
    int? lastAccessedTimestamp,
    int? podcastCount,
    int? videoCount,
    int? flashCardCount,
    int? pdfCount,
  }) {
    return QuickAccessItem(
      topicId: topicId ?? this.topicId,
      lessonId: lessonId ?? this.lessonId,
      topicName: topicName ?? this.topicName,
      lessonName: lessonName ?? this.lessonName,
      lastAccessedTimestamp: lastAccessedTimestamp ?? this.lastAccessedTimestamp,
      podcastCount: podcastCount ?? this.podcastCount,
      videoCount: videoCount ?? this.videoCount,
      flashCardCount: flashCardCount ?? this.flashCardCount,
      pdfCount: pdfCount ?? this.pdfCount,
    );
  }
}
