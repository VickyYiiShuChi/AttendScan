// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';

class LocationService {
  // UTAR Kampar Campus approximate boundaries
  static const double utarKamparLatMin = 4.3130;
  static const double utarKamparLatMax = 4.3230;
  static const double utarKamparLngMin = 101.1380;
  static const double utarKamparLngMax = 101.1480;

  // testing
  // static const double utarKamparLatMin = 4.3000;  
  // static const double utarKamparLatMax = 4.3400; 
  // static const double utarKamparLngMin = 101.1200; 
  // static const double utarKamparLngMax = 101.1550; 
  
  // UTAR Sungai Long Campus
  static const double utarSgLongLatMin = 3.0450;
  static const double utarSgLongLatMax = 3.0550;
  static const double utarSgLongLngMin = 101.7850;
  static const double utarSgLongLngMax = 101.7950;

  // testing
  // static const double utarSgLongLatMin = 4.3000; 
  // static const double utarSgLongLatMax = 4.3400; 
  // static const double utarSgLongLngMin = 101.1200; 
  // static const double utarSgLongLngMax = 101.1550; 
  
  /// Check if coordinates are within UTAR campus
  static bool isWithinUtarCampus(double latitude, double longitude) {
    // Check Kampar Campus
    if (latitude >= utarKamparLatMin && latitude <= utarKamparLatMax &&
        longitude >= utarKamparLngMin && longitude <= utarKamparLngMax) {
      return true;
    }
    
    // Check Sungai Long Campus
    if (latitude >= utarSgLongLatMin && latitude <= utarSgLongLatMax &&
        longitude >= utarSgLongLngMin && longitude <= utarSgLongLngMax) {
      return true;
    }
    
    return false;
  }
  
  /// Get campus name based on coordinates
  static String getCampusName(double latitude, double longitude) {
    if (latitude >= utarKamparLatMin && latitude <= utarKamparLatMax &&
        longitude >= utarKamparLngMin && longitude <= utarKamparLngMax) {
      return 'UTAR Kampar Campus';
    }
    
    if (latitude >= utarSgLongLatMin && latitude <= utarSgLongLatMax &&
        longitude >= utarSgLongLngMin && longitude <= utarSgLongLngMax) {
      return 'UTAR Sungai Long Campus';
    }
    
    return 'Outside UTAR Campus';
  }
  
  /// Get simplified location string (just campus name or "Outside UTAR")
  static String getSimplifiedLocation(double latitude, double longitude) {
    if (isWithinUtarCampus(latitude, longitude)) {
      return getCampusName(latitude, longitude);
    }
    return 'Outside UTAR Campus';
  }
  
  /// Check if user is within UTAR campus (async version with permission handling)
  static Future<bool> checkIfWithinUtarCampus() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return false;
      
      Position position = await Geolocator.getCurrentPosition();
      return isWithinUtarCampus(position.latitude, position.longitude);
    } catch (e) {
      return false;
    }
  }
}