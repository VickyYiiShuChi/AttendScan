// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:attend_scan/constants/app_colors.dart';
import 'package:attend_scan/constants/app_styles.dart';
import 'package:attend_scan/screens/auth_screen.dart';
import 'package:attend_scan/providers/theme_provider.dart';
import 'package:attend_scan/services/local_storage_service.dart';
import 'package:attend_scan/services/connectivity_service.dart';
import 'package:attend_scan/services/sync_manager.dart';
import 'package:attend_scan/screens/admin/admin_home_page.dart';
import 'package:attend_scan/screens/student/main_navigation.dart';
import 'package:attend_scan/services/notification_service.dart'; 
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:attend_scan/screens/splash_screen.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// App entry: initialize Firebase and core services, then run the app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print("Firebase initialized on Web!");
    } else {
      await Firebase.initializeApp();
      print("Firebase initialized on Mobile!");
    }
  } catch (e) {
    print("Firebase initialization error: $e");
  }

  // Initialize local storage
  final localStorage = LocalStorageService();
  await localStorage.init();
  
  // Initialize connectivity listener
  final connectivity = ConnectivityService();
  await connectivity.init();
  
  // Initialize sync manager
  final syncManager = SyncManager();
  await syncManager.init();
  
  // Initialize notification service
  await NotificationService().init();

  // Attempt to sync any pending offline operations on startup
  _syncPendingOperations(localStorage);
  
  // Start periodic background sync (every 5 minutes)
  _startPeriodicSync(localStorage);

  // Launch the Flutter application with providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => connectivity),
        ChangeNotifierProvider(create: (context) => syncManager),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Build app theme and initial route based on saved login
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        
        return MaterialApp(
          title: 'AttendScan',
          debugShowCheckedModeBanner: false,
          navigatorObservers: [routeObserver], 
          theme: ThemeData(
            useMaterial3: true,
            primaryColor: isDarkMode ? AppColors.primaryDark : AppColors.primary,
            colorScheme: ColorScheme.fromSeed(
              seedColor: isDarkMode ? AppColors.primaryDark : AppColors.primary,
              brightness: isDarkMode ? Brightness.dark : Brightness.light,
            ),
            scaffoldBackgroundColor: isDarkMode ? AppColors.backgroundDark : AppColors.background,
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(50),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDarkMode ? AppColors.inputBackgroundDark : AppColors.inputBackground,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? AppColors.primaryDark : AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: AppStyles.buttonLarge,
              ),
            ),
            textTheme: TextTheme(
              displayLarge: AppStyles.headlineLarge.copyWith(
                color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textLight,
              ),
              displayMedium: AppStyles.headlineMedium.copyWith(
                color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
              displaySmall: AppStyles.headlineSmall.copyWith(
                color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
              titleLarge: AppStyles.titleLarge.copyWith(
                color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
              titleMedium: AppStyles.titleMedium.copyWith(
                color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
              titleSmall: AppStyles.titleSmall.copyWith(
                color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
              bodyLarge: AppStyles.bodyLarge.copyWith(
                color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
              bodyMedium: AppStyles.bodyMedium.copyWith(
                color: isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
              bodySmall: AppStyles.bodySmall.copyWith(
                color: isDarkMode ? AppColors.textHintDark : AppColors.textHint,
              ),
              labelLarge: AppStyles.buttonLarge.copyWith(color: AppColors.white),
              labelMedium: AppStyles.buttonMedium.copyWith(color: AppColors.white),
            ),
          ),
          home: const SplashScreen(),
          routes: {
            '/auth': (context) => const AuthScreen(),
            '/student_home': (context) => const MainNavigation(),
            '/admin_home': (context) => const AdminHomePage(),
          },
        );
      },
    );
  }
}
// Check and sync any pending offline operations a short time after startup
void _syncPendingOperations(LocalStorageService storage) async {
  // Delay execution by 2 seconds so startup isn't blocked
  Future.delayed(const Duration(seconds: 2), () async {
    final hasInternet = await ConnectivityService.checkInternet();
    if (hasInternet) {
      await storage.syncPendingOperations();
    } else {
      print('No network — skipping sync');
    }
  });
  
  // Add another delayed sync after 10 seconds to ensure network stability
  Future.delayed(const Duration(seconds: 10), () async {
    final hasInternet = await ConnectivityService.checkInternet();
    if (hasInternet) {
      await storage.syncPendingOperations();
    }
  });
}

// Start periodic background sync (every 5 minutes)
void _startPeriodicSync(LocalStorageService storage) {
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    final hasInternet = await ConnectivityService.checkInternet();
    if (hasInternet) {
      await storage.syncPendingOperations();
    }
  });
}