import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/localization_service.dart';
import '../models/call_recording.dart';
import '../models/sticky_note.dart';
import '../theme/modern_ui_theme.dart';
import 'contact_sticky_notes_screen.dart';

class DailyContactsScreen extends StatefulWidget {
  final DateTime selectedDate;
  
  const DailyContactsScreen({
    super.key,
    required this.selectedDate,
  });

  @override
  State<DailyContactsScreen> createState() => _DailyContactsScreenState();
}

class _DailyContactsScreenState extends State<DailyContactsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<_ContactInfo> _contacts = [];
  bool _isLoading = true;
  Set<String> _contactsWithNotes = {};  // Track which contacts have sticky notes
  
  @override
  void initState() {
    super.initState();
    // CRITICAL: Force logging to console (ignore kDebugMode)
    print('🚀 [DailyContacts] initState called - Loading contacts...');
    print('📅 [DailyContacts] Selected date: ${widget.selectedDate}');
    _loadDailyContacts();
  }
  
  /// Load contacts who had calls on selected date
  Future<void> _loadDailyContacts() async {
    print('⏳ [DailyContacts] _loadDailyContacts() method started');
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ [DailyContacts] No user logged in');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      print('🔍 [DailyContacts] Loading contacts for userId: ${user.uid}');
      print('📅 [DailyContacts] Query date: ${widget.selectedDate}');
      
      // Get start and end of selected date
      final startOfDay = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
      );
      final endOfDay = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        23,
        59,
        59,
      );
      
      print('🕐 [DailyContacts] Query range:');
      print('   Start: $startOfDay');
      print('   End: $endOfDay');
      
      // Query sticky notes for selected date
      // CRITICAL FIX: Use sticky_notes instead of call_recordings to get contact info
      print('🔍 [DailyContacts] Executing Firestore query...');
      final querySnapshot = await _firestore
          .collection('sticky_notes')
          .where('userId', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
      
      print('📦 [DailyContacts] Query returned ${querySnapshot.docs.length} sticky notes');
      
      if (querySnapshot.docs.isEmpty) {
        print('⚠️ [DailyContacts] No sticky notes found for this date!');
        print('💡 [DailyContacts] Check Firestore:');
        print('   - Collection: sticky_notes');
        print('   - Field: userId = ${user.uid}');
        print('   - Field: date range: $startOfDay to $endOfDay');
      } else {
        print('✅ [DailyContacts] Found ${querySnapshot.docs.length} sticky notes:');
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          print('   📝 Note ID: ${doc.id}');
          print('      contactId: ${data['contactId']}');
          print('      contactName: ${data['contactName']}');
          print('      contactPhotoUrl: ${data['contactPhotoUrl']}');
          print('      date: ${data['date']}');
        }
      }
      
      // Group by contact (using data from sticky_notes directly)
      final Map<String, _ContactInfo> contactMap = {};
      
      print('🔄 [DailyContacts] Processing ${querySnapshot.docs.length} notes...');
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        
        // Get contact information from sticky note (already complete!)
        final contactId = data['contactId'] as String? ?? 'unknown';
        final contactName = data['contactName'] as String? ?? 'Unknown';
        final contactPhotoUrl = data['contactPhotoUrl'] as String?;
        
        print('   📝 Processing note: contactId=$contactId, name=$contactName, photoUrl=$contactPhotoUrl');
        
        if (contactMap.containsKey(contactId)) {
          // Contact already exists, increment sticky note count
          contactMap[contactId]!.noteCount++;
          print('      → Existing contact, count now: ${contactMap[contactId]!.noteCount}');
        } else {
          // New contact, add to map
          contactMap[contactId] = _ContactInfo(
            contactId: contactId,
            contactName: contactName,
            contactPhotoUrl: contactPhotoUrl,
            noteCount: 1,
            recordings: [], // Not used anymore
          );
          print('      → New contact added');
        }
      }
      
      print('✅ [DailyContacts] Processing complete, setting state...');
      
      setState(() {
        _contacts = contactMap.values.toList();
        _isLoading = false;
      });
      
      print('📱 [DailyContacts] Loaded ${_contacts.length} contacts');
      print('👥 [DailyContacts] Contact details:');
      for (var contact in _contacts) {
        print('   - ${contact.contactName}: ${contact.noteCount} notes, photoUrl: ${contact.contactPhotoUrl}');
      }
      
      // Mark all contacts as having sticky notes (since we query from sticky_notes)
      setState(() {
        _contactsWithNotes = contactMap.keys.toSet();
      });
      
      print('📝 [DailyContacts] All ${_contactsWithNotes.length} contacts marked with sticky notes');
    } catch (e, stackTrace) {
      print('❌ [DailyContacts] ERROR loading contacts: $e');
      print('📚 [DailyContacts] Stack trace: $stackTrace');
      
      // Check for common errors
      if (e.toString().contains('requires an index')) {
        print('🔥 [DailyContacts] FIRESTORE INDEX REQUIRED!');
        print('💡 [DailyContacts] Open Firebase Console and create composite index');
        print('   Collection: sticky_notes');
        print('   Fields: userId (Ascending), date (Ascending)');
      } else if (e.toString().contains('Missing or insufficient permissions')) {
        print('🔥 [DailyContacts] SECURITY RULES BLOCKING QUERY!');
        print('💡 [DailyContacts] Update Firestore rules:');
        print('   allow read: if request.auth != null;');
      }
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // REMOVED: _checkStickyNotes() - No longer needed since we query sticky_notes directly
  // REMOVED: _getContactName() - Contact name comes from sticky_notes.contactName
  // REMOVED: _getContactPhotoUrl() - Photo URL comes from sticky_notes.contactPhotoUrl
  
  /// Handle contact tap - navigate to sticky note editor
  Future<void> _onContactTap(_ContactInfo contact) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    // Check if sticky note already exists for this contact on this date
    StickyNote? existingNote;
    try {
      final startOfDay = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final querySnapshot = await _firestore
          .collection('sticky_notes')
          .where('userId', isEqualTo: user.uid)
          .where('contactId', isEqualTo: contact.contactId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        existingNote = StickyNote.fromFirestore(
          querySnapshot.docs.first.data(),
          querySnapshot.docs.first.id,
        );
        
        if (kDebugMode) {
          debugPrint('📝 [DailyContacts] Found existing note for ${contact.contactName}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [DailyContacts] Error checking existing note: $e');
      }
    }
    
    // Navigate to contact's sticky notes screen (filtered by selected date)
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactStickyNotesScreen(
          contactId: contact.contactId,
          contactName: contact.contactName,
          contactPhotoUrl: contact.contactPhotoUrl,
          selectedDate: widget.selectedDate,  // CRITICAL FIX: Pass selected date for filtering
        ),
      ),
    );
    
    // Reload contacts after returning from sticky note editor
    if (mounted) {
      if (kDebugMode) {
        debugPrint('🔄 [DailyContacts] Reloading contacts after returning');
      }
      await _loadDailyContacts();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('🎨 [DailyContacts] build() called - _isLoading: $_isLoading, _contacts.length: ${_contacts.length}');
    }
    
    final localService = Provider.of<LocalizationService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _formatDate(localService),
          style: ModernUITheme.headingMedium.copyWith(color: ModernUITheme.textWhite),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: ModernUITheme.primaryGradient)),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: ModernUITheme.backgroundGradient),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _contacts.isEmpty
                ? _buildEmptyState(localService)
                : _buildContactList(),
      ),
    );
  }
  
  
  /// Build empty state
  Widget _buildEmptyState(LocalizationService localService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone_disabled,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            localService.translate('no_calls_on_this_day'),
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build contact list
  Widget _buildContactList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return _buildContactCard(contact);
      },
    );
  }
  
  /// Build contact card
  Widget _buildContactCard(_ContactInfo contact) {
    if (kDebugMode) {
      debugPrint('🎨 [DailyContacts] Building card for ${contact.contactName}, photoUrl: ${contact.contactPhotoUrl}, hasNote: ${_contactsWithNotes.contains(contact.contactId)}');
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ModernUITheme.glassContainer(opacity: 0.15),
      child: InkWell(
        onTap: () => _onContactTap(contact),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Contact avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blue.shade100,
                backgroundImage: contact.contactPhotoUrl != null && contact.contactPhotoUrl!.isNotEmpty
                    ? NetworkImage(contact.contactPhotoUrl!)
                    : null,
                child: contact.contactPhotoUrl == null
                    ? Text(
                        contact.contactName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              
              // Contact info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.contactName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        final localService = Provider.of<LocalizationService>(context, listen: false);
                        final noteWord = contact.noteCount == 1 
                          ? localService.translate('note_singular')
                          : localService.translate('notes_plural');
                        return Text(
                          '${contact.noteCount} $noteWord',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ),
              
              // Sticky note indicator (if contact has a note)
              if (_contactsWithNotes.contains(contact.contactId)) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.note,
                    size: 20,
                    color: Colors.amber.shade700,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              
              // Arrow icon
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Format date based on locale
  String _formatDate(LocalizationService localService) {
    final monthNames = {
      'en': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
      'ja': ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'],
      'ko': ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월'],
      'zh': ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'],
      'es': ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'],
      'fr': ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'],
    };
    
    final lang = localService.currentLanguage;
    final year = widget.selectedDate.year;
    final month = widget.selectedDate.month;
    final day = widget.selectedDate.day;
    
    // Language-specific date formatting
    switch (lang) {
      case 'ja':
        // Japanese: 2025年12月10日
        return '${year}年${month}月${day}日';
        
      case 'ko':
        // Korean: 2025년 12월 10일
        return '${year}년 ${month}월 ${day}일';
        
      case 'zh':
        // Chinese: 2025年12月10日
        return '${year}年${month}月${day}日';
        
      case 'es':
        // Spanish: 10 de diciembre de 2025
        final monthNames = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 
                           'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
        return '$day de ${monthNames[month - 1]} de $year';
        
      case 'fr':
        // French: 10 décembre 2025
        final monthNames = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin',
                           'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
        return '$day ${monthNames[month - 1]} $year';
        
      default:
        // English: December 10, 2025
        final monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                           'July', 'August', 'September', 'October', 'November', 'December'];
        return '${monthNames[month - 1]} $day, $year';
    }
  }
}

/// Helper class to store contact information from sticky notes
class _ContactInfo {
  final String contactId;
  final String contactName;
  final String? contactPhotoUrl;
  int noteCount;  // Number of sticky notes for this contact
  final List<CallRecording> recordings;  // Kept for backward compatibility
  
  _ContactInfo({
    required this.contactId,
    required this.contactName,
    this.contactPhotoUrl,
    required this.noteCount,
    required this.recordings,
  });
}
