// Mobile version 
import 'package:flutter/material.dart';
import 'package:attend_scan/constants/app_colors.dart';
import 'package:attend_scan/constants/app_styles.dart';
import 'package:attend_scan/constants/app_dimensions.dart';
import 'package:attend_scan/services/firebase_service.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class AttendanceRecordsPage extends StatefulWidget {
  const AttendanceRecordsPage({super.key});

  @override
  State<AttendanceRecordsPage> createState() => _AttendanceRecordsPageState();
}

class _AttendanceRecordsPageState extends State<AttendanceRecordsPage> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  
  List<Exam> _allExams = [];
  List<Map<String, dynamic>> _allStudents = [];
  Exam? _selectedExam;
  Map<String, dynamic>? _attendanceData;
  
  bool _isLoading = true;
  bool _isLoadingAttendance = false;
  String? _errorMessage;
  String _searchQuery = '';
  
  int _selectedFilterIndex = 0;
  late TabController _tabController;
  
  String _sortBy = 'name';
  bool _sortAscending = true;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadData();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedFilterIndex = _tabController.index;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

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
        
        List<Exam> exams = [];
        if (examsResult['success'] == true) {
          final examsData = examsResult['exams'];
          if (examsData is List) {
            exams = examsData.whereType<Exam>().toList();
          }
        }
        
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
        
        setState(() {
          _allExams = exams;
          _allStudents = students;
          if (exams.isNotEmpty) {
            _selectedExam = exams.first;
            _loadAttendanceForExam(exams.first);
          }
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

  Future<void> _loadAttendanceForExam(Exam exam) async {
    setState(() {
      _isLoadingAttendance = true;
      _attendanceData = null;
    });
    
    try {
      final user = await _firebaseService.getCurrentUser();
      if (user != null && user.isAdmin) {
        final result = await _firebaseService.getExamAttendance(
          examId: exam.examId,
          adminUid: user.uid,
        );
        
        setState(() {
          _attendanceData = result;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading attendance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingAttendance = false;
      });
    }
  }

  Future<void> _markStudentPresent(String studentId, {String? seatNo, String? campusLocation}) async {
    try {
      final user = await _firebaseService.getCurrentUser();
      if (user == null || !user.isAdmin) return;

      final student = _allStudents.firstWhere(
        (s) => s['studentId'] == studentId,
        orElse: () => <String, dynamic>{},
      );
      
      final indexNo = student['indexNo']?.toString() ?? '';

      final attendanceData = {
        'Course': _selectedExam!.subjectName,
        'IndexNo': indexNo.isNotEmpty ? indexNo.split('').join(' ') : 'MANUAL',
        'Figures': indexNo,
        'SeatNo': seatNo ?? 'MANUAL',
      };

      final result = await _firebaseService.processHTRResultBySubject(
        studentId: studentId,
        HTRData: attendanceData,
        scannedLocation: campusLocation, 
      );

      if (result['success'] == true) {
        await _loadAttendanceForExam(_selectedExam!);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    campusLocation != null 
                        ? 'Student marked as present at $campusLocation'
                        : 'Student marked as present successfully'
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark attendance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _sortStudents(List<Map<String, dynamic>> students) {
    final sorted = List<Map<String, dynamic>>.from(students);
    
    sorted.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          final nameA = a['studentName']?.toString().toLowerCase() ?? '';
          final nameB = b['studentName']?.toString().toLowerCase() ?? '';
          return _sortAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
        case 'id':
          final idA = a['studentId']?.toString().toLowerCase() ?? '';
          final idB = b['studentId']?.toString().toLowerCase() ?? '';
          return _sortAscending ? idA.compareTo(idB) : idB.compareTo(idA);
        case 'status':
          final statusA = a['status']?.toString() ?? '';
          final statusB = b['status']?.toString() ?? '';
          return _sortAscending ? statusA.compareTo(statusB) : statusB.compareTo(statusA);
        default:
          return 0;
      }
    });
    
    return sorted;
  }

  List<Map<String, dynamic>> _getFilteredStudents() {
    if (_attendanceData == null) return [];
    
    final allStudents = _attendanceData!['allStudents'] as List? ?? [];
    
    List<Map<String, dynamic>> statusFiltered;
    switch (_selectedFilterIndex) {
      case 1:
        statusFiltered = allStudents.where((s) => s['status'] == 'present').cast<Map<String, dynamic>>().toList();
        break;
      case 2:
        statusFiltered = allStudents.where((s) => s['status'] == 'absent').cast<Map<String, dynamic>>().toList();
        break;
      default:
        statusFiltered = allStudents.cast<Map<String, dynamic>>().toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      statusFiltered = statusFiltered.where((s) {
        final name = s['studentName']?.toString().toLowerCase() ?? '';
        final id = s['studentId']?.toString().toLowerCase() ?? '';
        final indexNo = s['indexNo']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || id.contains(query) || indexNo.contains(query);
      }).toList();
    }
    
    return _sortStudents(statusFiltered);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'present':
        return Icons.check_circle_rounded;
      case 'absent':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'ATTENDANCE REPORTS',
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
              SliverToBoxAdapter(child: _buildExamSelectorCard()),
              if (_isLoadingAttendance || _isLoading)
                _buildShimmerList()
              else if (_attendanceData == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('No Data Available')),
                )
              else ...[
                SliverToBoxAdapter(child: _buildStatsCards()),
                SliverToBoxAdapter(child: _buildFilterTabs()),
                SliverToBoxAdapter(child: _buildSearchBar()),
                if (_getFilteredStudents().isNotEmpty)
                  SliverToBoxAdapter(child: _buildSortHeader()),
                if (_getFilteredStudents().isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('No Students Found')),
                  )
                else
                  _buildAttendanceList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamSelectorCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.assessment_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select Exam Course',
                      style: AppStyles.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose an exam course to view attendance',
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
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Exam>(
                value: _selectedExam,
                isExpanded: true,
                icon: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.getPrimaryColor(context),
                  ),
                ),
                dropdownColor: Colors.white,
                style: AppStyles.bodyMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
                items: _allExams.map((exam) {
                  return DropdownMenuItem<Exam>(
                    value: exam,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 56),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.school_rounded,
                                color: AppColors.getPrimaryColor(context),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      exam.subjectName,
                                      style: AppStyles.bodyMedium.copyWith(
                                        color: AppColors.getTextPrimary(context),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${exam.formattedDate} • ${exam.location}',
                                      style: AppStyles.bodySmall.copyWith(
                                        color: AppColors.getTextSecondary(context),
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (Exam? exam) {
                  if (exam != null) {
                    setState(() {
                      _selectedExam = exam;
                    });
                    _loadAttendanceForExam(exam);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final total = _attendanceData!['totalStudents'] ?? 0;
    final present = _attendanceData!['presentCount'] ?? 0;
    final absent = total - present;
    final attendanceRate = total > 0 ? (present / total * 100) : 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
        vertical: AppDimensions.paddingSmall,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactStatCard(
              label: 'Present',
              value: present.toString(),
              icon: Icons.check_circle_rounded,
              color: Colors.green,
              percentage: total > 0 ? (present / total) : 0,
            ),
          ),
          const SizedBox(width: 8), 
          Expanded(
            child: _buildCompactStatCard(
              label: 'Absent',
              value: absent.toString(),
              icon: Icons.cancel_rounded,
              color: Colors.red,
              percentage: total > 0 ? (absent / total) : 0,
            ),
          ),
          const SizedBox(width: 8), 
          Expanded(
            child: _buildCompactStatCard(
              label: 'Rate',
              value: '${attendanceRate.toStringAsFixed(1)}%',
              icon: Icons.analytics_rounded,
              color: Colors.blue,
              percentage: attendanceRate / 100,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required double percentage,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.getShadowColor(context).withOpacity(0.03), 
            blurRadius: 8, 
            offset: const Offset(0, 4), 
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 14), 
              ),
              const Spacer(),
              Text(
                value,
                style: AppStyles.titleMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 16, 
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
              fontSize: 11, 
            ),
          ),
          const SizedBox(height: 2), 
          ClipRRect(
            borderRadius: BorderRadius.circular(1), 
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 3, 
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
        vertical: AppDimensions.paddingSmall,
      ),
      padding: const EdgeInsets.all(6),
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
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                AppColors.getPrimaryColor(context),
                AppColors.getSecondaryColor(context),
              ],
            ),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.getTextSecondary(context),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'ALL'),
            Tab(text: 'PRESENT'),
            Tab(text: 'ABSENT'),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
        vertical: AppDimensions.paddingSmall,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.getPrimaryColor(context).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.getPrimaryColor(context).withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name, ID, or index number...',
                hintStyle: TextStyle(
                  color: AppColors.getTextHint(context).withOpacity(0.7),
                  fontSize: 14,
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
                suffixIcon: _searchQuery.isNotEmpty
                    ? Container(
                        margin: const EdgeInsets.all(8),
                        child: IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
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
                border: InputBorder.none,
              ),
              style: AppStyles.bodyLarge.copyWith(
                color: AppColors.getTextPrimary(context),
                fontSize: 14,
              ),
            ),
          ),
          if (_selectedFilterIndex != 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _selectedFilterIndex == 1 
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedFilterIndex == 1 
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _selectedFilterIndex == 1 
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: _selectedFilterIndex == 1 ? Colors.green : Colors.red,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _selectedFilterIndex == 1 ? 'PRESENT' : 'ABSENT',
                    style: AppStyles.bodySmall.copyWith(
                      color: _selectedFilterIndex == 1 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSortHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
        vertical: 4,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _buildSortChip('Name', 'name'),
          const SizedBox(width: 12),
          _buildSortChip('ID', 'id'),
          const SizedBox(width: 12),
          _buildSortChip('Status', 'status'),
          const Spacer(),
          Text(
            '${_getFilteredStudents().length} students',
            style: AppStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_sortBy == value) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = value;
            _sortAscending = true;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _sortBy == value 
              ? AppColors.getPrimaryColor(context).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppStyles.bodySmall.copyWith(
                color: _sortBy == value
                    ? AppColors.getPrimaryColor(context)
                    : AppColors.getTextSecondary(context),
                fontWeight: _sortBy == value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (_sortBy == value)
              Icon(
                _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: AppColors.getPrimaryColor(context),
                size: 14,
              ),
          ],
        ),
      ),
    );
  }

  SliverList _buildAttendanceList() {
    final filteredStudents = _getFilteredStudents();
    
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final student = filteredStudents[index];
          final status = student['status'] ?? 'absent';
          final statusColor = _getStatusColor(status);
          final scannedLocation = student['scannedLocation'];
          final isOutside = scannedLocation != null && scannedLocation.toString().contains('Outside');
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.getCardBackground(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showStudentDetails(student),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(width: 4, height: 40, decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(2),
                        )),
                        const SizedBox(width: 10),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: statusColor, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              student['studentName']?[0]?.toUpperCase() ?? '?',
                              style: TextStyle(color: statusColor, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                student['studentName'] ?? 'Unknown',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    student['studentId'] ?? '',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (student['indexNo']?.isNotEmpty == true) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Text(
                                        student['indexNo'],
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: AppColors.getPrimaryColor(context),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (status == 'present' && isOutside)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.3), width: 0.5),
                            ),
                            child: const Icon(
                              Icons.warning_rounded,
                              color: Colors.red,
                              size: 16,
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withOpacity(0.3), width: 0.5),
                          ),
                          child: Text(
                            status == 'present' ? 'P' : 'A',
                            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (status == 'absent')
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, size: 16, color: Colors.grey[600]),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            color: Colors.white,
                            onSelected: (value) => _showMarkPresentDialog(student),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'mark_present',
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                                    SizedBox(width: 8),
                                    Text('Mark Present', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else
                          const SizedBox(width: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        childCount: filteredStudents.length,
      ),
    );
  }

  SliverList _buildShimmerList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingLarge,
              vertical: 4,
            ),
            child: Container(
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
                    Container(width: 4, height: 40, color: Colors.grey),
                    const SizedBox(width: 12),
                    Container(width: 44, height: 44, decoration: const BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: double.infinity, height: 16, color: Colors.grey),
                          const SizedBox(height: 8),
                          Container(width: 100, height: 12, color: Colors.grey),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: 5,
      ),
    );
  }

  void _showStudentDetails(Map<String, dynamic> student) {
    final status = student['status'] ?? 'absent';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final studentName = student['studentName'] ?? 'Unknown';
    final initial = studentName.isNotEmpty ? studentName[0].toUpperCase() : '?';
    final scannedLocation = student['scannedLocation'];
    final isOutside = scannedLocation != null && scannedLocation.toString().contains('Outside');
    
    final studentData = _allStudents.firstWhere(
      (s) => s['studentId'] == student['studentId'],
      orElse: () => <String, dynamic>{},
    );
    
    final faculty = studentData['faculty']?.toString() ?? 'Not specified';
    final programme = studentData['programme']?.toString() ?? 'Not specified';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
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
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getTextHint(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isOutside && status == 'present'
                          ? [Colors.red.shade600, Colors.red.shade400]
                          : [statusColor.withOpacity(0.9), statusColor.withOpacity(0.7)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        studentName,
                        style: AppStyles.titleLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  status.toUpperCase(),
                                  style: AppStyles.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (status == 'present' && isOutside) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.warning_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'LOCATION MISMATCH',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
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
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildDetailItem(
                        icon: Icons.badge_rounded,
                        label: 'Student ID',
                        value: student['studentId'] ?? 'N/A',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailItem(
                        icon: Icons.school_rounded,
                        label: 'Faculty',
                        value: faculty,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailItem(
                        icon: Icons.book_rounded,
                        label: 'Programme',
                        value: programme,
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailItem(
                        icon: Icons.numbers_rounded,
                        label: 'Index Number',
                        value: student['indexNo']?.isNotEmpty == true
                            ? student['indexNo']
                            : 'Not assigned',
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailItem(
                        icon: Icons.event_seat_rounded,
                        label: 'Seat Number',
                        value: student['seatNo']?.isNotEmpty == true
                            ? student['seatNo']
                            : 'Not assigned',
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailItem(
                        icon: Icons.access_time_rounded,
                        label: 'Scanned At',
                        value: student['scannedAt'] != null
                            ? DateFormat('dd/MM/yyyy HH:mm').format(student['scannedAt'])
                            : 'Not scanned',
                        color: Colors.green,
                      ),
                      if (status == 'present' && scannedLocation != null && scannedLocation.isNotEmpty)
                        const SizedBox(height: 12),
                      if (status == 'present' && scannedLocation != null && scannedLocation.isNotEmpty)
                        _buildDetailItem(
                          icon: scannedLocation.contains('Outside') 
                              ? Icons.warning_rounded 
                              : Icons.location_on_rounded,
                          label: 'Scan Location',
                          value: scannedLocation,
                          color: scannedLocation.contains('Outside') 
                              ? Colors.orange 
                              : Colors.teal,
                        ),
                      const SizedBox(height: 12),
                      _buildDetailItem(
                        icon: Icons.subject_rounded,
                        label: 'Exam Course',
                        value: _selectedExam?.subjectName ?? 'Unknown',
                        color: AppColors.getPrimaryColor(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: AppColors.getTextSecondary(context).withOpacity(0.3),
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
                      if (status == 'absent') ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _showMarkPresentDialog(student);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Mark Present'),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  void _showMarkPresentDialog(Map<String, dynamic> student) {
    final seatController = TextEditingController();
    String? selectedCampus = 'UTAR Kampar Campus'; 
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Container(
                margin: const EdgeInsets.all(AppDimensions.paddingXXLarge),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.getCardBackground(context),
                    borderRadius: BorderRadius.circular(24),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Manual Mark Present',
                                  style: AppStyles.titleLarge.copyWith(
                                    color: AppColors.getTextPrimary(context),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Manually mark attendance for student',
                                  style: AppStyles.bodySmall.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.getBackgroundColor(context).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.withOpacity(0.1), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Student: ${student['studentName']}',
                              style: AppStyles.bodyMedium.copyWith(
                                color: AppColors.getTextPrimary(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Exam: ${_selectedExam?.subjectName}',
                              style: AppStyles.bodyMedium.copyWith(
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Seat Number Field
                            TextField(
                              controller: seatController,
                              decoration: InputDecoration(
                                labelText: 'Seat Number (Optional)',
                                hintText: 'Enter seat number',
                                prefixIcon: Icon(Icons.chair_rounded, color: Colors.orange),
                                filled: true,
                                fillColor: AppColors.getBackgroundColor(context),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.orange.withOpacity(0.3)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.orange.withOpacity(0.2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Campus Selection 
                            Text(
                              'Scan Location (Campus)',
                              style: AppStyles.bodySmall.copyWith(
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.getBackgroundColor(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.teal.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  RadioListTile<String>(
                                    title: Row(
                                      children: [
                                        Icon(Icons.location_on_rounded, color: Colors.teal, size: 20),
                                        const SizedBox(width: 8),
                                        const Text('UTAR Kampar Campus'),
                                      ],
                                    ),
                                    value: 'UTAR Kampar Campus',
                                    groupValue: selectedCampus,
                                    activeColor: Colors.teal,
                                    onChanged: (value) {
                                      setState(() {
                                        selectedCampus = value;
                                      });
                                    },
                                  ),
                                  const Divider(height: 1, indent: 56),
                                  RadioListTile<String>(
                                    title: Row(
                                      children: [
                                        Icon(Icons.location_on_rounded, color: Colors.teal, size: 20),
                                        const SizedBox(width: 8),
                                        const Text('UTAR Sungai Long Campus'),
                                      ],
                                    ),
                                    value: 'UTAR Sungai Long Campus',
                                    groupValue: selectedCampus,
                                    activeColor: Colors.teal,
                                    onChanged: (value) {
                                      setState(() {
                                        selectedCampus = value;
                                      });
                                    },
                                  ),             
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 14, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Select the campus where the student is taking the exam',
                                      style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: AppColors.getTextSecondary(context).withOpacity(0.3)),
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
                              onPressed: () {
                                Navigator.pop(ctx);
                                _markStudentPresent(
                                  student['studentId'],
                                  seatNo: seatController.text.isNotEmpty ? seatController.text : null,
                                  campusLocation: selectedCampus,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 4,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Confirm'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getBackgroundColor(context).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppStyles.bodyMedium.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}