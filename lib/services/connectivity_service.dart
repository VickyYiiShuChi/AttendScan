// lib/services/connectivity_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:attend_scan/services/local_storage_service.dart';

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  bool _hasInternet = true;
  late final LocalStorageService _storage;
  
  bool get hasInternet => _hasInternet;

  // Initialize connectivity monitoring and trigger sync on restore
  Future<void> init() async {

    // Initialize LocalStorageService
    _storage = LocalStorageService();
    await _storage.init();
    
    // Get initial network status
    final result = await _connectivity.checkConnectivity();
    _hasInternet = result != ConnectivityResult.none;
    notifyListeners();

    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {

      // Handle here to ensure execution
      final hasInternet = result != ConnectivityResult.none;
      
      if (_hasInternet != hasInternet) {
        _hasInternet = hasInternet;
        
        // Auto-sync when network is restored
        if (_hasInternet) {
          _syncPendingOperations();
        } 
        
        notifyListeners();
      }
    });
  }

  // Quick check whether device currently has internet
  static Future<bool> checkInternet() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }
  
  // Sync any pending offline operations when network is available
  Future<void> _syncPendingOperations() async {

      // Wait briefly to ensure network stability
      await Future.delayed(const Duration(seconds: 1));

      final queue = _storage.getSyncQueue();

      if (queue.isNotEmpty) {
        await _storage.syncPendingOperations();

    }
  }
}