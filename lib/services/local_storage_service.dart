// lib/services/local_storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:attend_scan/services/connectivity_service.dart'; 
import 'package:attend_scan/services/firebase_service.dart'; 

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static const String _userDataKey = 'user_data';
  static const String _lastSyncTimeKey = 'last_sync_time';
  static const String _cachedExamsKey = 'cached_exams';
  static const String _cachedStudentsKey = 'cached_students';
  static const String _cachedAttendanceKey = 'cached_attendance';
  static const String _profileKey = 'user_profile';
  static const String _examRecordsKey = 'exam_records';
  static const String _syncQueueKey = 'sync_queue';

  late SharedPreferences _prefs;
  // Initialize SharedPreferences instance
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ========== Login State ==========
  // Persist login user data and mark logged-in flag
  Future<void> saveLoginStatus(Map<String, dynamic> userData) async {
    await _prefs.setString(_userDataKey, jsonEncode(userData));
    await _prefs.setBool('is_logged_in', true);
  }

  bool get isLoggedIn => _prefs.getBool('is_logged_in') ?? false;
  
  Map<String, dynamic>? get userData {
    final String? data = _prefs.getString(_userDataKey);
    return data != null ? jsonDecode(data) : null;
  }

  // Clear stored login data and logged-in flag
  Future<void> clearLoginStatus() async {
    await _prefs.remove(_userDataKey);
    await _prefs.setBool('is_logged_in', false);
  }

  // ========== Data Cache ==========
  // Cache exams list locally and update last sync time
  Future<void> cacheExams(List<dynamic> exams) async {
    await _prefs.setString(_cachedExamsKey, jsonEncode(exams));
    await _prefs.setString(_lastSyncTimeKey, DateTime.now().toIso8601String());
  }

  // Retrieve cached exams from local storage
  List<dynamic>? getCachedExams() {
    final String? data = _prefs.getString(_cachedExamsKey);
    return data != null ? jsonDecode(data) : null;
  }

  // Cache students list locally
  Future<void> cacheStudents(List<dynamic> students) async {
    await _prefs.setString(_cachedStudentsKey, jsonEncode(students));
  }

  // Retrieve cached students from local storage
  List<dynamic>? getCachedStudents() {
    final String? data = _prefs.getString(_cachedStudentsKey);
    return data != null ? jsonDecode(data) : null;
  }

  // Get timestamp of last successful sync
  DateTime? getLastSyncTime() {
    final String? time = _prefs.getString(_lastSyncTimeKey);
    return time != null ? DateTime.parse(time) : null;
  }

  // Check whether cached data is still valid based on age
  bool isCacheValid({Duration maxAge = const Duration(hours: 1)}) {
    final lastSync = getLastSyncTime();
    if (lastSync == null) return false;
    return DateTime.now().difference(lastSync) < maxAge;
  }

  // Remove cached data keys
  Future<void> clearCache() async {
    await _prefs.remove(_cachedExamsKey);
    await _prefs.remove(_cachedStudentsKey);
    await _prefs.remove(_cachedAttendanceKey);
    await _prefs.remove(_lastSyncTimeKey);
  }

  // ========== Profile Cache ==========
  // Save user profile to local cache
  Future<void> saveProfile(Map<String, dynamic> profile) async {
    await _prefs.setString(_profileKey, jsonEncode(profile));
  }
  
  // Retrieve cached user profile
  Map<String, dynamic>? getProfile() {
    final String? data = _prefs.getString(_profileKey);
    return data != null ? jsonDecode(data) : null;
  }
  
  // Check if a profile exists in cache
  bool hasProfile() {
    return _prefs.containsKey(_profileKey);
  }
  
  // ========== Exam Records Cache ==========
  // Save exam records to cache
  Future<void> saveExamRecords(Map<String, dynamic> records) async {
    await _prefs.setString(_examRecordsKey, jsonEncode(records));
  }
  
  // Retrieve cached exam records
  Map<String, dynamic>? getExamRecords() {
    final String? data = _prefs.getString(_examRecordsKey);
    return data != null ? jsonDecode(data) : null;
  }
  
  // Check if exam records exist in cache
  bool hasExamRecords() {
    return _prefs.containsKey(_examRecordsKey);
  }
  
  // ========== Sync Queue ==========
  // Add an operation to the offline sync queue
  Future<void> addToSyncQueue(Map<String, dynamic> item) async {
    final List<String> queue = _prefs.getStringList(_syncQueueKey) ?? [];
    queue.add(jsonEncode(item));
    await _prefs.setStringList(_syncQueueKey, queue);
  }
  
  // Get list of pending sync operations
  List<Map<String, dynamic>> getSyncQueue() {
    final List<String> queue = _prefs.getStringList(_syncQueueKey) ?? [];
    return queue.map((item) {
      try {
        return jsonDecode(item) as Map<String, dynamic>;
      } catch (e) {
        return <String, dynamic>{};
      }
    }).toList();
  }
  
  // Clear the offline sync queue
  Future<void> clearSyncQueue() async {
    await _prefs.remove(_syncQueueKey);
  }
  
  // ========== Background Sync ==========
  // Process and sync pending offline operations
  Future<void> syncPendingOperations() async {
    final queue = getSyncQueue();
    if (queue.isEmpty) {
      return;
    }
    
    final hasInternet = await ConnectivityService.checkInternet();
    if (!hasInternet) {
      return;
    }
    
    final firebase = FirebaseService();
    final success = <String>[];
    
    for (final item in queue) {
      try {
        
        if (item['type'] == 'profile') {
          
          await firebase.updateStudentProfile(
            studentId: item['studentId'] ?? '',
            fullName: item['data']?['fullName'],
            indexNo: item['data']?['indexNo'],
            faculty: item['data']?['faculty'],
            programme: item['data']?['programme'],
            avatarStyle: item['data']?['avatarStyle'],
          );
          
          success.add(jsonEncode(item));
        }
        // Add other sync types here
      } catch (e) {
        print('Sync failed: $e');
        // Keep failed operations for retry
      }
    }
    
    // Remove successfully synced operations
    if (success.isNotEmpty) {
      final remainingQueue = queue.where((item) => !success.contains(jsonEncode(item))).toList();
      await _prefs.setStringList(_syncQueueKey, remainingQueue.map((item) => jsonEncode(item)).toList());
    }
  }
}