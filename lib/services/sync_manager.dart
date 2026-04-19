// lib/services/sync_manager.dart
import 'package:flutter/material.dart';
import 'package:attend_scan/services/firebase_service.dart';
import 'package:attend_scan/services/local_storage_service.dart';
import 'package:attend_scan/services/connectivity_service.dart';

class SyncManager extends ChangeNotifier {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final LocalStorageService _storage = LocalStorageService();
  
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  // Initialize storage and trigger background sync if possible
  Future<void> init() async {
    await _storage.init();
    
    // If online and logged in, run background sync
    if (await ConnectivityService.checkInternet() && _storage.isLoggedIn) {
      syncInBackground();
    }
  }

  // Run background synchronization without blocking UI
  Future<void> syncInBackground() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    notifyListeners();

    try {
      final user = await _firebaseService.getCurrentUser();
      if (user == null) return;

      // Sync different data depending on role
      if (user.isAdmin) {
        await _syncAdminData(user.uid);
      } else {
        await _syncStudentData(user.studentId ?? '');
      }

    } catch (e) {
      print('Background sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Sync admin-specific data (exams, students)
  Future<void> _syncAdminData(String adminUid) async {
    try {
      final examsResult = await _firebaseService.getAllExams(adminUid: adminUid);
      if (examsResult['success'] == true) {
        await _storage.cacheExams(examsResult['exams']);
      }

      final studentsResult = await _firebaseService.getAllStudents(adminUid);
      if (studentsResult['success'] == true) {
        await _storage.cacheStudents(studentsResult['students']);
      }
    } catch (e) {
      print('Failed to sync admin data: $e');
    }
  }

  // Sync student-specific data (exams for student)
  Future<void> _syncStudentData(String studentId) async {
    try {
      final exams = await _firebaseService.getExamsForStudent(studentId);
      await _storage.cacheExams(exams);
    } catch (e) {
      print('Failed to sync student data: $e');
    }
  }

  // Perform a manual forced sync, returns success status
  Future<bool> forceSync() async {
    if (!await ConnectivityService.checkInternet()) {
      return false;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final user = await _firebaseService.getCurrentUser();
      if (user == null) return false;

      if (user.isAdmin) {
        await _syncAdminData(user.uid);
      } else {
        await _syncStudentData(user.studentId ?? '');
      }
      
      return true;
    } catch (e) {
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}