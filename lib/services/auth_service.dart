import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../utils/error_handler.dart';
import '../config/app_config.dart';

class AuthService extends ChangeNotifier {
  // Refreshes current user model from Firestore so UI updates immediately after edits.
  Future<void> refreshCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return;

    _currentUserModel = UserModel.fromMap(user.uid, userDoc.data() as Map<String, dynamic>);
    notifyListeners();
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  UserModel? _currentUserModel;
  
  // Error handling state
  ErrorStatus _status = ErrorStatus.initial;
  AppError? _lastError;
  
  User? get currentUser => _currentUser;
  UserModel? get currentUserModel => _currentUserModel;
  ErrorStatus get status => _status;
  AppError? get lastError => _lastError;
  bool get isLoading => _status == ErrorStatus.loading;
  bool get hasError => _status == ErrorStatus.error;

  /// Quick email-based admin check — no Firestore lookup needed.
  bool get isCurrentUserAdmin {
    final email = _auth.currentUser?.email ?? '';
    return email.toLowerCase().trim() ==
        AppConfig.adminEmail.toLowerCase().trim();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _currentUser = user;
      notifyListeners();
    }, onError: (error) {
      if (kDebugMode) {
        print('Auth stream error: $error');
      }
    });
  }

  /// Auto-creates the admin Firestore document if the email matches AppConfig.adminEmail.
  /// Just set your email in lib/config/app_config.dart — no UID lookup needed.
  Future<void> _seedAdminIfNeeded(String uid, String email) async {
    if (email.toLowerCase().trim() != AppConfig.adminEmail.toLowerCase().trim()) return;
    try {
      final adminRef = _firestore.collection('admins').doc(uid);
      final adminDoc = await adminRef.get();
      if (!adminDoc.exists) {
        await adminRef.set({
          'uid': uid,
          'email': email,
          'isAdmin': true,
          'role': 'super_admin',
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (kDebugMode) debugPrint('Admin seeded for $email');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Admin seed failed: $e');
    }
  }
  
  // ACTION REQUIRED:
  // 1. Enable Email/Password sign-in in Firebase Console
  // 2. (Optional) Enable Google Sign-In and add SHA-1 fingerprint for Android
  // 3. (Optional) Enable Apple Sign-In for iOS
  
  void _setStatus(ErrorStatus status, {AppError? error}) {
    _status = status;
    _lastError = error;
    notifyListeners();
  }
  
  Future<UserModel?> registerWithEmail(String email, String password, String displayName) async {
    _setStatus(ErrorStatus.loading);
    
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password,
      );
      
      User? user = result.user;
      if (user != null) {
        // Create user profile in Firestore
        UserModel newUser = UserModel(
          uid: user.uid,
          email: email,
          displayName: displayName,
          createdAt: DateTime.now(),
        );
        
        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
        
        _currentUserModel = newUser;
        _setStatus(ErrorStatus.success);
        notifyListeners();
        await _seedAdminIfNeeded(user.uid, email);
        return newUser;
      }
    } catch (e) {
      AppError error = AppError.fromException(e, severity: ErrorSeverity.high);
      _setStatus(ErrorStatus.error, error: error);
      if (kDebugMode) print('Registration error: $e');
      rethrow;
    }
    return null;
  }
  
  Future<UserModel?> loginWithEmail(String email, String password) async {
    _setStatus(ErrorStatus.loading);
    
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password,
      );
      
      User? user = result.user;
      if (user != null) {
        // Fetch user data from Firestore
        final userRef = _firestore.collection('users').doc(user.uid);
        if (kDebugMode) {
          print('[AuthService.loginWithEmail] Reading user doc at: users/${user.uid}');
        }
        DocumentSnapshot userDoc = await userRef.get();

        if (userDoc.exists) {
          UserModel userModel = UserModel.fromMap(user.uid, userDoc.data() as Map<String, dynamic>);
          
          // Check if account is banned
          if (userModel.isBanned) {
            await _auth.signOut();
            _setStatus(ErrorStatus.error, error: AppError(
              message: 'Account has been banned. Reason: ${userModel.banReason ?? "Violation of terms"}',
              severity: ErrorSeverity.high,
            ));
            throw Exception('Account has been banned. Reason: ${userModel.banReason ?? "Violation of terms"}');
          }
          
          // Update last active
          try {
            final userRef = _firestore.collection('users').doc(user.uid);
            if (kDebugMode) {
              print('[AuthService.loginWithEmail] Updating lastActive at: users/${user.uid}');
            }
            await userRef.update({
              // Keep Firestore timestamp consistent with UserModel parsing
              'lastActive': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            if (kDebugMode) {
              print('[AuthService.loginWithEmail] permission/failed updating lastActive for users/${user.uid}: $e');
            }
            rethrow;
          }
          
          _currentUserModel = userModel;
          _setStatus(ErrorStatus.success);
          notifyListeners();
          await _seedAdminIfNeeded(user.uid, email);
          return userModel;
        } else {
          // User document doesn't exist - create one
          UserModel newUser = UserModel(
            uid: user.uid,
            email: email,
            displayName: user.displayName ?? email.split('@').first,
            createdAt: DateTime.now(),
          );
          
          await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
          
          _currentUserModel = newUser;
          _setStatus(ErrorStatus.success);
          notifyListeners();
          
          return newUser;
        }
      }
    } catch (e) {
      AppError error = AppError.fromException(e, severity: ErrorSeverity.high);
      _setStatus(ErrorStatus.error, error: error);
      
      if (kDebugMode) {
        print('Login error: $e');
      }
      rethrow;
    }
    return null;
  }
  
  Future<void> logout() async {
    _setStatus(ErrorStatus.loading);
    
    try {
      await _auth.signOut();
      _currentUserModel = null;
      _setStatus(ErrorStatus.success);
    } catch (e) {
      AppError error = AppError.fromException(e);
      _setStatus(ErrorStatus.error, error: error);
      rethrow;
    }
  }
  
Future<bool> isAdmin(String uid) async {
    try {
      // Check if the user document exists in the admins collection
      DocumentSnapshot adminDoc = await _firestore.collection('admins').doc(uid).get();
      
      // If the document doesn't exist, user is not an admin (return false, not an error)
      if (!adminDoc.exists) {
        return false;
      }
      
      // Check if the admin document has the isAdmin flag set to true
      final data = adminDoc.data() as Map<String, dynamic>?;
      return data != null && data['isAdmin'] == true;
    } catch (e) {
      // Silently handle permission errors - user is not an admin
      // This can happen if the admins collection doesn't exist yet
      if (kDebugMode) {
        // Only log non-permission errors
        if (!e.toString().contains('permission-denied')) {
          print('isAdmin check skipped: $e');
        }
      }
      return false;
    }
  }
  
  Future<void> freezeAccount(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'isFrozen': true,
    });
  }
  
  Future<void> unfreezeAccount(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'isFrozen': false,
      'matchedWithUid': null, // Clear match when unfreezing
    });
  }
  
  // Stubs for social sign-in and password reset
  Future<UserModel?> signInWithGoogle() async {
    // TODO: Implement Google Sign-In
    throw UnimplementedError('Google Sign-In not implemented');
  }
  
  Future<UserModel?> signInWithApple() async {
    // TODO: Implement Apple Sign-In
    throw UnimplementedError('Apple Sign-In not implemented');
  }
  
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}

// Add this method to your AuthService class
Future<bool> isAdminByEmail(String? email) async {
  if (email == null) return false;

  try {
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final userData = snapshot.docs.first.data() as Map<String, dynamic>;
      return userData['isAdmin'] == true || userData['role'] == 'admin';
    }
    return false;
  } catch (e) {
    print('Error checking admin by email: $e');
    return false;
  }
}
