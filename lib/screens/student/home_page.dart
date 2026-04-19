// lib/screens/student/home_page.dart
import 'package:flutter/material.dart';
import 'package:attend_scan/constants/app_colors.dart';
import 'package:attend_scan/constants/app_styles.dart';
import 'package:attend_scan/constants/app_dimensions.dart';
import '../auth_screen.dart';
import 'profile_page.dart';
import 'records_page.dart';
import '../../services/firebase_service.dart';
import '../../services/connectivity_service.dart';
import '../../repositories/student_repository.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/avatar_generator.dart';
import 'package:shimmer/shimmer.dart';
import 'package:attend_scan/services/local_storage_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState(); 
}

// lib/screens/student/home_page.dart
class HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final StudentRepository _repository = StudentRepository();
  final ConnectivityService _connectivity = ConnectivityService();
  
  UserModel? _currentStudent;
  List<Exam> _upcomingExams = [];
  int _presentCount = 0;
  int _absentCount = 0;
  bool _isLoading = true;
  bool _isOffline = false;
  bool _isSyncing = false;  // Add sync indicator
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _isLoading = true;
    
    Future.microtask(() {
      if (mounted) {
        _loadData(forceRefresh: true);
      }
    });
    
    _connectivity.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  // Handle app lifecycle changes (when app returns from background)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App resumed from background - check and sync
      _handleAppResume();
    }
  }

  // Handle app resume from background - critical for real devices
  Future<void> _handleAppResume() async {
    if (!mounted) return;
    
    // Check current internet status
    final hasInternet = await ConnectivityService.checkInternet();
    
    setState(() {
      _isOffline = !hasInternet;
    });
    
    if (hasInternet) {
      // Show syncing indicator
      setState(() {
        _isSyncing = true;
      });
      
      try {
        // Sync pending offline operations first
        await _syncPendingOperations();
        
        // Then force refresh data
        await _loadData(forceRefresh: true);
        
        // Show success message if there were pending changes
        final storage = LocalStorageService();
        final queue = storage.getSyncQueue();
        
        if (mounted && queue.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Offline changes synced successfully!'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Error syncing on resume: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isSyncing = false;
          });
        }
      }
    }
  }

  // Update offline flag and trigger background sync when regained
  void _onConnectivityChanged() {
    setState(() {
      _isOffline = !_connectivity.hasInternet;
    });
    
    if (_connectivity.hasInternet && mounted) {
      _syncInBackground();
    }
  }

  // Sync pending operations from local storage
  Future<void> _syncPendingOperations() async {
    try {
      final storage = LocalStorageService();
      final queue = storage.getSyncQueue();
      
      if (queue.isNotEmpty) {
        await storage.syncPendingOperations();
      }
    } catch (e) {
      print('Error syncing pending operations: $e');
    }
  }

  // Convert JSON map to Exam model
  Exam _examFromJson(Map<String, dynamic> json) {
    return Exam(
      examId: json['examId'],
      subjectName: json['subjectName'],
      location: json['location'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      isActive: json['isActive'],
      allowedClasses: [],
      createdAt: DateTime.now(),
      createdBy: '',
    );
  }

  // Build a summary of upcoming exams for UI components
  Future<Map<String, dynamic>> _getUpcomingExamsData() async {
    final upcoming = _upcomingExams;
    
    if (upcoming.isEmpty) {
      return {
        'upcomingExams': [],
        'firstExamTime': '',
        'firstExamLocation': '',
      };
    }
    
    final nextExam = upcoming.first;
    
    return {
      'upcomingExams': upcoming,
      'firstExamTime': nextExam.formattedTime,
      'firstExamLocation': nextExam.location,
    };
  }

  // Compute attendance stats for the current student
  Future<Map<String, dynamic>> _getAttendanceStats() async {
    return {
      'upcomingCount': _upcomingExams.length,
      'presentCount': _presentCount,
      'absentCount': _absentCount,
    };
  }

  // Load student profile and exam records (optionally forcing refresh)
  Future<void> _loadData({bool forceRefresh = false}) async {
    // Check internet status before loading
    final hasInternet = await ConnectivityService.checkInternet();
    
    setState(() {
      _isLoading = true;
      _isOffline = !hasInternet;
    });
    
    try {
      final student = await _repository.getProfile(forceRefresh: forceRefresh);
      if (student != null) {
        setState(() => _currentStudent = student);
      }
      
      final records = await _repository.getExamRecords(forceRefresh: forceRefresh);
      
      final upcoming = (records['upcoming'] as List).map((json) => _examFromJson(json)).toList();
      final present = (records['present'] as List).map((json) => _examFromJson(json)).toList();
      final absent = (records['absent'] as List).map((json) => _examFromJson(json)).toList();
      
      setState(() {
        _upcomingExams = upcoming;
        _presentCount = present.length;
        _absentCount = absent.length;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Synchronize data in background and refresh UI
  Future<void> _syncInBackground() async {
    try {
      setState(() {
        _isSyncing = true;
      });
      
      // First sync pending operations
      await _syncPendingOperations();
      
      // Then refresh data
      await _repository.getProfile(forceRefresh: true);
      await _repository.getExamRecords(forceRefresh: true);
      
      if (mounted) {
        await _loadData(forceRefresh: true);
      }
    } catch (e) {
      print('Background sync error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  // Public helper to refresh data when page becomes visible
  void refreshWhenVisible() {
    _loadData(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: SafeArea(
        child: RefreshIndicator(
          // Enhanced refresh to handle sync properly
          onRefresh: () async {
            // Check internet status
            final hasInternet = await ConnectivityService.checkInternet();
            
            if (hasInternet) {
              setState(() {
                _isOffline = false;
              });
              
              // Sync pending operations first
              await _syncPendingOperations();
              
              // Then refresh data
              await _loadData(forceRefresh: true);
              
              // Show sync success message if there were pending changes
              final storage = LocalStorageService();
              final queue = storage.getSyncQueue();
              
              if (mounted && queue.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Offline changes synced!'),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } else {
              // No internet - just refresh cached data
              await _loadData(forceRefresh: false);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('No internet connection. Showing cached data.'),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
              throw Exception('No internet connection');
            }
          },
          color: AppColors.getPrimaryColor(context),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildTopCard(context),
                // Add syncing indicator if needed
                if (_isSyncing)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.getPrimaryColor(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Syncing...',
                          style: AppStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
                  child: Column(
                    children: [
                      const SizedBox(height: AppDimensions.paddingSmall),
                      _buildWelcomeCard(context),
                      const SizedBox(height: AppDimensions.paddingXLarge),
                      _buildStatsCard(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Update the top card to show offline indicator and syncing status
  Widget _buildTopCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 32,
      ),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.getShadowColor(context).withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top title bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Menu button
              Container(
                decoration: BoxDecoration(
                  color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.menu_rounded,
                    color: AppColors.getPrimaryColor(context),
                    size: 24,
                  ),
                  onPressed: () => _showMenuDialog(context),
                ),
              ),
              
              // welcome back and avatar
              Flexible(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfilePage()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.getBackgroundColor(context).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.getPrimaryColor(context).withOpacity(0.15),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Offline status + welcome back
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isOffline)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.wifi_off_rounded, size: 10, color: Colors.orange),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Offline',
                                            style: TextStyle(fontSize: 8, color: Colors.orange),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_isOffline) const SizedBox(width: 4),
                                  if (_isSyncing)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 8,
                                            height: 8,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                AppColors.getPrimaryColor(context),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Syncing',
                                            style: TextStyle(fontSize: 8, color: AppColors.getPrimaryColor(context)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_isSyncing) const SizedBox(width: 4),
                                  Text(
                                    'Welcome back,',
                                    style: AppStyles.bodySmall.copyWith(
                                      color: AppColors.getTextSecondary(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              // Full name
                              Text(
                                _currentStudent?.fullName ?? 'Loading...',
                                style: AppStyles.titleSmall.copyWith(
                                  color: AppColors.getTextPrimary(context),
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Avatar with border and shadow
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.getPrimaryColor(context),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.getPrimaryColor(context).withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: _currentStudent != null
                                  ? DiceBearAvatar.getUserAvatar(
                                      userId: _currentStudent!.studentId ?? '',
                                      email: _currentStudent!.email,
                                      name: _currentStudent!.fullName,
                                      style: _currentStudent!.avatarStyle,
                                    )
                                  : 'https://api.dicebear.com/7.x/avataaars/svg?seed=default&size=40',
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.getPrimaryColor(context),
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.getPrimaryColor(context),
                                child: Center(
                                  child: Text(
                                    _getInitials(_currentStudent?.fullName ?? 'User'),
                                    style: TextStyle(
                                      color: AppColors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // School logo section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.getPrimaryColor(context).withOpacity(0.9),
                  AppColors.getSecondaryColor(context).withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.getPrimaryColor(context).withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo image
                      Container(
                        width: MediaQuery.of(context).size.width * 0.5,
                        height: MediaQuery.of(context).size.width * 0.4,
                        constraints: const BoxConstraints(
                          maxWidth: 180,
                          maxHeight: 90,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/utar-logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.school_rounded,
                                size: MediaQuery.of(context).size.width * 0.1,
                                color: AppColors.getPrimaryColor(context),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Title
                      Text(
                        'AttendScan',
                        style: AppStyles.titleLarge.copyWith(
                          color: Colors.white,
                          fontSize: MediaQuery.of(context).size.width * 0.04,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Container(
                        height: 1,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Description
                      Text(
                        'Secure & Automated Attendance Tracking',
                        style: AppStyles.bodyMedium.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: MediaQuery.of(context).size.width * 0.03,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUpcomingExamsData(),
      builder: (context, snapshot) {
        bool isLoading = _isLoading;
        bool hasError = snapshot.hasError;
        
        final data = snapshot.data ?? {};
        final upcomingExams = data['upcomingExams'] as List? ?? [];
        final firstExamTime = data['firstExamTime'] ?? '';
        final firstExamLocation = data['firstExamLocation'] ?? '';
        
        return GestureDetector(
          onTap: () {
            if (upcomingExams.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecordsPage(),
                ),
              );
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.getPrimaryColor(context).withOpacity(0.9),
                  AppColors.getSecondaryColor(context).withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.getPrimaryColor(context).withOpacity(0.3),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isLoading ? Icons.refresh_rounded :
                        hasError ? Icons.error_outline_rounded :
                        upcomingExams.isEmpty ? Icons.event_available_rounded :
                        Icons.calendar_today_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upcoming Session',
                            style: AppStyles.bodyMedium.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          if (isLoading)
                            Container(
                              height: 20,
                              margin: const EdgeInsets.only(top: 4),
                              child: Shimmer.fromColors(
                                baseColor: Colors.white.withOpacity(0.3),
                                highlightColor: Colors.white.withOpacity(0.6),
                                child: Container(
                                  width: 120,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            )
                          else if (hasError || upcomingExams.isEmpty)
                            Text(
                              'No upcoming exams',
                              style: AppStyles.headlineSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          else
                            Text(
                              upcomingExams.first.subjectName,
                              style: AppStyles.headlineSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (upcomingExams.isNotEmpty)
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white.withOpacity(0.8),
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (!isLoading && !hasError && upcomingExams.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: _buildInfoChip(
                          icon: Icons.access_time_rounded,
                          text: firstExamTime,
                          context: context,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: _buildInfoChip(
                          icon: Icons.location_on_rounded,
                          text: firstExamLocation,
                          context: context,
                        ),
                      ),
                    ],
                  )
                else if (isLoading)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildShimmerChip(),
                      const SizedBox(width: 8),
                      _buildShimmerChip(),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerChip() {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Shimmer.fromColors(
              baseColor: Colors.white.withOpacity(0.3),
              highlightColor: Colors.white.withOpacity(0.6),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Shimmer.fromColors(
                baseColor: Colors.white.withOpacity(0.3),
                highlightColor: Colors.white.withOpacity(0.6),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: AppStyles.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getAttendanceStats(),
      builder: (context, snapshot) {
        bool isLoading = _isLoading;
        bool hasError = snapshot.hasError;
        
        final stats = snapshot.data ?? {};
        final upcomingCount = stats['upcomingCount'] ?? 0;
        final presentCount = stats['presentCount'] ?? 0;
        final absentCount = stats['absentCount'] ?? 0;
        
        // Attendance rate based on PAST EXAMS ONLY
        final totalPastExams = presentCount + absentCount;
        final attendanceRate = totalPastExams > 0 ? presentCount / totalPastExams : 0;
        
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RecordsPage()),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.getShadowColor(context).withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Attendance Overview',
                        style: AppStyles.titleMedium.copyWith(
                          color: AppColors.getTextPrimary(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isLoading && !hasError)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View All',
                            style: AppStyles.bodySmall.copyWith(
                              color: AppColors.getPrimaryColor(context),
                              fontWeight: FontWeight.w100,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.getPrimaryColor(context),
                            size: 16,
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: AppDimensions.paddingLarge),
                
                if (isLoading)
                  _buildStatsLoading()
                else if (hasError)
                  _buildStatsError()
                else
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Flexible(
                            child: _buildStatItem(
                              context: context,
                              icon: Icons.calendar_today_rounded,
                              value: upcomingCount.toString(),
                              label: 'Upcoming',
                              color: Colors.blue,
                              progress: 0,
                            ),
                          ),
                          Flexible(
                            child: _buildStatItem(
                              context: context,
                              icon: Icons.check_circle_rounded,
                              value: presentCount.toString(),
                              label: 'Present',
                              color: Colors.green,
                              progress: totalPastExams > 0 ? presentCount / totalPastExams : 0,
                            ),
                          ),
                          Flexible(
                            child: _buildStatItem(
                              context: context,
                              icon: Icons.cancel_rounded,
                              value: absentCount.toString(),
                              label: 'Absent',
                              color: Colors.orange,
                              progress: totalPastExams > 0 ? absentCount / totalPastExams : 0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Exams Attendance',
                                  style: AppStyles.bodyMedium.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                totalPastExams > 0 
                                    ? '${(attendanceRate * 100).toStringAsFixed(1)}%'
                                    : 'No past exams',
                                style: AppStyles.bodyMedium.copyWith(
                                  color: totalPastExams > 0 
                                      ? AppColors.getPrimaryColor(context)
                                      : AppColors.getTextSecondary(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (totalPastExams > 0)
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.getBackgroundColor(context),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  if (attendanceRate > 0)
                                    Expanded(
                                      flex: (attendanceRate * 100).round(),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.green.withOpacity(0.8),
                                              Colors.green,
                                            ],
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4),
                                            bottomLeft: Radius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (attendanceRate < 1)
                                    Expanded(
                                      flex: ((1 - attendanceRate) * 100).round(),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.orange,
                                              Colors.orange.withOpacity(0.8),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.only(
                                            topRight: Radius.circular(4),
                                            bottomRight: Radius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          else
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.getBackgroundColor(context),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  'No past exams to calculate rate',
                                  style: AppStyles.bodySmall.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                      // Show upcoming exams count separately
                      if (upcomingCount > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.upcoming_rounded,
                                size: 16,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$upcomingCount upcoming ${upcomingCount == 1 ? 'exam' : 'exams'}',
                                style: AppStyles.bodySmall.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsLoading() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItemShimmer(),
            _buildStatItemShimmer(),
            _buildStatItemShimmer(),
          ],
        ),
        const SizedBox(height: 20),
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItemShimmer() {
    return Flexible(
      child: Column(
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 30,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 40,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsError() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItemError(),
            _buildStatItemError(),
            _buildStatItemError(),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItemError() {
    return Flexible(
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
                width: 6,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.grey,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '--',
            style: AppStyles.headlineSmall.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Error',
            style: AppStyles.bodySmall.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppStyles.titleMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: AppStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
              fontSize: 11,
            ),
          ),
          if (progress > 0) ...[
            const SizedBox(height: 4),
            Container(
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.getBackgroundColor(context),
                borderRadius: BorderRadius.circular(1),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    List<String> parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  void _showMenuDialog(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: max(20.0, screenWidth * 0.1),
            vertical: max(20.0, screenHeight * 0.1),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.8,
            ),
            child: SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getCardBackground(context),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.getPrimaryColor(context).withOpacity(0.9),
                            AppColors.getSecondaryColor(context).withOpacity(0.9),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(22),
                          topRight: Radius.circular(22),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.menu_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'MENU',
                            style: AppStyles.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMenuItem(
                            context: context,
                            icon: Icons.palette_rounded,
                            title: 'Theme Settings',
                            color: AppColors.getPrimaryColor(context),
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              _showThemeSettings(context);
                            },
                          ),
                          
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(
                              height: 0.5,
                              color: AppColors.getTextSecondary(context).withOpacity(0.1),
                            ),
                          ),
                          
                          _buildMenuItem(
                            context: context,
                            icon: Icons.info_outline_rounded,
                            title: 'About App',
                            color: Colors.blue,
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              _showAboutDialog(context);
                            },
                          ),
                          
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(
                              height: 0.5,
                              color: AppColors.getTextSecondary(context).withOpacity(0.1),
                            ),
                          ),
                          
                          _buildMenuItem(
                            context: context,
                            icon: Icons.logout_rounded,
                            title: 'Logout',
                            color: Colors.red,
                            isLogout: true,
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              _showLogoutConfirmation(context);
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.getBackgroundColor(context),
                            foregroundColor: AppColors.getTextPrimary(context),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: AppColors.getPrimaryColor(context).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Close',
                            style: AppStyles.bodyMedium.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: color.withOpacity(0.2),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: color,
                    size: 18,
                  ),
                ),
              ),
              
              const SizedBox(width: 14),
              
              Expanded(
                child: Text(
                  title,
                  style: AppStyles.bodyMedium.copyWith(
                    color: isLogout ? Colors.red : AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isLogout ? Colors.red.withOpacity(0.7) : AppColors.getTextSecondary(context).withOpacity(0.7),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemeSettings(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    bool isDarkMode = themeProvider.isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: max(20.0, screenWidth * 0.1),
                vertical: max(20.0, screenHeight * 0.1),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: screenHeight * 0.8,
                ),
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.getCardBackground(context),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.getPrimaryColor(context).withOpacity(0.9),
                                AppColors.getSecondaryColor(context).withOpacity(0.9),
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(22),
                              topRight: Radius.circular(22),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.palette_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'THEME SETTINGS',
                                style: AppStyles.titleMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildThemeOption(
                                context: context,
                                icon: Icons.light_mode_rounded,
                                title: 'Light Mode',
                                isSelected: !isDarkMode,
                                color: !isDarkMode 
                                    ? AppColors.getPrimaryColor(context) 
                                    : AppColors.getTextSecondary(context),
                                onTap: () {
                                  setState(() => isDarkMode = false);
                                },
                              ),
                              
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Divider(
                                  height: 0.5,
                                  color: AppColors.getTextSecondary(context).withOpacity(0.1),
                                ),
                              ),
                              
                              _buildThemeOption(
                                context: context,
                                icon: Icons.dark_mode_rounded,
                                title: 'Dark Mode',
                                isSelected: isDarkMode,
                                color: isDarkMode 
                                    ? AppColors.getPrimaryColor(context) 
                                    : AppColors.getTextSecondary(context),
                                onTap: () {
                                  setState(() => isDarkMode = true);
                                },
                              ),
                              
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Divider(
                                  height: 0.5,
                                  color: AppColors.getTextSecondary(context).withOpacity(0.1),
                                ),
                              ),
                              
                              _buildThemeOption(
                                context: context,
                                icon: Icons.settings_suggest_rounded,
                                title: 'System Default',
                                isSelected: false,
                                color: AppColors.getPrimaryColor(context),
                                onTap: () {
                                  themeProvider.setSystemTheme();
                                  Navigator.of(dialogContext).pop();
                                },
                              ),
                            ],
                          ),
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(dialogContext).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.getBackgroundColor(context),
                                    foregroundColor: AppColors.getTextPrimary(context),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: AppColors.getPrimaryColor(context).withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: AppStyles.bodyMedium.copyWith(
                                      color: AppColors.getTextPrimary(context),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    themeProvider.toggleTheme(isDarkMode);
                                    Navigator.of(dialogContext).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isDarkMode ? 'Dark theme applied' : 'Light theme applied',
                                        ),
                                        backgroundColor: AppColors.getPrimaryColor(context),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.getPrimaryColor(context),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Apply',
                                    style: AppStyles.bodyMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: color.withOpacity(0.2),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: color,
                    size: 18,
                  ),
                ),
              ),
              
              const SizedBox(width: 14),
              
              Expanded(
                child: Text(
                  title,
                  style: AppStyles.bodyMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.getPrimaryColor(context),
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: max(20.0, screenWidth * 0.1),
            vertical: max(20.0, screenHeight * 0.1),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.8,
            ),
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.getCardBackground(context),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.getPrimaryColor(context).withOpacity(0.9),
                            AppColors.getSecondaryColor(context).withOpacity(0.9),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(22),
                          topRight: Radius.circular(22),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'ABOUT APP',
                            style: AppStyles.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppColors.getPrimaryColor(context),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.school_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Text(
                            'AttendScan',
                            style: AppStyles.titleMedium.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          
                          const SizedBox(height: 6),
                          
                          Text(
                            'Version 1.0.0',
                            style: AppStyles.bodySmall.copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Text(
                            'UTAR Exam Attendance Management System\nfor Students and Faculty',
                            style: AppStyles.bodySmall.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.getPrimaryColor(context).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '© 2026 UTAR',
                              style: AppStyles.bodySmall.copyWith(
                                color: AppColors.getPrimaryColor(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.getPrimaryColor(context),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'OK',
                            style: AppStyles.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: max(20.0, screenWidth * 0.1),
            vertical: max(20.0, screenHeight * 0.1),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.8,
            ),
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.getCardBackground(context),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.red.withOpacity(0.9),
                            Colors.red.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(22),
                          topRight: Radius.circular(22),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.logout_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'LOGOUT',
                            style: AppStyles.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 28,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          Text(
                            'Confirm Logout?',
                            style: AppStyles.titleSmall.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.getBackgroundColor(context),
                                foregroundColor: AppColors.getTextPrimary(context),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: AppColors.getPrimaryColor(context).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Cancel',
                                style: AppStyles.bodyMedium.copyWith(
                                  color: AppColors.getTextPrimary(context),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                // Clear local login status
                                final storage = LocalStorageService();
                                await storage.clearLoginStatus();
                                
                                // Sign out from Firebase
                                await FirebaseService().signOut();
                                
                                if (mounted) {
                                  Navigator.of(dialogContext).pop();
                                  
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AuthScreen(),
                                    ),
                                  );
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Logged out successfully'),
                                      backgroundColor: AppColors.getPrimaryColor(context),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Logout',
                                style: AppStyles.bodyMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

double max(double a, double b) => a > b ? a : b;