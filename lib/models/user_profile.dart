import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String username;
  final String? photoUrl;
  final String? location;
  final String language;
  final bool isOnline;
  final DateTime? lastSeen;
  final List<String> friendsList;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.username,
    this.photoUrl,
    this.location,
    this.language = 'en',
    this.isOnline = false,
    this.lastSeen,
    this.friendsList = const [],
  });

  // Convert UserProfile to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'username': username,
      'photoUrl': photoUrl,
      'location': location,
      'language': language,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'friendsList': friendsList,
    };
  }

  // Create UserProfile from Firestore document
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      username: map['username'] ?? '',
      photoUrl: map['photoUrl'],
      location: map['location'],
      language: map['language'] ?? 'en',
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null 
          ? (map['lastSeen'] as Timestamp).toDate() 
          : null,
      friendsList: List<String>.from(map['friendsList'] ?? []),
    );
  }

  // Create a copy with updated fields
  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? username,
    String? photoUrl,
    String? location,
    String? language,
    bool? isOnline,
    DateTime? lastSeen,
    List<String>? friendsList,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      location: location ?? this.location,
      language: language ?? this.language,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      friendsList: friendsList ?? this.friendsList,
    );
  }
}
