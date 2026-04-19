// lib/pages/scan_page.dart
import 'package:dio/dio.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:attend_scan/constants/app_colors.dart';
import 'package:attend_scan/constants/app_styles.dart';
import 'package:attend_scan/constants/app_dimensions.dart';
import 'package:attend_scan/services/firebase_service.dart';
import 'package:attend_scan/services/connectivity_service.dart';
import 'package:provider/provider.dart';
import 'package:attend_scan/services/notification_service.dart';
import 'package:geolocator/geolocator.dart';  
import 'package:attend_scan/services/location_service.dart';  

// Scanning page: capture or pick image and process via HTR API
class ScanPage extends StatefulWidget {
  final String? examId;
  final String? studentId;

  const ScanPage({
    super.key,
    this.examId,
    this.studentId,
  });

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Camera Controller
  CameraController? _controller;
  bool _isProcessing = false;
  bool _isCameraReady = false;
  final ImagePicker _picker = ImagePicker();
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  
  // Firebase Service
  final FirebaseService _firebaseService = FirebaseService();
  final ConnectivityService _connectivity = ConnectivityService();

  // Current user data
  String? _currentStudentId;
  bool _isOffline = false;

  // HTR API URL
  final String apiUrl =
      "https://vky-04-exam-attendance-app-api.hf.space/predict";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
    _loadUserData();
    
    // Check initial connectivity
    _checkConnectivity();
    
