/// Backend'den gelen tek bir zamanlanmış çalışma bloğu.
class ScheduledBlock {
  final int id;
  final int lessonId;
  final String lessonName;
  final String date; // YYYY-MM-DD
  final String startTime; // HH:MM
  final String endTime; // HH:MM
  final int blockCount; // 1 blok = 30 dakika
  final bool isReview;
  final bool completed;

  ScheduledBlock({
    required this.id,
    required this.lessonId,
    required this.lessonName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.blockCount,
    required this.isReview,
    required this.completed,
  });

  factory ScheduledBlock.fromJson(Map<String, dynamic> j) => ScheduledBlock(
    id: j['id'] as int,
    lessonId: j['lessonId'] as int,
    lessonName:
        (j['lesson'] as Map<String, dynamic>?)?['name']?.toString() ?? 'Ders',
    date: DateTime.parse(
      j['date'] as String,
    ).toLocal().toIso8601String().substring(0, 10),
    startTime: j['startTime'] as String,
    endTime: j['endTime'] as String,
    blockCount: (j['blockCount'] as num).toInt(),
    isReview: j['isReview'] as bool? ?? false,
    completed: j['completed'] as bool? ?? false,
  );
}

/// Haftalık planı ve içindeki blokları temsil eden model.
class WeeklyPlan {
  final String weekStart; // YYYY-MM-DD
  final List<ScheduledBlock> blocks;

  WeeklyPlan({required this.weekStart, required this.blocks});

  factory WeeklyPlan.fromJson(Map<String, dynamic> j) => WeeklyPlan(
    weekStart: DateTime.parse(
      j['weekStart'] as String,
    ).toLocal().toIso8601String().substring(0, 10),
    blocks: ((j['blocks'] as List?) ?? [])
        .map((b) => ScheduledBlock.fromJson(b as Map<String, dynamic>))
        .toList(),
  );

  /// Belirli bir güne (YYYY-MM-DD) ait blokları startTime sırasıyla döndürür.
  List<ScheduledBlock> blocksForDate(String date) =>
      blocks.where((b) => b.date == date).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
}

/// Günlük checklist'teki tek bir ders kalemi.
class ChecklistItem {
  final int id;
  final int lessonId;
  final String lessonName; // API client tarafından doldurulur
  final int plannedBlocks;
  final int completedBlocks;
  final bool delayed;

  ChecklistItem({
    required this.id,
    required this.lessonId,
    required this.lessonName,
    required this.plannedBlocks,
    required this.completedBlocks,
    required this.delayed,
  });
}

/// Günlük checklist modeli (GET /checklist/:date yanıtı).
class DailyChecklist {
  final int id;
  final String date;
  final int stressLevel;
  final int fatigueLevel;
  final List<ChecklistItem> items;

  DailyChecklist({
    required this.id,
    required this.date,
    required this.stressLevel,
    required this.fatigueLevel,
    required this.items,
  });
}
