import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FirestoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ==================== AUTH & USER PROFILES ====================

  /// Current authenticated Firebase user
  User? get currentUser => _auth.currentUser;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Email & Password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  /// Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Get user profile document by ID
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserProfile(String userId) async {
    return await _db.collection('users').doc(userId).get();
  }

  /// Real-time User Profile Stream
  Stream<DocumentSnapshot<Map<String, dynamic>>> userProfileStream(String userId) {
    return _db.collection('users').doc(userId).snapshots();
  }

  /// Create or update user profile
  Future<void> setUserProfile(String userId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(userId).set(data, SetOptions(merge: true));
  }

  // ==================== GRADES (TEMPS RÉEL) ====================

  /// Stream student grades in real-time
  Stream<List<Map<String, dynamic>>> getStudentGradesStream(String studentId) {
    return _db
        .collection('grades')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Stream class grades in real-time (Teacher / Admin)
  Stream<List<Map<String, dynamic>>> getClassGradesStream(String classId, {String? subjectId}) {
    Query<Map<String, dynamic>> query = _db.collection('grades').where('classId', isEqualTo: classId);
    if (subjectId != null) {
      query = query.where('subjectId', isEqualTo: subjectId);
    }
    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Submit or update grade
  Future<void> addOrUpdateGrade(String gradeId, Map<String, dynamic> gradeData) async {
    gradeData['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('grades').doc(gradeId).set(gradeData, SetOptions(merge: true));
  }

  // ==================== ATTENDANCE (TEMPS RÉEL) ====================

  /// Stream student attendance in real-time
  Stream<List<Map<String, dynamic>>> getStudentAttendanceStream(String studentId) {
    return _db
        .collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Submit class attendance entry
  Future<void> recordAttendance(Map<String, dynamic> attendanceData) async {
    attendanceData['timestamp'] = FieldValue.serverTimestamp();
    await _db.collection('attendance').add(attendanceData);
  }

  // ==================== SCHEDULES / TIMETABLE (TEMPS RÉEL) ====================

  /// Stream class timetable in real-time
  Stream<List<Map<String, dynamic>>> getClassScheduleStream(String classId) {
    return _db
        .collection('schedules')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Add or update schedule slot
  Future<void> setScheduleSlot(String scheduleId, Map<String, dynamic> scheduleData) async {
    await _db.collection('schedules').doc(scheduleId).set(scheduleData, SetOptions(merge: true));
  }

  // ==================== ANNOUNCEMENTS ====================

  /// Stream school announcements in real-time
  Stream<List<Map<String, dynamic>>> getAnnouncementsStream(String schoolId) {
    return _db
        .collection('announcements')
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Post new announcement
  Future<void> postAnnouncement(Map<String, dynamic> announcementData) async {
    announcementData['timestamp'] = FieldValue.serverTimestamp();
    await _db.collection('announcements').add(announcementData);
  }
}
