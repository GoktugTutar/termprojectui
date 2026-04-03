import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String _base = 'http://localhost:3000';
  static const String _tokenKey = 'jwt_token';
  static const bool demoMode = true;

  static Map<String, dynamic> _demoUser = {
    'id': 'demo-user',
    'email': 'demo@derstakip.app',
    'name': 'Demo Ogrenci',
    'gpa': 3.42,
    'semester': '2025-2026 Bahar',
    'stress': 6,
    'busyTimes': [
      'Pazartesi 09:00-11:00',
      'Carsamba 14:00-16:00',
      'Cuma 10:00-12:00',
    ],
  };

  static List<Map<String, dynamic>> _demoLessons = [
    {
      'id': 'lesson-math',
      'lessonName': 'Ayrik Matematik',
      'difficulty': 4,
      'semester': '2025-2026 Bahar',
      'delay': 1,
      'deadlines': [
        {'type': 'midterm', 'date': '2026-04-08', 'label': 'Vize'},
      ],
    },
    {
      'id': 'lesson-ai',
      'lessonName': 'Yapay Zeka Temelleri',
      'difficulty': 5,
      'semester': '2025-2026 Bahar',
      'delay': 0,
      'deadlines': [
        {'type': 'homework', 'date': '2026-04-03', 'label': 'Proje Taslagi'},
      ],
    },
    {
      'id': 'lesson-db',
      'lessonName': 'Veritabani Sistemleri',
      'difficulty': 3,
      'semester': '2025-2026 Bahar',
      'delay': 2,
      'deadlines': [
        {'type': 'final', 'date': '2026-05-24', 'label': 'Final Sinavi'},
      ],
    },
  ];

  static Map<String, dynamic>? _demoPlan;
  static List<Map<String, dynamic>> _demoChecklist = [
    {
      'id': 'check-1',
      'lessonId': 'lesson-ai',
      'lessonName': 'Yapay Zeka Temelleri',
      'date': '2026-03-29',
      'plannedHours': 2.5,
      'actualHours': null,
      'status': 'pending',
      'remaining': 2.5,
    },
    {
      'id': 'check-2',
      'lessonId': 'lesson-db',
      'lessonName': 'Veritabani Sistemleri',
      'date': '2026-03-29',
      'plannedHours': 1.5,
      'actualHours': 1.5,
      'status': 'completed',
      'remaining': 0.0,
    },
  ];

  static Future<String?> getToken() async {
    if (demoMode) return 'demo-token';
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveToken(String token) async {
    if (demoMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    if (demoMode) return;
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
      msg = body['message'] ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  static Future<T> _demoDelay<T>(T value) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return value;
  }

  static Map<String, dynamic> _buildDemoPlan({double freeHours = 4}) {
    final days = [
      ('2026-03-29', 'Pazar'),
      ('2026-03-30', 'Pazartesi'),
      ('2026-03-31', 'Sali'),
      ('2026-04-01', 'Carsamba'),
      ('2026-04-02', 'Persembe'),
    ];

    final slots = <Map<String, dynamic>>[];
    for (var i = 0; i < days.length; i++) {
      final lessonA = _demoLessons[i % _demoLessons.length];
      final lessonB = _demoLessons[(i + 1) % _demoLessons.length];
      slots.add({
        'day': days[i].$1,
        'dayLabel': days[i].$2,
        'lessonId': lessonA['id'],
        'lessonName': lessonA['lessonName'],
        'hours': (freeHours * 0.55).clamp(1.0, 3.5),
        'score': 88 - (i * 3),
      });
      slots.add({
        'day': days[i].$1,
        'dayLabel': days[i].$2,
        'lessonId': lessonB['id'],
        'lessonName': lessonB['lessonName'],
        'hours': (freeHours * 0.35).clamp(0.8, 2.5),
        'score': 74 - (i * 2),
      });
    }

    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'weekStart': days.first.$1,
      'slots': slots,
    };
  }

  // Auth

  static Future<String> login(String email, String password) async {
    if (demoMode) {
      return _demoDelay('demo-token');
    }
    final res = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    final data = await _handleResponse(res);
    return data['access_token'] as String;
  }

  static Future<String> register(String email, String password) async {
    if (demoMode) {
      _demoUser = {..._demoUser, 'email': email};
      return _demoDelay('demo-token');
    }
    final res = await http.post(
      Uri.parse('$_base/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    final data = await _handleResponse(res);
    return data['access_token'] as String;
  }

  // User

  static Future<Map<String, dynamic>> getMe() async {
    if (demoMode) return _demoDelay(Map<String, dynamic>.from(_demoUser));
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$_base/person/me'), headers: headers);
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    if (demoMode) {
      _demoUser = {..._demoUser, ...data};
      return _demoDelay(Map<String, dynamic>.from(_demoUser));
    }
    final headers = await _authHeaders();
    final res = await http.patch(
      Uri.parse('$_base/person/update'),
      headers: headers,
      body: json.encode(data),
    );
    return await _handleResponse(res);
  }

  // Lessons

  static Future<List<dynamic>> getLessons() async {
    if (demoMode) {
      return _demoDelay(
        _demoLessons.map((e) => Map<String, dynamic>.from(e)).toList(),
      );
    }
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$_base/lesson'), headers: headers);
    return await _handleResponse(res);
  }

  static Future<List<dynamic>> registerLessons(
    List<Map<String, dynamic>> lessons,
  ) async {
    if (demoMode) {
      for (final lesson in lessons) {
        _demoLessons.add({
          'id': lesson['lessonName'].toString().toLowerCase().replaceAll(
            ' ',
            '-',
          ),
          'lessonName': lesson['lessonName'],
          'difficulty': lesson['difficulty'] ?? 3,
          'deadlines': List<Map<String, dynamic>>.from(
            lesson['deadlines'] ?? [],
          ),
          'semester': lesson['semester'] ?? _demoUser['semester'],
          'delay': lesson['delay'] ?? 0,
        });
      }
      return _demoDelay(
        _demoLessons.map((e) => Map<String, dynamic>.from(e)).toList(),
      );
    }
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/lesson/register'),
      headers: headers,
      body: json.encode(lessons),
    );
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> updateLesson(
    Map<String, dynamic> data,
  ) async {
    if (demoMode) {
      final index = _demoLessons.indexWhere(
        (lesson) => lesson['id'] == data['id'],
      );
      if (index == -1) throw Exception('Ders bulunamadi');
      _demoLessons[index] = {..._demoLessons[index], ...data};
      return _demoDelay(Map<String, dynamic>.from(_demoLessons[index]));
    }
    final headers = await _authHeaders();
    final res = await http.patch(
      Uri.parse('$_base/lesson/update'),
      headers: headers,
      body: json.encode(data),
    );
    return await _handleResponse(res);
  }

  static Future<void> deleteLesson(String id) async {
    if (demoMode) {
      _demoLessons.removeWhere((lesson) => lesson['id'] == id);
      _demoChecklist.removeWhere((item) => item['lessonId'] == id);
      return _demoDelay(null);
    }
    final headers = await _authHeaders();
    final res = await http.delete(
      Uri.parse('$_base/lesson/$id'),
      headers: headers,
    );
    await _handleResponse(res);
  }

  // Planner

  static Future<Map<String, dynamic>> createWeeklyPlan() async {
    if (demoMode) {
      _demoPlan = _buildDemoPlan();
      return _demoDelay(Map<String, dynamic>.from(_demoPlan!));
    }
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/planner/create'),
      headers: headers,
      body: json.encode({}),
    );
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> dailyUpdate(double freeHours) async {
    if (demoMode) {
      _demoPlan = _buildDemoPlan(freeHours: freeHours);
      return _demoDelay({
        'date': '2026-03-29',
        'slots': List<Map<String, dynamic>>.from(_demoPlan!['slots'] as List),
      });
    }
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/planner/dailyupdate'),
      headers: headers,
      body: json.encode({'freeHours': freeHours}),
    );
    return await _handleResponse(res);
  }

  // Checklist

  static Future<List<dynamic>> getTodayChecklist() async {
    if (demoMode) {
      return _demoDelay(
        _demoChecklist.map((e) => Map<String, dynamic>.from(e)).toList(),
      );
    }
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$_base/checklist/today'),
      headers: headers,
    );
    return await _handleResponse(res);
  }

  static Future<List<dynamic>> getAllChecklist() async {
    if (demoMode) {
      return _demoDelay(
        _demoChecklist.map((e) => Map<String, dynamic>.from(e)).toList(),
      );
    }
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$_base/checklist/get'),
      headers: headers,
    );
    return await _handleResponse(res);
  }

  static Future<List<dynamic>> createChecklist(
    List<Map<String, dynamic>> slots,
  ) async {
    if (demoMode) {
      _demoChecklist = slots
          .asMap()
          .entries
          .map(
            (entry) => {
              'id': 'check-${entry.key + 1}',
              'lessonId': entry.value['lessonId'],
              'lessonName': entry.value['lessonName'],
              'date': '2026-03-29',
              'plannedHours': (entry.value['hours'] as num).toDouble(),
              'actualHours': null,
              'status': 'pending',
              'remaining': (entry.value['hours'] as num).toDouble(),
            },
          )
          .toList();
      return _demoDelay(
        _demoChecklist.map((e) => Map<String, dynamic>.from(e)).toList(),
      );
    }
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/checklist/create'),
      headers: headers,
      body: json.encode({'slots': slots}),
    );
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> submitChecklist(
    Map<String, dynamic> data,
  ) async {
    if (demoMode) {
      final index = _demoChecklist.indexWhere(
        (item) => item['lessonId'] == data['lessonId'],
      );
      if (index == -1) throw Exception('Kontrol listesi kaydi bulunamadi');
      final actualHours = (data['actualHours'] as num?)?.toDouble();
      final plannedHours = (_demoChecklist[index]['plannedHours'] as num)
          .toDouble();
      _demoChecklist[index] = {
        ..._demoChecklist[index],
        'actualHours': actualHours,
        'status': data['status'],
        'remaining': actualHours == null
            ? plannedHours
            : (plannedHours - actualHours).clamp(0, plannedHours),
      };
      return _demoDelay(Map<String, dynamic>.from(_demoChecklist[index]));
    }
    final headers = await _authHeaders();
    final res = await http.patch(
      Uri.parse('$_base/checklist/submit'),
      headers: headers,
      body: json.encode(data),
    );
    return await _handleResponse(res);
  }
}
