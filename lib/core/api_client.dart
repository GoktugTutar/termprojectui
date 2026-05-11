import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Tüm backend HTTP isteklerini yöneten merkezi API katmanı.
/// Base URL platforma göre otomatik seçilir (web, Android emülatör, diğer).
class ApiClient {
  static const String _tokenKey = 'jwt_token';

  /// Platforma göre uygun base URL'yi döndürür.
  static String get _base {
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  // ── Token yönetimi ──────────────────────────────────────────────────────────

  /// SharedPreferences'tan JWT token'ını okur; yoksa null döner.
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// JWT token'ını SharedPreferences'a kaydeder.
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Kayıtlı JWT token'ını siler (çıkış işlemi).
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ── Ortak yardımcılar ───────────────────────────────────────────────────────

  /// Authorization header dahil ortak HTTP başlıklarını döndürür.
  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// HTTP yanıtını işler: 2xx ise body'yi parse eder, aksi hâlde exception fırlatır.
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

  /// Mevcut kullanıcıyla oturum açar; başarılı olursa JWT access_token döner.
  static Future<String> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    final data = await _handle(res);
    return data['access_token'] as String;
  }

  /// Yeni kullanıcı kaydeder; başarılı olursa JWT access_token döner.
  static Future<String> register(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_base/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    final data = await _handle(res);
    return data['access_token'] as String;
  }

  // ── USER ────────────────────────────────────────────────────────────────────

  /// Oturumdaki kullanıcının profil bilgilerini getirir (GET /user/me).
  static Future<Map<String, dynamic>> getMe() async {
    final h = await _authHeaders();
    final res = await http.get(Uri.parse('$_base/user/me'), headers: h);
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  /// Kullanıcı tercihlerini kaydeder: preferredStudyTime, studyStyle, busySlots.
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

  /// Kullanıcının meşguliyet slotlarını toplu olarak günceller (PUT /user/busy-slots).
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

  // ── LESSON ──────────────────────────────────────────────────────────────────

  /// Kullanıcının tüm derslerini listeler (GET /lesson).
  static Future<List<dynamic>> getLessons() async {
    final h = await _authHeaders();
    final res = await http.get(Uri.parse('$_base/lesson'), headers: h);
    return await _handle(res) as List;
  }

  /// Yeni ders oluşturur (POST /lesson).
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

  /// Mevcut dersi günceller (PUT /lesson/:id).
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

  /// Dersi siler (DELETE /lesson/:id).
  static Future<void> deleteLesson(int id) async {
    final h = await _authHeaders();
    final res = await http.delete(
      Uri.parse('$_base/lesson/$id'),
      headers: h,
    );
    await _handle(res);
  }

  /// Derse sınav tarihi ekler (POST /lesson/:id/exam).
  /// [examDate] formatı: "YYYY-MM-DD"
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

  /// Derse ödev / deadline ekler (POST /lesson/:id/deadline).
  /// [deadlineDate] formatı: "YYYY-MM-DD", [title] opsiyonel.
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

  /// Dersten deadline siler (DELETE /lesson/:lessonId/deadline/:deadlineId).
  static Future<void> deleteDeadline(int lessonId, int deadlineId) async {
    final h = await _authHeaders();
    final res = await http.delete(
      Uri.parse('$_base/lesson/$lessonId/deadline/$deadlineId'),
      headers: h,
    );
    await _handle(res);
  }

  // ── PLANNER ─────────────────────────────────────────────────────────────────

  /// Haftalık planı algoritma ile oluşturur (POST /planner/create).
  /// Yanıt: {weekStart, blocks: [...]}
  static Future<Map<String, dynamic>> createWeeklyPlan() async {
    final h = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/planner/create'),
      headers: h,
      body: '{}',
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  /// Mevcut haftanın planını getirir (GET /planner/week).
  /// Yanıt: {weekStart, blocks: [...]}
  static Future<Map<String, dynamic>> getWeekPlan() async {
    final h = await _authHeaders();
    final res = await http.get(Uri.parse('$_base/planner/week'), headers: h);
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  /// BusySlot değişikliği sonrası planı yeniden hesaplar (POST /planner/recalculate).
  static Future<Map<String, dynamic>> recalculate() async {
    final h = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/planner/recalculate'),
      headers: h,
      body: '{}',
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  // ── CHECKLIST ───────────────────────────────────────────────────────────────

  /// Belirli bir günün checklist'ini getirir (GET /checklist/:date).
  /// O gün için checklist yoksa null döner.
  /// [date] formatı: "YYYY-MM-DD"
  static Future<Map<String, dynamic>?> getChecklist(String date) async {
    final h = await _authHeaders();
    final res = await http.get(
      Uri.parse('$_base/checklist/$date'),
      headers: h,
    );
    if (res.statusCode == 404 || res.body == 'null' || res.body.isEmpty) {
      return null;
    }
    final data = await _handle(res);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  /// Günlük checklist'i gönderir (POST /checklist/submit).
  /// [items]: [{lessonId, plannedBlocks, completedBlocks, delayed?}]
  static Future<Map<String, dynamic>?> submitChecklist({
    required int stressLevel,
    required int fatigueLevel,
    required List<Map<String, dynamic>> items,
  }) async {
    final h = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/checklist/submit'),
      headers: h,
      body: json.encode({
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

  /// Haftalık geri bildirimi kaydeder (POST /feedback/weekly).
  /// [weekloadFeedback]: "cok_yogundu" | "tam_uygundu" | "yetersizdi"
  /// [lessonFeedbacks]: [{lessonId, needsMoreTime}]
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

  /// Aktif uyarı ve öneri mesajlarını getirir (GET /feedback/messages).
  static Future<List<dynamic>> getFeedbackMessages() async {
    final h = await _authHeaders();
    final res = await http.get(
      Uri.parse('$_base/feedback/messages'),
      headers: h,
    );
    return await _handle(res) as List;
  }

  // ── DEBUG (sadece MODE=test) ─────────────────────────────────────────────────

  /// Backend modunu döndürür: { mode: "test"|"prod", current: string }
  static Future<Map<String, dynamic>> getMode() async {
    final h = await _authHeaders();
    final res = await http.get(
      Uri.parse('$_base/debug/mode'),
      headers: h,
    );
    return Map<String, dynamic>.from(await _handle(res) as Map);
  }

  /// Test modunda backend saatini override eder (POST /debug/clock).
  /// [isoDateTime] örn: "2026-05-08T10:00:00"
  static Future<void> setTestClock(String isoDateTime) async {
    final h = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/debug/clock'),
      headers: h,
      body: json.encode({'datetime': isoDateTime}),
    );
    await _handle(res);
  }
}