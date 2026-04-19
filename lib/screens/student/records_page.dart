// lib/screens/student/records_page.dart
import 'package:flutter/material.dart';
import 'package:attend_scan/constants/app_colors.dart';
import 'package:attend_scan/constants/app_styles.dart';
import 'package:attend_scan/constants/app_dimensions.dart';
import '../../services/firebase_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:attend_scan/services/connectivity_service.dart';
import 'package:attend_scan/repositories/student_repository.dart';
import 'package:attend_scan/services/local_storage_service.dart';

// Student records page: list upcoming, present, and absent exams
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => RecordsPageState();
}

class RecordsPageState extends State<RecordsPage> with WidgetsBindingObserver {
  final StudentRepository _repository = StudentRepository();
  final ConnectivityService _connectivity = ConnectivityService();
  
  UserModel? _currentStudent;
  List<Exam> _upcomingExams = [];
  List<Exam> _presentExams = [];
  List<Exam> _absentExams = [];
  Map<String, Map<String, dynamic>> _attendanceMap = {};
  bool _isLoading = true;
  bool _isOffline = false;
  bool _isSyncing = false;  
  String? _errorMessage;
  
  int _selectedTab = 0;
  final List<String> _tabs = ['Upcoming', 'Present', 'Absent'];

  @override
  bool get wantKeepAlive => true;

  // Initialize state and start loading records
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

  // Remove observers and listeners on dispose
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

  // Update offline status and trigger background sync when regained
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

  // Public helper to refresh records when page becomes visible
  void refreshWhenVisible() {
    _loadData(forceRefresh: true);
  }
  
