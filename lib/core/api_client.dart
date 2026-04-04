import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String _configuredBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _tokenKey = 'jwt_token';
  static const List<String> _weekDays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  static const Map<String, String> _dayShortLabels = {
    'monday': 'Pzt',
    'tuesday': 'Sal',
    'wednesday': 'Car',
    'thursday': 'Per',
    'friday': 'Cum',
    'saturday': 'Cmt',
    'sunday': 'Paz',
  };
  static const Map<String, String> _dayLongLabels = {
    'monday': 'Pazartesi',
    'tuesday': 'Sali',
    'wednesday': 'Carsamba',
    'thursday': 'Persembe',
    'friday': 'Cuma',
    'saturday': 'Cumartesi',
    'sunday': 'Pazar',
  };

  static String get _base {
    if (_configuredBase.isNotEmpty) return _configuredBase;
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> _handleResponse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return Future.value(null);
      return Future.value(json.decode(res.body));
    }

    String msg = 'Hata: ${res.statusCode}';
    try {
      final body = json.decode(res.body);
      if (body is Map<String, dynamic>) {
        final message = body['message'];
        if (message is List) {
          msg = message.join('\n');
        } else if (message is String) {
          msg = message;
        }
      }
    } catch (_) {}
    throw Exception(msg);
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _parseSemester(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  static String _dateOnly(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return '';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    return parsed.toIso8601String().substring(0, 10);
  }

  static String _displayRange(String range) {
    final parts = range.split('-');
    if (parts.length != 2) return range;
    final start = int.tryParse(parts[0]);
    final end = int.tryParse(parts[1]);
    if (start == null || end == null) return range;
    return '${start.toString().padLeft(2, '0')}:00-${end.toString().padLeft(2, '0')}:00';
  }

  static int _rangeCompare(String a, String b) {
    final aStart = int.tryParse(a.split('-').first) ?? 0;
    final bStart = int.tryParse(b.split('-').first) ?? 0;
    return aStart.compareTo(bStart);
  }

  static String _normalizeTurkish(String value) {
    return value
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u');
  }

  static String? _extractDayKey(String value) {
    final normalized = _normalizeTurkish(value);
    if (normalized.contains('pazartesi')) return 'monday';
    if (normalized.contains('monday')) return 'monday';
    if (normalized.contains('sali')) return 'tuesday';
    if (normalized.contains('tuesday')) return 'tuesday';
    if (normalized.contains('carsamba')) return 'wednesday';
    if (normalized.contains('wednesday')) return 'wednesday';
    if (normalized.contains('persembe')) return 'thursday';
    if (normalized.contains('thursday')) return 'thursday';
    if (normalized.contains('cuma')) return 'friday';
    if (normalized.contains('friday')) return 'friday';
    if (normalized.contains('cumartesi')) return 'saturday';
    if (normalized.contains('saturday')) return 'saturday';
    if (normalized.contains('pazar')) return 'sunday';
    if (normalized.contains('sunday')) return 'sunday';
    return null;
  }

  static List<String> _busyTimesFromBackend(dynamic value) {
    if (value is! Map) return [];

    final result = <String>[];
    final busyTimes = Map<String, dynamic>.from(value);

    for (final day in _weekDays) {
      final rawDay = busyTimes[day];
      if (rawDay is! Map) continue;

      final dayBusy = Map<String, dynamic>.from(rawDay);
      final ranges = dayBusy.keys.toList()..sort(_rangeCompare);

      for (final range in ranges) {
        final label = dayBusy[range]?.toString().trim() ?? '';
        final base = '${_dayLongLabels[day]} ${_displayRange(range)}';
        if (label.isEmpty || _normalizeTurkish(label) == 'mesgul') {
          result.add(base);
        } else {
          result.add('$base ($label)');
        }
      }
    }

    return result;
  }

  static Map<String, dynamic>? _busyTimesToBackend(dynamic value) {
    if (value is! List) return null;

    final result = <String, Map<String, String>>{};
    for (final rawEntry in value) {
      final entry = rawEntry.toString().trim();
      if (entry.isEmpty) continue;

      final dayKey = _extractDayKey(entry);
      final match = RegExp(
        r'(\d{1,2})[:.](\d{2})\s*-\s*(\d{1,2})[:.](\d{2})',
      ).firstMatch(entry);

      if (dayKey == null || match == null) continue;

      final startHour = int.parse(match.group(1)!);
      final startMinute = int.parse(match.group(2)!);
      final endHour = int.parse(match.group(3)!);
      final endMinute = int.parse(match.group(4)!);

      final normalizedStart = startHour;
      var normalizedEnd = endHour + (endMinute > 0 ? 1 : 0);
      if (startMinute > 0 && normalizedEnd <= normalizedStart) {
        normalizedEnd = normalizedStart + 1;
      }
      if (normalizedEnd <= normalizedStart) {
        normalizedEnd = normalizedStart + 1;
      }

      final labelMatch = RegExp(r'\(([^)]+)\)\s*$').firstMatch(entry);
      final label = labelMatch?.group(1)?.trim() ?? 'Mesgul';

      (result[dayKey] ??= {})['$normalizedStart-$normalizedEnd'] = label;
    }

    return result;
  }

  static Map<String, dynamic> _mapUserFromBackend(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'email': data['email'],
      'name': data['name'],
      'gpa': _toDouble(data['gpa']),
      'semester': data['semester']?.toString() ?? '',
      'stress': (_toInt(data['stressLevel']) ?? 1).clamp(1, 5),
      'busyTimes': _busyTimesFromBackend(data['busyTimes']),
    };
  }

  static Map<String, dynamic> _mapLessonFromBackend(Map<String, dynamic> data) {
    final deadlines = <Map<String, dynamic>>[];
    final vizeDate = _dateOnly(data['vizeDate']);
    final finalDate = _dateOnly(data['finalDate']);
    final homeworkDates = (data['homeworkDeadlines'] as List? ?? const [])
        .cast<dynamic>();

    if (vizeDate.isNotEmpty) {
      deadlines.add({'type': 'midterm', 'date': vizeDate, 'label': 'Vize'});
    }
    if (finalDate.isNotEmpty) {
      deadlines.add({'type': 'final', 'date': finalDate, 'label': 'Final'});
    }
    for (var i = 0; i < homeworkDates.length; i++) {
      deadlines.add({
        'type': 'homework',
        'date': _dateOnly(homeworkDates[i]),
        'label': 'Odev ${i + 1}',
      });
    }

    return {
      'id': data['id'],
      'lessonName': data['name'],
      'difficulty': (_toInt(data['difficulty']) ?? 3).clamp(1, 5),
      'deadlines': deadlines,
      'semester': data['semester']?.toString() ?? '',
      'delay': _toInt(data['delayCount']) ?? 0,
      'credit': _toDouble(data['credit']) ?? 0,
    };
  }

  static Map<String, dynamic> _mapLessonToBackend(Map<String, dynamic> data) {
    final deadlines = (data['deadlines'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    String? vizeDate;
    String? finalDate;
    final homeworkDeadlines = <String>[];

    for (final deadline in deadlines) {
      final date = _dateOnly(deadline['date']);
      if (date.isEmpty) continue;

      switch (deadline['type']) {
        case 'midterm':
          vizeDate ??= date;
          break;
        case 'final':
          finalDate ??= date;
          break;
        case 'homework':
        default:
          homeworkDeadlines.add(date);
      }
    }

    final mapped = <String, dynamic>{
      'name': data['newLessonName'] ?? data['lessonName'] ?? data['name'],
      'credit': _toDouble(data['credit']) ?? 3,
      'difficulty': (_toInt(data['difficulty']) ?? 3).clamp(1, 5),
      'semester': _parseSemester(data['semester']) ?? 1,
    };

    if (vizeDate != null) mapped['vizeDate'] = vizeDate;
    if (finalDate != null) mapped['finalDate'] = finalDate;
    if (homeworkDeadlines.isNotEmpty) {
      mapped['homeworkDeadlines'] = homeworkDeadlines;
    }

    return mapped;
  }

  static Future<List<Map<String, dynamic>>> _fetchRawLessons() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$_base/lesson'), headers: headers);
    final data = await _handleResponse(res);
    return (data as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, String>> _fetchLessonNames() async {
    final lessons = await _fetchRawLessons();
    return {
      for (final lesson in lessons)
        lesson['id'].toString(): lesson['name']?.toString() ?? 'Ders',
    };
  }

  static String _checklistStatus(dynamic hoursCompleted) {
    final hours = _toDouble(hoursCompleted);
    if (hours == null) return 'pending';
    if (hours == 9999) return 'early';
    if (hours == -9999) return 'not_done';
    if (hours < 0) return 'incomplete';
    return 'completed';
  }

  static double? _checklistActualHours(dynamic hoursCompleted) {
    final hours = _toDouble(hoursCompleted);
    if (hours == null || hours == 9999 || hours == -9999) return null;
    return hours.abs();
  }

  static double _checklistRemaining(
    dynamic hoursCompleted,
    double plannedHours,
  ) {
    final hours = _toDouble(hoursCompleted);
    if (hours == null) return plannedHours;
    if (hours == 9999) return 0;
    if (hours == -9999) return plannedHours;
    return (plannedHours - hours.abs()).clamp(0, plannedHours);
  }

  static Future<List<dynamic>> _mapChecklistFromBackend(
    Map<String, dynamic> data,
  ) async {
    final lessonNames = await _fetchLessonNames();
    final lessons = (data['lessons'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    return lessons.map((lesson) {
      final plannedHours = _toDouble(lesson['allocatedHours']) ?? 0;
      return {
        'id': '${data['id']}-${lesson['lessonId']}',
        'lessonId': lesson['lessonId'],
        'lessonName': lessonNames[lesson['lessonId']] ?? 'Ders',
        'date': data['date']?.toString() ?? '',
        'plannedHours': plannedHours,
        'actualHours': _checklistActualHours(lesson['hoursCompleted']),
        'status': _checklistStatus(lesson['hoursCompleted']),
        'remaining': lesson['remainingHours'] != null
            ? _toDouble(lesson['remainingHours'])
            : _checklistRemaining(lesson['hoursCompleted'], plannedHours),
      };
    }).toList();
  }

  static Future<Map<String, dynamic>> _mapScheduleFromBackend(
    Map<String, dynamic> data,
  ) async {
    final lessonNames = await _fetchLessonNames();
    final rawSchedule = Map<String, dynamic>.from(data['schedule'] as Map);
    final startDate =
        DateTime.tryParse(data['startDate']?.toString() ?? '') ??
        DateTime.now();

    final slots = <Map<String, dynamic>>[];

    for (var dayIndex = 0; dayIndex < _weekDays.length; dayIndex++) {
      final dayKey = _weekDays[dayIndex];
      final date = startDate.add(Duration(days: dayIndex));
      final dayString = date.toIso8601String().substring(0, 10);
      final daySlots = List.generate(14, (hourIndex) {
        return {
          'day': dayString,
          'dayLabel': _dayShortLabels[dayKey],
          'dayKey': dayKey,
          'dayIndex': dayIndex,
          'hourIndex': hourIndex,
          'lessonId': '',
          'lessonName': '',
          'hours': 1.0,
          'score': 0.0,
          'isBusy': false,
          'isEmpty': true,
        };
      });

      final rawDay = rawSchedule[dayKey];
      if (rawDay is Map) {
        final entries = Map<String, dynamic>.from(rawDay);
        for (final entry in entries.entries) {
          final range = entry.key.split('-');
          if (range.length != 2) continue;

          final startHour = int.tryParse(range[0]);
          final endHour = int.tryParse(range[1]);
          if (startHour == null || endHour == null) continue;

          for (var hour = startHour; hour < endHour; hour++) {
            final hourIndex = hour - 8;
            if (hourIndex < 0 || hourIndex >= daySlots.length) continue;

            final value = entry.value?.toString() ?? '';
            final isBusy = value.startsWith('busy:');

            daySlots[hourIndex] = {
              'day': dayString,
              'dayLabel': _dayShortLabels[dayKey],
              'dayKey': dayKey,
              'dayIndex': dayIndex,
              'hourIndex': hourIndex,
              'lessonId': isBusy ? 'busy-$dayKey-$hour' : value,
              'lessonName': isBusy
                  ? value.replaceFirst('busy:', '').trim()
                  : (lessonNames[value] ?? 'Ders'),
              'hours': 1.0,
              'score': 0.0,
              'isBusy': isBusy,
              'isEmpty': false,
            };
          }
        }
      }

      slots.addAll(daySlots);
    }

    return {
      'generatedAt':
          data['lastUpdatedDate']?.toString() ??
          DateTime.now().toIso8601String(),
      'weekStart': data['startDate']?.toString() ?? '',
      'slots': slots,
    };
  }

  static num _encodeChecklistHours(Map<String, dynamic> data) {
    final actualHours = _toDouble(data['actualHours']) ?? 0;
    switch (data['status']) {
      case 'early':
        return 9999;
      case 'not_done':
        return -9999;
      case 'incomplete':
        return -actualHours.abs();
      case 'completed':
      default:
        return actualHours;
    }
  }

  static Future<String> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    final data = await _handleResponse(res);
    return data['access_token'] as String;
  }

  static Future<String> register(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_base/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    final data = await _handleResponse(res);
    return data['access_token'] as String;
  }

  static Future<Map<String, dynamic>> getMe() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$_base/person/me'), headers: headers);
    final data = Map<String, dynamic>.from(await _handleResponse(res) as Map);
    return _mapUserFromBackend(data);
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    final payload = <String, dynamic>{};

    if (data['name'] != null && data['name'].toString().trim().isNotEmpty) {
      payload['name'] = data['name'].toString().trim();
    }
    if (data['gpa'] != null) {
      final gpa = _toDouble(data['gpa']);
      if (gpa != null) payload['gpa'] = gpa;
    }
    final semester = _parseSemester(data['semester']);
    if (semester != null) payload['semester'] = semester;

    final stress = _toInt(data['stress']);
    if (stress != null) {
      payload['stressLevel'] = stress.clamp(1, 5);
    }

    final busyTimes = _busyTimesToBackend(data['busyTimes']);
    if (busyTimes != null) payload['busyTimes'] = busyTimes;

    final headers = await _authHeaders();
    final res = await http.put(
      Uri.parse('$_base/person/update'),
      headers: headers,
      body: json.encode(payload),
    );
    final response = Map<String, dynamic>.from(
      await _handleResponse(res) as Map,
    );
    return _mapUserFromBackend(response);
  }

  static Future<List<dynamic>> getLessons() async {
    final lessons = await _fetchRawLessons();
    return lessons.map(_mapLessonFromBackend).toList();
  }

  static Future<List<dynamic>> registerLessons(
    List<Map<String, dynamic>> lessons,
  ) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/lesson/register'),
      headers: headers,
      body: json.encode(lessons.map(_mapLessonToBackend).toList()),
    );
    final data = await _handleResponse(res);
    return (data as List)
        .map(
          (item) =>
              _mapLessonFromBackend(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  static Future<Map<String, dynamic>> updateLesson(
    Map<String, dynamic> data,
  ) async {
    final currentName = data['lessonName']?.toString().trim() ?? '';
    final headers = await _authHeaders();
    final res = await http.put(
      Uri.parse('$_base/lesson/update/${Uri.encodeComponent(currentName)}'),
      headers: headers,
      body: json.encode(_mapLessonToBackend(data)),
    );
    final response = Map<String, dynamic>.from(
      await _handleResponse(res) as Map,
    );
    return _mapLessonFromBackend(response);
  }

  static Future<void> deleteLesson(String id) async {
    final headers = await _authHeaders();
    final res = await http.delete(
      Uri.parse('$_base/lesson/$id'),
      headers: headers,
    );
    await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> createWeeklyPlan() async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/planner/create'),
      headers: headers,
      body: json.encode({}),
    );
    final data = Map<String, dynamic>.from(await _handleResponse(res) as Map);
    return _mapScheduleFromBackend(data);
  }

  static Future<Map<String, dynamic>> dailyUpdate([double? freeHours]) async {
    if (freeHours != null) {
      // Backend su an serbest saat parametresi almiyor; mevcut plani yeniden hesapliyor.
    }
    return createWeeklyPlan();
  }

  static Future<Map<String, dynamic>> getSchedule() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$_base/planner/schedule'),
      headers: headers,
    );
    final data = Map<String, dynamic>.from(await _handleResponse(res) as Map);
    return _mapScheduleFromBackend(data);
  }

  static Future<List<dynamic>> getTodayChecklist() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$_base/checklist/get'),
      headers: headers,
    );
    final data = Map<String, dynamic>.from(await _handleResponse(res) as Map);
    return _mapChecklistFromBackend(data);
  }

  static Future<List<dynamic>> getAllChecklist() async {
    return getTodayChecklist();
  }

  static Future<List<dynamic>> createChecklist(
    List<Map<String, dynamic>> slots,
  ) async {
    if (slots.isNotEmpty) {
      // Checklist sunucuda mevcut schedule'dan turetiliyor; istemci slot gondermiyor.
    }
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/checklist/create'),
      headers: headers,
      body: json.encode({}),
    );
    final data = Map<String, dynamic>.from(await _handleResponse(res) as Map);
    return _mapChecklistFromBackend(data);
  }

  static Future<Map<String, dynamic>> submitChecklist(
    Map<String, dynamic> data,
  ) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/checklist/submit'),
      headers: headers,
      body: json.encode({
        'lessons': [
          {
            'lessonId': data['lessonId'],
            'hoursCompleted': _encodeChecklistHours(data),
          },
        ],
      }),
    );
    return Map<String, dynamic>.from(await _handleResponse(res) as Map);
  }
}
