import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String _base = 'http://localhost:3000';
  static const String _tokenKey = 'jwt_token';

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
      msg = body['message'] ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

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

  // ─── User ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMe() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$_base/person/me'), headers: headers);
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> data) async {
    final headers = await _authHeaders();
    final res = await http.patch(
      Uri.parse('$_base/person/update'),
      headers: headers,
      body: json.encode(data),
    );
    return await _handleResponse(res);
  }

  // ─── Lessons ───────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getLessons() async {
    final headers = await _authHeaders();
    final res =
        await http.get(Uri.parse('$_base/lesson'), headers: headers);
    return await _handleResponse(res);
  }

  static Future<List<dynamic>> registerLessons(
      List<Map<String, dynamic>> lessons) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/lesson/register'),
      headers: headers,
      body: json.encode(lessons),
    );
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> updateLesson(
      Map<String, dynamic> data) async {
    final headers = await _authHeaders();
    final res = await http.patch(
      Uri.parse('$_base/lesson/update'),
      headers: headers,
      body: json.encode(data),
    );
    return await _handleResponse(res);
  }

  static Future<void> deleteLesson(String id) async {
    final headers = await _authHeaders();
    final res = await http.delete(
        Uri.parse('$_base/lesson/$id'),
        headers: headers);
    await _handleResponse(res);
  }

  // ─── Planner ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createWeeklyPlan() async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/planner/create'),
      headers: headers,
      body: json.encode({}),
    );
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> dailyUpdate(double freeHours) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/planner/dailyupdate'),
      headers: headers,
      body: json.encode({'freeHours': freeHours}),
    );
    return await _handleResponse(res);
  }

  // ─── Checklist ─────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getTodayChecklist() async {
    final headers = await _authHeaders();
    final res = await http.get(
        Uri.parse('$_base/checklist/today'), headers: headers);
    return await _handleResponse(res);
  }

  static Future<List<dynamic>> getAllChecklist() async {
    final headers = await _authHeaders();
    final res = await http.get(
        Uri.parse('$_base/checklist/get'), headers: headers);
    return await _handleResponse(res);
  }

  static Future<List<dynamic>> createChecklist(
      List<Map<String, dynamic>> slots) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/checklist/create'),
      headers: headers,
      body: json.encode({'slots': slots}),
    );
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> submitChecklist(
      Map<String, dynamic> data) async {
    final headers = await _authHeaders();
    final res = await http.patch(
      Uri.parse('$_base/checklist/submit'),
      headers: headers,
      body: json.encode(data),
    );
    return await _handleResponse(res);
  }
}
