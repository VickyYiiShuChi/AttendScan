// lib/screens/student/profile_page.dart
import 'package:flutter/material.dart';
import 'package:attend_scan/constants/app_colors.dart';
import 'package:attend_scan/constants/app_styles.dart';
import 'package:attend_scan/constants/app_dimensions.dart';
import '../../services/firebase_service.dart';
import '../../services/connectivity_service.dart';
import '../../repositories/student_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/avatar_generator.dart';
import 'package:shimmer/shimmer.dart';
import 'package:attend_scan/services/local_storage_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  final FirebaseService _firebaseService = FirebaseService();
  final StudentRepository _repository = StudentRepository();
  final ConnectivityService _connectivity = ConnectivityService();
  
  UserModel? _currentStudent;
  bool _isLoading = true;
  bool _isOffline = false;
  bool _isRefreshing = false;
  String? _errorMessage;

  final List<String> _faculties = [
    'Faculty of Information and Communication Technology',
    'Faculty of Engineering',
    'Faculty of Business and Finance',
    'Faculty of Science',
    'Faculty of Medicine and Health Sciences',
    'Faculty of Arts and Social Science',
  ];
  
  final Map<String, List<String>> _programmes = {
    'Faculty of Information and Communication Technology': [
      'Bachelor of Computer Science',
      'Bachelor of Information Technology',
      'Bachelor of Software Engineering',
      'Bachelor of Data Science',
      'Bachelor of Artificial Intelligence',
    ],
    'Faculty of Engineering': [
      'Bachelor of Mechanical Engineering',
      'Bachelor of Electrical Engineering',
      'Bachelor of Civil Engineering',
      'Bachelor of Chemical Engineering',
      'Bachelor of Electronic Engineering',
    ],
    'Faculty of Business and Finance': [
      'Bachelor of Business Administration',
      'Bachelor of Accounting',
      'Bachelor of Finance',
      'Bachelor of Marketing',
      'Bachelor of Economics',
    ],
    'Faculty of Science': [
      'Bachelor of Science',
      'Bachelor of Biotechnology',
      'Bachelor of Chemistry',
      'Bachelor of Physics',
      'Bachelor of Mathematics',
    ],
    'Faculty of Medicine and Health Sciences': [
      'Bachelor of Medicine',
      'Bachelor of Pharmacy',
      'Bachelor of Nursing',
      'Bachelor of Biomedical Science',
    ],
    'Faculty of Arts and Social Science': [
      'Bachelor of Psychology',
      'Bachelor of Sociology',
      'Bachelor of Communication',
      'Bachelor of English Literature',
    ],
  };

  @override
  bool get wantKeepAlive => true;
  
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
    
    // Add connectivity listener
    _connectivity.addListener(_onConnectivityChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingSync();
    });
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
  
  // Handle connectivity changes and trigger background sync
  void _onConnectivityChanged() {
    setState(() {
      _isOffline = !_connectivity.hasInternet;
    });
    
    if (_connectivity.hasInternet && mounted) {
      _syncInBackground();
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
      // Show refreshing indicator
      setState(() {
        _isRefreshing = true;
      });
      
      try {
        // Sync pending offline operations first
        await _syncPendingOperations();
        
        // Then force refresh profile data
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
            _isRefreshing = false;
          });
        }
      }
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

  void _checkPendingSync() {
    final storage = LocalStorageService();
    final queue = storage.getSyncQueue();
    if (queue.isNotEmpty) {
      setState(() {});
    }
  }
  
  // Load profile data, optionally forcing a refresh from network
  Future<void> _loadData({bool forceRefresh = false}) async {
    // Check internet status before loading
    final hasInternet = await ConnectivityService.checkInternet();
    
    setState(() {
      _isLoading = true;
      _isOffline = !hasInternet;
    });
    
    try {
      final student = await _repository.getProfile(forceRefresh: forceRefresh);
      setState(() {
        _currentStudent = student;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  // Sync profile data in background
  Future<void> _syncInBackground() async {
    try {
      // First sync pending operations
      await _syncPendingOperations();
      
      // Then refresh profile
      await _repository.getProfile(forceRefresh: true);
      
      if (mounted) {
        await _loadData(forceRefresh: true);
      }
    } catch (e) {
      print('Background sync error: $e');
    }
  }

  String _getAvatarUrl() {
    if (_currentStudent == null) {
      return DiceBearAvatar.getUserAvatar(
        userId: '',
        email: '',
        name: 'User',
        style: 'avataaars',
      );
    }
    
    return DiceBearAvatar.getUserAvatar(
      userId: _currentStudent!.studentId ?? '',
      email: _currentStudent!.email,
      name: _currentStudent!.fullName,
      style: _currentStudent!.avatarStyle,
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
              'PROFILE',
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
            if (_isRefreshing)
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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
              child: _isLoading ? _buildShimmerContent() : _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  // Shimmer content for loading state
  Widget _buildShimmerContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildUserInfoCardShimmer(),
        const SizedBox(height: AppDimensions.paddingXLarge),
        _buildActionButtonsShimmer(),
      ],
    );
  }

  Widget _buildUserInfoCardShimmer() {
    return Container(
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
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.white.withOpacity(0.2),
        highlightColor: Colors.white.withOpacity(0.4),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 150,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 200,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                height: 1,
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildProfileInfoItemShimmer(),
                    const SizedBox(height: 16),
                    _buildProfileInfoItemShimmer(),
                    const SizedBox(height: 16),
                    _buildProfileInfoItemShimmer(),
                    const SizedBox(height: 16),
                    _buildProfileInfoItemShimmer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfoItemShimmer() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtonsShimmer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Actual content
  Widget _buildContent() {
    if (_currentStudent == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_rounded,
              size: 60,
              color: AppColors.getTextSecondary(context),
            ),
            SizedBox(height: 16),
            Text(
              'No profile data found',
              style: AppStyles.titleSmall.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadData,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildUserInfoCard(),
        const SizedBox(height: AppDimensions.paddingXLarge),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
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
            color: AppColors.getPrimaryColor(context).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _showAvatarStyleDialog(),
                  child: Stack(
                    children: [
                      _buildDiceBearAvatar(),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 20,
                            color: AppColors.getPrimaryColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),
                
                Text(
                  _currentStudent!.fullName,
                  style: AppStyles.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 3),
                
                Text(
                  _currentStudent!.email,
                  style: AppStyles.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  height: 1,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                
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
                  child: Column(
                    children: [
                      _buildProfileInfoItem(
                        icon: Icons.badge_rounded,
                        label: 'Student ID',
                        value: _currentStudent!.studentId ?? '',
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      _buildProfileInfoItem(
                        icon: Icons.assignment_ind_rounded,
                        label: 'Index No',
                          value: (_currentStudent!.indexNo ?? '').isEmpty 
                              ? 'Not set' 
                              : _currentStudent!.indexNo ?? '',
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      _buildProfileInfoItem(
                        icon: Icons.school_rounded,
                        label: 'Faculty',
                          value: _currentStudent!.faculty ?? 'Not specified',
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      _buildProfileInfoItem(
                        icon: Icons.book_rounded,
                        label: 'Programme',
                        value: _currentStudent!.programme ?? 'Not specified',
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      _buildProfileInfoItem(
                        icon: Icons.calendar_today_rounded,
                        label: 'Member Since',
                        value: _currentStudent!.formattedMemberSince,
                        color: Colors.white,
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

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.getShadowColor(context).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showEditProfileDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.9),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_rounded,
                    color: AppColors.getPrimaryColor(context),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Edit Profile',
                    style: AppStyles.buttonMedium.copyWith(
                      color: AppColors.getPrimaryColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: AppDimensions.paddingMedium),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showChangePasswordDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.getPrimaryColor(context).withOpacity(0.9),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_reset_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Change Password',
                    style: AppStyles.buttonMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widgets
  Widget _buildProfileInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
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
                  color: color.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppStyles.titleSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiceBearAvatar() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: _getAvatarUrl(),
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.white.withOpacity(0.1),
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: AppColors.getPrimaryColor(context),
            child: Center(
              child: Text(
                _getInitials(_currentStudent!.fullName),
                style: AppStyles.headlineLarge.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAvatarStyleDialog() {
    final styles = DiceBearAvatar.getAvailableStyles();
    final screenHeight = MediaQuery.of(context).size.height;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: max(20.0, MediaQuery.of(context).size.width * 0.1),
            vertical: max(20.0, screenHeight * 0.05),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.8,
            ),
            child: SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getCardBackground(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
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
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
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
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'CHOOSE AVATAR STYLE',
                              style: AppStyles.titleLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Current preview
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Current Preview',
                            style: AppStyles.bodyMedium.copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.getPrimaryColor(context),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.getPrimaryColor(context).withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: _getAvatarUrl(),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DiceBearAvatar.getStyleDisplayName(_currentStudent!.avatarStyle),
                            style: AppStyles.titleMedium.copyWith(
                              color: AppColors.getPrimaryColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    // Avatar style grid
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: styles.length,
                        itemBuilder: (context, index) {
                          final style = styles[index];
                          bool isSelected = _currentStudent!.avatarStyle == style['id']!;
                          
                          return GestureDetector(
                            onTap: () async {
                              try {
                                // Update through repository (handles local cache and sync queue)
                                final updateSuccess = await _repository.updateProfile(
                                  studentId: _currentStudent!.studentId ?? '',
                                  avatarStyle: style['id']!,
                                );
                                
                                if (updateSuccess) {
                                  // Update local state
                                  setState(() {
                                    _currentStudent = _currentStudent!.copyWith(
                                      avatarStyle: style['id']!,
                                    );
                                  });
                                  
                                  Navigator.of(dialogContext).pop();
                                  
                                  // Show success message - same as edit profile
                                  String message = _connectivity.hasInternet
                                      ? 'Avatar updated successfully!'
                                      : 'Avatar saved offline. Will sync when online.';
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(
                                            _connectivity.hasInternet
                                                ? Icons.check_circle_rounded
                                                : Icons.save_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              message,
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: _connectivity.hasInternet ? Colors.green : Colors.orange,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text('Failed to update: $e'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.getPrimaryColor(context).withOpacity(0.1)
                                    : AppColors.getBackgroundColor(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.getPrimaryColor(context)
                                      : AppColors.getTextHint(context).withOpacity(0.3),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 48, 
                                    height: 48, 
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      image: DecorationImage(
                                        image: NetworkImage(style['previewUrl']!),
                                        fit: BoxFit.cover,
                                      ),
                                      border: Border.all(
                                        color: AppColors.getTextHint(context).withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    style['name']!,
                                    style: AppStyles.bodySmall.copyWith(
                                      color: isSelected
                                          ? AppColors.getPrimaryColor(context)
                                          : AppColors.getTextSecondary(context),
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Close button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.getBackgroundColor(context),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: AppColors.getPrimaryColor(context).withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: Text(
                            'Close',
                            style: AppStyles.buttonMedium.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w600,
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

  void _showEditProfileDialog() async {
    final TextEditingController nameController = TextEditingController(
      text: _currentStudent!.fullName
    );
    final TextEditingController indexNoController = TextEditingController(
      text: _currentStudent!.indexNo
    );
    
    String selectedFaculty = _currentStudent!.faculty ?? '';
    String selectedProgramme = _currentStudent!.programme ?? '';
    List<String> availableProgrammes = [];
    
    if (_faculties.contains(selectedFaculty)) {
      availableProgrammes = _programmes[selectedFaculty] ?? [];
    }
    
    bool _isSaving = false;
    bool success = false;
    final screenHeight = MediaQuery.of(context).size.height;
    
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              insetPadding: EdgeInsets.symmetric(
                horizontal: max(20.0, MediaQuery.of(context).size.width * 0.1),
                vertical: max(20.0, screenHeight * 0.05),
              ),
              child: Container(
                width: 500,
                constraints: BoxConstraints(
                  maxHeight: screenHeight * 0.72,
                ),
                decoration: BoxDecoration(
                  color: AppColors.getCardBackground(context),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.getPrimaryColor(context).withOpacity(0.95),
                            AppColors.getSecondaryColor(context).withOpacity(0.95),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Profile',
                                  style: AppStyles.titleLarge.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Update your personal information',
                                  style: AppStyles.bodySmall.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content area
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Avatar preview
                            Center(
                              child: Container(
                                width: 80,
                                height: 80,
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.getPrimaryColor(context),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.getPrimaryColor(context).withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: _getAvatarUrl(),
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            // Form card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.getBackgroundColor(context).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Name field
                                  _buildModernTextField(
                                    controller: nameController,
                                    label: 'Full Name',
                                    icon: Icons.person_rounded,
                                    color: Colors.blue,
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  // Index Number field
                                  _buildModernTextField(
                                    controller: indexNoController,
                                    label: 'Index Number',
                                    icon: Icons.numbers_rounded,
                                    color: Colors.purple,
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  // Faculty dropdown
                                  _buildModernDropdown(
                                    value: selectedFaculty.isNotEmpty && _faculties.contains(selectedFaculty)
                                        ? selectedFaculty
                                        : null,
                                    hint: 'Select Faculty',
                                    icon: Icons.school_rounded,
                                    color: Colors.orange,
                                    items: _faculties,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        selectedFaculty = value ?? '';
                                        selectedProgramme = '';
                                        availableProgrammes = _programmes[selectedFaculty] ?? [];
                                      });
                                    },
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  // Programme dropdown
                                  _buildModernDropdown(
                                    value: selectedProgramme.isNotEmpty && availableProgrammes.contains(selectedProgramme)
                                        ? selectedProgramme
                                        : null,
                                    hint: selectedFaculty.isEmpty
                                        ? 'Select Faculty First'
                                        : 'Select Programme',
                                    icon: Icons.book_rounded,  
                                    color: selectedFaculty.isEmpty ? Colors.grey : Colors.green,
                                    items: availableProgrammes,
                                    enabled: selectedFaculty.isNotEmpty,
                                    onChanged: selectedFaculty.isEmpty
                                        ? null
                                        : (value) {
                                            setDialogState(() {
                                              selectedProgramme = value ?? '';
                                            });
                                          },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Action buttons
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: AppColors.getTextHint(context).withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving ? null : () => Navigator.of(dialogContext).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: BorderSide(
                                  color: AppColors.getTextHint(context).withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: AppStyles.buttonMedium.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : () async {
                                setDialogState(() => _isSaving = true);
                                
                                try {
                                  final newName = nameController.text.trim();
                                  final newIndexNo = indexNoController.text.trim();
                                  
                                  final hasInternet = await ConnectivityService.checkInternet();
                                  
                                  
                                  final updateSuccess = await _repository.updateProfile(
                                    studentId: _currentStudent!.studentId ?? '',
                                    fullName: newName,
                                    indexNo: newIndexNo,
                                    faculty: selectedFaculty.isNotEmpty ? selectedFaculty : null,
                                    programme: selectedProgramme.isNotEmpty ? selectedProgramme : null,
                                  );
                                  
                                  
                                  if (updateSuccess) {
                                    // Reload from local cache
                                    final updatedStudent = await _repository.getProfile(forceRefresh: true);
                                    
                                    setState(() {
                                      _currentStudent = updatedStudent;
                                    });
                                    
                                    success = true;
                                    
                                    if (dialogContext.mounted) {
                                      Navigator.of(dialogContext).pop();
                                    }
                                    
                                    Future.microtask(() {
                                      if (context.mounted) {
                                        String message = hasInternet
                                            ? 'Profile updated successfully!'
                                            : 'Profile saved offline. Will sync when online.';
                                        
                                        ScaffoldMessenger.of(context).clearSnackBars();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                Icon(
                                                  hasInternet
                                                      ? Icons.check_circle_rounded
                                                      : Icons.save_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    message,
                                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: hasInternet ? Colors.green : Colors.orange,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    });
                                  } else {
                                    throw Exception('Failed to update profile');
                                  }
                                } catch (e) {
                                  
                                  if (dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                  }
                                  
                                  Future.microtask(() {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text('Failed to update: $e'),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    }
                                  });
                                } finally {
                                  setDialogState(() => _isSaving = false);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.getPrimaryColor(context),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Save',
                                          style: AppStyles.buttonMedium.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    
    if (success) {
      _loadData();
    }
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        style: AppStyles.bodyLarge.copyWith(
          color: AppColors.getTextPrimary(context),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: AppColors.getTextSecondary(context),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          filled: true,
          fillColor: AppColors.getBackgroundColor(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppColors.getTextHint(context).withOpacity(0.2),
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppColors.getTextHint(context).withOpacity(0.2),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: color,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildModernDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required Color color,
    required List<String> items,
    required Function(String?)? onChanged,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hint,
                style: TextStyle(
                  color: enabled
                      ? AppColors.getTextSecondary(context)
                      : AppColors.getTextHint(context).withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        isExpanded: true,
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: enabled ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: enabled ? color : AppColors.getTextHint(context).withOpacity(0.3),
              size: 18,
            ),
          ),
          filled: true,
          fillColor: AppColors.getBackgroundColor(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppColors.getTextHint(context).withOpacity(0.2),
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppColors.getTextHint(context).withOpacity(0.2),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: enabled ? color : Colors.grey,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: enabled ? color : AppColors.getTextHint(context).withOpacity(0.3),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: AppStyles.bodyMedium.copyWith(
                color: AppColors.getTextPrimary(context),
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    bool _isChanging = false;
    final screenHeight = MediaQuery.of(context).size.height;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: EdgeInsets.symmetric(
                horizontal: max(20.0, MediaQuery.of(context).size.width * 0.1),
                vertical: max(20.0, screenHeight * 0.05),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: screenHeight * 0.8,
                ),
                child: SingleChildScrollView(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.getCardBackground(context),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 30,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
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
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
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
                                  Icons.lock_reset_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'CHANGE PASSWORD',
                                  style: AppStyles.titleLarge.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Offline warning (if no internet)
                        if (!_connectivity.hasInternet)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.wifi_off_rounded,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'You are offline. Password change requires internet connection.',
                                    style: TextStyle(
                                      color: Colors.orange[800],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Form
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [                   
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.getBackgroundColor(context).withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.getTextHint(context).withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: currentPasswordController,
                                      obscureText: true,
                                      style: AppStyles.bodyLarge.copyWith(
                                        color: AppColors.getTextPrimary(context),
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Current Password',
                                        labelStyle: TextStyle(
                                          color: AppColors.getTextSecondary(context),
                                          fontSize: 14,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.lock_rounded,
                                          color: AppColors.getPrimaryColor(context),
                                          size: 20,
                                        ),
                                        filled: true,
                                        fillColor: AppColors.getBackgroundColor(context),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.getTextHint(context).withOpacity(0.3),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.getTextHint(context).withOpacity(0.3),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.getPrimaryColor(context),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    TextFormField(
                                      controller: newPasswordController,
                                      obscureText: true,
                                      style: AppStyles.bodyLarge.copyWith(
                                        color: AppColors.getTextPrimary(context),
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'New Password',
                                        labelStyle: TextStyle(
                                          color: AppColors.getTextSecondary(context),
                                          fontSize: 14,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.lock_outline_rounded,
                                          color: AppColors.getPrimaryColor(context),
                                          size: 20,
                                        ),
                                        filled: true,
                                        fillColor: AppColors.getBackgroundColor(context),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.getTextHint(context).withOpacity(0.3),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.getTextHint(context).withOpacity(0.3),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.getPrimaryColor(context),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    TextFormField(
                                      controller: confirmPasswordController,
                                      obscureText: true,
                                      style: AppStyles.bodyLarge.copyWith(
                                        color: AppColors.getTextPrimary(context),
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Confirm New Password',
                                        labelStyle: TextStyle(
                                          color: AppColors.getTextSecondary(context),
                                          fontSize: 14,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.lock_reset_rounded,
                                          color: AppColors.getPrimaryColor(context),
                                          size: 20,
                                        ),
                                        filled: true,
                                        fillColor: AppColors.getBackgroundColor(context),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.getTextHint(context).withOpacity(0.3),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.getTextHint(context).withOpacity(0.3),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.getPrimaryColor(context),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Action buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isChanging ? null : () => Navigator.of(dialogContext).pop(),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.getBackgroundColor(context),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: BorderSide(
                                            color: AppColors.getTextHint(context).withOpacity(0.3),
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Cancel',
                                        style: AppStyles.buttonMedium.copyWith(
                                          color: AppColors.getTextSecondary(context),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isChanging ? null : () async {
                                        // Check internet first
                                        if (!_connectivity.hasInternet) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                                                  const SizedBox(width: 12),
                                                  const Expanded(
                                                    child: Text('Cannot change password while offline'),
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
                                          return;
                                        }
                                        
                                        if (newPasswordController.text != confirmPasswordController.text) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                                                  const SizedBox(width: 12),
                                                  const Expanded(
                                                    child: Text('New passwords do not match'),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        
                                        if (newPasswordController.text.length < 6) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                                                  const SizedBox(width: 12),
                                                  const Expanded(
                                                    child: Text('Password must be at least 6 characters'),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        
                                        setState(() => _isChanging = true);
                                        
                                        try {
                                          String? result = await _firebaseService.changePassword(
                                            currentPassword: currentPasswordController.text,
                                            newPassword: newPasswordController.text,
                                          );
                                          
                                          if (result == 'Success') {
                                            Navigator.of(dialogContext).pop();
                                            
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(Icons.check_circle_rounded, color: Colors.white),
                                                    const SizedBox(width: 8),
                                                    const Expanded(
                                                      child: Text('Password changed successfully'),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor: Colors.green,
                                                duration: const Duration(seconds: 3),
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(Icons.error_outline_rounded, color: Colors.white),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(result ?? 'Failed to change password'),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor: Colors.red,
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.error_outline_rounded, color: Colors.white),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text('Error: $e'),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          );
                                        } finally {
                                          setState(() => _isChanging = false);
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.getPrimaryColor(context),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: _isChanging
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                                                const SizedBox(width: 6),
                                                const Text('Update'),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
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
}

double max(double a, double b) => a > b ? a : b;