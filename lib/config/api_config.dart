import 'package:flutter/foundation.dart';
import '../utils/storage_util.dart';

class ApiConfig {
  /// Base URL of the backend API
  static const String defaultBaseUrl = 'https://api.edutrack.com/api';
  
  static String _baseUrl = defaultBaseUrl;

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url;
  }

  // Auth endpoints
  static String get loginEndpoint => '$baseUrl/auth/login';
  static String get signupEndpoint => '$baseUrl/auth/signup';
  static String get refreshTokenEndpoint => '$baseUrl/auth/refresh';
  static String get forgotPasswordEndpoint => '$baseUrl/auth/forgot-password';
  static String get resetPasswordEndpoint => '$baseUrl/auth/reset-password';
  static String get logoutEndpoint => '$baseUrl/auth/logout';

  // Grades endpoints
  static String get gradesEndpoint => '$baseUrl/grades';
  static String studentGradesEndpoint(String studentId) => '$baseUrl/students/$studentId/grades';
  static String classGradesEndpoint(String classId) => '$baseUrl/classes/$classId/grades';

  // Attendance endpoints
  static String get attendanceEndpoint => '$baseUrl/attendance';
  static String studentAttendanceEndpoint(String studentId) => '$baseUrl/students/$studentId/attendance';
  static String classAttendanceEndpoint(String classId) => '$baseUrl/classes/$classId/attendance';

  // Schedule / Timetable endpoints
  static String get scheduleEndpoint => '$baseUrl/schedules';
  static String classScheduleEndpoint(String classId) => '$baseUrl/classes/$classId/schedule';
  static String teacherScheduleEndpoint(String teacherId) => '$baseUrl/teachers/$teacherId/schedule';
  static String studentScheduleEndpoint(String studentId) => '$baseUrl/students/$studentId/schedule';

  /// Standard HTTP headers with JWT Bearer Token authorization
  static Future<Map<String, String>> getAuthHeaders() async {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final token = await StorageUtil.getString('accessToken') ?? await StorageUtil.getString('schoolToken');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ ApiConfig: Failed to retrieve auth token: $e');
      }
    }

    return headers;
  }
}
