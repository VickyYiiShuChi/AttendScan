// lib/services/firebase_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:attend_scan/services/location_service.dart';

// ==================== DATA MODELS ====================

/// User Model
/// Represents a user document from Firestore (both student and admin)
class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String role; // 'student' or 'admin'
  
  // Student only fields
  final String? studentId;
  final String? indexNo;
  final String? faculty;    
  final String? programme;   
  
  // Common fields
  final String avatarStyle;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastLogin;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.studentId,
    this.indexNo,
    this.faculty,
    this.programme,
    required this.avatarStyle,
    required this.createdAt,
    required this.updatedAt,
    required this.lastLogin,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return UserModel(
      uid: data['uid'] ?? doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      role: data['role'] ?? 'student',
      studentId: data['studentId'],
      indexNo: data['indexNo'] ?? '',
      faculty: data['faculty'] ?? '',         
      programme: data['programme'] ?? '',     
      avatarStyle: data['avatarStyle'] ?? 'avataaars',
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      lastLogin: _parseDateTime(data['lastLogin']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try { return DateTime.parse(value); } catch (_) { return DateTime.now(); }
    }
    return DateTime.now();
  }

  bool get isStudent => role == 'student';
  bool get isAdmin => role == 'admin';
  
  String get formattedMemberSince {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    final day = createdAt.day;
    final daySuffix = _getDaySuffix(day);
    return '$day$daySuffix ${months[createdAt.month - 1]} ${createdAt.year}';
  }

  static String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  // Allow creating a locally modified copy (used by UI for local updates)
  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? role,
    String? studentId,
    String? indexNo,
    String? faculty,
    String? programme,
    String? avatarStyle,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      studentId: studentId ?? this.studentId,
      indexNo: indexNo ?? this.indexNo,
      faculty: faculty ?? this.faculty,
      programme: programme ?? this.programme,
      avatarStyle: avatarStyle ?? this.avatarStyle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}

/// Exam Model
/// Represents an exam document from Firestore
class Exam {
  final String examId;
  final String subjectName;
  final String location;
  final List<String> allowedClasses;
  final bool isActive;
  final DateTime createdAt;
  final DateTime startTime;
  final DateTime endTime;
  final String createdBy; // Admin UID who created this exam

  Exam({
    required this.examId,
    required this.subjectName,
    required this.location,
    required this.allowedClasses,
    required this.isActive,
    required this.createdAt,
    required this.startTime,
    required this.endTime,
    required this.createdBy,
  });

  factory Exam.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    DateTime startTime;
    if (data['startTime'] is Timestamp) {
      startTime = (data['startTime'] as Timestamp).toDate();
    } else if (data['startTime'] is String) {
      try {
        startTime = DateTime.parse(data['startTime'] as String);
      } catch (e) {
        startTime = DateTime.now();
      }
    } else {
      throw Exception('Missing or invalid startTime field');
    }
    
    DateTime endTime;
    if (data['endTime'] is Timestamp) {
      endTime = (data['endTime'] as Timestamp).toDate();
    } else if (data['endTime'] is String) {
      try {
        endTime = DateTime.parse(data['endTime'] as String);
      } catch (e) {
        endTime = startTime.add(const Duration(hours: 2));
      }
    } else {
      endTime = startTime.add(const Duration(hours: 2));
    }
    
    DateTime createdAt;
    try {
      if (data['createdAt'] is Timestamp) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is String) {
        createdAt = DateTime.parse(data['createdAt'] as String);
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      createdAt = DateTime.now();
    }
    
    List<String> allowedClasses = [];
    if (data['allowedClasses'] is List) {
      allowedClasses = List<String>.from(data['allowedClasses'] ?? []);
    }
    
    return Exam(
      examId: doc.id,
      subjectName: data['subjectName']?.toString() ?? 'Unknown Subject',
      location: data['location']?.toString() ?? 'Unknown Location',
      allowedClasses: allowedClasses,
      isActive: data['isActive'] ?? false,
      createdAt: createdAt,
      startTime: startTime,
      endTime: endTime,
      createdBy: data['createdBy'] ?? '',
    );
  }

  String get formattedDate {
    return '${startTime.day}/${startTime.month}/${startTime.year}';
  }
  
  String get formattedTime {
    return '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} - ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
  }
  
  String get formattedDateTime {
    return '$formattedDate • $formattedTime';
  }
}

/// AttendanceRecord Model
class AttendanceRecord {
  final String attendanceId;
  final String examId;
  final String studentId;
  final String indexNo;
  final String indexNoWords;
  final String seatNo;
  final DateTime scannedAt;
  final String status;
  final String? scannedLocation;
  final double? scannedLatitude;
  final double? scannedLongitude;

