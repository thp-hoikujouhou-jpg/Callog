import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/localization_service.dart';
import '../models/call_recording.dart';
import 'call_history_screen.dart';
import 'daily_contacts_screen.dart';

class CalendarMemoScreen extends StatefulWidget {
  const CalendarMemoScreen({super.key});

  @override
  State<CalendarMemoScreen> createState() => _CalendarMemoScreenState();
}

class _CalendarMemoScreenState extends State<CalendarMemoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  Map<String, int> _callCountByDate = {}; // Date -> Call count
  
  @override
  void initState() {
    super.initState();
    _loadCallCounts();
  }
  
  /// Load call counts for current month
  Future<void> _loadCallCounts() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Get first and last day of current month
      final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
      
      // Query call recordings for current month
      final querySnapshot = await _firestore
          .collection('call_recordings')
          .where('userId', isEqualTo: user.uid)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(lastDay))
          .get();
      
      // Count calls per date
      final Map<String, int> counts = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final startTime = (data['timestamp'] as Timestamp?)?.toDate();
        if (startTime != null) {
          final dateKey = '${startTime.year}-${startTime.month}-${startTime.day}';
          counts[dateKey] = (counts[dateKey] ?? 0) + 1;
        }
      }
      
      setState(() {
        _callCountByDate = counts;
      });
      
      if (kDebugMode) {
        debugPrint('📅 [CalendarMemo] Loaded call counts: ${counts.length} days with calls');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [CalendarMemo] Error loading call counts: $e');
      }
    }
  }
  
  /// Get call count for specific date
  int _getCallCount(DateTime date) {
    final dateKey = '${date.year}-${date.month}-${date.day}';
    return _callCountByDate[dateKey] ?? 0;
  }
  
  /// Generate calendar grid for current month
  List<DateTime?> _generateCalendarDays() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    
    // Get day of week for first day (0 = Sunday)
    final firstWeekday = firstDayOfMonth.weekday % 7;
    
    List<DateTime?> days = [];
    
    // Add empty cells for days before first day of month
    for (int i = 0; i < firstWeekday; i++) {
      days.add(null);
    }
    
    // Add all days of month
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, day));
    }
    
    return days;
  }
  
  /// Navigate to previous month
  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadCallCounts();
  }
  
  /// Navigate to next month
  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadCallCounts();
  }
  
  /// Handle date tap - navigate to daily contacts screen
  void _onDateTap(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    
    // Navigate to daily contacts screen (show contact avatars with call history)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyContactsScreen(selectedDate: date),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final localService = Provider.of<LocalizationService>(context);
    final calendarDays = _generateCalendarDays();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localService.translate('calendar')),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CallHistoryScreen()),
              );
            },
            tooltip: localService.translate('call_history'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Month navigation header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              color: Colors.blue.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _previousMonth,
                    icon: const Icon(Icons.chevron_left, size: 32),
                  ),
                  Text(
                    _getMonthYearText(localService),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right, size: 32),
                  ),
                ],
              ),
            ),
            
            // Weekday headers
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _getWeekdayHeaders(localService),
              ),
            ),
            
            const Divider(height: 1),
            
            // Calendar grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: calendarDays.length,
                itemBuilder: (context, index) {
                  final date = calendarDays[index];
                  if (date == null) {
                    return Container(); // Empty cell
                  }
                  
                  final callCount = _getCallCount(date);
                  final isToday = _isToday(date);
                  final isSelected = _isSameDay(date, _selectedDate);
                  
                  return _buildCalendarCell(
                    date: date,
                    callCount: callCount,
                    isToday: isToday,
                    isSelected: isSelected,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build calendar cell widget
  Widget _buildCalendarCell({
    required DateTime date,
    required int callCount,
    required bool isToday,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _onDateTap(date),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.shade100
              : (isToday ? Colors.blue.shade50 : null),
          border: Border.all(
            color: isToday ? Colors.blue.shade600 : Colors.grey.shade300,
            width: isToday ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Date number
            Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? Colors.blue.shade600 : Colors.black87,
                ),
              ),
            ),
            
            // Call count indicator (if any)
            if (callCount > 0)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$callCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  /// Get month/year text based on locale
  String _getMonthYearText(LocalizationService localService) {
    final monthNames = {
      'en': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
      'ja': ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'],
      'ko': ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월'],
      'zh': ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'],
      'es': ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'],
      'fr': ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'],
    };
    
    final lang = localService.currentLanguage;
    final months = monthNames[lang] ?? monthNames['en']!;
    
    if (lang == 'ja' || lang == 'ko' || lang == 'zh') {
      return '${_currentMonth.year}年 ${months[_currentMonth.month - 1]}';
    } else {
      return '${months[_currentMonth.month - 1]} ${_currentMonth.year}';
    }
  }
  
  /// Get weekday headers
  List<Widget> _getWeekdayHeaders(LocalizationService localService) {
    final weekdays = {
      'en': ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
      'ja': ['日', '月', '火', '水', '木', '金', '土'],
      'ko': ['일', '월', '화', '수', '목', '금', '토'],
      'zh': ['日', '一', '二', '三', '四', '五', '六'],
      'es': ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'],
      'fr': ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'],
    };
    
    final lang = localService.currentLanguage;
    final days = weekdays[lang] ?? weekdays['en']!;
    
    return days.map((day) {
      return Expanded(
        child: Text(
          day,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      );
    }).toList();
  }
  
  /// Check if date is today
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
  
  /// Check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
