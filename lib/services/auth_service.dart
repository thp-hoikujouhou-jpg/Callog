import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Automatically create user profile in Firestore
      if (result.user != null) {
        final profile = UserProfile(
          uid: result.user!.uid,
          email: email,
          displayName: result.user!.displayName ?? email.split('@')[0],
          username: email.split('@')[0], // Use email prefix as default username
          photoUrl: '',
          location: null,
          language: 'en',
          isOnline: true,
          lastSeen: DateTime.now(),
          friendsList: [],
        );
        await createUserProfile(profile);
      }
      
      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      
      // Check if user profile exists, if not create one
      if (result.user != null) {
        final profileExists = await userProfileExists(result.user!.uid);
        if (!profileExists) {
          final profile = UserProfile(
            uid: result.user!.uid,
            email: result.user!.email ?? '',
            displayName: result.user!.displayName ?? 'User',
            username: result.user!.email?.split('@')[0] ?? 'user',
            photoUrl: result.user!.photoURL ?? '',
            location: null,
            language: 'en',
            isOnline: true,
            lastSeen: DateTime.now(),
            friendsList: [],
          );
          await createUserProfile(profile);
        }
      }
      
      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Google if user was signed in with Google
      if (_googleSignIn.currentUser != null) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Check if user profile exists
  Future<bool> userProfileExists(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get user profile
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Create user profile
  Future<void> createUserProfile(UserProfile profile) async {
    try {
      await _firestore.collection('users').doc(profile.uid).set(profile.toMap());
    } catch (e) {
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      rethrow;
    }
  }

  // Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      return query.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // Upload profile image to Firebase Storage (supports both Web and Mobile)
  Future<String?> uploadProfileImage(String uid, dynamic imageFile) async {
    try {
      // Create a unique file path in Firebase Storage
      final storageRef = _storage.ref().child('profile_images/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      // Upload the file (Web uses putData, Mobile uses putFile)
      final UploadTask uploadTask;
      if (kIsWeb) {
        // For Web: Read file as bytes and use putData
        // imageFile should be XFile for Web
        final XFile xFile = imageFile is XFile ? imageFile : XFile(imageFile.path);
        final bytes = await xFile.readAsBytes();
        uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(
            contentType: 'image/jpeg',
          ),
        );
      } else {
        // For Mobile: Use putFile with File object
        final file = imageFile is File ? imageFile : File(imageFile.path);
        uploadTask = storageRef.putFile(file);
      }
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  // Update profile photo URL
  Future<void> updateProfilePhoto(String uid, String photoUrl) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'photoUrl': photoUrl,
      });
    } catch (e) {
      rethrow;
    }
  }
}