  AttendanceRecord({
    required this.attendanceId,
    required this.examId,
    required this.studentId,
    required this.indexNo,
    required this.indexNoWords,
    required this.seatNo,
    required this.scannedAt,
    required this.status,
    this.scannedLocation,
    this.scannedLatitude,
    this.scannedLongitude,
  });

  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return AttendanceRecord(
      attendanceId: doc.id,
      examId: data['examId'] ?? '',
      studentId: data['studentId'] ?? '',
      indexNo: data['indexNo'] ?? '',
      indexNoWords: data['indexNoWords'] ?? '',
      seatNo: data['seatNo'] ?? '',
      scannedAt: data['scannedAt'] is Timestamp
          ? (data['scannedAt'] as Timestamp).toDate()
          : DateTime.parse(data['scannedAt'] ?? DateTime.now().toIso8601String()),
      status: data['status'] ?? 'present',
      scannedLocation: data['scannedLocation']?.toString(),
      scannedLatitude: data['scannedLatitude'] != null ? (data['scannedLatitude'] as num).toDouble() : null,
      scannedLongitude: data['scannedLongitude'] != null ? (data['scannedLongitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'examId': examId,
      'studentId': studentId,
      'indexNo': indexNo,
      'indexNoWords': indexNoWords,
      'seatNo': seatNo,
      'scannedAt': scannedAt.toIso8601String(),
      'status': status,
      if (scannedLocation != null) 'scannedLocation': scannedLocation,
      if (scannedLatitude != null) 'scannedLatitude': scannedLatitude,
      if (scannedLongitude != null) 'scannedLongitude': scannedLongitude,
    };
  }
  
  // Simple check if scanned within UTAR campus
  bool get isWithinUtar {
    if (scannedLatitude == null || scannedLongitude == null) return false;
    return LocationService.isWithinUtarCampus(scannedLatitude!, scannedLongitude!);
  }
}

// ==================== FIREBASE SERVICE MAIN CLASS ====================

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ==================== USER AUTHENTICATION ====================

  /// Register a new student
  Future<String?> registerStudent({
    required String email,
    required String password,
    required String fullName,
    required String studentId,
  }) async {
    try {
      // Check if studentId already exists
      final studentIdQuery = await _firestore
          .collection('users')
          .where('studentId', isEqualTo: studentId)
          .get();
      if (studentIdQuery.docs.isNotEmpty) {
        return 'Student ID already registered';
      }

      // Check if email already exists
      final emailQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      if (emailQuery.docs.isNotEmpty) {
        return 'Email already registered';
      }

      // Create Auth user
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      DateTime now = DateTime.now();
      String nowString = now.toIso8601String();
      
      // Save to users collection with role = 'student'
      // Use `studentId` as the document ID and store the auth `uid` inside the doc
      await _firestore.collection('users').doc(studentId).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'fullName': fullName,
        'role': 'student',
        'studentId': studentId,
        'indexNo': '',
        'faculty': '',       
        'programme': '',     
        'avatarStyle': 'avataaars',
        'createdAt': nowString,
        'updatedAt': nowString,
        'lastLogin': nowString,
      });

