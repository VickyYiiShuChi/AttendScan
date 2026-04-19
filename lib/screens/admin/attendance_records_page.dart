// Platform-aware export for attendance records (mobile vs web)
export 'attendance_records_page_mobile.dart'
    if (dart.library.html) 'attendance_records_page_web.dart';