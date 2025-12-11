import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/localization_service.dart';
import '../models/call_recording.dart';
import '../models/sticky_note.dart';
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
    _loadDailyContacts();
  }
  
  /// Load contacts who had calls on selected date
  Future<void> _loadDailyContacts() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
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
      
      // Query call recordings for selected date
      final querySnapshot = await _firestore
          .collection('call_recordings')
          .where('userId', isEqualTo: user.uid)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
      
      // Group by contact
      final Map<String, _ContactInfo> contactMap = {};
      
      for (var doc in querySnapshot.docs) {
        final recording = CallRecording.fromMap(doc.data(), doc.id);
        
        // Get contact ID (other participant)
        final contactId = recording.callPartner ?? 'unknown';
        
        if (contactMap.containsKey(contactId)) {
          contactMap[contactId]!.callCount++;
          contactMap[contactId]!.recordings.add(recording);
        } else {
          // Fetch contact display name
          final contactName = await _getContactName(contactId);
          final contactPhotoUrl = await _getContactPhotoUrl(contactId);
          
          contactMap[contactId] = _ContactInfo(
            contactId: contactId,
            contactName: contactName,
            contactPhotoUrl: contactPhotoUrl,
            callCount: 1,
            recordings: [recording],
          );
        }
      }
      
      setState(() {
        _contacts = contactMap.values.toList();
        _isLoading = false;
      });
      
      if (kDebugMode) {
        debugPrint('📱 [DailyContacts] Loaded ${_contacts.length} contacts for ${widget.selectedDate}');
      }
      
      // Check which contacts have sticky notes
      _checkStickyNotes();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DailyContacts] Error loading contacts: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Check which contacts have sticky notes
  Future<void> _checkStickyNotes() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      final startOfDay = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final querySnapshot = await _firestore
          .collection('sticky_notes')
          .where('userId', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
      
      final contactsWithNotes = <String>{};
      for (var doc in querySnapshot.docs) {
        final contactId = doc.data()['contactId'] as String?;
        if (contactId != null) {
          contactsWithNotes.add(contactId);
        }
      }
      
      setState(() {
        _contactsWithNotes = contactsWithNotes;
      });
      
      if (kDebugMode) {
        debugPrint('📝 [DailyContacts] Found ${contactsWithNotes.length} contacts with sticky notes');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [DailyContacts] Error checking sticky notes: $e');
      }
    }
  }
  
  /// Get contact display name
  Future<String> _getContactName(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['username'] ?? data?['name'] ?? userId;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DailyContacts] Error fetching contact name: $e');
      }
    }
    return userId;
  }
  
  /// Get contact photo URL
  Future<String?> _getContactPhotoUrl(String userId) async {
    try {
      if (kDebugMode) {
        debugPrint('🔍 [DailyContacts] Fetching photo URL for userId: $userId');
      }
      
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (kDebugMode) {
        debugPrint('📄 [DailyContacts] User doc exists: ${doc.exists}');
      }
      
      if (doc.exists) {
        final data = doc.data();
        final photoUrl = data?['photoUrl'] as String?;
        
        if (kDebugMode) {
          debugPrint('📸 [DailyContacts] Photo URL for $userId: $photoUrl');
        }
        
        return photoUrl;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DailyContacts] Error fetching photo URL: $e');
      }
    }
    return null;
  }
  
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
    
    // Navigate to contact's sticky notes screen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactStickyNotesScreen(
          contactId: contact.contactId,
          contactName: contact.contactName,
          contactPhotoUrl: contact.contactPhotoUrl,
        ),
      ),
    );
    
    // Reload sticky notes indicators after returning
    if (mounted) {
      if (kDebugMode) {
        debugPrint('🔄 [DailyContacts] Reloading sticky notes after returning');
      }
      await _checkStickyNotes();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final localService = Provider.of<LocalizationService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_formatDate(localService)),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? _buildEmptyState(localService)
              : _buildContactList(),
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
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _onContactTap(contact),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Contact avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blue.shade100,
                backgroundImage: contact.contactPhotoUrl != null
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
                        final callWord = contact.callCount == 1 
                          ? localService.translate('call_singular')
                          : localService.translate('calls_plural');
                        return Text(
                          '${contact.callCount} $callWord',
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

/// Helper class to store contact information
class _ContactInfo {
  final String contactId;
  final String contactName;
  final String? contactPhotoUrl;
  int callCount;
  final List<CallRecording> recordings;
  
  _ContactInfo({
    required this.contactId,
    required this.contactName,
    this.contactPhotoUrl,
    required this.callCount,
    required this.recordings,
  });
}
