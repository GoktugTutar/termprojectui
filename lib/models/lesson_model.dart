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

/// Ödev / deadline tarihini temsil eden model.
class LessonDeadline {
  final int id;
  final String deadlineDate; // ISO string (orn: "2026-05-25T00:00:00.000Z")
  final String? title;       // Opsiyonel başlık (orn: "Proje teslimi")

  LessonDeadline({required this.id, required this.deadlineDate, this.title});

  factory LessonDeadline.fromJson(Map<String, dynamic> j) => LessonDeadline(
    id: j['id'] as int,
    deadlineDate: j['deadlineDate'] as String,
    title: j['title'] as String?,
  );

  /// Tarihin sadece YYYY-MM-DD kısmını döndürür.
  String get dateOnly => deadlineDate.length >= 10 ? deadlineDate.substring(0, 10) : deadlineDate;
}

/// Backend /lesson endpoint'inden gelen ders modeli.
class Lesson {
  final String id;
  final String lessonName;
  final int difficulty;
  final List<LessonExam> exams;
  final List<LessonDeadline> deadlines;
  final int keyfiDelayCount;
  final int zorunluDelayCount;
  final int needsMoreTime;

  Lesson({
    required this.id,
    required this.lessonName,
    required this.difficulty,
    required this.exams,
    required this.deadlines,
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
    deadlines: ((j['deadlines'] as List?) ?? [])
        .map((d) => LessonDeadline.fromJson(d as Map<String, dynamic>))
        .toList(),
    keyfiDelayCount: (j['keyfiDelayCount'] as num?)?.toInt() ?? 0,
    zorunluDelayCount: (j['zorunluDelayCount'] as num?)?.toInt() ?? 0,
    needsMoreTime: (j['needsMoreTime'] as num?)?.toInt() ?? 0,
  );
}