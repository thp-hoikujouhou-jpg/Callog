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
        return 'ja_JP';
      case 'ko':
        return 'ko_KR';
      case 'zh':
        return 'zh_CN';
      case 'es':
        return 'es_ES';
      case 'fr':
        return 'fr_FR';
      default:
        return 'en_US';
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
                    DateFormat.yMMMM(locale).format(_selectedDate),
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
                      '${localService.translate('no_notes_for')} ${DateFormat.yMMMd(locale).format(_selectedDate)}',
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
              content: Text('${localService.translate('add_note_for')} ${DateFormat.MMMd(locale).format(_selectedDate)}'),
            ),
          );
        },
        backgroundColor: Colors.blue.shade600,
        child: const Icon(Icons.add),
      ),
    );
  }
}
