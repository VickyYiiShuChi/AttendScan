// lib/screens/admin/manage_exams_page.dart
import 'package:flutter/material.dart';
import 'package:attend_scan/constants/app_colors.dart';
import 'package:attend_scan/constants/app_styles.dart';
import 'package:attend_scan/constants/app_dimensions.dart';
import 'package:attend_scan/services/firebase_service.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

// Admin page to manage exams: list, filter, sort, and create exams
class ManageExamsPage extends StatefulWidget {
  const ManageExamsPage({super.key});

  @override
  State<ManageExamsPage> createState() => _ManageExamsPageState();
}

class _ManageExamsPageState extends State<ManageExamsPage> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Exam> _allExams = [];
  List<Exam> _filteredExams = [];
  List<Map<String, dynamic>> _allStudents = [];
  bool _isLoading = true;
  String _selectedFilter = 'upcoming';
  String _searchQuery = '';
  String? _errorMessage;
  String _sortBy = 'date'; // 'date', 'subject', 'students'
  bool _sortAscending = false; // false = newest to oldest, true = oldest to newest
  final TextEditingController _searchController = TextEditingController();

  // Load exams and students on initialization
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Dispose controllers when leaving the page
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetch exams and student lists from Firebase
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final user = await _firebaseService.getCurrentUser();
      if (user != null && user.isAdmin) {
        final examsResult = await _firebaseService.getAllExams(adminUid: user.uid);
        final studentsResult = await _firebaseService.getAllStudents(user.uid);
        
        List<Map<String, dynamic>> students = [];
        if (studentsResult['success'] == true) {
          final studentsData = studentsResult['students'];
          if (studentsData is List) {
            students = studentsData.map((item) {
              if (item is Map<String, dynamic>) {
                return item;
              }
              return <String, dynamic>{};
            }).where((item) => item.isNotEmpty).toList();
          }
        }
        
        List<Exam> exams = [];
        if (examsResult['success'] == true) {
          final examsData = examsResult['exams'];
          if (examsData is List) {
            exams = examsData.whereType<Exam>().toList();
          }
        }
        
        setState(() {
          _allExams = exams;
          _allStudents = students;
          _applyFilter();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Apply selected filter and search term to exams
  void _applyFilter() {
    final now = DateTime.now();
    
    List<Exam> filtered = List.from(_allExams);
    
    switch (_selectedFilter) {
      case 'upcoming':
        filtered = filtered.where((e) => e.startTime.isAfter(now)).toList();
        break;
      case 'past':
        filtered = filtered.where((e) => e.endTime.isBefore(now)).toList();
        break;
      case 'active':
        filtered = filtered.where((e) => e.isActive).toList();
        break;
      case 'inactive':
        filtered = filtered.where((e) => !e.isActive).toList();
        break;
      case 'all':
      default:
        break;
    }
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((e) =>
        e.subjectName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        e.location.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    _applySorting(filtered);
  }

  // Sort filtered exams according to selected field
  void _applySorting(List<Exam> filtered) {
    switch (_sortBy) {
      case 'date':
        filtered.sort((a, b) => _sortAscending 
            ? a.startTime.compareTo(b.startTime)
            : b.startTime.compareTo(a.startTime));
        break;
      case 'subject':
        filtered.sort((a, b) => _sortAscending
            ? a.subjectName.compareTo(b.subjectName)
            : b.subjectName.compareTo(a.subjectName));
        break;
      case 'students':
        filtered.sort((a, b) => _sortAscending
            ? a.allowedClasses.length.compareTo(b.allowedClasses.length)
            : b.allowedClasses.length.compareTo(a.allowedClasses.length));
        break;
    }
    
    setState(() {
      _filteredExams = filtered;
    });
  }

  // Toggle sorting field and direction then reapply filters
  void _toggleSort(String sortBy) {
    if (_sortBy == sortBy) {
      setState(() {
        _sortAscending = !_sortAscending;
      });
    } else {
      setState(() {
        _sortBy = sortBy;
        _sortAscending = false; // Default to newest first
      });
    }
    _applyFilter();
  }

  // Resolve student full name by ID
  String _getStudentName(String studentId) {
    try {
      final student = _allStudents.firstWhere(
        (s) => s['studentId'] == studentId,
        orElse: () => <String, dynamic>{},
      );
      return student['fullName']?.toString() ?? 'Unknown Student';
    } catch (e) {
      return 'Unknown Student';
    }
  }

  // Format a DateTime for display
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Choose a color representing exam status (upcoming/ongoing/ended)
  Color _getExamStatusColor(Exam exam) {
    if (!exam.isActive) return Colors.grey;
    final now = DateTime.now();
    if (exam.startTime.isAfter(now)) return Colors.blue;
    if (exam.endTime.isBefore(now)) return Colors.grey;
    return Colors.orange;
  }

  // Return a human-friendly exam status label
  String _getExamStatusText(Exam exam) {
    if (!exam.isActive) return 'Inactive';
    final now = DateTime.now();
    if (exam.startTime.isAfter(now)) return 'Upcoming';
    if (exam.endTime.isBefore(now)) return 'Ended';
    return 'Ongoing';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'EXAM MANAGEMENT',
          style: AppStyles.titleLarge.copyWith(
            color: AppColors.getPrimaryColor(context),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_rounded,
              color: AppColors.getPrimaryColor(context),
            ),
            onPressed: _showCreateExamDialog,
            tooltip: 'Create New Exam',
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: AppColors.getPrimaryColor(context),
            ),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.getPrimaryColor(context),
          child: CustomScrollView(
            slivers: [
              // Header Stats Card (like attendance report)
              SliverToBoxAdapter(
                child: _buildHeaderStatsCard(),
              ),
              
              // Search and Filter Bar
              SliverToBoxAdapter(
                child: _buildSearchFilterBar(context),
              ),

              // Sort Bar (redesigned like attendance report)
              SliverToBoxAdapter(
                child: _buildSortBar(context),
              ),

              // Exams List
              if (_isLoading)
                _buildShimmerList()
              else if (_errorMessage != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: SingleChildScrollView(
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
                                onPressed: _loadData,
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
                  ),
                )
              else if (_filteredExams.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(),
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
                        final exam = _filteredExams[index];
                        final statusColor = _getExamStatusColor(exam);
                        final statusText = _getExamStatusText(exam);
                        
                        return _buildExamCard(
                          context,
                          exam,
                          statusText,
                          statusColor,
                          index,
                        );
                      },
                      childCount: _filteredExams.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStatsCard() {
    final now = DateTime.now();
    final upcomingCount = _allExams.where((e) => e.startTime.isAfter(now)).length;
    final ongoingCount = _allExams.where((e) => 
        e.isActive && 
        e.startTime.isBefore(now) && 
        e.endTime.isAfter(now)
    ).length;
    final totalStudents = _allExams.fold<int>(0, (sum, e) => sum + e.allowedClasses.length);
    
    return Container(
      margin: const EdgeInsets.all(AppDimensions.paddingLarge),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
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
                      'Exam Overview',
                      style: AppStyles.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total ${_allExams.length} exams scheduled',
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
          const SizedBox(height: 20),
          
          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  label: 'Upcoming',
                  value: upcomingCount.toString(),
                  icon: Icons.schedule_rounded,
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  label: 'Ongoing',
                  value: ongoingCount.toString(),
                  icon: Icons.play_circle_rounded,
                  color: Colors.orange,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  label: 'Students',
                  value: totalStudents.toString(),
                  icon: Icons.people_rounded,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppStyles.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: AppStyles.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilterBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
        vertical: AppDimensions.paddingSmall,
      ),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          // Search Field
          Container(
            decoration: BoxDecoration(
              color: AppColors.getInputBackground(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _searchQuery = value;
                _applyFilter();
              },
              decoration: InputDecoration(
                hintText: 'Search exams by subject or location...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Upcoming', 'upcoming'),
                const SizedBox(width: 8),
                _buildFilterChip('Past', 'past'),
                const SizedBox(width: 8),
                _buildFilterChip('Active', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('Inactive', 'inactive'),
                const SizedBox(width: 8),
                _buildFilterChip('All', 'all'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
          _applyFilter();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          color: isSelected ? null : AppColors.getInputBackground(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? Colors.white.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppStyles.bodyMedium.copyWith(
              color: isSelected 
                  ? Colors.white
                  : AppColors.getTextSecondary(context),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
        vertical: AppDimensions.paddingSmall,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.getPrimaryColor(context).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Sort by Date
          GestureDetector(
            onTap: () => _toggleSort('date'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _sortBy == 'date' 
                    ? AppColors.getPrimaryColor(context).withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Date',
                    style: AppStyles.bodySmall.copyWith(
                      color: _sortBy == 'date'
                          ? AppColors.getPrimaryColor(context)
                          : AppColors.getTextSecondary(context),
                      fontWeight: _sortBy == 'date' ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (_sortBy == 'date')
                    Icon(
                      _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: AppColors.getPrimaryColor(context),
                      size: 14,
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Sort by Subject
          GestureDetector(
            onTap: () => _toggleSort('subject'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _sortBy == 'subject' 
                    ? AppColors.getPrimaryColor(context).withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Subject',
                    style: AppStyles.bodySmall.copyWith(
                      color: _sortBy == 'subject'
                          ? AppColors.getPrimaryColor(context)
                          : AppColors.getTextSecondary(context),
                      fontWeight: _sortBy == 'subject' ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (_sortBy == 'subject')
                    Icon(
                      _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: AppColors.getPrimaryColor(context),
                      size: 14,
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Sort by Students
          GestureDetector(
            onTap: () => _toggleSort('students'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _sortBy == 'students' 
                    ? AppColors.getPrimaryColor(context).withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Students',
                    style: AppStyles.bodySmall.copyWith(
                      color: _sortBy == 'students'
                          ? AppColors.getPrimaryColor(context)
                          : AppColors.getTextSecondary(context),
                      fontWeight: _sortBy == 'students' ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (_sortBy == 'students')
                    Icon(
                      _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: AppColors.getPrimaryColor(context),
                      size: 14,
                    ),
                ],
              ),
            ),
          ),
          
          const Spacer(),
          
          Text(
            '${_filteredExams.length} exams',
            style: AppStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  SliverList _buildShimmerList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingLarge,
              vertical: 4,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 150,
                          height: 16,
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
          );
        },
        childCount: 3,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context).withOpacity(0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.getPrimaryColor(context).withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.event_busy_rounded,
                      size: 40,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Exams Found',
                    style: AppStyles.titleLarge.copyWith(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Click the + button to create a new exam',
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
      ),
    );
  }

  Widget _buildExamCard(
    BuildContext context, 
    Exam exam, 
    String status,
    Color statusColor,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showExamOptions(exam),
          borderRadius: BorderRadius.circular(18),
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
            child: Column(
              children: [
                Row(
                  children: [
                    // Icon with status indicator
                    Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                statusColor.withOpacity(0.2),
                                statusColor.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: statusColor.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              exam.isActive ? Icons.event_available_rounded : Icons.event_busy_rounded,
                              color: statusColor,
                              size: 28,
                            ),
                          ),
                        ),
                        // Status dot
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: exam.isActive ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Exam Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  exam.subjectName,
                                  style: AppStyles.titleMedium.copyWith(
                                    color: AppColors.getTextPrimary(context),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status,
                                  style: AppStyles.bodySmall.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 14,
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
                          
                          const SizedBox(height: 4),
                          
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: AppColors.getTextSecondary(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('dd/MM/yyyy').format(exam.startTime),
                                style: AppStyles.bodySmall.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: AppColors.getTextSecondary(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${exam.startTime.hour}:${exam.startTime.minute.toString().padLeft(2, '0')}',
                                style: AppStyles.bodySmall.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Students Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.getBackgroundColor(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people_rounded,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${exam.allowedClasses.length} Students Enrolled',
                        style: AppStyles.bodyMedium.copyWith(
                          color: AppColors.getTextPrimary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.getTextSecondary(context),
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
  }

  void _showExamOptions(Exam exam) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          decoration: BoxDecoration(
            color: AppColors.getCardBackground(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
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
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.menu_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        exam.subjectName,
                        style: AppStyles.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.visibility_rounded, color: Colors.blue),
                  ),
                  title: const Text('View Details'),
                  subtitle: Text('See complete exam information'),
                  onTap: () {
                    Navigator.pop(context);
                    _showExamDetails(exam);
                  },
                ),
                
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.green),
                  ),
                  title: const Text('Edit Exam'),
                  subtitle: Text('Modify exam details'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditExamDialog(exam);
                  },
                ),
                
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_rounded, color: Colors.red),
                  ),
                  title: const Text('Delete Exam'),
                  subtitle: Text('Remove this exam permanently'),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(exam);
                  },
                ),
                
                const SizedBox(height: 16),
                
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExamDetails(Exam exam) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header with gradient
                Container(
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
                        child: Icon(
                          Icons.info_rounded,
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
                              'Exam Details',
                              style: AppStyles.titleLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Complete examination information',
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
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Card
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
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _getExamStatusColor(exam).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  exam.isActive 
                                      ? Icons.event_available_rounded 
                                      : Icons.event_busy_rounded,
                                  color: _getExamStatusColor(exam),
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Status',
                                      style: AppStyles.bodySmall.copyWith(
                                        color: AppColors.getTextSecondary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: _getExamStatusColor(exam),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _getExamStatusText(exam),
                                          style: AppStyles.titleSmall.copyWith(
                                            color: _getExamStatusColor(exam),
                                            fontWeight: FontWeight.w600,
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
                        
                        const SizedBox(height: 20),
                        
                        // Subject Card
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.school_rounded,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Subject Information',
                                    style: AppStyles.titleMedium.copyWith(
                                      color: AppColors.getTextPrimary(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Subject Name
                              _buildDetailRow(
                                icon: Icons.book_rounded,
                                label: 'Subject Name',
                                value: exam.subjectName,
                                color: Colors.blue,
                              ),
                              
                              // Location
                              _buildDetailRow(
                                icon: Icons.location_on_rounded,
                                label: 'Location',
                                value: exam.location,
                                color: Colors.orange,
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Date & Time Card
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
                                      Icons.access_time_rounded,
                                      color: Colors.purple,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Schedule',
                                    style: AppStyles.titleMedium.copyWith(
                                      color: AppColors.getTextPrimary(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Start Date & Time
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.getBackgroundColor(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.play_circle_rounded,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Start Time',
                                            style: AppStyles.bodySmall.copyWith(
                                              color: AppColors.getTextSecondary(context),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat('EEEE, dd MMMM yyyy').format(exam.startTime),
                                            style: AppStyles.bodyMedium.copyWith(
                                              color: AppColors.getTextPrimary(context),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            DateFormat('h:mm a').format(exam.startTime),
                                            style: AppStyles.titleSmall.copyWith(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // End Date & Time
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.getBackgroundColor(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.stop_circle_rounded,
                                        color: Colors.orange,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'End Time',
                                            style: AppStyles.bodySmall.copyWith(
                                              color: AppColors.getTextSecondary(context),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat('EEEE, dd MMMM yyyy').format(exam.endTime),
                                            style: AppStyles.bodyMedium.copyWith(
                                              color: AppColors.getTextPrimary(context),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            DateFormat('h:mm a').format(exam.endTime),
                                            style: AppStyles.titleSmall.copyWith(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Duration
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.timer_rounded,
                                      color: Colors.green,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Duration: ${exam.endTime.difference(exam.startTime).inHours}h ${exam.endTime.difference(exam.startTime).inMinutes % 60}m',
                                      style: AppStyles.bodySmall.copyWith(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Students Card
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.people_rounded,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Enrolled Students (${exam.allowedClasses.length})',
                                      style: AppStyles.titleMedium.copyWith(
                                        color: AppColors.getTextPrimary(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Students List in same style as edit dialog
                              Container(
                                height: 300,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.getTextHint(context).withOpacity(0.2),
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: exam.allowedClasses.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.people_outline_rounded,
                                              size: 50,
                                              color: Colors.grey.withOpacity(0.5),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No students enrolled',
                                              style: AppStyles.bodyMedium.copyWith(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: exam.allowedClasses.length,
                                        separatorBuilder: (context, index) => Divider(
                                          height: 1,
                                          color: Colors.grey.withOpacity(0.2),
                                        ),
                                        itemBuilder: (context, index) {
                                          final studentId = exam.allowedClasses[index];
                                          final student = _allStudents.firstWhere(
                                            (s) => s['studentId'] == studentId,
                                            orElse: () => <String, dynamic>{},
                                          );
                                          
                                          final fullName = student['fullName']?.toString() ?? 'Unknown Student';
                                          final faculty = student['faculty']?.toString() ?? '';
                                          final programme = student['programme']?.toString() ?? '';
                                          
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            child: Row(
                                              children: [
                                                // Student Avatar (same as edit dialog)
                                                Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        AppColors.getPrimaryColor(context).withOpacity(0.8),
                                                        AppColors.getSecondaryColor(context).withOpacity(0.8),
                                                      ],
                                                    ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                
                                                const SizedBox(width: 12),
                                                
                                                // Student Info
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        fullName,
                                                        style: AppStyles.bodyMedium.copyWith(
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      
                                                      // Student ID with icon
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.badge_rounded,
                                                            size: 12,
                                                            color: Colors.grey,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Expanded(
                                                            child: Text(
                                                              studentId,
                                                              style: AppStyles.bodySmall.copyWith(
                                                                color: Colors.grey,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      
                                                      // Faculty (if available)
                                                      if (faculty.isNotEmpty) ...[
                                                        const SizedBox(height: 2),
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons.school_rounded,
                                                              size: 12,
                                                              color: Colors.grey,
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Expanded(
                                                              child: Text(
                                                                faculty,
                                                                style: AppStyles.bodySmall.copyWith(
                                                                  color: Colors.grey,
                                                                  fontSize: 11,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                      
                                                      // Programme (if available)
                                                      if (programme.isNotEmpty) ...[
                                                        const SizedBox(height: 2),
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons.book_rounded,
                                                              size: 12,
                                                              color: Colors.grey,
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Expanded(
                                                              child: Text(
                                                                programme,
                                                                style: AppStyles.bodySmall.copyWith(
                                                                  color: Colors.grey,
                                                                  fontSize: 11,
                                                                ),
                                                                maxLines: 1,
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
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Footer Buttons
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
                          onPressed: () => Navigator.pop(context),
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
                            'Close',
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
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditExamDialog(exam);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.getPrimaryColor(context),
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
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Edit Exam',
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
  }

  void _showCreateExamDialog() {
    _showExamDialog();
  }

  void _showEditExamDialog(Exam exam) {
    _showExamDialog(exam: exam);
  }

  Future<void> _showExamDialog({Exam? exam}) async {
    final formKey = GlobalKey<FormState>();
    final subjectController = TextEditingController(text: exam?.subjectName ?? '');
    final locationController = TextEditingController(text: exam?.location ?? '');
    
    DateTime? startDate = exam?.startTime;
    DateTime? endDate = exam?.endTime;
    TimeOfDay? startTime = exam != null 
        ? TimeOfDay.fromDateTime(exam.startTime)
        : null;
    TimeOfDay? endTime = exam != null 
        ? TimeOfDay.fromDateTime(exam.endTime)
        : null;
    
    List<String> selectedStudents = List.from(exam?.allowedClasses ?? []);
    bool isActive = exam?.isActive ?? true;
    bool isLoading = false;

    final isEditing = exam != null;

    // Filter-related state variables
    String? selectedFacultyFilter;
    String? selectedProgrammeFilter;
    String studentSearchQuery = '';
    
    // Get all available faculties
    final allFaculties = _allStudents
        .map((s) => s['faculty']?.toString() ?? '')
        .where((f) => f.isNotEmpty)
        .toSet()
        .toList()..sort();
    
    // Get available programmes based on selected faculty
    List<String> getAvailableProgrammes() {
      if (selectedFacultyFilter == null) return [];
      return _allStudents
          .where((s) => s['faculty'] == selectedFacultyFilter)
          .map((s) => s['programme']?.toString() ?? '')
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList()..sort();
    }

    // Get filtered students list
    List<Map<String, dynamic>> getFilteredStudents() {
      return _allStudents.where((student) {
        // Faculty filter
        if (selectedFacultyFilter != null && 
            student['faculty'] != selectedFacultyFilter) {
          return false;
        }
        
        // Programme filter
        if (selectedProgrammeFilter != null && 
            student['programme'] != selectedProgrammeFilter) {
          return false;
        }
        
        // Search query
        if (studentSearchQuery.isNotEmpty) {
          final name = student['fullName']?.toString().toLowerCase() ?? '';
          final id = student['studentId']?.toString().toLowerCase() ?? '';
          final query = studentSearchQuery.toLowerCase();
          if (!name.contains(query) && !id.contains(query)) {
            return false;
          }
        }
        
        return true;
      }).toList();
    }

    if (!isEditing) {
      final now = DateTime.now();
      startDate = now;
      endDate = now.add(const Duration(hours: 2));
      startTime = TimeOfDay.fromDateTime(now);
      endTime = TimeOfDay.fromDateTime(now.add(const Duration(hours: 2)));
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final filteredStudents = getFilteredStudents();
            
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.getCardBackground(context),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header with gradient
                    Container(
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
                            child: Icon(
                              isEditing ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
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
                                  isEditing ? 'Edit Exam' : 'Create New Exam',
                                  style: AppStyles.titleLarge.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isEditing 
                                      ? 'Update exam details and settings'
                                      : 'Set up a new examination',
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
                    
                    // Form Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Exam Details Card
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
                                    // Subject Name
                                    _buildModernTextField(
                                      context: context,
                                      controller: subjectController,
                                      label: 'Subject Name',
                                      icon: Icons.school_rounded,
                                      color: AppColors.getPrimaryColor(context),
                                    ),
                                    
                                    const SizedBox(height: 20),
                                    
                                    // Location
                                    _buildModernTextField(
                                      context: context,
                                      controller: locationController,
                                      label: 'Location',
                                      icon: Icons.location_on_rounded,
                                      color: AppColors.getSecondaryColor(context),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Date & Time Card
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.access_time_rounded,
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Schedule',
                                          style: AppStyles.titleMedium.copyWith(
                                            color: AppColors.getTextPrimary(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 20),
                                    
                                    // Start Date & Time
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDateTimePicker(
                                            context: context,
                                            label: 'Start Date',
                                            value: startDate != null
                                                ? DateFormat('dd/MM/yyyy').format(startDate!)
                                                : null,
                                            icon: Icons.calendar_today_rounded,
                                            color: Colors.blue,
                                            onTap: () async {
                                              final date = await showDatePicker(
                                                context: context,
                                                initialDate: startDate ?? DateTime.now(),
                                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                              );
                                              if (date != null) {
                                                setState(() => startDate = date);
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildDateTimePicker(
                                            context: context,
                                            label: 'Start Time',
                                            value: startTime != null
                                                ? startTime!.format(context)
                                                : null,
                                            icon: Icons.access_time_rounded,
                                            color: Colors.blue,
                                            onTap: () async {
                                              final time = await showTimePicker(
                                                context: context,
                                                initialTime: startTime ?? TimeOfDay.now(),
                                              );
                                              if (time != null) {
                                                setState(() => startTime = time);
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // End Date & Time
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDateTimePicker(
                                            context: context,
                                            label: 'End Date',
                                            value: endDate != null
                                                ? DateFormat('dd/MM/yyyy').format(endDate!)
                                                : null,
                                            icon: Icons.calendar_today_rounded,
                                            color: Colors.orange,
                                            onTap: () async {
                                              final date = await showDatePicker(
                                                context: context,
                                                initialDate: endDate ?? startDate ?? DateTime.now(),
                                                firstDate: startDate ?? DateTime.now(),
                                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                              );
                                              if (date != null) {
                                                setState(() => endDate = date);
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildDateTimePicker(
                                            context: context,
                                            label: 'End Time',
                                            value: endTime != null
                                                ? endTime!.format(context)
                                                : null,
                                            icon: Icons.access_time_rounded,
                                            color: Colors.orange,
                                            onTap: () async {
                                              final time = await showTimePicker(
                                                context: context,
                                                initialTime: endTime ?? startTime ?? TimeOfDay.now(),
                                              );
                                              if (time != null) {
                                                setState(() => endTime = time);
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 20),
                                    
                                    // Active Status
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive 
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isActive 
                                              ? Colors.green.withOpacity(0.3)
                                              : Colors.grey.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isActive 
                                                ? Icons.toggle_on_rounded 
                                                : Icons.toggle_off_rounded,
                                            color: isActive ? Colors.green : Colors.grey,
                                            size: 30,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Exam Status',
                                              style: AppStyles.bodyMedium.copyWith(
                                                color: AppColors.getTextPrimary(context),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            isActive ? 'Active' : 'Inactive',
                                            style: AppStyles.bodySmall.copyWith(
                                              color: isActive ? Colors.green : Colors.grey,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Switch(
                                            value: isActive,
                                            onChanged: (value) {
                                              setState(() => isActive = value);
                                            },
                                            activeColor: Colors.green,
                                            activeTrackColor: Colors.green.withOpacity(0.3),
                                            inactiveThumbColor: Colors.grey,
                                            inactiveTrackColor: Colors.grey.withOpacity(0.3),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Student Selection Card
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
                                            Icons.people_rounded,
                                            color: Colors.purple,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Select Students',
                                          style: AppStyles.titleMedium.copyWith(
                                            color: AppColors.getTextPrimary(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 20),
                                    
                                    // Faculty Filter
                                    _buildModernDropdown(
                                      context: context,
                                      value: selectedFacultyFilter,
                                      hint: 'Filter by Faculty',
                                      icon: Icons.school_rounded,
                                      color: Colors.orange,
                                      items: [
                                        'All Faculties',
                                        ...allFaculties,
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          selectedFacultyFilter = value == 'All Faculties' ? null : value;
                                          selectedProgrammeFilter = null; // Reset programme filter
                                        });
                                      },
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // Programme Filter
                                    _buildModernDropdown(
                                      context: context,
                                      value: selectedProgrammeFilter,
                                      hint: selectedFacultyFilter == null
                                          ? 'Select Faculty First'
                                          : 'Filter by Programme',
                                      icon: Icons.book_rounded,
                                      color: selectedFacultyFilter == null ? Colors.grey : Colors.green,
                                      items: [
                                        'All Programmes',
                                        ...getAvailableProgrammes(),
                                      ],
                                      enabled: selectedFacultyFilter != null,
                                      onChanged: selectedFacultyFilter == null
                                          ? null
                                          : (value) {
                                              setState(() {
                                                selectedProgrammeFilter = value == 'All Programmes' ? null : value;
                                              });
                                            },
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // Search Field
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.getPrimaryColor(context).withOpacity(0.2),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: TextField(
                                        onChanged: (value) {
                                          setState(() {
                                            studentSearchQuery = value;
                                          });
                                        },
                                        decoration: InputDecoration(
                                          hintText: 'Search by name or student ID...',
                                          hintStyle: TextStyle(
                                            color: AppColors.getTextHint(context).withOpacity(0.7),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          prefixIcon: Container(
                                            margin: const EdgeInsets.all(8),
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              Icons.search_rounded,
                                              color: AppColors.getPrimaryColor(context),
                                              size: 20,
                                            ),
                                          ),
                                          suffixIcon: studentSearchQuery.isNotEmpty
                                              ? Container(
                                                  margin: const EdgeInsets.all(8),
                                                  child: IconButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        studentSearchQuery = '';
                                                      });
                                                    },
                                                    icon: Icon(
                                                      Icons.close_rounded,
                                                      color: AppColors.getTextSecondary(context),
                                                      size: 18,
                                                    ),
                                                    splashRadius: 20,
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                )
                                              : null,
                                          filled: false,
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                        ),
                                        style: AppStyles.bodyLarge.copyWith(
                                          color: AppColors.getTextPrimary(context),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 12),
                                    
                                    // Results count
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${filteredStudents.length} students found',
                                            style: AppStyles.bodySmall.copyWith(
                                              color: AppColors.getPrimaryColor(context),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (selectedStudents.isNotEmpty)
                                          TextButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                selectedStudents.clear();
                                              });
                                            },
                                            icon: const Icon(Icons.clear_all_rounded, size: 18),
                                            label: const Text('Clear All'),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                          ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // Students List
                                    Container(
                                      height: 300,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppColors.getTextHint(context).withOpacity(0.2),
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: _allStudents.isEmpty
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.people_outline_rounded,
                                                    size: 50,
                                                    color: Colors.grey.withOpacity(0.5),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'No students available',
                                                    style: AppStyles.bodyMedium.copyWith(
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : filteredStudents.isEmpty
                                              ? Center(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.search_off_rounded,
                                                        size: 50,
                                                        color: Colors.grey.withOpacity(0.5),
                                                      ),
                                                      const SizedBox(height: 12),
                                                      Text(
                                                        'No students match filters',
                                                        style: AppStyles.bodyMedium.copyWith(
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      ElevatedButton(
                                                        onPressed: () {
                                                          setState(() {
                                                            selectedFacultyFilter = null;
                                                            selectedProgrammeFilter = null;
                                                            studentSearchQuery = '';
                                                          });
                                                        },
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: AppColors.getPrimaryColor(context),
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 20,
                                                            vertical: 10,
                                                          ),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(20),
                                                          ),
                                                        ),
                                                        child: const Text('Clear Filters'),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : ListView.separated(
                                                  itemCount: filteredStudents.length,
                                                  separatorBuilder: (context, index) => Divider(
                                                    height: 1,
                                                    color: Colors.grey.withOpacity(0.2),
                                                  ),
                                                  itemBuilder: (context, index) {
                                                    final student = filteredStudents[index];
                                                    final studentId = student['studentId']?.toString() ?? '';
                                                    final fullName = student['fullName']?.toString() ?? 'Unknown';
                                                    final faculty = student['faculty']?.toString() ?? '';
                                                    final programme = student['programme']?.toString() ?? '';
                                                    final isSelected = selectedStudents.contains(studentId);
                                                    
                                                    return CheckboxListTile(
                                                      contentPadding: const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                      title: Text(
                                                        fullName,
                                                        style: AppStyles.bodyMedium.copyWith(
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      subtitle: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Icon(
                                                                Icons.badge_rounded,
                                                                size: 12,
                                                                color: Colors.grey,
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Expanded(
                                                                child: Text(
                                                                  studentId,
                                                                  style: AppStyles.bodySmall.copyWith(
                                                                    color: Colors.grey,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          if (faculty.isNotEmpty) ...[
                                                            const SizedBox(height: 2),
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.school_rounded,
                                                                  size: 12,
                                                                  color: Colors.grey,
                                                                ),
                                                                const SizedBox(width: 4),
                                                                Expanded(
                                                                  child: Text(
                                                                    faculty,
                                                                    style: AppStyles.bodySmall.copyWith(
                                                                      color: Colors.grey,
                                                                      fontSize: 11,
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                          if (programme.isNotEmpty) ...[
                                                            const SizedBox(height: 2),
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.book_rounded,
                                                                  size: 12,
                                                                  color: Colors.grey,
                                                                ),
                                                                const SizedBox(width: 4),
                                                                Expanded(
                                                                  child: Text(
                                                                    programme,
                                                                    style: AppStyles.bodySmall.copyWith(
                                                                      color: Colors.grey,
                                                                      fontSize: 11,
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      value: isSelected,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          if (value == true) {
                                                            selectedStudents.add(studentId);
                                                          } else {
                                                            selectedStudents.remove(studentId);
                                                          }
                                                        });
                                                      },
                                                      secondary: Container(
                                                        width: 48,
                                                        height: 48,
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              AppColors.getPrimaryColor(context).withOpacity(0.8),
                                                              AppColors.getSecondaryColor(context).withOpacity(0.8),
                                                            ],
                                                          ),
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 18,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
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
                    
                    // Footer Buttons
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
                              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
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
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      if (formKey.currentState!.validate()) {
                                        if (startDate == null || startTime == null) {
                                          _showSnackBar('Please select start date and time', isError: true);
                                          return;
                                        }
                                        if (endDate == null || endTime == null) {
                                          _showSnackBar('Please select end date and time', isError: true);
                                          return;
                                        }
                                        if (selectedStudents.isEmpty) {
                                          _showSnackBar('Please select at least one student', isError: true);
                                          return;
                                        }
                                        
                                        setState(() => isLoading = true);
                                        
                                        try {
                                          final startDateTime = DateTime(
                                            startDate!.year,
                                            startDate!.month,
                                            startDate!.day,
                                            startTime!.hour,
                                            startTime!.minute,
                                          );
                                          final endDateTime = DateTime(
                                            endDate!.year,
                                            endDate!.month,
                                            endDate!.day,
                                            endTime!.hour,
                                            endTime!.minute,
                                          );
                                          
                                          if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
                                            _showSnackBar('End time must be after start time', isError: true);
                                            setState(() => isLoading = false);
                                            return;
                                          }
                                          
                                          final user = await _firebaseService.getCurrentUser();
                                          if (user != null) {
                                            Map<String, dynamic> result;
                                            
                                            if (isEditing) {
                                              result = await _firebaseService.updateExam(
                                                examId: exam!.examId,
                                                subjectName: subjectController.text,
                                                location: locationController.text,
                                                startTime: startDateTime,
                                                endTime: endDateTime,
                                                allowedClasses: selectedStudents,
                                                isActive: isActive,
                                                adminUid: user.uid,
                                              );
                                            } else {
                                              result = await _firebaseService.createExam(
                                                subjectName: subjectController.text,
                                                location: locationController.text,
                                                startTime: startDateTime,
                                                endTime: endDateTime,
                                                allowedClasses: selectedStudents,
                                                adminUid: user.uid,
                                              );
                                            }
                                            
                                            if (result['success'] == true) {
                                              Navigator.pop(dialogContext);
                                              _showSnackBar(
                                                isEditing 
                                                    ? 'Exam updated successfully!' 
                                                    : 'Exam created successfully!'
                                              );
                                              _loadData();
                                            } else {
                                              _showSnackBar(
                                                result['message']?.toString() ?? 'Operation failed', 
                                                isError: true
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          _showSnackBar('Error: $e', isError: true);
                                        } finally {
                                          setState(() => isLoading = false);
                                        }
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
                              child: isLoading
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
                                        Icon(
                                          isEditing ? Icons.update_rounded : Icons.add_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isEditing ? 'Update Exam' : 'Create Exam',
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
  }

  Widget _buildDateTimePicker({
    required BuildContext context,
    required String label,
    required String? value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.getBackgroundColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.getTextHint(context).withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    value ?? 'Select',
                    style: AppStyles.bodyMedium.copyWith(
                      color: value != null
                          ? AppColors.getTextPrimary(context)
                          : AppColors.getTextHint(context),
                      fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required BuildContext context,
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
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildModernDropdown({
    required BuildContext context,
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
        hint: Padding(
          padding: const EdgeInsets.only(left: 12),
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
            value: item == 'All Faculties' || item == 'All Programmes' ? null : item,
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

  void _showDeleteConfirmation(Exam exam) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 320, vertical:36),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Red warning header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Warning icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_forever_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Title
                      Text(
                        'Delete Exam',
                        style: AppStyles.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Exam name
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.getPrimaryColor(context).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.getPrimaryColor(context).withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'You are about to delete:',
                              style: AppStyles.bodySmall.copyWith(
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              exam.subjectName,
                              style: AppStyles.titleMedium.copyWith(
                                color: AppColors.getTextPrimary(context),
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              exam.location,
                              style: AppStyles.bodyMedium.copyWith(
                                color: AppColors.getTextSecondary(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Warning message
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'This action cannot be undone!',
                                    style: AppStyles.bodyMedium.copyWith(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'All attendance records for this exam will also be deleted.',
                                    style: AppStyles.bodySmall.copyWith(
                                      color: Colors.red.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Statistics
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.getBackgroundColor(context).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.people_rounded,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Students',
                                    style: AppStyles.bodySmall.copyWith(
                                      color: AppColors.getTextSecondary(context),
                                    ),
                                  ),
                                  Text(
                                    exam.allowedClasses.length.toString(),
                                    style: AppStyles.titleSmall.copyWith(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.getBackgroundColor(context).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Date',
                                    style: AppStyles.bodySmall.copyWith(
                                      color: AppColors.getTextSecondary(context),
                                    ),
                                  ),
                                  Text(
                                    DateFormat('dd/MM').format(exam.startTime),
                                    style: AppStyles.titleSmall.copyWith(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                          child: Text(
                            'CANCEL',
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
                          onPressed: () async {
                            Navigator.pop(context); // Close dialog
                            
                            setState(() {
                              _isLoading = true;
                            });
                            
                            try {
                              final user = await _firebaseService.getCurrentUser();
                              if (user != null && user.isAdmin) {
                                // Show deleting SnackBar
                                if (!mounted) return;
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text('Deleting exam...'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.orange,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                                
                                await _firebaseService.deleteExam(exam.examId, user.uid);
                                
                                setState(() {
                                  _allExams.removeWhere((e) => e.examId == exam.examId);
                                  _applyFilter();
                                });
                                
                                if (!mounted) return;
                                
                                // Success SnackBar
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.white),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text('Exam deleted successfully!'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!mounted) return;
                              
                              // Error SnackBar
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
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'DELETE',
                            style: AppStyles.buttonMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
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
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
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

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}