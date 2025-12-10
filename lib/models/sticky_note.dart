import 'package:cloud_firestore/cloud_firestore.dart';

/// Sticky Note Model for Calendar Memos
/// 
/// Features:
/// - Store meeting notes in sticky note format
/// - Support multiple notes per day
/// - Customizable colors
/// - Import from call history
class StickyNote {
  final String id;
  final String userId;
  final DateTime date;
  final String contactId;
  final String contactName;
  final String? contactPhotoUrl;
  final String keyPoints;      // 話し合いの要点
  final String results;         // 話し合いの結果
  final String colorHex;        // Sticky note color (#RRGGBB format)
  final int position;           // Display position (0-based, left to right, top to bottom)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool importedFromCallHistory;
  final String? callRecordingId;  // Link to call_recordings collection

  StickyNote({
    required this.id,
    required this.userId,
    required this.date,
    required this.contactId,
    required this.contactName,
    this.contactPhotoUrl,
    required this.keyPoints,
    required this.results,
    required this.colorHex,
    required this.position,
    required this.createdAt,
    this.updatedAt,
    this.importedFromCallHistory = false,
    this.callRecordingId,
  });

  /// Create StickyNote from Firestore document
  factory StickyNote.fromFirestore(Map<String, dynamic> data, String docId) {
    return StickyNote(
      id: docId,
      userId: data['userId'] as String? ?? '',
      date: (data['date'] as Timestamp).toDate(),
      contactId: data['contactId'] as String? ?? '',
      contactName: data['contactName'] as String? ?? '',
      contactPhotoUrl: data['contactPhotoUrl'] as String?,
      keyPoints: data['keyPoints'] as String? ?? '',
      results: data['results'] as String? ?? '',
      colorHex: data['colorHex'] as String? ?? '#FFEB3B',  // Default: Yellow
      position: data['position'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      importedFromCallHistory: data['importedFromCallHistory'] as bool? ?? false,
      callRecordingId: data['callRecordingId'] as String?,
    );
  }

  /// Convert StickyNote to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'contactId': contactId,
      'contactName': contactName,
      'contactPhotoUrl': contactPhotoUrl,
      'keyPoints': keyPoints,
      'results': results,
      'colorHex': colorHex,
      'position': position,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'importedFromCallHistory': importedFromCallHistory,
      'callRecordingId': callRecordingId,
    };
  }

  /// Create a copy with updated fields
  StickyNote copyWith({
    String? id,
    String? userId,
    DateTime? date,
    String? contactId,
    String? contactName,
    String? contactPhotoUrl,
    String? keyPoints,
    String? results,
    String? colorHex,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? importedFromCallHistory,
    String? callRecordingId,
  }) {
    return StickyNote(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      contactPhotoUrl: contactPhotoUrl ?? this.contactPhotoUrl,
      keyPoints: keyPoints ?? this.keyPoints,
      results: results ?? this.results,
      colorHex: colorHex ?? this.colorHex,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      importedFromCallHistory: importedFromCallHistory ?? this.importedFromCallHistory,
      callRecordingId: callRecordingId ?? this.callRecordingId,
    );
  }
}

/// Predefined sticky note colors
class StickyNoteColors {
  static const List<String> colors = [
    '#FFEB3B',  // Yellow
    '#FF9800',  // Orange
    '#E91E63',  // Pink
    '#9C27B0',  // Purple
    '#2196F3',  // Blue
    '#4CAF50',  // Green
    '#FFC107',  // Amber
    '#FF5722',  // Deep Orange
    '#00BCD4',  // Cyan
    '#8BC34A',  // Light Green
  ];

  static String getColorName(String hex, String languageCode) {
    final colorNames = {
      'en': ['Yellow', 'Orange', 'Pink', 'Purple', 'Blue', 'Green', 'Amber', 'Deep Orange', 'Cyan', 'Light Green'],
      'ja': ['黄色', 'オレンジ', 'ピンク', '紫', '青', '緑', '琥珀', '深いオレンジ', 'シアン', '薄緑'],
      'ko': ['노란색', '주황색', '분홍색', '보라색', '파란색', '초록색', '호박색', '진한 주황색', '청록색', '연두색'],
      'zh': ['黄色', '橙色', '粉色', '紫色', '蓝色', '绿色', '琥珀色', '深橙色', '青色', '浅绿色'],
      'es': ['Amarillo', 'Naranja', 'Rosa', 'Morado', 'Azul', 'Verde', 'Ámbar', 'Naranja Oscuro', 'Cian', 'Verde Claro'],
      'fr': ['Jaune', 'Orange', 'Rose', 'Violet', 'Bleu', 'Vert', 'Ambre', 'Orange Foncé', 'Cyan', 'Vert Clair'],
    };

    final index = colors.indexOf(hex);
    if (index == -1) return 'Unknown';

    final names = colorNames[languageCode] ?? colorNames['en']!;
    return names[index];
  }
}
