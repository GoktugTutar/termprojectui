class Deadline {
  final String type; // midterm | final | homework
  final String date; // YYYY-MM-DD
  final String? label;

  Deadline({required this.type, required this.date, this.label});

  factory Deadline.fromJson(Map<String, dynamic> j) => Deadline(
    type: j['type'] as String,
    date: j['date'] as String,
    label: j['label'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'date': date,
    if (label != null) 'label': label,
  };
}

class Lesson {
  final String id;
  final String lessonName;
  final double credit;
  final int difficulty;
  final List<Deadline> deadlines;
  final String semester;
  final int delay;

  Lesson({
    required this.id,
    required this.lessonName,
    required this.credit,
    required this.difficulty,
    required this.deadlines,
    required this.semester,
    required this.delay,
  });

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
    id: j['id'] as String,
    lessonName: j['lessonName'] as String,
    credit: (j['credit'] as num?)?.toDouble() ?? 0,
    difficulty: (j['difficulty'] as num).toInt(),
    deadlines: (j['deadlines'] as List)
        .map((d) => Deadline.fromJson(d as Map<String, dynamic>))
        .toList(),
    semester: j['semester'] as String,
    delay: (j['delay'] as num?)?.toInt() ?? 0,
  );
}
