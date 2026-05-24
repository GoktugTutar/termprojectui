import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Tüm backend HTTP isteklerini yöneten merkezi API katmanı.
/// Base URL platforma göre otomatik seçilir (web, Android emülatör, diğer).
class ApiClient {
  static final String _tokenKey = 'jwt_token';

  /// Platforma göre uygun base URL'yi döndürür.
  static String get _base {
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  // ── Token yönetimi ──────────────────────────────────────────────────────────

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

  // ── Ortak yardımcılar ───────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return Future.value(null);
      return Future.value(json.decode(res.body));
    }
    String msg = 'Hata: ${res.statusCode}';
    try {
      final b = json.decode(res.body);
      if (b is Map && b['message'] != null) {
        final m = b['message'];
        msg = m is List ? m.join('\n') : m.toString();
      }
    } catch (_) {}
    throw Exception(msg);
  }

  // ── AUTH ────────────────────────────────────────────────────────────────────

  static Future<String> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    final data = await _handle(res);
    return data['access_token'] as String;
  }

  static Future<String> register(
    String email,
    String password, {
    int? gradeLevel,
    double? gpa,
    String? academicTerm,
  }) async {
    final body = <String, dynamic>{'email': email, 'password': password};
    if (gradeLevel != null) {
      body['gradeLevel'] = gradeLevel;
    }
    if (gpa != null) {
      body['gpa'] = gpa;
    }
    if (academicTerm != null && academicTerm.trim().isNotEmpty) {
      body['academicTerm'] = academicTerm.trim();
    }
    final res = await http.post(
      Uri.parse('$_base/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    final data = await _handle(res);
    return data['access_token'] as String;
  }

  // ── USER ────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMe() async {
    final h = await _authHeaders();
    final res = await http.get(Uri.parse('$_base/user/me'), headers: h);
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<Map<String, dynamic>> setupUser(
    Map<String, dynamic> data,
  ) async {
    final h = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/user/setup'),
      headers: h,
      body: json.encode(data),
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<Map<String, dynamic>> updateBusySlots(
    List<Map<String, dynamic>> busySlots,
  ) async {
    final h = await _authHeaders();
    final res = await http.put(
      Uri.parse('$_base/user/busy-slots'),
      headers: h,
      body: json.encode({'busySlots': busySlots}),
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<Map<String, dynamic>> saveAvatar({
    required String avatarSvg,
    required String avatarOptions,
  }) async {
    final h = await _authHeaders();
    final res = await http.put(
      Uri.parse('$_base/user/avatar'),
      headers: h,
      body: json.encode({
        'avatarSvg': avatarSvg,
        'avatarOptions': avatarOptions,
      }),
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<Map<String, dynamic>> getStudentProfile() async {
    final h = await _authHeaders();
    final res = await http.get(
      Uri.parse('$_base/user/student-profile'),
      headers: h,
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<void> endTerm() async {
    final h = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/user/end-term'),
      headers: h,
      body: '{}',
    );
    await _handle(res);
  }

  static Future<Map<String, dynamic>> startTerm({String? name}) async {
    final h = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/user/start-term'),
      headers: h,
      body: json.encode({'name': name}),
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  // ── LESSON ──────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getLessons() async {
    final h = await _authHeaders();
    final res = await http.get(Uri.parse('$_base/lesson'), headers: h);
    return await _handle(res) as List;
  }

  static Future<Map<String, dynamic>> createLesson(
    String name,
    int difficulty,
  ) async {
    final h = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/lesson'),
      headers: h,
      body: json.encode({'name': name, 'difficulty': difficulty}),
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<Map<String, dynamic>> updateLesson(
    int id, {
    String? name,
    int? difficulty,
  }) async {
    final h = await _authHeaders();
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (difficulty != null) body['difficulty'] = difficulty;
    final res = await http.put(
      Uri.parse('$_base/lesson/$id'),
      headers: h,
      body: json.encode(body),
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<void> deleteLesson(int id) async {
    final h = await _authHeaders();
    final res = await http.delete(Uri.parse('$_base/lesson/$id'), headers: h);
    await _handle(res);
  }

  static Future<Map<String, dynamic>> addExam(
    int lessonId,
    String examDate,
  ) async {
    final h = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/lesson/$lessonId/exam'),
      headers: h,
      body: json.encode({'examDate': examDate}),
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<Map<String, dynamic>> addDeadline(
    int lessonId,
    String deadlineDate, {
    String? title,
  }) async {
    final h = await _authHeaders();
    final body = <String, dynamic>{'deadlineDate': deadlineDate};
    if (title != null && title.isNotEmpty) body['title'] = title;
    final res = await http.post(
      Uri.parse('$_base/lesson/$lessonId/deadline'),
      headers: h,
      body: json.encode(body),
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<void> deleteDeadline(int lessonId, int deadlineId) async {
    final h = await _authHeaders();
    final res = await http.delete(
      Uri.parse('$_base/lesson/$lessonId/deadline/$deadlineId'),
      headers: h,
    );
    await _handle(res);
  }

  static Future<Map<String, dynamic>> saveExamResult({
    required int lessonId,
    required int examId,
    String? grade,
    bool? satisfied,
  }) async {
    final h = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/lesson/$lessonId/exam-result'),
      headers: h,
      body: json.encode({
        'examId': examId,
        'grade': grade,
        'satisfied': satisfied,
      }),
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<void> deleteExamResult({
    required int lessonId,
    required int examId,
  }) async {
    final h = await _authHeaders();
    final res = await http.delete(
      Uri.parse('$_base/lesson/$lessonId/exam-result/$examId'),
      headers: h,
    );
    await _handle(res);
  }

  // ── PLANNER ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createWeeklyPlan() async {
    final h = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/planner/create'),
      headers: h,
      body: '{}',
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<Map<String, dynamic>> getWeekPlan() async {
    final h = await _authHeaders();
    final res = await http.get(Uri.parse('$_base/planner/week'), headers: h);
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<Map<String, dynamic>> recalculate({String? fromDate}) async {
    final h = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/planner/recalculate'),
      headers: h,
      body: json.encode({'fromDate': fromDate}),
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  // ── CHECKLIST ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getChecklist(String date) async {
    final h = await _authHeaders();
    final res = await http.get(Uri.parse('$_base/checklist/$date'), headers: h);
    if (res.statusCode == 404 || res.body == 'null' || res.body.isEmpty) {
      return null;
    }
    final data = await _handle(res);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<List<Map<String, dynamic>>> getChecklistHistory() async {
    final h = await _authHeaders();
    final res = await http.get(
      Uri.parse('$_base/checklist/history'),
      headers: h,
    );
    final data = await _handle(res);
    return (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> getChecklistStatus(String date) async {
    final h = await _authHeaders();
    final res = await http.get(
      Uri.parse('$_base/checklist/status/$date'),
      headers: h,
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<Map<String, dynamic>?> submitChecklist({
    String? date,
    required int stressLevel,
    required int fatigueLevel,
    required List<Map<String, dynamic>> items,
  }) async {
    final h = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/checklist/submit'),
      headers: h,
      body: json.encode({
        'date': ?date,
        'stressLevel': stressLevel,
        'fatigueLevel': fatigueLevel,
        'items': items,
      }),
    );
    final data = await _handle(res);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  // ── FEEDBACK ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> submitWeeklyFeedback({
    required String weekloadFeedback,
    required List<Map<String, dynamic>> lessonFeedbacks,
  }) async {
    final h = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/feedback/weekly'),
      headers: h,
      body: json.encode({
        'weekloadFeedback': weekloadFeedback,
        'lessonFeedbacks': lessonFeedbacks,
      }),
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<bool> getWeeklyFeedbackStatus() async {
    final h = await _authHeaders();
    final res = await http.get(
      Uri.parse('$_base/feedback/weekly/status'),
      headers: h,
    );
    final data = await _handle(res) as Map;
    return data['submitted'] == true;
  }

  /// Sistem feedback mesajlarını ve AI mesajını getirir (GET /system-feedback/message).
  /// Yanıt: { messages: [...], aiMessage: "..." }
  static Future<Map<String, dynamic>> getFeedbackMessages() async {
    final h = await _authHeaders();
    final res = await http.get(
      Uri.parse('$_base/system-feedback/message'),
      headers: h,
    );
    final data = await _handle(res);
    // Backend düz liste dönerse (eski format) uyumlu hale getir
    if (data is List) return {'messages': data, 'aiMessage': ''};
    return Map<String, dynamic>.from(data as Map);
  }

  // ── DEBUG (sadece MODE=test) ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMode() async {
    final h = await _authHeaders();
    final res = await http.get(Uri.parse('$_base/debug/mode'), headers: h);
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<void> setTestClock(String isoDateTime) async {
    final h = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/debug/clock'),
      headers: h,
      body: json.encode({'datetime': isoDateTime}),
    );
    await _handle(res);
  }

  // ── AI COACH ────────────────────────────────────────────────────────────────

  /// POST /ai-coach/what-if
  /// userId JWT'den alınır, body'ye eklenmez.
  static Future<Map<String, dynamic>> whatIf({
    required String scenario,
    int? focusLessonId,
    String? emptyDayName,
    int? emptyDayBlockCount,
  }) async {
    final h = await _authHeaders();
    final body = <String, dynamic>{'scenario': scenario};
    if (focusLessonId != null) body['focusLessonId'] = focusLessonId;
    if (emptyDayName != null) body['emptyDayName'] = emptyDayName;
    if (emptyDayBlockCount != null) {
      body['emptyDayBlockCount'] = emptyDayBlockCount;
    }
    final res = await http.post(
      Uri.parse('$_base/ai-coach/what-if'),
      headers: h,
      body: json.encode(body),
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  /// POST /ai-coach/daily-coach
  /// userId JWT'den alınır.
  static Future<Map<String, dynamic>> dailyCoach() async {
    final h = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/ai-coach/daily-coach'),
      headers: h,
      body: '{}',
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<Map<String, dynamic>> getSleepStatus() async {
    final h = await _authHeaders();
    final res = await http.get(
      Uri.parse('$_base/checklist/sleep/status'),
      headers: h,
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  static Future<void> submitSleep(bool sleptWell) async {
    final h = await _authHeaders();
    await http.post(
      Uri.parse('$_base/checklist/sleep'),
      headers: h,
      body: json.encode({'sleptWell': sleptWell}),
    );
  }
}