  // Load exam records and attendance map, optionally forcing refresh
  Future<void> _loadData({bool forceRefresh = false}) async {
    // Check internet status before loading
    final hasInternet = await ConnectivityService.checkInternet();
    
    setState(() {
      _isLoading = true;
      _isOffline = !hasInternet;
    });
    
    try {
      final student = await _repository.getProfile(forceRefresh: forceRefresh);
      final records = await _repository.getExamRecords(forceRefresh: forceRefresh);
      
      setState(() {
        _currentStudent = student;
        
        _upcomingExams = (records['upcoming'] as List).map((json) => _examFromJson(json)).toList();
        _presentExams = (records['present'] as List).map((json) => _examFromJson(json)).toList();
        _absentExams = (records['absent'] as List).map((json) => _examFromJson(json)).toList();
        _attendanceMap = Map<String, Map<String, dynamic>>.from(records['attendanceMap'] ?? {});
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  // Sync records in the background without blocking UI
  Future<void> _syncInBackground() async {
    try {
      setState(() {
        _isSyncing = true;
      });
      
      // First sync pending operations
      await _syncPendingOperations();
      
      // Then refresh data
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

  // Convert raw exam JSON into an Exam model
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

  List<Exam> get _currentExams {
    switch (_selectedTab) {
      case 0:
        return _upcomingExams;
      case 1:
        return _presentExams;
      case 2:
        return _absentExams;
      default:
        return [];
    }
  }

  String _getExamStatus(Exam exam) {
    if (_presentExams.any((e) => e.examId == exam.examId)) return 'Present';
    if (_absentExams.any((e) => e.examId == exam.examId)) return 'Absent';
    if (_upcomingExams.any((e) => e.examId == exam.examId)) return 'Upcoming';
    return 'Unknown';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Present':
        return Colors.green;
      case 'Absent':
        return Colors.red;
      case 'Upcoming':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Present':
        return Icons.check_circle_rounded;
      case 'Absent':
        return Icons.cancel_rounded;
      case 'Upcoming':
        return Icons.calendar_today_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$day/$month/$year $hour:$minute';
  }

  AttendanceRecord? _attendanceRecordFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    
    return AttendanceRecord(
      attendanceId: map['attendanceId'] ?? '',
      examId: map['examId'] ?? '',
      studentId: map['studentId'] ?? '',
      indexNo: map['indexNo'] ?? '',
      indexNoWords: map['indexNoWords'] ?? '',
      seatNo: map['seatNo'] ?? '',
      scannedAt: map['scannedAt'] != null 
          ? DateTime.parse(map['scannedAt']) 
          : DateTime.now(),
      status: map['status'] ?? 'present',
      scannedLocation: map['scannedLocation'],  
      scannedLatitude: map['scannedLatitude'] != null ? (map['scannedLatitude'] as num).toDouble() : null,  
      scannedLongitude: map['scannedLongitude'] != null ? (map['scannedLongitude'] as num).toDouble() : null,  
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'RECORDS',
              style: AppStyles.titleLarge.copyWith(
                color: AppColors.getPrimaryColor(context), 
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            if (_isOffline)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      'Offline',
                      style: TextStyle(fontSize: 10, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            if (_isSyncing)
              Container(
                margin: const EdgeInsets.only(left: 8),
                width: 20,
                height: 20,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
          ],
        ),
        centerTitle: true,
      ),
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
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeaderCard(context)),
              SliverToBoxAdapter(child: _buildTabBar(context)),
              if (_isLoading)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingXLarge,
                    vertical: AppDimensions.paddingMedium,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildExamCardShimmer(context, index),
                      childCount: 3,
                    ),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.getCardBackground(context).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 60,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: AppStyles.bodyMedium.copyWith(
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () => _loadData(forceRefresh: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.getPrimaryColor(context),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Retry',
                                style: AppStyles.buttonMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else if (_currentExams.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: AppColors.getCardBackground(context).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.getPrimaryColor(context).withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _selectedTab == 0 ? Icons.calendar_today_outlined :
                                _selectedTab == 1 ? Icons.check_circle_outline_rounded :
                                Icons.cancel_outlined,
                                size: 40,
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _selectedTab == 0 ? 'No Upcoming Exams' :
                              _selectedTab == 1 ? 'No Attendance Records' :
                              'No Absent Exams',
                              style: AppStyles.titleLarge.copyWith(
                                color: AppColors.getTextPrimary(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedTab == 0 ? 'Your upcoming exams will appear here' :
                              _selectedTab == 1 ? 'Your attendance records will appear here' :
                              'No exams missed yet',
                              textAlign: TextAlign.center,
                              style: AppStyles.bodyMedium.copyWith(
                                color: AppColors.getTextSecondary(context).withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingXLarge,
                    vertical: AppDimensions.paddingMedium,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final exam = _currentExams[index];
                        final status = _getExamStatus(exam);
                        final attendance = _attendanceMap[exam.examId];
                        
                        return _buildExamCard(
                          context, 
                          exam, 
                          status,
                          attendance != null ? _attendanceRecordFromMap(attendance) : null,
                          index
                        );
                      },
                      childCount: _currentExams.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Build header card (with Shimmer effect)
  Widget _buildHeaderCard(BuildContext context) {
    final totalExams = _upcomingExams.length + _presentExams.length + _absentExams.length;
    
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingXLarge,
        vertical: AppDimensions.paddingSmall,
      ),
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
            color: AppColors.getPrimaryColor(context).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: _isLoading 
            ? _buildHeaderShimmer()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Records',
                        style: AppStyles.titleLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentStudent != null
                            ? '${_currentStudent!.fullName} • ${_currentStudent!.studentId}'
                            : 'Loading...',
                        style: AppStyles.bodyMedium.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: Container(
                      height: 1,
                      width: MediaQuery.of(context).size.width * 0.8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Total
                        _buildHeaderStatItem(
                          icon: Icons.library_books_rounded,
                          value: totalExams.toString(),
                          label: 'Total',
                          color: Colors.white,
                        ),
                        
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        
                        // Upcoming
                        _buildHeaderStatItem(
                          icon: Icons.calendar_today_rounded,
                          value: _upcomingExams.length.toString(),
                          label: 'Upcoming',
                          color: const Color(0xFF2196F3),
                        ),
                        
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        
                        // Present
                        _buildHeaderStatItem(
                          icon: Icons.check_circle_rounded,
                          value: _presentExams.length.toString(),
                          label: 'Present',
                          color: const Color(0xFF4CAF50),
                        ),
                        
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        
                        // Absent
                        _buildHeaderStatItem(
                          icon: Icons.cancel_rounded,
                          value: _absentExams.length.toString(),
                          label: 'Absent',
                          color: const Color(0xFFF44336),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  if (totalExams > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Attendance Rate',
                                style: AppStyles.bodyMedium.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              Text(
                                (_presentExams.length + _absentExams.length) > 0
                                    ? '${((_presentExams.length / (_presentExams.length + _absentExams.length)) * 100).toStringAsFixed(1)}%'
                                    : 'No past exams',
                                style: AppStyles.titleMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_presentExams.length + _absentExams.length > 0)
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Row(
                                children: [
                                  if (_presentExams.length > 0)
                                    Expanded(
                                      flex: _presentExams.length,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.green.withOpacity(0.8),
                                              Colors.green,
                                            ],
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(3),
                                            bottomLeft: Radius.circular(3),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_absentExams.length > 0)
                                    Expanded(
                                      flex: _absentExams.length,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(3),
                                            bottomRight: Radius.circular(3),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          else
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  // Shimmer effect used for the header card while loading
  Widget _buildHeaderShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shimmer.fromColors(
          baseColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.4),
          child: Container(
            width: 200,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Shimmer.fromColors(
          baseColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.4),
          child: Container(
            width: 150,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Center(
          child: Container(
            height: 1,
            width: MediaQuery.of(context).size.width * 0.8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderStatShimmer(),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.2),
              ),
              _buildHeaderStatShimmer(),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.2),
              ),
              _buildHeaderStatShimmer(),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.2),
              ),
              _buildHeaderStatShimmer(),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Shimmer.fromColors(
                    baseColor: Colors.white.withOpacity(0.2),
                    highlightColor: Colors.white.withOpacity(0.4),
                    child: Container(
                      width: 100,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Shimmer.fromColors(
                    baseColor: Colors.white.withOpacity(0.2),
                    highlightColor: Colors.white.withOpacity(0.4),
                    child: Container(
                      width: 50,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Shimmer.fromColors(
                baseColor: Colors.white.withOpacity(0.2),
                highlightColor: Colors.white.withOpacity(0.4),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderStatShimmer() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Shimmer.fromColors(
              baseColor: Colors.white.withOpacity(0.2),
              highlightColor: Colors.white.withOpacity(0.4),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Shimmer.fromColors(
              baseColor: Colors.white.withOpacity(0.2),
              highlightColor: Colors.white.withOpacity(0.4),
              child: Container(
                width: 30,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Shimmer.fromColors(
          baseColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.4),
          child: Container(
            width: 40,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: AppStyles.titleMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingXLarge,
        vertical: AppDimensions.paddingSmall,
      ),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.getPrimaryColor(context).withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: _isLoading
            ? _buildTabBarShimmer()
            : Row(
                children: _tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tab = entry.value;
                  final isSelected = _selectedTab == index;
                  
                  return Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedTab = index;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: isSelected 
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.getPrimaryColor(context).withOpacity(0.7),
                                      AppColors.getSecondaryColor(context).withOpacity(0.7),
                                    ],
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected 
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? Colors.white.withOpacity(0.2)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected 
                                        ? Colors.white.withOpacity(0.3)
                                        : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    index == 0 ? Icons.calendar_today_rounded :
                                    index == 1 ? Icons.check_circle_rounded :
                                    Icons.cancel_rounded,
                                    size: 16,
                                    color: isSelected 
                                        ? Colors.white
                                        : AppColors.getTextSecondary(context).withOpacity(0.7),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tab,
                                style: AppStyles.bodyMedium.copyWith(
                                  color: isSelected 
                                      ? Colors.white
                                      : AppColors.getTextSecondary(context),
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  // Shimmer effect used for the tab bar while loading
  Widget _buildTabBarShimmer() {
    return Row(
      children: List.generate(3, (index) {
        return Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    width: 50,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // Shimmer effect used for individual exam cards while loading
  Widget _buildExamCardShimmer(BuildContext context, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context).withOpacity(0.8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.grey.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status label
              Container(
                width: 80,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Subject name
              Container(
                width: 200,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Date and time
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 6),
              
              // Location
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 150,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Attendance info area
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 60,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 50,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 100,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamCard(
    BuildContext context, 
    Exam exam, 
    String status,
    AttendanceRecord? attendance,
    int index
  ) {
    final statusColor = _getStatusColor(status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showExamDetails(context, exam, status, attendance);
          },
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context).withOpacity(0.8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: statusColor.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.getShadowColor(context).withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [   
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status label
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status,
                                style: AppStyles.bodySmall.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Subject name
                            Text(
                              exam.subjectName,
                              style: AppStyles.titleMedium.copyWith(
                                color: AppColors.getTextPrimary(context),
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            
                            // Date and time
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: AppColors.getTextSecondary(context),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    exam.formattedDateTime, 
                                    style: AppStyles.bodySmall.copyWith(
                                      color: AppColors.getTextSecondary(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            
                            // Location
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: AppColors.getTextSecondary(context),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    exam.location,
                                    style: AppStyles.bodySmall.copyWith(
                                      color: AppColors.getTextSecondary(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (attendance != null && status == 'Present') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.getBackgroundColor(context).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.chair_rounded,
                                          size: 14,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Seat',
                                          style: AppStyles.bodySmall.copyWith(
                                            color: AppColors.getTextSecondary(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      (attendance.seatNo != null && attendance.seatNo.isNotEmpty) 
                                          ? attendance.seatNo 
                                          : 'Not Assigned',
                                      style: AppStyles.titleSmall.copyWith(
                                        color: (attendance.seatNo != null && attendance.seatNo.isNotEmpty) 
                                            ? Colors.green 
                                            : AppColors.getTextSecondary(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.qr_code_scanner_rounded,
                                          size: 14,
                                          color: AppColors.getPrimaryColor(context),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Scanned',
                                          style: AppStyles.bodySmall.copyWith(
                                            color: AppColors.getTextSecondary(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      attendance.scannedAt != null 
                                          ? _formatDateTime(attendance.scannedAt)
                                          : 'Not Scanned',
                                      style: AppStyles.bodySmall.copyWith(
                                        color: AppColors.getTextPrimary(context),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (attendance.scannedLocation != null && attendance.scannedLocation!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Divider(
                              height: 1,
                              color: Colors.grey.withOpacity(0.2),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  attendance.scannedLocation!.contains('Outside') 
                                      ? Icons.warning_rounded 
                                      : Icons.location_on_rounded,
                                  size: 14,
                                  color: attendance.scannedLocation!.contains('Outside') 
                                      ? Colors.orange 
                                      : Colors.teal,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    attendance.scannedLocation!,
                                    style: AppStyles.bodySmall.copyWith(
                                      color: attendance.scannedLocation!.contains('Outside') 
                                          ? Colors.orange 
                                          : Colors.teal,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showExamDetails(BuildContext context, Exam exam, String status, AttendanceRecord? attendance) {
    // Format date and time for display in the details modal
    final formattedDate = '${exam.startTime.day}/${exam.startTime.month}/${exam.startTime.year}';
    final formattedTime = '${exam.startTime.hour.toString().padLeft(2, '0')}:${exam.startTime.minute.toString().padLeft(2, '0')} - ${exam.endTime.hour.toString().padLeft(2, '0')}:${exam.endTime.minute.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        
        return Container(
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.9,
          ),
          decoration: BoxDecoration(
            color: AppColors.getCardBackground(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.getPrimaryColor(context).withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getStatusColor(status).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            status,
                            style: AppStyles.bodyMedium.copyWith(
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                          
                        const SizedBox(height: 10),
                        
                        Text(
                          exam.subjectName,
                          style: AppStyles.titleLarge.copyWith(
                            color: AppColors.getTextPrimary(context),
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // Exam details
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.getBackgroundColor(context).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.getPrimaryColor(context).withOpacity(0.15),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDetailRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Exam Date',
                          value: formattedDate,
                          color: Colors.blue,
                        ),
                        
                        const SizedBox(height: 10),
                        
                        _buildDetailRow(
                          icon: Icons.access_time_rounded,
                          label: 'Exam Time',
                          value: formattedTime,
                          color: Colors.blue,
                        ),
                        
                        const SizedBox(height: 10),
                        
                        _buildDetailRow(
                          icon: Icons.location_on_rounded,
                          label: 'Location',
                          value: exam.location,
                          color: Colors.orange,
                        ),
                        
                        const SizedBox(height: 10),
                        
                        _buildDetailRow(
                          icon: Icons.event_available_rounded,
                          label: 'Duration',
                          value: _formatDuration(exam.startTime, exam.endTime),
                          color: Colors.purple,
                        ),
                        
                        if (attendance != null && status == 'Present') ...[
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            icon: Icons.chair_rounded,
                            label: 'Seat Number',
                            value: (attendance.seatNo != null && attendance.seatNo.isNotEmpty) 
                                ? attendance.seatNo 
                                : 'Not Assigned',
                            color: (attendance.seatNo != null && attendance.seatNo.isNotEmpty) 
                                ? Colors.deepPurple 
                                : AppColors.getTextSecondary(context),
                          ),
                          
                          const SizedBox(height: 10),
                          
                          _buildDetailRow(
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'Scanned At',
                            value: attendance.scannedAt != null 
                                ? _formatDateTime(attendance.scannedAt)
                                : 'Not Scanned',
                            color: Colors.green,
                          ),

                          if (attendance.scannedLocation != null && attendance.scannedLocation!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _buildDetailRow(
                              icon: attendance.scannedLocation!.contains('Outside') 
                                  ? Icons.warning_rounded 
                                  : Icons.location_on_rounded,
                              label: 'Scan Location',
                              value: attendance.scannedLocation!,
                              color: attendance.scannedLocation!.contains('Outside') 
                                  ? Colors.orange 
                                  : Colors.teal,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  
                  if (attendance != null && attendance.indexNo.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.getPrimaryColor(context).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.badge_rounded,
                                color: AppColors.getPrimaryColor(context),
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Index Number',
                                  style: AppStyles.bodySmall.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  attendance.indexNo,
                                  style: AppStyles.titleSmall.copyWith(
                                    color: AppColors.getTextPrimary(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 15),
                  
                  // Close button
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.getPrimaryColor(context).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.getPrimaryColor(context),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Close',
                              style: AppStyles.buttonMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper: format exam duration into human-readable text
  String _formatDuration(DateTime startTime, DateTime endTime) {
    final duration = endTime.difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0 && minutes > 0) {
      return '$hours hours $minutes minutes';
    } else if (hours > 0) {
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    } else {
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.getBackgroundColor(context),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1.5,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppStyles.titleSmall.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}