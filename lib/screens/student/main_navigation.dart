// lib/screens/student/main_navigation.dart
import 'package:flutter/material.dart';
import 'package:attend_scan/constants/app_colors.dart';
import 'home_page.dart';
import 'scan_page.dart';
import 'records_page.dart';
import 'profile_page.dart';

// Bottom navigation hosting main student pages (home, scan, records, profile)
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  
  // Use Keys to force rebuild pages
  Key _homeKey = UniqueKey();
  Key _recordsKey = UniqueKey();
  Key _profileKey = UniqueKey();

  // Handle bottom navigation item taps and optionally force rebuilds
  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
      
      // When switching to a page, update its key to force rebuild
      if (index == 0) {
        _homeKey = UniqueKey();
      } else if (index == 2) {
        _recordsKey = UniqueKey();
      } else if (index == 3) {
        _profileKey = UniqueKey();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomePage(key: _homeKey),
          const ScanPage(),
          RecordsPage(key: _recordsKey),
          ProfilePage(key: _profileKey),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.getCardBackground(context),
        selectedItemColor: AppColors.getPrimaryColor(context),
        unselectedItemColor: AppColors.getTextSecondary(context),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_rounded),
            label: 'Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}