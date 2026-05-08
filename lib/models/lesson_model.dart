/// Sınav tarihini temsil eden model.
class LessonExam {
  final int id;
  final String examDate; // ISO string (orn: "2026-05-20T00:00:00.000Z")

  LessonExam({required this.id, required this.examDate});

  factory LessonExam.fromJson(Map<String, dynamic> j) => LessonExam(
    id: j['id'] as int,
    examDate: j['examDate'] as String,
  );

  /// Tarihin sadece YYYY-MM-DD kısmını döndürür.
  String get dateOnly => examDate.length >= 10 ? examDate.substring(0, 10) : examDate;
}

/// Backend /lesson endpoint'inden gelen ders modeli.
class Lesson {
  final String id;
  final String lessonName;
  final int difficulty;
  final List<LessonExam> exams;
  final int keyfiDelayCount;
  final int zorunluDelayCount;
  final int needsMoreTime;

  Lesson({
    required this.id,
    required this.lessonName,
    required this.difficulty,
    required this.exams,
    required this.keyfiDelayCount,
    required this.zorunluDelayCount,
    required this.needsMoreTime,
  });

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
    id: j['id'].toString(),
    lessonName: j['name'] as String,
    difficulty: (j['difficulty'] as num).toInt(),
    exams: ((j['exams'] as List?) ?? [])
        .map((e) => LessonExam.fromJson(e as Map<String, dynamic>))
        .toList(),
    keyfiDelayCount: (j['keyfiDelayCount'] as num?)?.toInt() ?? 0,
    zorunluDelayCount: (j['zorunluDelayCount'] as num?)?.toInt() ?? 0,
    needsMoreTime: (j['needsMoreTime'] as num?)?.toInt() ?? 0,
  );
}