      return 'Success';
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'Registration failed: $e';
    }
  }

  /// Login user (works for both student and admin)
  /// Returns: { success: bool, role: string, message: string, uid: string }
  Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Get user data from Firestore by querying the `uid` field (doc id may be studentId)
      final userQuery = await _firestore
          .collection('users')
          .where('uid', isEqualTo: userCredential.user!.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        await _auth.signOut();
        return {
          'success': false,
          'message': 'No user record found. Please contact administrator.',
        };
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();

      // Update last login on the found document id
      await _firestore.collection('users').doc(userDoc.id).update({
        'lastLogin': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      return {
        'success': true,
        'role': userData['role'],
        'uid': userCredential.user!.uid,
        'message': 'Success',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Login failed: $e',
      };
    }
  }

  /// Get current user (returns UserModel)
  Future<UserModel?> getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user == null) return null;
    
    try {
      // Query the users collection by the stored auth uid (document id may be studentId)
      final userQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return null;

      return UserModel.fromFirestore(userQuery.docs.first);
    } catch (e) {
      return null;
    }
  }

  // `getCurrentStudent()` removed; use `getCurrentUser()` returning `UserModel`.

  /// Sign out current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ==================== PASSWORD MANAGEMENT ====================

  /// Change user password
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return 'User not logged in';
      
      // Re-authenticate user
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      // Update password
      await user.updatePassword(newPassword);
      
      return 'Success';
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'Failed to change password: $e';
    }
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
      );
      
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('Email not registered');
        case 'invalid-email':
          throw Exception('Invalid email format');
        default:
          throw Exception('Failed to send reset email');
      }
    }
  }

  // ==================== EXAM RELATED METHODS (STUDENT) ====================

  /// Get all exams that a student is allowed to take
  Future<List<Exam>> getExamsForStudent(String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('exams')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();
      
      if (snapshot.docs.isEmpty) {
        return [];
      }
      
      final exams = snapshot.docs
          .map((doc) => Exam.fromFirestore(doc))
          .where((exam) => exam.allowedClasses.contains(studentId))
          .toList();
      
      return exams;
    } catch (e) {
      return [];
    }
  }

  /// Get exam by ID
  Future<Exam?> getExamById(String examId) async {
    try {
      final doc = await _firestore.collection('exams').doc(examId).get();
      if (doc.exists) {
        return Exam.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get all exams for a student with their attendance status
  Future<Map<String, dynamic>> getStudentExamsWithStatus(String studentId) async {
    try {
      final allowedExams = await getExamsForStudent(studentId);
      final attendanceRecords = await getAttendanceHistory(studentId);
      
      final attendedExamIds = attendanceRecords
          .where((record) => record.status == 'present')
          .map((record) => record.examId)
          .toSet();
      
      final now = DateTime.now();
      final upcomingExams = <Exam>[];
      final presentExams = <Exam>[];
      final absentExams = <Exam>[];
      
      for (final exam in allowedExams) {
        try {
          if (attendedExamIds.contains(exam.examId)) {
            presentExams.add(exam);
          } else if (now.isAfter(exam.endTime)) {
            absentExams.add(exam);
            await _createAbsentAttendanceIfNeeded(exam.examId, studentId);
          } else if (now.isAfter(exam.startTime)) {
            upcomingExams.add(exam);
          } else {
            upcomingExams.add(exam);
          }
        } catch (e) {
          // Silently handle error
        }
      }
      
      return {
        'upcoming': upcomingExams,
        'present': presentExams,
        'absent': absentExams,
        'total': allowedExams.length,
      };
    } catch (e) {
      return {
        'upcoming': [],
        'present': [],
        'absent': [],
        'total': 0,
      };
    }
  }

  // ==================== EXAM RELATED METHODS (ADMIN) ====================

  /// Create a new exam (admin only)
  Future<Map<String, dynamic>> createExam({
    required String subjectName,
    required String location,
    required DateTime startTime,
    required DateTime endTime,
    required List<String> allowedClasses,
    required String adminUid,
  }) async {
    try {
      // Verify admin role (lookup by stored auth uid)
      final adminQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: adminUid)
          .limit(1)
          .get();
      if (adminQuery.docs.isEmpty || adminQuery.docs.first.data()?['role'] != 'admin') {
        return {
          'success': false,
          'message': 'Unauthorized. Admin access required.',
        };
      }

      // Use a deterministic document ID based on subjectName
      final String examId = _slugify(subjectName);
      final examDocRef = _firestore.collection('exams').doc(examId);

      // Prevent accidental duplicate subject names
      final existing = await examDocRef.get();
      if (existing.exists) {
        return {
          'success': false,
          'message': 'An exam with a similar subject name already exists. Please use a unique subject name.',
        };
      }

      final now = DateTime.now();
      await examDocRef.set({
        'subjectName': subjectName,
        'location': location,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'allowedClasses': allowedClasses,
        'isActive': true,
        'createdAt': now.toIso8601String(),
        'createdBy': adminUid,
      });

      return {
        'success': true,
        'examId': examId,
        'message': 'Exam created successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create exam: $e',
      };
    }
  }

  /// Update an exam (admin only)
  Future<Map<String, dynamic>> updateExam({
    required String examId,
    required String? subjectName,
    required String? location,
    required DateTime? startTime,
    required DateTime? endTime,
    required List<String>? allowedClasses,
    required bool? isActive,
    required String adminUid,
  }) async {
    try {
      // Verify admin role (lookup by stored auth uid)
      final adminQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: adminUid)
          .limit(1)
          .get();
      if (adminQuery.docs.isEmpty || adminQuery.docs.first.data()?['role'] != 'admin') {
        return {
          'success': false,
          'message': 'Unauthorized. Admin access required.',
        };
      }

      final updates = <String, dynamic>{};
      
      if (subjectName != null) updates['subjectName'] = subjectName;
      if (location != null) updates['location'] = location;
      if (startTime != null) updates['startTime'] = startTime.toIso8601String();
      if (endTime != null) updates['endTime'] = endTime.toIso8601String();
      if (allowedClasses != null) updates['allowedClasses'] = allowedClasses;
      if (isActive != null) updates['isActive'] = isActive;
      
      updates['updatedAt'] = DateTime.now().toIso8601String();

      await _firestore.collection('exams').doc(examId).update(updates);

      return {
        'success': true,
        'message': 'Exam updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update exam: $e',
      };
    }
  }

  /// Get all exams (admin only)
  Future<Map<String, dynamic>> getAllExams({
    required String adminUid,
    bool? isActive,
  }) async {
    try {
      // Verify admin role (lookup by stored auth uid)
      final adminQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: adminUid)
          .limit(1)
          .get();
      if (adminQuery.docs.isEmpty || adminQuery.docs.first.data()?['role'] != 'admin') {
        return {
          'success': false,
          'message': 'Unauthorized. Admin access required.',
          'exams': [],
        };
      }

      Query query = _firestore.collection('exams').orderBy('createdAt', descending: true);
      
      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      }

      final snapshot = await query.get();
      
      final exams = snapshot.docs
          .map((doc) => Exam.fromFirestore(doc))
          .toList();

      return {
        'success': true,
        'exams': exams,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get exams: $e',
        'exams': [],
      };
    }
  }

  // ==================== ATTENDANCE RELATED METHODS (ADMIN) ====================

  /// Get attendance records for a specific exam (admin only)
  Future<Map<String, dynamic>> getExamAttendance({
    required String examId,
    required String adminUid,
  }) async {
    try {
      // Verify admin role (lookup by stored auth uid)
      final adminQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: adminUid)
          .limit(1)
          .get();
      if (adminQuery.docs.isEmpty || adminQuery.docs.first.data()?['role'] != 'admin') {
        return {
          'success': false,
          'message': 'Unauthorized. Admin access required.',
          'attendance': [],
        };
      }

      // Get exam details
      final examDoc = await _firestore.collection('exams').doc(examId).get();
      if (!examDoc.exists) {
        return {
          'success': false,
          'message': 'Exam not found',
          'attendance': [],
        };
      }
      final exam = Exam.fromFirestore(examDoc);

      // Get attendance records
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('examId', isEqualTo: examId)
          .orderBy('scannedAt', descending: true)
          .get();

      final attendanceRecords = attendanceSnapshot.docs
          .map((doc) => AttendanceRecord.fromFirestore(doc))
          .toList();

      // Get student details for each attendance record
      final List<Map<String, dynamic>> detailedAttendance = [];
      
      for (final record in attendanceRecords) {
        final studentDoc = await _firestore
            .collection('users')
            .where('studentId', isEqualTo: record.studentId)
            .limit(1)
            .get();
        
        String studentName = 'Unknown';
        if (studentDoc.docs.isNotEmpty) {
          studentName = studentDoc.docs.first.data()['fullName'] ?? 'Unknown';
        }

        detailedAttendance.add({
          'attendance': record,
          'studentName': studentName,
        });
      }

      // Get all allowed students and their status
      final allStudents = <Map<String, dynamic>>[];
      for (final studentId in exam.allowedClasses) {
        final studentDoc = await _firestore
            .collection('users')
            .where('studentId', isEqualTo: studentId)
            .limit(1)
            .get();
        
        String studentName = 'Unknown';
        String indexNo = '';
        if (studentDoc.docs.isNotEmpty) {
          final data = studentDoc.docs.first.data();
          studentName = data['fullName'] ?? 'Unknown';
          indexNo = data['indexNo'] ?? '';
        }

        final attendance = attendanceRecords.firstWhere(
          (a) => a.studentId == studentId,
          orElse: () => AttendanceRecord(
            attendanceId: '',
            examId: examId,
            studentId: studentId,
            indexNo: '',
            indexNoWords: '',
            seatNo: '',
            scannedAt: DateTime.now(),
            status: 'absent',
          ),
        );

        allStudents.add({
          'studentId': studentId,
          'studentName': studentName,
          'indexNo': indexNo,
          'status': attendance.status,
          'seatNo': attendance.seatNo,
          'scannedAt': attendance.status == 'present' ? attendance.scannedAt : null,
          'scannedLocation': attendance.scannedLocation,
          'scannedLatitude': attendance.scannedLatitude,
          'scannedLongitude': attendance.scannedLongitude,
        });
      }

      return {
        'success': true,
        'exam': exam,
        'attendance': detailedAttendance,
        'allStudents': allStudents,
        'totalStudents': exam.allowedClasses.length,
        'presentCount': attendanceRecords.where((a) => a.status == 'present').length,
        'absentCount': attendanceRecords.where((a) => a.status == 'absent').length,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get attendance: $e',
        'attendance': [],
      };
    }
  }

  // ==================== STUDENT MANAGEMENT (ADMIN) ====================

  /// Get all students (admin only)
  Future<Map<String, dynamic>> getAllStudents(String adminUid) async {
    try {
      // Verify admin role (lookup by stored auth uid)
      final adminQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: adminUid)
          .limit(1)
          .get();
      if (adminQuery.docs.isEmpty || adminQuery.docs.first.data()?['role'] != 'admin') {
        return {
          'success': false,
          'message': 'Unauthorized. Admin access required.',
          'students': [],
        };
      }

      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .orderBy('studentId')
          .get();

      final List<Map<String, dynamic>> students = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        students.add({
          'studentId': data['studentId'] ?? '',
          'fullName': data['fullName'] ?? '',
          'email': data['email'] ?? '',
          'indexNo': data['indexNo'] ?? '',
          'faculty': data['faculty'] ?? '',        
          'programme': data['programme'] ?? '',   
          'avatarStyle': data['avatarStyle'] ?? 'avataaars',
        });
      }

      return {
        'success': true,
        'students': students,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get students: $e',
        'students': [],
      };
    }
  }

  // ==================== HTR BY SUBJECT NAME METHOD ====================

  Future<Map<String, dynamic>> processHTRResultBySubject({
    required String studentId,
    required Map<String, dynamic> HTRData,
    double? scannedLatitude,
    double? scannedLongitude,
    String? scannedLocation,
  }) async {
    try {
      final scannedSubject = HTRData['Course']?.toString().trim() ?? '';
      
      if (scannedSubject.isEmpty) {
        return {
          'success': false,
          'error': 'Subject not detected',
          'message': 'Could not detect subject name from the scanned image',
          'details': {'scannedSubject': scannedSubject}
        };
      }

      final examsSnapshot = await _firestore
          .collection('exams')
          .where('isActive', isEqualTo: true)
          .get();

      if (examsSnapshot.docs.isEmpty) {
        return {
          'success': false,
          'error': 'Exam not found',
          'message': 'No active exams found',
          'details': {'scannedSubject': scannedSubject}
        };
      }

      final matchingExams = examsSnapshot.docs
          .map((doc) => Exam.fromFirestore(doc))
          .where((exam) => 
              exam.subjectName.trim().toUpperCase() == 
              scannedSubject.trim().toUpperCase())
          .toList();

      if (matchingExams.isEmpty) {
        return {
          'success': false,
          'error': 'Exam not found',
          'message': 'Could not find an exam matching the scanned subject name',
          'details': {'scannedSubject': scannedSubject}
        };
      }

      if (matchingExams.length > 1) {
        return {
          'success': false,
          'error': 'Multiple exams found',
          'message': 'Multiple active exams found with the same subject name',
          'details': {
            'scannedSubject': scannedSubject,
            'examCount': matchingExams.length,
          }
        };
      }

      final exam = matchingExams.first;

      if (!exam.isActive) {
        return {
          'success': false,
          'error': 'Exam inactive',
          'message': 'This exam is no longer active',
          'details': {
            'examId': exam.examId,
            'subjectName': exam.subjectName,
          }
        };
      }

      final scannedIndexWords = HTRData['IndexNo']?.toString().trim() ?? 
                              HTRData['Index']?.toString().trim() ?? '';

      final scannedIndexNo = HTRData['Index No (Words)']?.toString().trim() ?? 
                            HTRData['IndexNoWords']?.toString().trim() ?? 
                            HTRData['Index Words']?.toString().trim() ?? 
                            _wordsToCompact(scannedIndexWords);

      final scannedSeatNo = HTRData['SeatNo']?.toString().trim() ?? 
                          HTRData['Seat No']?.toString().trim() ?? 
                          HTRData['Seat']?.toString().trim() ?? 
                          HTRData['SeatNumber']?.toString().trim() ?? '';

      // Get student data from users collection
      final studentQuery = await _firestore
          .collection('users')
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();
      
      if (studentQuery.docs.isEmpty) {
        return {
          'success': false,
          'error': 'Student not found',
          'message': 'Student record not found',
        };
      }
      
      final studentData = studentQuery.docs.first.data();
      final studentIndexNo = studentData['indexNo'] ?? '';

      if (!exam.allowedClasses.contains(studentId)) {
        return {
          'success': false,
          'error': 'Not authorized',
          'message': 'You are not enrolled in this exam',
          'details': {
            'examId': exam.examId,
            'subjectName': exam.subjectName,
          }
        };
      }

      // Check ALL existing attendance records for this student-exam pair
      final existingAttendance = await _firestore
          .collection('attendance')
          .where('examId', isEqualTo: exam.examId)
          .where('studentId', isEqualTo: studentId)
          .get();

      // Handle multiple records case
      if (existingAttendance.docs.isNotEmpty) {
        // If multiple records exist, merge them (keep the first, delete others)
        if (existingAttendance.docs.length > 1) {
          final batch = _firestore.batch();
          final primaryDoc = existingAttendance.docs.first;
          
          // Delete all other records
          for (int i = 1; i < existingAttendance.docs.length; i++) {
            batch.delete(existingAttendance.docs[i].reference);
          }
          
          // Update the primary record to present with location
          final now = DateTime.now();
          final updateData = <String, dynamic>{
            'indexNo': scannedIndexNo,
            'indexNoWords': _convertToWords(scannedIndexNo),
            'seatNo': scannedSeatNo,
            'scannedAt': now.toIso8601String(),
            'status': 'present',
            'updatedAt': now.toIso8601String(),
          };
          
          // Add location data if available
          if (scannedLatitude != null) updateData['scannedLatitude'] = scannedLatitude;
          if (scannedLongitude != null) updateData['scannedLongitude'] = scannedLongitude;
          if (scannedLocation != null) updateData['scannedLocation'] = scannedLocation;
          
          batch.update(primaryDoc.reference, updateData);
          await batch.commit();
          
          final updatedDoc = await primaryDoc.reference.get();
          final updatedRecord = AttendanceRecord.fromFirestore(updatedDoc);
          
          // Update student index if empty
          if (studentIndexNo.isEmpty) {
            await _firestore.collection('users').doc(studentQuery.docs.first.id).update({
              'indexNo': scannedIndexNo,
              'updatedAt': now.toIso8601String(),
            });
          }
          
          return {
            'success': true,
            'alreadyAttended': false,
            'attendance': updatedRecord,
            'message': 'Attendance recorded successfully',
            'seatNo': scannedSeatNo,
            'examName': exam.subjectName,
          };
        } else {
          // Single record exists
          final record = AttendanceRecord.fromFirestore(existingAttendance.docs.first);
          final now = DateTime.now();
          
          if (record.status == 'present') {
            return {
              'success': true,
              'alreadyAttended': true,
              'attendance': record,
              'message': 'You have already marked attendance for this exam',
              'examName': exam.subjectName,
              'seatNo': record.seatNo,
            };
          }
          
          // Update absent to present with location
          final updateData = <String, dynamic>{
            'indexNo': scannedIndexNo,
            'indexNoWords': _convertToWords(scannedIndexNo),
            'seatNo': scannedSeatNo,
            'scannedAt': now.toIso8601String(),
            'status': 'present',
            'updatedAt': now.toIso8601String(),
          };
          
          // Add location data if available
          if (scannedLatitude != null) updateData['scannedLatitude'] = scannedLatitude;
          if (scannedLongitude != null) updateData['scannedLongitude'] = scannedLongitude;
          if (scannedLocation != null) updateData['scannedLocation'] = scannedLocation;
          
          await existingAttendance.docs.first.reference.update(updateData);
          
          final updatedDoc = await existingAttendance.docs.first.reference.get();
          final updatedRecord = AttendanceRecord.fromFirestore(updatedDoc);
          
          if (studentIndexNo.isEmpty) {
            await _firestore.collection('users').doc(studentQuery.docs.first.id).update({
              'indexNo': scannedIndexNo,
              'updatedAt': now.toIso8601String(),
            });
          }
          
          return {
            'success': true,
            'alreadyAttended': false,
            'attendance': updatedRecord,
            'message': 'Attendance recorded successfully',
            'seatNo': scannedSeatNo,
            'examName': exam.subjectName,
          };
        }
      } else {
        // No records exist - create new present record with location
        final docId = '${exam.examId}_$studentId';
        final attendanceRef = _firestore.collection('attendance').doc(docId);
        final now = DateTime.now();
        
        final attendanceMap = <String, dynamic>{
          'attendanceId': docId,
          'examId': exam.examId,
          'studentId': studentId,
          'indexNo': scannedIndexNo,
          'indexNoWords': _convertToWords(scannedIndexNo),
          'seatNo': scannedSeatNo,
          'scannedAt': now.toIso8601String(),
          'status': 'present',
          'autoCreated': false,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        };
        
        // Add location data if available
        if (scannedLatitude != null) attendanceMap['scannedLatitude'] = scannedLatitude;
        if (scannedLongitude != null) attendanceMap['scannedLongitude'] = scannedLongitude;
        if (scannedLocation != null) attendanceMap['scannedLocation'] = scannedLocation;
        
        await attendanceRef.set(attendanceMap);
        
        if (studentIndexNo.isEmpty) {
          await _firestore.collection('users').doc(studentQuery.docs.first.id).update({
            'indexNo': scannedIndexNo,
            'updatedAt': now.toIso8601String(),
          });
        }
        
        final attendanceRecord = AttendanceRecord(
          attendanceId: docId,
          examId: exam.examId,
          studentId: studentId,
          indexNo: scannedIndexNo,
          indexNoWords: _convertToWords(scannedIndexNo),
          seatNo: scannedSeatNo,
          scannedAt: now,
          status: 'present',
          scannedLocation: scannedLocation,
          scannedLatitude: scannedLatitude,
          scannedLongitude: scannedLongitude,
        );
        
        return {
          'success': true,
          'alreadyAttended': false,
          'attendance': attendanceRecord,
          'message': 'Attendance recorded successfully',
          'seatNo': scannedSeatNo,
          'examName': exam.subjectName,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'System error',
        'message': 'Failed to process attendance',
      };
    }
  }

  // ==================== ATTENDANCE RELATED METHODS (STUDENT) ====================

  Future<bool> hasAttendedExam(String examId, String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('attendance')
          .where('examId', isEqualTo: examId)
          .where('studentId', isEqualTo: studentId)
          .where('status', isEqualTo: 'present')
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<List<AttendanceRecord>> getAttendanceHistory(String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .orderBy('scannedAt', descending: true)
          .get();
      
      // Group by examId and keep only the latest record per exam
      final Map<String, DocumentSnapshot> latestRecords = {};
      
      for (var doc in snapshot.docs) {
        final examId = doc.data()['examId'] as String? ?? '';
        if (examId.isNotEmpty) {
          // If we haven't seen this exam before, or this record is newer
          if (!latestRecords.containsKey(examId)) {
            latestRecords[examId] = doc;
          } else {
            // Compare scannedAt timestamps to keep the latest
            final existing = latestRecords[examId]!.data() as Map<String, dynamic>;
            final current = doc.data() as Map<String, dynamic>;
            
            final existingTime = existing['scannedAt'] is Timestamp
                ? (existing['scannedAt'] as Timestamp).toDate()
                : DateTime.parse(existing['scannedAt'] ?? DateTime.now().toIso8601String());
            
            final currentTime = current['scannedAt'] is Timestamp
                ? (current['scannedAt'] as Timestamp).toDate()
                : DateTime.parse(current['scannedAt'] ?? DateTime.now().toIso8601String());
            
            if (currentTime.isAfter(existingTime)) {
              latestRecords[examId] = doc;
            }
          }
        }
      }
      
      // Convert the latest records to AttendanceRecord objects
      return latestRecords.values
          .map((doc) => AttendanceRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _createAbsentAttendanceIfNeeded(String examId, String studentId) async {
    try {
      // Use a deterministic document ID to avoid race-created duplicates.
      final docId = '${examId}_$studentId';
      final attendanceRef = _firestore.collection('attendance').doc(docId);

      // If a doc already exists with this deterministic ID, nothing to do.
      final snapshot = await attendanceRef.get();
      if (snapshot.exists) return;

      // As an extra safety, also check for any existing records via query.
      final existing = await _firestore
          .collection('attendance')
          .where('examId', isEqualTo: examId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return;

      final now = DateTime.now();
      await attendanceRef.set({
        'attendanceId': docId,
        'examId': examId,
        'studentId': studentId,
        'indexNo': '',
        'indexNoWords': '',
        'seatNo': '',
        'scannedAt': now.toIso8601String(),
        'status': 'absent',
        'autoCreated': true,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
    } catch (e) {
      // Silently handle error
    }
  }

  Future<Map<String, dynamic>> updateAttendanceSeatNo({
    required String examId,
    required String studentId,
    required String seatNo,
    required String adminUid,
  }) async {
    try {
      // Verify admin role (lookup by stored auth uid)
      final adminQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: adminUid)
          .limit(1)
          .get();
      if (adminQuery.docs.isEmpty || adminQuery.docs.first.data()?['role'] != 'admin') {
        return {
          'success': false,
          'message': 'Unauthorized. Admin access required.',
        };
      }

      // Find the attendance record
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('examId', isEqualTo: examId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (attendanceQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'Attendance record not found',
        };
      }

      // Update the seat number
      await attendanceQuery.docs.first.reference.update({
        'seatNo': seatNo,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'message': 'Seat number updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update seat number: $e',
      };
    }
  }
  
    // ==================== EXPORT ATTENDANCE REPORT ====================
  
  Future<Map<String, dynamic>> exportAttendanceReport({
    required String examId,
    required String adminUid,
  }) async {
    try {
      // Verify admin role (lookup by stored auth uid)
      final adminQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: adminUid)
          .limit(1)
          .get();
      if (adminQuery.docs.isEmpty || adminQuery.docs.first.data()?['role'] != 'admin') {
        return {
          'success': false,
          'message': 'Unauthorized. Admin access required.',
        };
      }

      // Get exam details
      final examDoc = await _firestore.collection('exams').doc(examId).get();
      if (!examDoc.exists) {
        return {
          'success': false,
          'message': 'Exam not found',
        };
      }
      final exam = Exam.fromFirestore(examDoc);

      // Get all attendance records
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('examId', isEqualTo: examId)
          .get();

      final attendanceRecords = attendanceSnapshot.docs
          .map((doc) => AttendanceRecord.fromFirestore(doc))
          .toList();

      // Get all students data
      final studentsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      final studentsMap = <String, Map<String, dynamic>>{};
      for (var doc in studentsSnapshot.docs) {
        final data = doc.data();
        final studentId = data['studentId'] ?? '';
        if (studentId.isNotEmpty) {
          studentsMap[studentId] = {
            'fullName': data['fullName'] ?? 'Unknown',
            'faculty': data['faculty'] ?? 'Not specified',
            'programme': data['programme'] ?? 'Not specified',
            'indexNo': data['indexNo'] ?? '',
          };
        }
      }

      // Create CSV data
      final List<Map<String, String>> csvData = [];

      // Header
      csvData.add({
        'Exam Name': exam.subjectName,
        'Date': exam.formattedDate,
        'Time': exam.formattedTime,
        'Location': exam.location,
      });

      csvData.add({}); // Empty row

      // Column headers
      csvData.add({
        'Student ID': 'Student ID',
        'Full Name': 'Full Name',
        'Faculty': 'Faculty',
        'Programme': 'Programme',
        'Index No': 'Index No',
        'Status': 'Status',
        'Seat No': 'Seat No',
        'Scanned At': 'Scanned At',
      });

      // Student rows
      for (final studentId in exam.allowedClasses) {
        final student = studentsMap[studentId] ?? {};
        final attendance = attendanceRecords.firstWhere(
          (a) => a.studentId == studentId,
          orElse: () => AttendanceRecord(
            attendanceId: '',
            examId: examId,
            studentId: studentId,
            indexNo: '',
            indexNoWords: '',
            seatNo: '',
            scannedAt: DateTime.now(),
            status: 'absent',
          ),
        );

        csvData.add({
          'Student ID': studentId,
          'Full Name': student['fullName'] ?? 'Unknown',
          'Faculty': student['faculty'] ?? 'Not specified',
          'Programme': student['programme'] ?? 'Not specified',
          'Index No': student['indexNo'] ?? '',
          'Status': attendance.status.toUpperCase(),
          'Seat No': attendance.seatNo.isNotEmpty ? attendance.seatNo : '-',
          'Scanned At': attendance.status == 'present' 
              ? DateFormat('dd/MM/yyyy HH:mm:ss').format(attendance.scannedAt)
              : '-',
        });
      }

      // Summary
      final presentCount = attendanceRecords.where((a) => a.status == 'present').length;
      final absentCount = exam.allowedClasses.length - presentCount;
      final attendanceRate = exam.allowedClasses.isNotEmpty 
          ? (presentCount / exam.allowedClasses.length * 100).toStringAsFixed(1)
          : '0.0';

      csvData.add({}); // Empty row
      csvData.add({
        'Summary': 'Summary',
        '': '',
        'Total Students': exam.allowedClasses.length.toString(),
        'Present': presentCount.toString(),
        'Absent': absentCount.toString(),
        'Attendance Rate': '$attendanceRate%',
      });

      return {
        'success': true,
        'data': csvData,
        'filename': '${exam.subjectName}_${exam.formattedDate}_Attendance.csv',
        'exam': exam,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to export attendance: $e',
      };
    }
  }

  // ==================== STUDENT PROFILE MANAGEMENT ====================

  Future<void> updateStudentProfile({
    required String studentId,
    String? fullName,
    String? indexNo,
    String? avatarStyle,
    String? faculty,      
    String? programme,    
  }) async {
    try {
      final userQuery = await _firestore
          .collection('users')
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();
      
      if (userQuery.docs.isEmpty) return;
      
      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      if (fullName != null && fullName.isNotEmpty) {
        updates['fullName'] = fullName;
      }
      
      if (indexNo != null) {
        updates['indexNo'] = indexNo;
      }
      
      if (avatarStyle != null) {
        updates['avatarStyle'] = avatarStyle;
      }

      if (faculty != null) {
        updates['faculty'] = faculty;
      }
    
      if (programme != null) {
        updates['programme'] = programme;
      }
      
      await _firestore.collection('users').doc(userQuery.docs.first.id).update(updates);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> getStudentById(String studentId) async {
    try {
      final userQuery = await _firestore
          .collection('users')
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();
      
      if (userQuery.docs.isEmpty) return null;
      
      final doc = userQuery.docs.first;
      final data = doc.data();

      return UserModel(
        uid: doc.id,
        email: data['email'] ?? '',
        fullName: data['fullName'] ?? '',
        role: data['role'] ?? 'student',
        studentId: data['studentId'],
        indexNo: data['indexNo'] ?? '',
        faculty: data['faculty'] ?? '',
        programme: data['programme'] ?? '',
        avatarStyle: data['avatarStyle'] ?? 'avataaars',
        createdAt: UserModel._parseDateTime(data['createdAt']),
        updatedAt: UserModel._parseDateTime(data['updatedAt']),
        lastLogin: UserModel._parseDateTime(data['lastLogin']),
      );
    } catch (e) {
      return null;
    }
  }

  // ==================== HELPER METHODS ====================

  String _convertToWords(String indexNo) {
    final mapping = {
      '0': 'Zero', '1': 'One', '2': 'Two', '3': 'Three',
      '4': 'Four', '5': 'Five', '6': 'Six', '7': 'Seven',
      '8': 'Eight', '9': 'Nine',
      'A': 'A', 'B': 'B', 'C': 'C', 'D': 'D', 'E': 'E',
      'F': 'F', 'G': 'G', 'H': 'H', 'I': 'I', 'J': 'J',
      'K': 'K', 'L': 'L', 'M': 'M', 'N': 'N', 'O': 'O',
      'P': 'P', 'Q': 'Q', 'R': 'R', 'S': 'S', 'T': 'T',
      'U': 'U', 'V': 'V', 'W': 'W', 'X': 'X', 'Y': 'Y', 'Z': 'Z'
    };
    
    return indexNo.split('').map((char) => mapping[char.toUpperCase()] ?? char).join(' ');
  }


  String _wordsToCompact(String words) {
    final parts = words.trim().split(' ');
    
    final Map<String, String> wordToDigit = {
      'ZERO': '0', 'ONE': '1', 'TWO': '2', 'THREE': '3',
      'FOUR': '4', 'FIVE': '5', 'SIX': '6', 'SEVEN': '7',
      'EIGHT': '8', 'NINE': '9',
    };
    
    StringBuffer result = StringBuffer();
    
    for (final part in parts) {
      if (wordToDigit.containsKey(part)) {
        result.write(wordToDigit[part]);
      } else {
        result.write(part);
      }
    }
    
    return result.toString();
  }

  // Create a simple slug from subject names to use as deterministic document IDs.
  // Keeps lowercase letters, numbers and hyphens; replaces spaces and other chars with hyphens.
  String _slugify(String input) {
    final slug = input
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s-]"), '') // remove invalid chars
        .trim()
        .replaceAll(RegExp(r"\s+"), '-') // spaces to hyphens
        .replaceAll(RegExp(r"-+"), '-'); // collapse multiple hyphens
    return slug.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : slug;
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email is already registered';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-credential':  
        return 'Incorrect password';
      default:
        return 'An error occurred. Please try again';
    }
  }

  /// Delete an exam (admin only)
  Future<void> deleteExam(String examId, String adminUid) async {
    try {
      // Verify admin role (lookup by stored auth uid)
      final adminQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: adminUid)
          .limit(1)
          .get();
      if (adminQuery.docs.isEmpty || adminQuery.docs.first.data()?['role'] != 'admin') {
        throw Exception('Unauthorized. Admin access required.');
      }

      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('examId', isEqualTo: examId)
          .get();

      final batch = _firestore.batch();
      for (var doc in attendanceSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      batch.delete(_firestore.collection('exams').doc(examId));
      
      await batch.commit();
      
    } catch (e) {
      rethrow;
    }
  }
}