// lib/screens/admin/manage_students_page.dart
import 'package:flutter/material.dart';
import 'package:attend_scan/constants/app_colors.dart';
import 'package:attend_scan/constants/app_styles.dart';
import 'package:attend_scan/constants/app_dimensions.dart';
import 'package:attend_scan/services/firebase_service.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

// Admin page to view, filter, sort, and paginate student list
class ManageStudentsPage extends StatefulWidget {
  const ManageStudentsPage({super.key});

  @override
  State<ManageStudentsPage> createState() => _ManageStudentsPageState();
}

class _ManageStudentsPageState extends State<ManageStudentsPage> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Exam> _allExams = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Filter and search
  String _searchQuery = '';
  String? _selectedFacultyFilter;
  String? _selectedProgrammeFilter;
  final TextEditingController _searchController = TextEditingController();
  
  // Sorting
  String _sortBy = 'name'; // 'name', 'id', 'faculty', 'exams'
  bool _sortAscending = true;
  
  // Pagination
  int _currentPage = 0;
  final int _itemsPerPage = 10;

  // Load students and exams on init
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

  // Fetch students and exams from Firebase
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final user = await _firebaseService.getCurrentUser();
      if (user != null && user.isAdmin) {
        // Load all students
        final studentsResult = await _firebaseService.getAllStudents(user.uid);
        
        // Load all exams to check which exams each student is assigned to
        final examsResult = await _firebaseService.getAllExams(adminUid: user.uid);
        
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
          _allStudents = students;
          _allExams = exams;
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

  // Apply active filters and search query to the students list
  void _applyFilter() {
    List<Map<String, dynamic>> filtered = List.from(_allStudents);
    
    // Apply faculty filter
    if (_selectedFacultyFilter != null) {
      filtered = filtered.where((s) => 
        s['faculty']?.toString() == _selectedFacultyFilter
      ).toList();
    }
    
    // Apply programme filter
    if (_selectedProgrammeFilter != null) {
      filtered = filtered.where((s) => 
        s['programme']?.toString() == _selectedProgrammeFilter
      ).toList();
    }
    
    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) {
        final name = s['fullName']?.toString().toLowerCase() ?? '';
        final id = s['studentId']?.toString().toLowerCase() ?? '';
        final indexNo = s['indexNo']?.toString().toLowerCase() ?? '';
        final faculty = s['faculty']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || 
               id.contains(query) || 
               indexNo.contains(query) ||
               faculty.contains(query);
      }).toList();
    }
    
    _applySorting(filtered);
  }

  // Sort filtered students based on selected criteria
  void _applySorting(List<Map<String, dynamic>> filtered) {
    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) {
          final nameA = a['fullName']?.toString().toLowerCase() ?? '';
          final nameB = b['fullName']?.toString().toLowerCase() ?? '';
          return _sortAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
        });
        break;
      case 'id':
        filtered.sort((a, b) {
          final idA = a['studentId']?.toString().toLowerCase() ?? '';
          final idB = b['studentId']?.toString().toLowerCase() ?? '';
          return _sortAscending ? idA.compareTo(idB) : idB.compareTo(idA);
        });
        break;
      case 'faculty':
        filtered.sort((a, b) {
          final facultyA = a['faculty']?.toString().toLowerCase() ?? '';
          final facultyB = b['faculty']?.toString().toLowerCase() ?? '';
          return _sortAscending ? facultyA.compareTo(facultyB) : facultyB.compareTo(facultyA);
        });
        break;
      case 'exams':
        filtered.sort((a, b) {
          final countA = _getStudentExamCount(a['studentId']?.toString() ?? '');
          final countB = _getStudentExamCount(b['studentId']?.toString() ?? '');
          return _sortAscending ? countA.compareTo(countB) : countB.compareTo(countA);
        });
        break;
    }
    
    setState(() {
      _filteredStudents = filtered;
      _currentPage = 0; // Reset to first page when filter changes
    });
  }

  // Toggle sort field and direction then reapply filters
  void _toggleSort(String sortBy) {
    if (_sortBy == sortBy) {
      setState(() {
        _sortAscending = !_sortAscending;
      });
    } else {
      setState(() {
        _sortBy = sortBy;
        _sortAscending = true;
      });
    }
    _applyFilter();
  }

  // Get unique faculties for filter dropdown
  // Return unique faculty names for filter dropdown
  List<String> _getUniqueFaculties() {
    return _allStudents
        .map((s) => s['faculty']?.toString() ?? '')
        .where((f) => f.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  // Get programmes for selected faculty
  // Return programmes for the selected faculty
  List<String> _getProgrammesForFaculty(String? faculty) {
    if (faculty == null) return [];
    return _allStudents
        .where((s) => s['faculty']?.toString() == faculty)
        .map((s) => s['programme']?.toString() ?? '')
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  // Get exams assigned to a student
  // Get exams assigned to a specific student
  List<Exam> _getStudentExams(String studentId) {
    return _allExams.where((exam) => 
      exam.allowedClasses.contains(studentId)
    ).toList();
  }

  // Get exam count for a student
  // Count exams assigned to a student
  int _getStudentExamCount(String studentId) {
    return _getStudentExams(studentId).length;
  }

  // Get upcoming exams for a student
  // Get upcoming active exams for a student
  List<Exam> _getStudentUpcomingExams(String studentId) {
    final now = DateTime.now();
    return _getStudentExams(studentId)
        .where((exam) => exam.startTime.isAfter(now) && exam.isActive)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  // Get paginated students
  // Return current page of students for pagination
  List<Map<String, dynamic>> _getPaginatedStudents() {
    final start = _currentPage * _itemsPerPage;
    final end = start + _itemsPerPage;
    if (start >= _filteredStudents.length) return [];
    return _filteredStudents.sublist(start, end > _filteredStudents.length ? _filteredStudents.length : end);
  }

  @override
  Widget build(BuildContext context) {
    final uniqueFaculties = _getUniqueFaculties();
    final programmesForFaculty = _getProgrammesForFaculty(_selectedFacultyFilter);
    final paginatedStudents = _getPaginatedStudents();
    final totalPages = (_filteredStudents.length / _itemsPerPage).ceil();

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'STUDENT MANAGEMENT',
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
              // Search and Filter Bar
              SliverToBoxAdapter(
                child: _buildSearchFilterBar(context, uniqueFaculties, programmesForFaculty),
              ),

              // Sort Bar
              SliverToBoxAdapter(
                child: _buildSortBar(context),
              ),

              // Students List
              if (_isLoading)
                _buildShimmerList()
              else if (_errorMessage != null)
                SliverFillRemaining(
                  child: _buildErrorState(),
                )
              else if (_filteredStudents.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingLarge,
                    vertical: AppDimensions.paddingMedium,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final student = paginatedStudents[index];
                        return _buildStudentCard(context, student);
                      },
                      childCount: paginatedStudents.length,
                    ),
                  ),
                ),

              // Pagination
              if (!_isLoading && _filteredStudents.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildPagination(totalPages),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchFilterBar(
    BuildContext context, 
    List<String> faculties, 
    List<String> programmes
  ) {
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
          // Header Row 
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.filter_list_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Search & Filter',
                      style: AppStyles.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Filter students by faculty and programme',
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
          
          // Search Field 
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14), 
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _searchQuery = value;
                _applyFilter();
              },
              style: AppStyles.bodyMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
              decoration: InputDecoration(
                hintText: 'Search by name, ID, index number...',
                hintStyle: AppStyles.bodySmall.copyWith(
                  color: AppColors.getTextHint(context),
                ),
                prefixIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.search_rounded,
                    color: AppColors.getPrimaryColor(context),
                    size: 20,
                  ),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: AppColors.getTextSecondary(context),
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery = '';
                          _applyFilter();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Filter Row 
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _buildFilterDropdown(
                    value: _selectedFacultyFilter,
                    hint: 'All Faculties',
                    items: faculties,
                    onChanged: (value) {
                      setState(() {
                        _selectedFacultyFilter = value;
                        _selectedProgrammeFilter = null;
                        _applyFilter();
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12), 
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _buildFilterDropdown(
                    value: _selectedProgrammeFilter,
                    hint: _selectedFacultyFilter == null 
                        ? 'Select Faculty First' 
                        : 'All Programmes',
                    items: programmes,
                    enabled: _selectedFacultyFilter != null,
                    onChanged: _selectedFacultyFilter == null
                        ? null
                        : (value) {
                            setState(() {
                              _selectedProgrammeFilter = value;
                              _applyFilter();
                            });
                          },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?)? onChanged,
    bool enabled = true,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
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
        icon: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: enabled 
                ? AppColors.getPrimaryColor(context)
                : AppColors.getTextHint(context).withOpacity(0.3),
          ),
        ),
        dropdownColor: Colors.white,
        style: AppStyles.bodyMedium.copyWith(
          color: enabled
              ? AppColors.getTextPrimary(context)
              : AppColors.getTextHint(context).withOpacity(0.5),
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                hint == 'All Faculties' ? 'All Faculties' : 'All Programmes',
                style: AppStyles.bodyMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ),
          ),
          ...items.map((item) => DropdownMenuItem<String>(
            value: item,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                item,
                style: AppStyles.bodyMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )),
        ],
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  Widget _buildSortBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
        vertical: AppDimensions.paddingSmall,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.getPrimaryColor(context).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Sort by Name
            GestureDetector(
              onTap: () => _toggleSort('name'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _sortBy == 'name' 
                      ? AppColors.getPrimaryColor(context).withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Name',
                      style: AppStyles.bodySmall.copyWith(
                        color: _sortBy == 'name'
                            ? AppColors.getPrimaryColor(context)
                            : AppColors.getTextSecondary(context),
                        fontWeight: _sortBy == 'name' ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (_sortBy == 'name')
                      Icon(
                        _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: AppColors.getPrimaryColor(context),
                        size: 14,
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Sort by ID
            GestureDetector(
              onTap: () => _toggleSort('id'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _sortBy == 'id' 
                      ? AppColors.getPrimaryColor(context).withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ID',
                      style: AppStyles.bodySmall.copyWith(
                        color: _sortBy == 'id'
                            ? AppColors.getPrimaryColor(context)
                            : AppColors.getTextSecondary(context),
                        fontWeight: _sortBy == 'id' ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (_sortBy == 'id')
                      Icon(
                        _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: AppColors.getPrimaryColor(context),
                        size: 14,
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Sort by Faculty
            GestureDetector(
              onTap: () => _toggleSort('faculty'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _sortBy == 'faculty' 
                      ? AppColors.getPrimaryColor(context).withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Faculty',
                      style: AppStyles.bodySmall.copyWith(
                        color: _sortBy == 'faculty'
                            ? AppColors.getPrimaryColor(context)
                            : AppColors.getTextSecondary(context),
                        fontWeight: _sortBy == 'faculty' ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (_sortBy == 'faculty')
                      Icon(
                        _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: AppColors.getPrimaryColor(context),
                        size: 14,
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Sort by Exams
            GestureDetector(
              onTap: () => _toggleSort('exams'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _sortBy == 'exams' 
                      ? AppColors.getPrimaryColor(context).withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Exams',
                      style: AppStyles.bodySmall.copyWith(
                        color: _sortBy == 'exams'
                            ? AppColors.getPrimaryColor(context)
                            : AppColors.getTextSecondary(context),
                        fontWeight: _sortBy == 'exams' ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (_sortBy == 'exams')
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
            
            // Student count - now part of the scrollable row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_filteredStudents.length}',
                style: AppStyles.bodySmall.copyWith(
                  color: AppColors.getPrimaryColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'students',
              style: AppStyles.bodySmall.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context, Map<String, dynamic> student) {
    final studentId = student['studentId']?.toString() ?? '';
    final fullName = student['fullName']?.toString() ?? 'Unknown';
    final indexNo = student['indexNo']?.toString() ?? 'N/A';
    final faculty = student['faculty']?.toString() ?? 'Not specified';
    final programme = student['programme']?.toString() ?? 'Not specified';
    final examCount = _getStudentExamCount(studentId);
    final upcomingExams = _getStudentUpcomingExams(studentId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showStudentDetails(student),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context).withOpacity(0.8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: examCount > 0 ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
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
                    // Avatar with initial
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.getPrimaryColor(context).withOpacity(0.2),
                            AppColors.getSecondaryColor(context).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.getPrimaryColor(context).withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: AppColors.getPrimaryColor(context),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Student Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  fullName,
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
                                  color: examCount > 0 ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.assignment_rounded,
                                      size: 12,
                                      color: examCount > 0 ? Colors.green : Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$examCount',
                                      style: AppStyles.bodySmall.copyWith(
                                        color: examCount > 0 ? Colors.green : Colors.grey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 4),
                          
                          Row(
                            children: [
                              Icon(
                                Icons.badge_rounded,
                                size: 12,
                                color: AppColors.getTextSecondary(context),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  studentId,
                                  style: AppStyles.bodySmall.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 2),
                          
                          Row(
                            children: [
                              Icon(
                                Icons.numbers_rounded,
                                size: 12,
                                color: AppColors.getTextSecondary(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Index: $indexNo',
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
                
                const SizedBox(height: 12),
                
                // Faculty and Programme
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.getBackgroundColor(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
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
                          Icon(
                            Icons.school_rounded,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              faculty,
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
                            Icons.book_rounded,
                            size: 14,
                            color: Colors.purple,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              programme,
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
                
                // Upcoming Exams Preview
                if (upcomingExams.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.upcoming_rounded,
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${upcomingExams.length} upcoming ${upcomingExams.length == 1 ? 'exam' : 'exams'}',
                            style: AppStyles.bodySmall.copyWith(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.paddingLarge),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.getPrimaryColor(context).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _currentPage > 0
                ? () {
                    setState(() {
                      _currentPage--;
                    });
                  }
                : null,
            color: _currentPage > 0
                ? AppColors.getPrimaryColor(context)
                : AppColors.getTextHint(context),
          ),
          const SizedBox(width: 8),
          Text(
            'Page ${_currentPage + 1} of $totalPages',
            style: AppStyles.bodyMedium.copyWith(
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _currentPage < totalPages - 1
                ? () {
                    setState(() {
                      _currentPage++;
                    });
                  }
                : null,
            color: _currentPage < totalPages - 1
                ? AppColors.getPrimaryColor(context)
                : AppColors.getTextHint(context),
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
                    decoration: const BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
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
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 150,
                          height: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 100,
                          height: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: 5,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
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
                      Icons.people_outline_rounded,
                      size: 40,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Students Found',
                    style: AppStyles.titleLarge.copyWith(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No students match your search criteria',
                    textAlign: TextAlign.center,
                    style: AppStyles.bodyMedium.copyWith(
                      color: AppColors.getTextSecondary(context).withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                        _selectedFacultyFilter = null;
                        _selectedProgrammeFilter = null;
                        _applyFilter();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.getPrimaryColor(context),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Clear Filters'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

void _showStudentDetails(Map<String, dynamic> student) async {
  final studentId = student['studentId']?.toString() ?? '';
  final fullName = student['fullName']?.toString() ?? 'Unknown';
  final indexNo = student['indexNo']?.toString() ?? 'N/A';
  final faculty = student['faculty']?.toString() ?? 'Not specified';
  final programme = student['programme']?.toString() ?? 'Not specified';
  
  // Show loading state first
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
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
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading student data...',
                      style: AppStyles.bodyMedium.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  // Fetch real data
  try {
    // Get all exams this student is assigned to
    final assignedExams = _getStudentExams(studentId);
    
    // Get attendance history for this student
    final attendanceHistory = await _firebaseService.getAttendanceHistory(studentId);
    
    // Create a map of examId -> attendance status
    final attendanceMap = <String, AttendanceRecord>{};
    for (var record in attendanceHistory) {
      attendanceMap[record.examId] = record;
    }
    
    // Calculate attendance statistics
    int totalPastExams = 0;
    int attendedExams = 0;
    int missedExams = 0;
    
    final now = DateTime.now();
    final List<Exam> upcomingExams = [];
    final List<Map<String, dynamic>> pastExamsWithStatus = [];
    
    for (var exam in assignedExams) {
      final attendance = attendanceMap[exam.examId];
      final hasAttended = attendance != null && attendance.status == 'present';
      
      if (exam.endTime.isBefore(now)) {
        // Past exam - count for attendance rate
        totalPastExams++;
        
        if (hasAttended) {
          attendedExams++;
        } else {
          missedExams++;
        }
        
        pastExamsWithStatus.add({
          'exam': exam,
          'attended': hasAttended,
          'attendance': attendance,
        });
      } else {
        // Upcoming exam - don't count for attendance rate
        upcomingExams.add(exam);
      }
    }
    
    // Also check if there are any attendance records for exams that might be missing from assignedExams
    // This handles cases where exam might have been deleted but student attended
    for (var record in attendanceHistory) {
      if (record.status == 'present') {
        // Check if this exam is already counted in past exams
        final examExistsInPast = pastExamsWithStatus.any((item) => 
          (item['exam'] as Exam).examId == record.examId
        );
        
        if (!examExistsInPast && record.examId.isNotEmpty) {
          // This is an exam that might have been deleted but student attended
          // We still count it as a past exam for attendance rate
          totalPastExams++;
          attendedExams++;
          
          // Try to get exam details if available
          Exam? examDetails;
          try {
            examDetails = await _firebaseService.getExamById(record.examId);
          } catch (e) {
            // Exam details not available
          }
          
          pastExamsWithStatus.add({
            'exam': examDetails ?? Exam(
              examId: record.examId,
              subjectName: 'Unknown Exam',
              location: 'Unknown',
              allowedClasses: [],
              isActive: false,
              createdAt: DateTime.now(),
              startTime: record.scannedAt.subtract(const Duration(hours: 2)),
              endTime: record.scannedAt,
              createdBy: '',
            ),
            'attended': true,
            'attendance': record,
          });
        }
      }
    }
    
    // Calculate attendance rate
    double attendanceRate = totalPastExams > 0 
        ? (attendedExams / totalPastExams * 100) 
        : 0;
    
    // Close loading and show real data
    Navigator.pop(context); // Close loading bottom sheet
    
    // Show actual data bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: AppColors.getCardBackground(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getTextHint(context).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.getPrimaryColor(context).withOpacity(0.9),
                      AppColors.getSecondaryColor(context).withOpacity(0.7),
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
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Center(
                        child: Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      fullName,
                      style: AppStyles.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailSection(
                        title: 'Student Information',
                        children: [
                          _buildDetailRow(
                            icon: Icons.badge_rounded,
                            label: 'Student ID',
                            value: studentId,
                            color: Colors.blue,
                          ),
                          _buildDetailRow(
                            icon: Icons.numbers_rounded,
                            label: 'Index Number',
                            value: indexNo,
                            color: Colors.teal,
                          ),
                          _buildDetailRow(
                            icon: Icons.school_rounded,
                            label: 'Faculty',
                            value: faculty,
                            color: Colors.orange,
                          ),
                          _buildDetailRow(
                            icon: Icons.book_rounded,
                            label: 'Programme',
                            value: programme,
                            color: Colors.purple,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Attendance Rate Section
                      _buildDetailSection(
                        title: 'Attendance Rate',
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.getBackgroundColor(context).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _getAttendanceRateColor(attendanceRate).withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Circular progress indicator
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 120,
                                      height: 120,
                                      child: CircularProgressIndicator(
                                        value: attendanceRate / 100,
                                        backgroundColor: Colors.grey.withOpacity(0.2),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          _getAttendanceRateColor(attendanceRate),
                                        ),
                                        strokeWidth: 12,
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${attendanceRate.toStringAsFixed(1)}%',
                                          style: AppStyles.titleLarge.copyWith(
                                            color: _getAttendanceRateColor(attendanceRate),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 28,
                                          ),
                                        ),
                                        Text(
                                          'Attendance',
                                          style: AppStyles.bodySmall.copyWith(
                                            color: AppColors.getTextSecondary(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Statistics Row - Shows past exams only
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildAttendanceStat(
                                      label: 'Total Past Exams',
                                      value: totalPastExams.toString(),
                                      color: Colors.blue,
                                      icon: Icons.assignment_rounded,
                                    ),
                                    _buildAttendanceStat(
                                      label: 'Attended',
                                      value: attendedExams.toString(),
                                      color: Colors.green,
                                      icon: Icons.check_circle_rounded,
                                    ),
                                    _buildAttendanceStat(
                                      label: 'Missed',
                                      value: missedExams.toString(),
                                      color: Colors.red,
                                      icon: Icons.cancel_rounded,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Upcoming Exams Section (Not counted in attendance rate)
                      if (upcomingExams.isNotEmpty) ...[
                        _buildDetailSection(
                          title: 'Upcoming Exams (${upcomingExams.length})',
                          children: upcomingExams.map((exam) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.getBackgroundColor(context).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.upcoming_rounded,
                                      color: Colors.blue,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exam.subjectName,
                                          style: AppStyles.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${DateFormat('dd/MM/yyyy').format(exam.startTime)} • ${exam.location}',
                                          style: AppStyles.bodySmall.copyWith(
                                            color: AppColors.getTextSecondary(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      DateFormat('HH:mm').format(exam.startTime),
                                      style: AppStyles.bodySmall.copyWith(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      
                      // Past Exams Section (These count for attendance rate)
                      if (pastExamsWithStatus.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildDetailSection(
                          title: 'Past Exams (${pastExamsWithStatus.length})',
                          children: pastExamsWithStatus.map((item) {
                            final exam = item['exam'] as Exam;
                            final attended = item['attended'] as bool;
                            final attendance = item['attendance'] as AttendanceRecord?;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.getBackgroundColor(context).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: attended ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: attended ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      attended ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                      color: attended ? Colors.green : Colors.red,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exam.subjectName,
                                          style: AppStyles.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              DateFormat('dd/MM/yyyy').format(exam.startTime),
                                              style: AppStyles.bodySmall.copyWith(
                                                color: AppColors.getTextSecondary(context),
                                              ),
                                            ),
                                            if (attendance != null && attendance.seatNo.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Seat: ${attendance.seatNo}',
                                                  style: AppStyles.bodySmall.copyWith(
                                                    color: Colors.orange,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: attended ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      attended ? 'Present' : 'Absent',
                                      style: AppStyles.bodySmall.copyWith(
                                        color: attended ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // Close button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.getPrimaryColor(context),
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
        );
      },
    );
    
  } catch (e) {
    // Handle error
    Navigator.pop(context); // Close loading
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading student data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Color _getAttendanceRateColor(double rate) {
  if (rate >= 75) return Colors.green;
  if (rate >= 50) return Colors.orange;
  return Colors.red;
}

Widget _buildAttendanceStat({
  required String label,
  required String value,
  required Color color,
  required IconData icon,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppStyles.titleSmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: AppStyles.bodySmall.copyWith(
            color: AppColors.getTextSecondary(context),
            fontSize: 10,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildDetailSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppStyles.titleSmall.copyWith(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getBackgroundColor(context).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
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
                  style: AppStyles.bodyMedium.copyWith(
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