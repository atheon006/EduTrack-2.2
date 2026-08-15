import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class ApiService {
  final http.Client _client;
  final String? baseUrl;

  ApiService([this.baseUrl, http.Client? client]) : _client = client ?? http.Client();

  // ==================== AUTHENTICATION ====================

  /// User Login
  Future<Map<String, dynamic>> login(String email, String password, {String? schoolToken}) async {
    final url = Uri.parse(ApiConfig.loginEndpoint);
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        if (schoolToken != null) 'schoolToken': schoolToken,
      }),
    );

    return _processResponse(response);
  }

  /// Signup User
  Future<http.Response> signup(Map<String, dynamic> userDetails) async {
    final url = Uri.parse(ApiConfig.signupEndpoint);
    return await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(userDetails),
    );
  }

  /// Forgot Password
  Future<http.Response> forgotPassword(String email) async {
    final url = Uri.parse(ApiConfig.forgotPasswordEndpoint);
    return await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
  }

  /// Reset Password
  Future<http.Response> resetPassword(String token, String newPassword) async {
    final url = Uri.parse(ApiConfig.resetPasswordEndpoint);
    return await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'password': newPassword}),
    );
  }

  /// Bulk Signup
  Future<http.Response> bulkSignup(List<Map<String, dynamic>> rows, String accessToken) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/bulk-upload');
    return await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'rows': rows}),
    );
  }

  /// Refresh Auth Token
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final url = Uri.parse(ApiConfig.refreshTokenEndpoint);
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    return _processResponse(response);
  }

  /// Logout User
  Future<bool> logout() async {
    final headers = await ApiConfig.getAuthHeaders();
    final url = Uri.parse(ApiConfig.logoutEndpoint);
    try {
      final response = await _client.post(url, headers: headers);
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('⚠️ ApiService logout error: $e');
      return false;
    }
  }

  // ==================== GRADES ====================

  /// Get grades for a student (Student / Parent role)
  Future<List<dynamic>> getStudentGrades(String studentId) async {
    final headers = await ApiConfig.getAuthHeaders();
    final url = Uri.parse(ApiConfig.studentGradesEndpoint(studentId));
    final response = await _client.get(url, headers: headers);
    final data = _processResponse(response);
    return data['grades'] as List<dynamic>? ?? [];
  }

  /// Get grades for a class (Teacher / Admin role)
  Future<List<dynamic>> getClassGrades(String classId, {String? subjectId}) async {
    final headers = await ApiConfig.getAuthHeaders();
    var uri = Uri.parse(ApiConfig.classGradesEndpoint(classId));
    if (subjectId != null) {
      uri = uri.replace(queryParameters: {'subjectId': subjectId});
    }
    final response = await _client.get(uri, headers: headers);
    final data = _processResponse(response);
    return data['grades'] as List<dynamic>? ?? [];
  }

  /// Submit bulk grades (Teacher / Admin role)
  Future<Map<String, dynamic>> submitGrades(Map<String, dynamic> gradePayload) async {
    final headers = await ApiConfig.getAuthHeaders();
    final url = Uri.parse(ApiConfig.gradesEndpoint);
    final response = await _client.post(
      url,
      headers: headers,
      body: jsonEncode(gradePayload),
    );
    return _processResponse(response);
  }

  // ==================== ATTENDANCE ====================

  /// Get attendance records for a student
  Future<List<dynamic>> getStudentAttendance(String studentId, {String? startDate, String? endDate}) async {
    final headers = await ApiConfig.getAuthHeaders();
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;

    final uri = Uri.parse(ApiConfig.studentAttendanceEndpoint(studentId)).replace(queryParameters: queryParams);
    final response = await _client.get(uri, headers: headers);
    final data = _processResponse(response);
    return data['attendance'] as List<dynamic>? ?? [];
  }

  /// Submit attendance (Teacher / Admin role)
  Future<Map<String, dynamic>> submitAttendance(Map<String, dynamic> attendancePayload) async {
    final headers = await ApiConfig.getAuthHeaders();
    final url = Uri.parse(ApiConfig.attendanceEndpoint);
    final response = await _client.post(
      url,
      headers: headers,
      body: jsonEncode(attendancePayload),
    );
    return _processResponse(response);
  }

  // ==================== SCHEDULE / TIMETABLE ====================

  /// Get class timetable schedule
  Future<List<dynamic>> getClassSchedule(String classId) async {
    final headers = await ApiConfig.getAuthHeaders();
    final url = Uri.parse(ApiConfig.classScheduleEndpoint(classId));
    final response = await _client.get(url, headers: headers);
    final data = _processResponse(response);
    return data['schedule'] as List<dynamic>? ?? [];
  }

  /// Get teacher schedule
  Future<List<dynamic>> getTeacherSchedule(String teacherId) async {
    final headers = await ApiConfig.getAuthHeaders();
    final url = Uri.parse(ApiConfig.teacherScheduleEndpoint(teacherId));
    final response = await _client.get(url, headers: headers);
    final data = _processResponse(response);
    return data['schedule'] as List<dynamic>? ?? [];
  }

  /// Helper to handle and validate HTTP responses
  Map<String, dynamic> _processResponse(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is Map<String, dynamic>) {
        return body;
      }
      return {'data': body};
    } else {
      final message = body is Map && body.containsKey('message') 
          ? body['message'] 
          : 'HTTP Error ${response.statusCode}';
      throw Exception(message);
    }
  }
}
