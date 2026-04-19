// register_page.dart
import 'package:flutter/material.dart';
import 'package:attend_scan/constants/app_colors.dart';
import 'package:attend_scan/constants/app_styles.dart';
import 'package:attend_scan/constants/app_dimensions.dart';
import '../services/firebase_service.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback onSwitchToLogin;

  const RegisterPage({
    super.key,
    required this.onSwitchToLogin,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Handle student registration and provide user feedback
  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        // Use the new registerStudent method
        String? result = await FirebaseService().registerStudent(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _nameController.text.trim(),
          studentId: _studentIdController.text.trim(),
        );
        
        if (result == 'Success') {
          // Show success message
          if (!mounted) return;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '🎉 Registration successful! Please login.',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Wait a moment then switch to login
          await Future.delayed(const Duration(milliseconds: 2000));
          
          if (mounted) {
            widget.onSwitchToLogin();
          }
        } else {
          // Show error message
          if (!mounted) return;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(result ?? 'Registration failed')),
                ],
              ),
              backgroundColor: AppColors.getPrimaryColor(context),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: $e')),
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
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
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
            minHeight: screenHeight * 0.8,
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 32.0 : AppDimensions.paddingXLarge,
                vertical: isLandscape ? 16.0 : AppDimensions.paddingLarge,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Register title
                  Text(
                    'Create Account',
                    style: AppStyles.headlineSmall.copyWith(
                      color: AppColors.getSecondaryColor(context),
                      fontSize: isLandscape ? 22 : 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Text(
                    'Fill in your details to get started',
                    style: AppStyles.bodyMedium.copyWith(
                      color: AppColors.getTextSecondary(context),
                      fontSize: isLandscape ? 12 : 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.paddingLarge),
                  
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Full Name
                        _buildTextField(
                          context: context,
                          controller: _nameController,
                          labelText: 'Full Name',
                          icon: Icons.person_rounded,
                          validator: _validateName,
                          isLandscape: isLandscape,
                        ),
                        const SizedBox(height: AppDimensions.paddingMedium),
                        
                        // Student ID
                        _buildTextField(
                          context: context,
                          controller: _studentIdController,
                          labelText: 'Student ID',
                          icon: Icons.badge_rounded,
                          validator: _validateStudentId,
                          isLandscape: isLandscape,
                        ),
                        const SizedBox(height: AppDimensions.paddingMedium),
                        
                        // Email
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
                        
                        // Password
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
                        const SizedBox(height: AppDimensions.paddingMedium),
                        
                        // Confirm Password
                        _buildTextField(
                          context: context,
                          controller: _confirmPasswordController,
                          labelText: 'Confirm Password',
                          icon: Icons.lock_reset_rounded,
                          isPassword: true,
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppColors.getTextHint(context),
                              size: 20,
                            ),
                            onPressed: _toggleConfirmPasswordVisibility,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          validator: _validateConfirmPassword,
                          isLandscape: isLandscape,
                        ),
                        const SizedBox(height: AppDimensions.paddingLarge),
                        
                        // Register button
                        SizedBox(
                          height: isLandscape ? 44 : AppDimensions.buttonHeightLarge,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.getSecondaryColor(context),
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
                                    'Create Account',
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
                  
                  // Divider
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
                  
                  // Switch to login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: AppStyles.bodySmall.copyWith(
                          color: AppColors.getTextSecondary(context),
                          fontSize: isLandscape ? 11 : 12,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onSwitchToLogin,
                        child: Text(
                          'Sign In',
                          style: AppStyles.bodySmall.copyWith(
                            color: AppColors.getSecondaryColor(context),
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
          color: AppColors.getSecondaryColor(context),
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
            color: AppColors.getSecondaryColor(context),
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

  /// Toggle confirm password visibility
  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  /// Validate name
  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    return null;
  }

  /// Validate student ID
  String? _validateStudentId(String? value) {
    if (value == null || value.isEmpty) {
      return 'Student ID is required';
    }
    return null;
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

  /// Validate confirm password
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }
}