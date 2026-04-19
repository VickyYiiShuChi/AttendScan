// lib/repositories/student_repository.dart
import 'package:attend_scan/services/firebase_service.dart';
import 'package:attend_scan/services/local_storage_service.dart';
import 'package:attend_scan/services/connectivity_service.dart';

class StudentRepository {
  final FirebaseService _firebaseService = FirebaseService();
  final LocalStorageService _storage = LocalStorageService();
  
  // ========== Profile ==========
  // Fetch user profile, using cache unless forceRefresh or online
  Future<UserModel?> getProfile({bool forceRefresh = false}) async {
    final hasInternet = await ConnectivityService.checkInternet();
    
    // If online and (forceRefresh or no cache), fetch from Firebase
    if (hasInternet && (forceRefresh || !_storage.hasProfile())) {
      try {
        final user = await _firebaseService.getCurrentUser();
        if (user != null) {
          // Save to cache
          await _storage.saveProfile({
            'uid': user.uid,
            'email': user.email,
            'fullName': user.fullName,
            'studentId': user.studentId,
            'indexNo': user.indexNo,
            'faculty': user.faculty,
            'programme': user.programme,
            'avatarStyle': user.avatarStyle,
            'createdAt': user.createdAt.toIso8601String(),
          });
          return user;
        }
      } catch (e) {
        print('Failed to fetch profile from Firebase: $e');
      }
    }
    
    // Get from cache
    final cached = _storage.getProfile();
    if (cached != null) {
      return UserModel(
        uid: cached['uid'] ?? '',
        email: cached['email'] ?? '',
        fullName: cached['fullName'] ?? '',
        role: 'student',
        studentId: cached['studentId'],
        indexNo: cached['indexNo'],
        faculty: cached['faculty'],
        programme: cached['programme'],
        avatarStyle: cached['avatarStyle'] ?? 'avataaars',
        createdAt: DateTime.parse(cached['createdAt'] ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );
    }
    
    return null;
  }
  
  // ========== Update Profile ==========
  // Update profile locally and attempt to sync (or queue if offline)
  Future<bool> updateProfile({
    required String studentId,
    String? fullName,
    String? indexNo,
    String? faculty,
    String? programme,
    String? avatarStyle,
  }) async {
    try {
      final hasInternet = await ConnectivityService.checkInternet();
      
      if (!hasInternet) {
        // Add to sync queue
        final storage = LocalStorageService();
        await storage.addToSyncQueue({
          'type': 'profile',
          'studentId': studentId,
          'data': {
            if (fullName != null) 'fullName': fullName,
            if (indexNo != null) 'indexNo': indexNo,
            if (faculty != null) 'faculty': faculty,
            if (programme != null) 'programme': programme,
            if (avatarStyle != null) 'avatarStyle': avatarStyle,
          },
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        // Update local cache
        final currentProfile = storage.getProfile() ?? {};
        currentProfile.addAll({
          if (fullName != null) 'fullName': fullName,
          if (indexNo != null) 'indexNo': indexNo,
          if (faculty != null) 'faculty': faculty,
          if (programme != null) 'programme': programme,
          if (avatarStyle != null) 'avatarStyle': avatarStyle,
        });
        await storage.saveProfile(currentProfile);
        
        return true;
      }
      
      // Online: Update directly to Firebase
      await _firebaseService.updateStudentProfile(
        studentId: studentId,
        fullName: fullName,
        indexNo: indexNo,
        faculty: faculty,
        programme: programme,
        avatarStyle: avatarStyle,
      );
      
      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }
  
  // ========== Exam Records ==========
  // Retrieve student's exam records, refresh from Firebase when needed
  Future<Map<String, dynamic>> getExamRecords({bool forceRefresh = false}) async {
    final hasInternet = await ConnectivityService.checkInternet();
    
    // If online and (forceRefresh or no cache), fetch from Firebase
    if (hasInternet && (forceRefresh || !_storage.hasExamRecords())) {
      try {
        final user = await _firebaseService.getCurrentUser();
        if (user != null && user.studentId != null) {
          final examsData = await _firebaseService.getStudentExamsWithStatus(user.studentId!);
          final attendanceHistory = await _firebaseService.getAttendanceHistory(user.studentId!);
          
          // Build attendance map
          final attendanceMap = <String, Map<String, dynamic>>{};
          for (final record in attendanceHistory) {
            attendanceMap[record.examId] = {
              'seatNo': record.seatNo,
              'scannedAt': record.scannedAt.toIso8601String(),
              'indexNo': record.indexNo,
              'indexNoWords': record.indexNoWords,
              'attendanceId': record.attendanceId,
              'examId': record.examId,
              'studentId': record.studentId,
              'status': record.status,
              'scannedLocation': record.scannedLocation,
              'scannedLatitude': record.scannedLatitude,
              'scannedLongitude': record.scannedLongitude,
            };
          }
          
          final data = {
            'upcoming': (examsData['upcoming'] as List).map((e) => _examToJson(e)).toList(),
            'present': (examsData['present'] as List).map((e) => _examToJson(e)).toList(),
            'absent': (examsData['absent'] as List).map((e) => _examToJson(e)).toList(),
            'attendanceMap': attendanceMap,
          };
          
          // Save to cache
          await _storage.saveExamRecords(data);
          return data;
        }
      } catch (e) {
        print('Failed to fetch exam records from Firebase: $e');
      }
    }
    
    // Get from cache
    return _storage.getExamRecords() ?? {
      'upcoming': [],
      'present': [],
      'absent': [],
      'attendanceMap': {},
    };
  }
  
  // Convert Exam model to a JSON-serializable map
  Map<String, dynamic> _examToJson(Exam exam) {
    return {
      'examId': exam.examId,
      'subjectName': exam.subjectName,
      'location': exam.location,
      'startTime': exam.startTime.toIso8601String(),
      'endTime': exam.endTime.toIso8601String(),
      'isActive': exam.isActive,
    };
  }
}