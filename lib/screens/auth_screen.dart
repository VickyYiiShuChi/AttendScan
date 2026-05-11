// auth_screen.dart
import 'package:flutter/material.dart';
import 'package:attend_scan/constants/app_colors.dart';
import 'package:attend_scan/constants/app_styles.dart';
import 'package:attend_scan/constants/app_dimensions.dart';
import 'login_page.dart';
import 'register_page.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _showLogin = true;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final paddingTop = MediaQuery.of(context).padding.top;
    final isLandscape = screenWidth > screenHeight;
    
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: Stack(
        children: [
          // Gradient background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.getBackgroundGradient(context),
              ),
            ),
          ),
          
          // Use LayoutBuilder for better responsive control
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        Container(
                          height: isLandscape ? 100 : 120, 
                          width: double.infinity,
                          padding: EdgeInsets.only(
                            top: paddingTop + (isLandscape ? 8 : 12),
                            left: AppDimensions.paddingXLarge,
                            right: AppDimensions.paddingXLarge,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Icon
                              Container(
                                margin: const EdgeInsets.only(right: 16),
                                child: Icon(
                                  _showLogin ? Icons.login_rounded : Icons.person_add_rounded,
                                  size: 32,
                                  color: AppColors.white,
                                ),
                              ),
                              
                              // Text Column
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _showLogin ? 'Welcome Back!' : 'Join Us!',
                                      style: AppStyles.headlineSmall.copyWith(
                                        fontSize: isLandscape ? 18 : 20,
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _showLogin ? 'Sign in to continue' : 'Create account',
                                      style: AppStyles.bodySmall.copyWith(
                                        color: AppColors.white.withOpacity(0.9),
                                        fontSize: isLandscape ? 11 : 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Bottom section - Rounded card form
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 600),
                            switchInCurve: Curves.fastOutSlowIn,
                            switchOutCurve: Curves.fastOutSlowIn,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            child: Container(
                              key: ValueKey(_showLogin),
                              decoration: BoxDecoration(
                                color: AppColors.getCardBackground(context),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(30),
                                  topRight: Radius.circular(30),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.getShadowColor(context).withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, -5),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(30),
                                  topRight: Radius.circular(30),
                                ),
                                child: _showLogin
                                    ? LoginPage(
                                        key: const ValueKey('login-page'),
                                        onSwitchToRegister: _toggleView,
                                      )
                                    : RegisterPage(
                                        key: const ValueKey('register-page'),
                                        onSwitchToLogin: _toggleView,
                                      ),
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
        ],
      ),
    );
  }

  // Toggle between login and register views
  void _toggleView() {
    setState(() {
      _showLogin = !_showLogin;
    });
  }
}