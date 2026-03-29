class DailySlot {
  final String day;
  final String? dayLabel;
  final String lessonId;
  final String lessonName;
  final double hours;
  final double score;

  DailySlot({
    required this.day,
    this.dayLabel,
    required this.lessonId,
    required this.lessonName,
    required this.hours,
    required this.score,
  });

  factory DailySlot.fromJson(Map<String, dynamic> j) => DailySlot(
        day: j['day'] as String,
        dayLabel: j['dayLabel'] as String?,
        lessonId: j['lessonId'] as String,
        lessonName: j['lessonName'] as String,
        hours: (j['hours'] as num).toDouble(),
        score: (j['score'] as num).toDouble(),
      );
}

class WeeklySchedule {
  final String generatedAt;
  final String weekStart;
  final List<DailySlot> slots;

  WeeklySchedule({
    required this.generatedAt,
    required this.weekStart,
    required this.slots,
  });

  factory WeeklySchedule.fromJson(Map<String, dynamic> j) => WeeklySchedule(
        generatedAt: j['generatedAt'] as String,
        weekStart: j['weekStart'] as String,
        slots: (j['slots'] as List)
            .map((s) => DailySlot.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  Map<String, List<DailySlot>> get byDay {
    final Map<String, List<DailySlot>> map = {};
    for (final slot in slots) {
      (map[slot.day] ??= []).add(slot);
    }
    return map;
  }
}

class ChecklistItem {
  final String id;
  final String lessonId;
  final String lessonName;
  final String date;
  final double plannedHours;
  final double? actualHours;
  final String status;
  final double? remaining;

  ChecklistItem({
    required this.id,
    required this.lessonId,
    required this.lessonName,
    required this.date,
    required this.plannedHours,
    this.actualHours,
    required this.status,
    this.remaining,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
        id: j['id'] as String,
        lessonId: j['lessonId'] as String,
        lessonName: j['lessonName'] as String,
        date: j['date'] as String,
        plannedHours: (j['plannedHours'] as num).toDouble(),
        actualHours: j['actualHours'] != null
            ? (j['actualHours'] as num).toDouble()
            : null,
        status: j['status'] as String,
        remaining: j['remaining'] != null
            ? (j['remaining'] as num).toDouble()
            : null,
      );
}