    // Add connectivity listener
    _connectivity.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivity.removeListener(_onConnectivityChanged);
    _controller?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Handle app lifecycle changes (when app returns from background)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App resumed from background - check connectivity
      _checkConnectivity();
    }
  }

  // Handle connectivity changes
  void _onConnectivityChanged() {
    _checkConnectivity();
  }

  // Check current connectivity status
  Future<void> _checkConnectivity() async {
    final hasInternet = await ConnectivityService.checkInternet();
    if (mounted) {
      setState(() {
        _isOffline = !hasInternet;
      });
    }
  }

  // Initialize animations for processing feedback
  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  // Load current logged-in student id from Firebase if needed
  Future<void> _loadUserData() async {
    if (widget.studentId != null) {
      _currentStudentId = widget.studentId;
    } else {
      final student = await _firebaseService.getCurrentUser();
      _currentStudentId = student?.studentId ?? '';
    }

    if (mounted) setState(() {});
  }

  // Initialize device camera for capturing scan images
  Future<void> _initCamera() async {
    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showErrorSnackBar('No camera available');
        return;
      }

      _controller = CameraController(
        cameras[0],
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to initialize camera: $e');
    }
  }

  // Ensure device has internet before attempting HTR processing
  Future<bool> _checkInternetConnection() async {
    final hasInternet = await ConnectivityService.checkInternet();
    if (!hasInternet) {
      _showOfflineDialog();
      return false;
    }
    return true;
  }

  // Display an offline mode dialog explaining scanning limitations
  void _showOfflineDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.05,
            vertical: MediaQuery.of(context).size.height * 0.05,
          ),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context),
              borderRadius: BorderRadius.circular(24),
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
                // Offline Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'OFFLINE MODE',
                          style: AppStyles.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.wifi_off_rounded,
                              color: Colors.orange,
                              size: 50,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No Internet Connection',
                          style: AppStyles.titleLarge.copyWith(
                            color: AppColors.getTextPrimary(context),
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You are currently offline. Scanning requires an internet connection to process the image.',
                          style: AppStyles.bodyMedium.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Alternative Option',
                                      style: AppStyles.titleSmall.copyWith(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'You can request the exam invigilator to manually mark your attendance.',
                                style: AppStyles.bodyMedium.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                          child: Text(
                            'GO BACK',
                            style: AppStyles.buttonMedium.copyWith(
                              color: AppColors.getTextSecondary(context),
                              fontWeight: FontWeight.w600,
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

  // Upload image to HTR API and handle the response
  Future<void> _processImage(String path) async {
    // Check internet connection first
    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) return;
    
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(path, filename: "capture.jpg"),
      });

      // Send image to HTR API (POST)
      var response = await Dio().post(apiUrl, data: formData);

      if (response.statusCode == 200) {
        await _processHTRResult(response.data);
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorSnackBar("HTR Error: $e");
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // ==================== OCR DATA EXTRACTION & VALIDATION ====================

  // Convert OCR words to compact index string (e.g., "A ZERO ONE" -> "A01")
  String _wordsToCompact(String words) {
    if (words.isEmpty) return '';
    
    final Map<String, String> wordToDigit = {
      'ZERO': '0', 'ONE': '1', 'TWO': '2', 'THREE': '3',
      'FOUR': '4', 'FIVE': '5', 'SIX': '6', 'SEVEN': '7',
      'EIGHT': '8', 'NINE': '9',
    };
    
    StringBuffer result = StringBuffer();
    final parts = words.trim().split(' ');
    
    for (final part in parts) {
      if (wordToDigit.containsKey(part)) {
        result.write(wordToDigit[part]);
      } else {
        result.write(part);
      }
    }
    
    return result.toString();
  }

  // Validate index words against full index figures after user confirmation
  bool _validateIndexWithFullIndex(String indexWords, String fullIndex) {
    if (indexWords.isEmpty || fullIndex.isEmpty) return false;
    
    // Convert words to compact format for comparison
    final compactFromWords = _wordsToCompact(indexWords);
    
    final isMatch = compactFromWords == fullIndex;
    
    return isMatch;
  }

  // Normalize index number for reliable comparisons
  String _cleanIndexNumber(String indexNo) {
    return indexNo.replaceAll(' ', '').toUpperCase();
  }

  // ==================== PROCESS HTR RESULT ====================

  // Process HTR API result and show confirmation dialog to user
  Future<void> _processHTRResult(Map<String, dynamic> HTRData) async {
    if (_currentStudentId == null) {
      _showErrorSnackBar('Please login first');
      if (mounted) {
        setState(() => _isProcessing = false);
      }
      return;
    }

    try {

      // Extract only the 4 fields from OCR response
      final scannedIndexWords = HTRData['IndexWords']?.toString().trim() ?? '';     // "A ZERO ZERO FIVE ZERO NINE BBFNF"
      final scannedFullIndex = HTRData['IndexFigures']?.toString().trim() ?? '';      // "A00509BBFNF"
      final scannedSeatNo = HTRData['SeatNo']?.toString().trim() ?? '';          // "7"
      final scannedCourse = HTRData['Course']?.toString().trim() ?? '';          // "UBFF2083 FINANCIAL MANAGEMENT"

      if (scannedCourse.isEmpty) {
        _showErrorDialog({
          'error': 'Subject not detected',
          'message': 'Could not detect subject name from the scanned image',
          'details': null
        });
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
      
      // Prepare scan data for confirmation dialog
      final scanData = {
        'subjectName': scannedCourse,
        'indexWords': scannedIndexWords,
        'fullIndex': scannedFullIndex,
        'seatNo': scannedSeatNo,
        'rawData': HTRData,  
      };

      // Show confirmation dialog
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        await _showScanDetailsDialog(scanData);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorSnackBar("Failed to process scan: $e");
      }
    }
  }

  // ==================== SCAN DETAILS DIALOG ====================

  Future<void> _showScanDetailsDialog(Map<String, dynamic> scanData) async {
    String editableSubjectName = scanData['subjectName'] ?? '';
    String editableIndexWords = scanData['indexWords'] ?? '';
    String editableFullIndex = scanData['fullIndex'] ?? '';
    String editableSeatNo = scanData['seatNo'] ?? '';
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
                vertical: MediaQuery.of(context).size.height * 0.05,
              ),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.getCardBackground(context),
                  borderRadius: BorderRadius.circular(24),
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
                    // Header - Fixed at top
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.getPrimaryColor(context),
                            AppColors.getSecondaryColor(context),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'EDIT SCAN DETAILS',
                              style: AppStyles.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content - Scrollable
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Subject Name
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.getBackgroundColor(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.school_rounded,
                                        color: Colors.orange,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Subject Name',
                                        style: AppStyles.bodySmall.copyWith(
                                          color: AppColors.getTextSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: editableSubjectName,
                                    style: AppStyles.bodyLarge.copyWith(
                                      color: AppColors.getTextPrimary(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.orange.withOpacity(0.5),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.orange.withOpacity(0.3),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.orange,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      editableSubjectName = value;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Index Words
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.getBackgroundColor(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.purple.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.text_fields_rounded,
                                        color: Colors.purple,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Index Number (Words)',
                                        style: AppStyles.bodySmall.copyWith(
                                          color: AppColors.getTextSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: editableIndexWords,
                                    style: AppStyles.bodyLarge.copyWith(
                                      color: Colors.purple,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.purple.withOpacity(0.5),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.purple.withOpacity(0.3),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.purple,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      editableIndexWords = value;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Full Index
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.getBackgroundColor(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.numbers_rounded,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Index Number (Figures)',
                                        style: AppStyles.bodySmall.copyWith(
                                          color: AppColors.getTextSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: editableFullIndex,
                                    style: AppStyles.bodyLarge.copyWith(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.blue.withOpacity(0.5),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.blue.withOpacity(0.3),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.blue,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      editableFullIndex = value;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Seat Number
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.getBackgroundColor(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.chair_rounded,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Seat Number',
                                        style: AppStyles.bodySmall.copyWith(
                                          color: AppColors.getTextSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: editableSeatNo,
                                    style: AppStyles.bodyLarge.copyWith(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.green.withOpacity(0.5),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.green.withOpacity(0.3),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.green,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      editableSeatNo = value;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            
                            // Add bottom padding for scroll
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // Buttons - Fixed at bottom
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                if (mounted) {
                                  setState(() {
                                    _isProcessing = false;
                                  });
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                // ============================================
                                // STEP 1: Basic field validation
                                // ============================================
                                if (editableSubjectName.isEmpty) {
                                  _showErrorSnackBar('Subject name cannot be empty!');
                                  return;
                                }
                                if (editableSeatNo.isEmpty) {
                                  _showErrorSnackBar('Seat number cannot be empty!');
                                  return;
                                }
                                if (editableIndexWords.isEmpty) {
                                  _showErrorSnackBar('Index Words cannot be empty!');
                                  return;
                                }
                                if (editableFullIndex.isEmpty) {
                                  _showErrorSnackBar('Index Number cannot be empty!');
                                  return;
                                }
                                
                                // ============================================
                                // STEP 2: Validate Index Words matches Full Index
                                // ============================================
                                final isWordsMatch = _validateIndexWithFullIndex(
                                  editableIndexWords, 
                                  editableFullIndex
                                );
                                
                                if (!isWordsMatch) {
                                  // Show error dialog
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (ctx) => _buildValidationErrorDialog(
                                      context,
                                      editableIndexWords,
                                      editableFullIndex,
                                    ),
                                  );
                                  return;
                                }
                                
                                // ============================================
                                // STEP 3: Close dialog and process attendance
                                // ============================================
                                Navigator.of(ctx).pop();
                                
                                if (mounted) {
                                  await _processAttendanceWithDetails(
                                    subjectName: editableSubjectName,
                                    indexWords: editableIndexWords,
                                    indexNo: editableFullIndex,
                                    seatNo: editableSeatNo,
                                    originalData: scanData,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.getPrimaryColor(context),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'SUBMIT',
                                style: AppStyles.buttonMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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

  // Validation error dialog (extracted)
  Widget _buildValidationErrorDialog(
    BuildContext context,
    String indexWords,
    String fullIndex,
  ) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.05,
        vertical: MediaQuery.of(context).size.height * 0.05,
      ),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context),
          borderRadius: BorderRadius.circular(24),
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
            // Error Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFD32F2F), Color(0xFFC62828)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'VALIDATION FAILED',
                      style: AppStyles.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Index Words and Index Number do not match!',
                      style: AppStyles.titleSmall.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please correct them before submitting.',
                      style: AppStyles.bodyMedium.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDetailRow(
                            'Words:',
                            indexWords,
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            'Number:',
                            fullIndex,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: AppColors.getPrimaryColor(context),
                    ),
                  ),
                  child: Text(
                    'CLOSE',
                    style: AppStyles.buttonMedium.copyWith(
                      color: AppColors.getPrimaryColor(context),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PROCESS ATTENDANCE ====================

  /// Get current location with permissions
  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackBar('Location services are disabled.');
      return null;
    }

    // Check for location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackBar('Location permissions are denied.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackBar('Location permissions are permanently denied.');
      return null;
    }

    // Get the current position
    return await Geolocator.getCurrentPosition();
  }

  /// Safe pop method - avoid black screen when no previous page
  void _safePop(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    } else {
      if (mounted) {
        setState(() {
          _isCameraReady = false;
          _isProcessing = false;
          _controller?.dispose();
          _controller = null;
        });
      }
    }
  }

  /// Process attendance after user confirmation
  /// Validates scanned index against student's registered index
  Future<void> _processAttendanceWithDetails({
    required String subjectName,
    required String indexWords,
    required String indexNo,
    required String seatNo,
    required Map<String, dynamic> originalData,
  }) async {
    if (_currentStudentId == null) {
      _showErrorSnackBar('Please login first');
      setState(() => _isProcessing = false);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Get current location (simplified)
      String? scannedLocation;
      double? lat;
      double? lng;
      bool isWithinUtar = false;
      
      try {
        final position = await _getCurrentLocation();
        if (position != null) {
          lat = position.latitude;
          lng = position.longitude;
          
          // Use simplified location service
          scannedLocation = LocationService.getSimplifiedLocation(lat, lng);
          isWithinUtar = LocationService.isWithinUtarCampus(lat, lng);
          
        }
      } catch (e) {
        // Location failed - continue without location data
        debugPrint('Failed to get location: $e');
      }

      // ============================================
      // STEP 5: Get student and check registered index
      // ============================================
      final student = await _firebaseService.getStudentById(_currentStudentId!);
      
      if (student == null) {
        _showErrorSnackBar('Student record not found');
        setState(() => _isProcessing = false);
        return;
      }

      // Check index match
      if ((student.indexNo ?? '').isNotEmpty) {
        final cleanedStudentIndex = _cleanIndexNumber(student.indexNo ?? '');
        final cleanedScannedIndex = _cleanIndexNumber(indexNo);
        
        if (cleanedScannedIndex != cleanedStudentIndex) {
          if (mounted) {
            setState(() => _isProcessing = false);
            _showErrorDialog({
              'error': 'Index mismatch',
              'message': 'Scanned index number does not match your registered index',
              'details': {
                'scannedIndex': indexNo,
                'registeredIndex': student.indexNo ?? '',
              }
            });
          }
          return;
        }
      }

      // ============================================
      // STEP 6: Submit to Firebase with simplified location
      // ============================================
      final updatedHTRData = {
        'Course': subjectName,
        'IndexNo': indexWords,
        'Figures': indexNo,
        'SeatNo': seatNo,
      };

      final result = await _firebaseService.processHTRResultBySubject(
        studentId: _currentStudentId!,
        HTRData: updatedHTRData,
        scannedLatitude: lat,
        scannedLongitude: lng,
        scannedLocation: scannedLocation, // Just campus name or "Outside UTAR"
      );

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      if (result['success'] == true) {
        final examName = result['examName'] ?? subjectName;
        final alreadyAttended = result['alreadyAttended'] ?? false;
        
        if (!alreadyAttended) {
          await NotificationService().showSuccessNotification(
            title: '✅ Attendance Recorded',
            body: 'Subject: $examName',
            payload: 'attendance_success',
          );
        }
        
        // // Show location warning only if outside UTAR AND this is a new attendance
        // if (!alreadyAttended && !isWithinUtar && mounted && scannedLocation != null) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(
        //       content: Row(
        //         children: [
        //           const Icon(Icons.warning_rounded, color: Colors.orange),
        //           const SizedBox(width: 8),
        //           const Expanded(child: Text('Warning: You are outside UTAR campus!')),
        //         ],
        //       ),
        //       backgroundColor: Colors.orange,
        //       behavior: SnackBarBehavior.floating,
        //       duration: const Duration(seconds: 3),
        //     ),
        //   );
        // }
        
        _showSuccessDialog(result);
      } else {
        // Error case - show error notification
        await NotificationService().showErrorNotification(
          title: '❌ Attendance Failed',
          body: result['message'] ?? 'Please try again',
        );
        
        _showErrorDialog(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorSnackBar("Failed to process attendance: $e");
      }
    }
  }

  // ==================== DIALOGS ====================

/// Show success dialog after attendance recorded
void _showSuccessDialog(Map<String, dynamic> result) {
  final attendance = result['attendance'];
  final alreadyAttended = result['alreadyAttended'] ?? false;
  final examName = result['examName'] ?? 'Unknown Exam';
  final seatNo = result['seatNo'] ?? 'N/A';
  final scannedLocation = attendance?.scannedLocation;
  final isOutside = scannedLocation != null && scannedLocation.toString().contains('Outside');

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.05,
          vertical: MediaQuery.of(context).size.height * 0.05,
        ),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: AppColors.getCardBackground(context),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
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
                      colors: alreadyAttended
                          ? [Colors.orange, Colors.amber]
                          : [Colors.green, Colors.teal],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          alreadyAttended
                              ? Icons.info_rounded
                              : Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alreadyAttended
                                  ? 'ALREADY ATTENDED'
                                  : 'ATTENDANCE RECORDED',
                              style: AppStyles.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (alreadyAttended)
                              Text(
                                'You have already marked attendance',
                                style: AppStyles.bodySmall.copyWith(
                                  color: Colors.white.withOpacity(0.9),
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

                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        examName,
                        style: AppStyles.titleMedium.copyWith(
                          color: AppColors.getTextPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      _buildResultItem(
                        label: 'Index No',
                        value: attendance?.indexNo ?? 'N/A',
                        icon: Icons.numbers_rounded,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      _buildResultItem(
                        label: 'Seat No',
                        value: attendance?.seatNo ?? seatNo,
                        icon: Icons.chair_rounded,
                        color: Colors.brown,
                      ),
                      const SizedBox(height: 12),
                      // Add location display
                      if (scannedLocation != null && scannedLocation.isNotEmpty)
                        _buildResultItem(
                          label: 'Scan Location',
                          value: scannedLocation,
                          icon: scannedLocation.contains('Outside') 
                              ? Icons.warning_rounded 
                              : Icons.location_on_rounded,
                          color: scannedLocation.contains('Outside') 
                              ? Colors.orange 
                              : Colors.teal,
                        ),
                      const SizedBox(height: 12),
                      _buildResultItem(
                        label: 'Scanned At',
                        value: attendance?.scannedAt != null
                            ? _formatDateTime(attendance.scannedAt)
                            : DateTime.now().toString().substring(0, 16),
                        icon: Icons.access_time_rounded,
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 12),
                      _buildResultItem(
                        label: 'Status',
                        value: attendance?.status?.toUpperCase() ?? 'PRESENT',
                        icon: Icons.check_circle_rounded,
                        color: Colors.green,
                      ),
                      
                      // Shortened warning message if outside UTAR
                      if (isOutside && !alreadyAttended) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_rounded, color: Colors.orange, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Recorded outside UTAR campus. This attendance will be flagged for review.',
                                  style: AppStyles.bodySmall.copyWith(
                                    color: Colors.orange.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
 
                // Buttons 
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _safePop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.getPrimaryColor(context),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'DONE',
                        style: AppStyles.buttonMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  /// Show error dialog
  void _showErrorDialog(Map<String, dynamic> result) {
    final error = result['error'] ?? 'Unknown error';
    final message = result['message'] ?? 'Failed to process attendance';
    final details = result['details'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.05,
            vertical: MediaQuery.of(context).size.height * 0.05,
          ),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Error Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFD32F2F), Color(0xFFC62828)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'ATTENDANCE FAILED',
                            style: AppStyles.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message,
                          style: AppStyles.titleSmall.copyWith(
                            color: AppColors.getTextPrimary(context),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getErrorMessage(error),
                          style: AppStyles.bodyMedium.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (details != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (details['scannedIndex'] != null)
                                  _buildDetailRow(
                                    'Scanned Index:',
                                    details['scannedIndex'].toString(),
                                  ),
                                if (details['registeredIndex'] != null) ...[
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    'Registered Index:',
                                    details['registeredIndex'].toString(),
                                  ),
                                ],
                                if (details['subjectName'] != null) ...[
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    'Exam:',
                                    details['subjectName'].toString(),
                                  ),
                                ],
                                if (details['scannedSubject'] != null) ...[
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    'Scanned Subject:',
                                    details['scannedSubject'].toString(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          if (mounted) {
                            setState(() {
                              _isCameraReady = true;
                              _isProcessing = false;
                            });
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: AppColors.getPrimaryColor(context),
                          ),
                        ),
                        child: Text(
                          'CLOSE',
                          style: AppStyles.buttonMedium.copyWith(
                            color: AppColors.getPrimaryColor(context),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

  /// Get error message based on error code
  String _getErrorMessage(String error) {
    switch (error) {
      case 'Index mismatch':
        return 'The scanned index number does not match your registered index.';
      case 'Not authorized':
        return 'You are not enrolled in this exam.';
      case 'Exam inactive':
        return 'This exam is no longer active.';
      case 'Exam not found':
        return 'Could not find an exam matching the scanned subject name.';
      case 'Subject not detected':
        return 'Could not detect subject name from the scanned image.';
      case 'Multiple exams found':
        return 'Multiple active exams found with the same subject name.';
      case 'Student not found':
        return 'Student record not found.';
      default:
        return 'Please try again or contact your instructor.';
    }
  }

  /// Build detail row for error dialog
  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppStyles.bodySmall.copyWith(
            color: AppColors.getTextSecondary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AppStyles.bodySmall.copyWith(
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Format DateTime to string
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ==================== BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return _buildProcessingPage();
    }

    if (_isCameraReady && _controller != null) {
      return _buildCameraPage();
    }

    return _buildEntryPage();
  }

  /// Build processing page with loading animation
  Widget _buildProcessingPage() {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;
            final isLandscape = screenWidth > screenHeight;
            
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Custom AppBar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingLarge,
                          vertical: AppDimensions.paddingMedium,
                        ),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.getPrimaryColor(context).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.arrow_back_rounded,
                                  color: AppColors.getPrimaryColor(context),
                                ),
                                onPressed: () => _safePop(context),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'PROCESSING',
                              style: AppStyles.titleLarge.copyWith(
                                color: AppColors.getPrimaryColor(context),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.all(
                              isLandscape ? 20 : 40,
                            ),
                            margin: EdgeInsets.symmetric(
                              horizontal: isLandscape 
                                  ? screenWidth * 0.15 
                                  : AppDimensions.paddingXLarge,
                              vertical: AppDimensions.paddingXLarge,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.getPrimaryColor(context).withOpacity(0.1),
                                  AppColors.getSecondaryColor(context).withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.getPrimaryColor(context).withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Animated icon
                                AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _pulseAnimation.value,
                                      child: Container(
                                        width: isLandscape ? 80 : 100,
                                        height: isLandscape ? 80 : 100,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.getPrimaryColor(context),
                                              AppColors.getSecondaryColor(context),
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.getPrimaryColor(context).withOpacity(0.3),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.qr_code_scanner_rounded,
                                            color: Colors.white,
                                            size: 50,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Processing HTR...',
                                  style: AppStyles.titleMedium.copyWith(
                                    color: AppColors.getTextPrimary(context),
                                    fontWeight: FontWeight.w600,
                                    fontSize: isLandscape ? 14 : 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'Please wait while we extract and verify information',
                                    style: AppStyles.bodyMedium.copyWith(
                                      color: AppColors.getTextSecondary(context),
                                      fontSize: isLandscape ? 12 : 14,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: isLandscape ? 150 : 200,
                                  child: LinearProgressIndicator(
                                    color: AppColors.getPrimaryColor(context),
                                    backgroundColor: AppColors.getPrimaryColor(context).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
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
        ),
      ),
    );
  }

  /// Build camera preview page
  Widget _buildCameraPage() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SCAN',
          style: AppStyles.titleLarge.copyWith(
            color: Colors.white, 
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () {
            if (mounted) {
              setState(() {
                _isCameraReady = false;
                _controller?.dispose();
                _controller = null;
              });
            }
          },
        ),
      ),
      body: Stack(
        children: [
          // Camera preview
          Center(
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: CameraPreview(_controller!),
            ),
          ),

          // Simple semi-transparent overlay with only text hint
          Positioned.fill(
            child: Container(
              color: Colors.transparent,
            ),
          ),

          // Bottom capture button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Simple instruction
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.cyanAccent.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.screen_rotation_rounded,
                        color: Colors.cyanAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hold phone horizontally',
                        style: AppStyles.bodySmall.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery button
                    GestureDetector(
                      onTap: () async {
                        final hasInternet = await _checkInternetConnection();
                        if (!hasInternet) return;
                        
                        final img = await _picker.pickImage(
                            source: ImageSource.gallery);
                        if (img != null) _processImage(img.path);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.photo_library_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),

                    // Capture button
                    GestureDetector(
                      onTap: () async {
                        final hasInternet = await _checkInternetConnection();
                        if (!hasInternet) return;
                        
                        if (_controller != null &&
                            _controller!.value.isInitialized) {
                          final img = await _controller!.takePicture();
                          _processImage(img.path);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 3,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: AppColors.getPrimaryColor(context),
                            size: 35,
                          ),
                        ),
                      ),
                    ),

                    // Placeholder for symmetry
                    const SizedBox(width: 60),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build entry page with scan options
  Widget _buildEntryPage() {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'SCAN',
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
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;
            final isLandscape = screenWidth > screenHeight;
            
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scan options card
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLandscape 
                              ? screenWidth * 0.1 
                              : AppDimensions.paddingXLarge,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: isLandscape ? 32 : 24,
                            vertical: isLandscape ? 20 : 24,
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
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(
                                  isLandscape ? 12 : 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.qr_code_scanner_rounded,
                                  color: Colors.white,
                                  size: isLandscape ? 40 : 50,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Scan Exam Slip',
                                      style: AppStyles.titleMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: isLandscape ? 16 : 18,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Position the exam slip within the frame',
                                      style: AppStyles.bodySmall.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: isLandscape ? 12 : 14,
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

                      const SizedBox(height: AppDimensions.paddingLarge),

                      // Scan options
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLandscape 
                              ? screenWidth * 0.1 
                              : AppDimensions.paddingXLarge,
                        ),
                        child: Column(
                          children: [
                            _buildScanOption(
                              context,
                              icon: Icons.camera_alt_rounded,
                              title: 'Take Photo',
                              description: 'Use camera to scan exam slip',
                              color: Colors.blue,
                              onTap: _initCamera,
                            ),
                            const SizedBox(height: AppDimensions.paddingLarge),
                            _buildScanOption(
                              context,
                              icon: Icons.photo_library_rounded,
                              title: 'Choose from Album',
                              description: 'Select an existing photo',
                              color: Colors.orange,
                              onTap: () async {
                                final hasInternet = await _checkInternetConnection();
                                if (!hasInternet) return;
                                
                                final img = await _picker.pickImage(
                                    source: ImageSource.gallery);
                                if (img != null) _processImage(img.path);
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppDimensions.paddingLarge),

                      // Scanning Tips
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLandscape 
                              ? screenWidth * 0.1 
                              : AppDimensions.paddingXLarge,
                          vertical: AppDimensions.paddingSmall,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.getCardBackground(context),
                            borderRadius: BorderRadius.circular(16),
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
                                    Icons.info_outline_rounded,
                                    color: AppColors.getPrimaryColor(context),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Scanning Tips',
                                    style: AppStyles.titleSmall.copyWith(
                                      color: AppColors.getTextPrimary(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildTipItem(
                                icon: Icons.crop_free_rounded,
                                text: 'Ensure the exam slip is well-lit',
                              ),
                              const SizedBox(height: 12),
                              _buildTipItem(
                                icon: Icons.screen_rotation_rounded,
                                text: 'Hold your phone horizontally',
                              ),
                              const SizedBox(height: 12),
                              _buildTipItem(
                                icon: Icons.photo_size_select_actual_rounded,
                                text: 'Make sure all text is clearly visible',
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
          },
        ),
      ),
    );
  }

  /// Build scan option card
  Widget _buildScanOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.getShadowColor(context).withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppStyles.titleMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.getTextSecondary(context),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// Build tip item for scanning tips section
  Widget _buildTipItem({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.getPrimaryColor(context).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: AppColors.getPrimaryColor(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppStyles.bodyMedium.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ),
      ],
    );
  }

  /// Build result item for success dialog
  Widget _buildResultItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
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
                  maxLines: 2,
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
