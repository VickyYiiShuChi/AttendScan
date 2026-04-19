// login_page.dart
import 'package:flutter/material.dart';
import 'package:attend_scan/constants/app_colors.dart';
import 'package:attend_scan/constants/app_styles.dart';
import 'package:attend_scan/constants/app_dimensions.dart';
import '../services/firebase_service.dart';
import 'student/main_navigation.dart';
import 'admin/admin_home_page.dart'; 
import 'package:attend_scan/services/local_storage_service.dart';
import 'package:attend_scan/services/sync_manager.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onSwitchToRegister;

  const LoginPage({
    super.key,
    required this.onSwitchToRegister,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for text fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Forgot password dialog controller
  final _resetEmailController = TextEditingController();
  
  // UI state variables
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isResettingPassword = false;

  // Dispose controllers when widget is removed
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  // Handle user login (supports both student and admin)
  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        // Use the new loginUser method that returns role information
        final result = await FirebaseService().loginUser(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        
        if (result['success'] == true) {
          // Save login status locally
          final localStorage = LocalStorageService();
          await localStorage.saveLoginStatus({
            'uid': result['uid'],
            'role': result['role'],
            'email': _emailController.text.trim(),
          });
          
          // Trigger background sync
          final syncManager = SyncManager();
          syncManager.syncInBackground();
          
          if (mounted) {
            if (result['role'] == 'admin') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminHomePage()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MainNavigation()),
              );
            }
          }
        } else {
          // Show error message
          _showSnackBar(result['message'] ?? 'Login failed');
        }
      } catch (e) {
        _showSnackBar('Error: $e', isError: true);
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // Handle password reset and notify user
  Future<void> _resetPassword() async {
    if (_resetEmailController.text.trim().isEmpty) {
      _showSnackBar('Please enter your email', isError: true);
      return;
    }
    
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(_resetEmailController.text.trim())) {
      _showSnackBar('Please enter a valid email', isError: true);
      return;
    }
    
    setState(() => _isResettingPassword = true);
    
    try {
      await FirebaseService().resetPassword(_resetEmailController.text.trim());
      
      Navigator.of(context).pop();
      _showSnackBar(
        'Password reset email sent! Check your inbox.',
        isError: false,
      );
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isResettingPassword = false);
      }
    }
  }

  // Show a snack bar message (error or info)
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError 
            ? Colors.red 
            : AppColors.getPrimaryColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // Show the forgot-password dialog to request reset email
  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
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
                // Header
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
                          Icons.lock_reset_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'RESET PASSWORD',
                        style: AppStyles.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
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
                    children: [
                      Text(
                        'Enter your email address and we\'ll send you a link to reset your password.',
                        style: AppStyles.bodyMedium.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      
                      // Email field
                      TextFormField(
                        controller: _resetEmailController,
                        keyboardType: TextInputType.emailAddress,
                        style: AppStyles.bodyLarge.copyWith(
                          color: AppColors.getTextPrimary(context),
                        ),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(
                            Icons.email_rounded,
                            color: AppColors.getTextHint(context),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.getTextHint(context).withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.getPrimaryColor(context),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isResettingPassword 
                              ? null 
                              : () => Navigator.of(context).pop(),
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
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isResettingPassword ? null : _resetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.getPrimaryColor(context),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isResettingPassword
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'SEND',
                                  style: AppStyles.buttonMedium.copyWith(
                                    color: Colors.white,
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
    ).then((_) {
      _resetEmailController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape = screenWidth > screenHeight;
    
    return Container(
      height: double.infinity,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: screenHeight * 0.7,
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 32.0 : AppDimensions.paddingXLarge,
                vertical: isLandscape ? 24.0 : AppDimensions.paddingXXLarge,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Form title
                  Text(
                    'Sign In',
                    style: AppStyles.headlineSmall.copyWith(
                      color: AppColors.getPrimaryColor(context),
                      fontSize: isLandscape ? 22 : 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Description text
                  Text(
                    'Enter your credentials to continue',
                    style: AppStyles.bodyMedium.copyWith(
                      color: AppColors.getTextSecondary(context),
                      fontSize: isLandscape ? 12 : 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.paddingLarge),
                  
                  // Login form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email field
                        _buildTextField(
                          context: context,
                          controller: _emailController,
                          labelText: 'Email Address',
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          isLandscape: isLandscape,
                        ),
                        const SizedBox(height: AppDimensions.paddingMedium),
                        
                        // Password field
                        _buildTextField(
                          context: context,
                          controller: _passwordController,
                          labelText: 'Password',
                          icon: Icons.lock_rounded,
                          isPassword: true,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppColors.getTextHint(context),
                              size: 20,
                            ),
                            onPressed: _togglePasswordVisibility,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          validator: _validatePassword,
                          isLandscape: isLandscape,
                        ),
                        const SizedBox(height: AppDimensions.paddingSmall),
                        
                        // Forgot password link
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Forgot Password?',
                              style: AppStyles.bodySmall.copyWith(
                                color: AppColors.getPrimaryColor(context),
                                fontWeight: FontWeight.w500,
                                fontSize: isLandscape ? 11 : 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.paddingMedium),
                        
                        // Login button
                        SizedBox(
                          height: isLandscape ? 44 : AppDimensions.buttonHeightLarge,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.getPrimaryColor(context),
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.borderRadiusLarge,
                                ),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Sign In',
                                    style: AppStyles.buttonMedium.copyWith(
                                      fontSize: isLandscape ? 14 : 16,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: AppDimensions.paddingLarge),
                  
                  // Divider with "Or" text
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppColors.getTextHint(context).withOpacity(0.3),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Or',
                          style: AppStyles.bodySmall.copyWith(
                            color: AppColors.getTextHint(context),
                            fontSize: isLandscape ? 11 : 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppColors.getTextHint(context).withOpacity(0.3),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppDimensions.paddingMedium),
                  
                  // Switch to register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: AppStyles.bodySmall.copyWith(
                          color: AppColors.getTextSecondary(context),
                          fontSize: isLandscape ? 11 : 12,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onSwitchToRegister,
                        child: Text(
                          'Sign Up',
                          style: AppStyles.bodySmall.copyWith(
                            color: AppColors.getPrimaryColor(context),
                            fontWeight: FontWeight.bold,
                            fontSize: isLandscape ? 11 : 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Bottom padding
                  const SizedBox(height: AppDimensions.paddingMedium),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build a styled text form field
  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    required bool isLandscape,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: AppStyles.bodyMedium.copyWith(
        color: AppColors.getTextPrimary(context),
        fontSize: isLandscape ? 13 : 14,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: AppStyles.bodySmall.copyWith(
          color: AppColors.getTextHint(context),
          fontSize: isLandscape ? 11 : 12,
        ),
        floatingLabelStyle: AppStyles.bodySmall.copyWith(
          color: AppColors.getPrimaryColor(context),
          fontSize: isLandscape ? 11 : 12,
        ),
        prefixIcon: Icon(
          icon,
          color: AppColors.getTextHint(context),
          size: isLandscape ? 18 : 20,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.getInputBackground(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppDimensions.borderRadiusLarge,
          ),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppDimensions.borderRadiusLarge,
          ),
          borderSide: BorderSide(
            color: AppColors.getPrimaryColor(context),
            width: 1.5,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 14 : 20,
          vertical: isLandscape ? 12 : 18,
        ),
        isDense: true,
      ),
    );
  }

  /// Toggle password visibility
  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  /// Validate email format
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  /// Validate password
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Min 6 characters';
    }
    return null;
  }
}