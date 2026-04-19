// lib/screens/admin/admin_home_page.dart
import 'package:flutter/material.dart';
import 'package:attend_scan/constants/app_colors.dart';
import 'package:attend_scan/constants/app_styles.dart';
import 'package:attend_scan/constants/app_dimensions.dart';
import 'package:attend_scan/services/firebase_service.dart';
import 'package:attend_scan/screens/auth_screen.dart';
import 'package:attend_scan/screens/admin/manage_exams_page.dart';
import 'package:attend_scan/screens/admin/manage_students_page.dart';
import 'package:attend_scan/screens/admin/attendance_records_page.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

// Admin dashboard showing stats, quick actions, and recent activity
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _adminName = 'Admin';

  // Load dashboard stats on startup
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Fetch exams and students, compute dashboard statistics
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = await _firebaseService.getCurrentUser();
      if (user != null && user.isAdmin) {
        _adminName = user.fullName;
        
        final examsResult = await _firebaseService.getAllExams(adminEmail: user.email);
        final studentsResult = await _firebaseService.getAllStudents(user.email);
        
        final exams = examsResult['exams'] as List? ?? [];
        final students = studentsResult['students'] as List? ?? [];
        
        final now = DateTime.now();
        final todayExams = exams.where((e) => 
          e.startTime.year == now.year &&
          e.startTime.month == now.month &&
          e.startTime.day == now.day
        ).length;
        
        // Get upcoming exams (next 7 days)
        final upcomingExams = exams.where((e) => 
          e.startTime.isAfter(now) &&
          e.startTime.isBefore(now.add(const Duration(days: 7)))
        ).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
        
        setState(() {
          _stats = {
            'totalExams': exams.length,
            'activeExams': exams.where((e) => e.isActive).length,
            'totalStudents': students.length,
            'todayExams': todayExams,
            'upcomingExams': upcomingExams.take(3).toList(),
            'recentExams': exams.take(5).toList(),
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Sign out the admin and return to auth screen
  Future<void> _logout() async {
    await _firebaseService.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isTablet = screenWidth > 600 && screenWidth <= 900;
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const SizedBox.shrink(), // Empty title
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: AppColors.getPrimaryColor(context),
            ),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(
              Icons.logout_rounded,
              color: AppColors.getPrimaryColor(context),
            ),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.getPrimaryColor(context),
          child: CustomScrollView(
            slivers: [
              // Welcome Header Card
              SliverToBoxAdapter(
                child: _buildWelcomeHeader(),
              ),
              
              // Stats Cards
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingLarge,
                  vertical: AppDimensions.paddingSmall,
                ),
                sliver: SliverToBoxAdapter(
                  child: _isLoading
                      ? _buildStatsShimmer(crossAxisCount)
                      : _buildStatsGrid(crossAxisCount),
                ),
              ),
              
              // Quick Actions Section
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingLarge,
                  vertical: AppDimensions.paddingMedium,
                ),
                sliver: SliverToBoxAdapter(
                  child: _buildQuickActionsSection(isDesktop),
                ),
              ),
              
              // Upcoming Exams Section
              if (!_isLoading && _stats['upcomingExams'] != null && _stats['upcomingExams'].isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingLarge,
                    vertical: AppDimensions.paddingSmall,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _buildUpcomingExamsSection(),
                  ),
                ),
              
              // Recent Activity Section
              if (!_isLoading && _stats['recentExams'] != null && _stats['recentExams'].isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                  sliver: SliverToBoxAdapter(
                    child: _buildRecentActivitySection(),
                  ),
                ),
              
              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build welcome header with greeting and date
  Widget _buildWelcomeHeader() {
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    
    return Container(
      margin: const EdgeInsets.all(AppDimensions.paddingLarge),
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: AppStyles.bodyLarge.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _adminName,
                  style: AppStyles.headlineMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(now),
                  style: AppStyles.bodySmall.copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getGreetingIcon(now.hour),
              color: Colors.white,
              size: 48,
            ),
          ),
        ],
      ),
    );
  }

  // Build grid of statistic cards
  Widget _buildStatsGrid(int crossAxisCount) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8, 
      children: [
        _buildStatCard(
          label: 'Total Exams',
          value: _stats['totalExams'].toString(),
          icon: Icons.quiz_rounded,
          color: Colors.blue,
          subtitle: 'All time',
        ),
        _buildStatCard(
          label: 'Active Exams',
          value: _stats['activeExams'].toString(),
          icon: Icons.event_available_rounded,
          color: Colors.green,
          subtitle: 'Currently active',
        ),
        _buildStatCard(
          label: 'Total Students',
          value: _stats['totalStudents'].toString(),
          icon: Icons.people_rounded,
          color: Colors.orange,
          subtitle: 'Enrolled',
        ),
        _buildStatCard(
          label: "Today's Exams",
          value: _stats['todayExams'].toString(),
          icon: Icons.calendar_today_rounded,
          color: Colors.purple,
          subtitle: 'Scheduled',
        ),
      ],
    );
  }

  // Single statistic card widget
  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10), // Even more compact
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppColors.getTextPrimary(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.getTextSecondary(context),
              fontSize: 9,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.flash_on_rounded,
                color: AppColors.getPrimaryColor(context),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Quick Actions',
              style: AppStyles.titleMedium.copyWith(
                color: AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 3 : 1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isDesktop ? 2.2 : 2.8, 
          children: [
            _buildActionCard(
              title: 'Manage Exams',
              description: 'Create, edit, and manage exam schedules',
              icon: Icons.quiz_rounded,
              color: Colors.blue,
              stats: '${_stats['totalExams'] ?? 0} total',
              onTap: () => _navigateTo(const ManageExamsPage()),
            ),
            _buildActionCard(
              title: 'Manage Students',
              description: 'View and manage student records',
              icon: Icons.people_rounded,
              color: Colors.green,
              stats: '${_stats['totalStudents'] ?? 0} students',
              onTap: () => _navigateTo(const ManageStudentsPage()),
            ),
            _buildActionCard(
              title: 'Attendance Reports',
              description: 'View and analyze attendance records',
              icon: Icons.assessment_rounded,
              color: Colors.orange,
              stats: 'View reports',
              onTap: () => _navigateTo(const AttendanceRecordsPage()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String stats,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.9),
                color.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8), 
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: Colors.white, size: 22), 
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, 
                            vertical: 4, 
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16), 
                          ),
                          child: Text(
                            stats,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10, 
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8), // Add spacing
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2), 
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11, 
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildUpcomingExamsSection() {
    final upcomingExams = _stats['upcomingExams'] as List;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.upcoming_rounded,
                color: Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Upcoming Exams',
              style: AppStyles.titleMedium.copyWith(
                color: AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _navigateTo(const ManageExamsPage()),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.getPrimaryColor(context),
              ),
              child: const Text('View All →'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...upcomingExams.map((exam) => _buildExamTile(exam, isUpcoming: true)),
      ],
    );
  }

  Widget _buildRecentActivitySection() {
    final recentExams = _stats['recentExams'] as List? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Colors.purple,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Recent Exams',
              style: AppStyles.titleMedium.copyWith(
                color: AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...recentExams.map((exam) => _buildExamTile(exam, isUpcoming: false)),
      ],
    );
  }

  Widget _buildExamTile(Exam exam, {required bool isUpcoming}) {
    final statusColor = isUpcoming ? Colors.orange : 
                       (exam.isActive ? Colors.green : Colors.grey);
    final statusText = isUpcoming ? 'Upcoming' : 
                      (exam.isActive ? 'Active' : 'Inactive');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isUpcoming ? Icons.schedule_rounded : Icons.event_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.subjectName,
                  style: AppStyles.bodyMedium.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: AppColors.getTextSecondary(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      exam.formattedDate,
                      style: AppStyles.bodySmall.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.location_on_rounded,
                      size: 12,
                      color: AppColors.getTextSecondary(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
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
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsShimmer(int crossAxisCount) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: List.generate(4, (index) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 50,
                    height: 30,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: 100,
                height: 16,
                color: Colors.grey,
              ),
              const SizedBox(height: 4),
              Container(
                width: 80,
                height: 12,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      )),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  IconData _getGreetingIcon(int hour) {
    if (hour < 12) return Icons.wb_sunny_rounded;
    if (hour < 17) return Icons.wb_twilight_rounded;
    return Icons.nightlight_round_rounded;
  }

  void _navigateTo(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }
}