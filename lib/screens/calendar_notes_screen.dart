import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/localization_service.dart';

class CalendarNotesScreen extends StatefulWidget {
  const CalendarNotesScreen({super.key});

  @override
  State<CalendarNotesScreen> createState() => _CalendarNotesScreenState();
}

class _CalendarNotesScreenState extends State<CalendarNotesScreen> {
  DateTime _selectedDate = DateTime.now();

  String _getLocalizedDateFormat(String languageCode) {
    switch (languageCode) {
      case 'ja':
        return 'ja';
      case 'ko':
        return 'ko';
      case 'zh':
        return 'zh';
      case 'es':
        return 'es';
      case 'fr':
        return 'fr';
      default:
        return 'en';
    }
  }

  String _formatDate(DateTime date, String pattern, String locale) {
    try {
      // Use simple locale code instead of locale_COUNTRY format
      return DateFormat(pattern, locale).format(date);
    } catch (e) {
      // If locale-specific formatting fails, use custom formatting
      return _customFormatDate(date, pattern, locale);
    }
  }

  String _customFormatDate(DateTime date, String pattern, String locale) {
    final months = _getMonthNames(locale);
    
    if (pattern == 'yMMMM') {
      return '${months[date.month - 1]} ${date.year}';
    } else if (pattern == 'yMMMd') {
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } else if (pattern == 'MMMd') {
      return '${months[date.month - 1]} ${date.day}';
    }
    
    // Fallback to basic format
    return '${date.year}/${date.month}/${date.day}';
  }

  List<String> _getMonthNames(String locale) {
    switch (locale) {
      case 'ja':
        return ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
      case 'ko':
        return ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월'];
      case 'zh':
        return ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
      case 'es':
        return ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
      case 'fr':
        return ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
      default:
        return ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final localService = Provider.of<LocalizationService>(context);
    final locale = _getLocalizedDateFormat(localService.currentLanguage);

    return Scaffold(
      appBar: AppBar(
        title: Text(localService.translate('calendar')),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedDate = DateTime(
                          _selectedDate.year,
                          _selectedDate.month - 1,
                        );
                      });
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    _formatDate(_selectedDate, 'yMMMM', locale),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedDate = DateTime(
                          _selectedDate.year,
                          _selectedDate.month + 1,
                        );
                      });
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_note,
                      size: 80,
                      color: Colors.blue.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      localService.translate('meeting_notes'),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${localService.translate('no_notes_for')} ${_formatDate(_selectedDate, 'yMMMd', locale)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.blue.shade600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${localService.translate('add_note_for')} ${_formatDate(_selectedDate, 'MMMd', locale)}'),
            ),
          );
        },
        backgroundColor: Colors.blue.shade600,
        child: const Icon(Icons.add),
      ),
    );
  }
}
