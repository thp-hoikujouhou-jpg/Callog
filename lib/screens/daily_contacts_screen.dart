import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/localization_service.dart';
import '../models/call_recording.dart';
import 'sticky_note_editor_screen.dart';

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
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
      
      // Group by contact
      final Map<String, _ContactInfo> contactMap = {};
      
      for (var doc in querySnapshot.docs) {
        final recording = CallRecording.fromFirestore(doc.data(), doc.id);
        
        // Get contact ID (other participant)
        final contactId = recording.otherUserId ?? 'unknown';
        
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
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DailyContacts] Error loading contacts: $e');
      }
      setState(() {
        _isLoading = false;
      });
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
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['photoUrl'] as String?;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DailyContacts] Error fetching photo URL: $e');
      }
    }
    return null;
  }
  
  /// Handle contact tap - navigate to sticky note editor
  void _onContactTap(_ContactInfo contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StickyNoteEditorScreen(
          selectedDate: widget.selectedDate,
          contactId: contact.contactId,
          contactName: contact.contactName,
          contactPhotoUrl: contact.contactPhotoUrl,
          callRecordings: contact.recordings,
        ),
      ),
    );
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
    final months = monthNames[lang] ?? monthNames['en']!;
    
    if (lang == 'ja' || lang == 'ko' || lang == 'zh') {
      return '${widget.selectedDate.year}年${months[widget.selectedDate.month - 1]}${widget.selectedDate.day}日';
    } else {
      return '${months[widget.selectedDate.month - 1]} ${widget.selectedDate.day}, ${widget.selectedDate.year}';
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
