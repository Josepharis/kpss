class StudyProgramTask {
  final String start; // "09:00"
  final String end; // "10:00"
  final String title; // "Konu çalış" / "Test çöz" etc.
  final String kind; // "konu" | "test" | "tekrar" | "video" | ...
  final String lesson; // "Vatandaşlık"
  final String topic; // "Temel Haklar"
  final String notes; // optional free text
  final String detail; // legacy: "60 dk" / "20 soru" etc. (UI may hide)
  final bool isCompleted;

  const StudyProgramTask({
    required this.start,
    required this.end,
    required this.title,
    required this.kind,
    this.lesson = '',
    this.topic = '',
    this.notes = '',
    required this.detail,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'start': start,
      'end': end,
      'title': title,
      'kind': kind,
      'lesson': lesson,
      'topic': topic,
      'notes': notes,
      'detail': detail,
      'isCompleted': isCompleted,
    };
  }

  factory StudyProgramTask.fromMap(Map<String, dynamic> map) {
    return StudyProgramTask(
      start: (map['start'] ?? '') as String,
      end: (map['end'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      kind: (map['kind'] ?? 'konu') as String,
      lesson: (map['lesson'] ?? '') as String,
      topic: (map['topic'] ?? '') as String,
      notes: (map['notes'] ?? '') as String,
      detail: (map['detail'] ?? '') as String,
      isCompleted: (map['isCompleted'] ?? false) as bool,
    );
  }

  StudyProgramTask copyWith({
    String? start,
    String? end,
    String? title,
    String? kind,
    String? lesson,
    String? topic,
    String? notes,
    String? detail,
    bool? isCompleted,
  }) {
    return StudyProgramTask(
      start: start ?? this.start,
      end: end ?? this.end,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      lesson: lesson ?? this.lesson,
      topic: topic ?? this.topic,
      notes: notes ?? this.notes,
      detail: detail ?? this.detail,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class StudyProgramDay {
  /// 1 = Monday ... 7 = Sunday (DateTime.weekday)
  final int weekday;
  final List<StudyProgramTask> tasks;

  const StudyProgramDay({required this.weekday, required this.tasks});

  Map<String, dynamic> toMap() {
    return {'weekday': weekday, 'tasks': tasks.map((t) => t.toMap()).toList()};
  }

  factory StudyProgramDay.fromMap(Map<String, dynamic> map) {
    final tasksRaw = map['tasks'];
    return StudyProgramDay(
      weekday: (map['weekday'] ?? 1) as int,
      tasks: (tasksRaw is List)
          ? tasksRaw
                .whereType<Map>()
                .map(
                  (e) => StudyProgramTask.fromMap(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const <StudyProgramTask>[],
    );
  }
}

class StudyProgram {
  final int createdAtMillis;
  final String title; // e.g. "Haftalık Çalışma Programı"
  final String subtitle; // e.g. "Genel Kültür • 7 Günlük Plan"
  final List<StudyProgramDay> days;

  const StudyProgram({
    required this.createdAtMillis,
    required this.title,
    required this.subtitle,
    required this.days,
  });

  Map<String, dynamic> toMap() {
    return {
      'createdAtMillis': createdAtMillis,
      'title': title,
      'subtitle': subtitle,
      'days': days.map((d) => d.toMap()).toList(),
    };
  }

  factory StudyProgram.fromMap(Map<String, dynamic> map) {
    final daysRaw = map['days'];
    return StudyProgram(
      createdAtMillis: (map['createdAtMillis'] ?? 0) as int,
      title: (map['title'] ?? '') as String,
      subtitle: (map['subtitle'] ?? '') as String,
      days: (daysRaw is List)
          ? daysRaw
                .whereType<Map>()
                .map(
                  (e) => StudyProgramDay.fromMap(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const <StudyProgramDay>[],
    );
  }
}
