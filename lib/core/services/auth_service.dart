import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'progress_service.dart';
import '../models/app_user.dart';

/// Authentication service for handling user login, registration, and session management
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';
  static const String _keyKpssType = 'kpss_type';

  /// Get current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }

  /// Get current user ID
  String? getUserId() {
    return _auth.currentUser?.uid;
  }

  /// Get current user email
  String? getUserEmail() {
    return _auth.currentUser?.email;
  }

  /// Get current user name
  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName) ?? _auth.currentUser?.displayName;
  }

  /// Get current user KPSS type
  Future<String?> getKpssType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyKpssType);
  }

  /// Login user with email and password
  Future<AuthResult> login(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Save user data locally
      if (userCredential.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUserEmail, email.trim());

        // Get user name from Firestore or use display name
        final displayName = userCredential.user?.displayName;
        if (displayName != null) {
          await prefs.setString(_keyUserName, displayName);
        }

        // Update last login and ensure user data exists in Firestore
        await _updateUserLastLogin(userCredential.user!);
      }

      return AuthResult.success(userCredential.user?.uid ?? '');
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Giriş başarısız. Lütfen tekrar deneyin.';

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Bu e-posta adresine kayıtlı kullanıcı bulunamadı.';
          break;
        case 'wrong-password':
          errorMessage = 'Hatalı şifre. Lütfen tekrar deneyin.';
          break;
        case 'invalid-email':
          errorMessage = 'Geçersiz e-posta adresi.';
          break;
        case 'user-disabled':
          errorMessage = 'Bu kullanıcı hesabı devre dışı bırakılmış.';
          break;
        case 'too-many-requests':
          errorMessage =
              'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.';
          break;
        case 'network-request-failed':
          errorMessage = 'İnternet bağlantınızı kontrol edin.';
          break;
        default:
          errorMessage = 'Giriş başarısız: ${e.message ?? "Bilinmeyen hata"}';
      }

      return AuthResult.failure(errorMessage);
    } catch (e) {
      return AuthResult.failure('Bir hata oluştu: ${e.toString()}');
    }
  }

  /// Register user with email and password
  Future<AuthResult> register(
    String name,
    String email,
    String password,
    String? kpssType,
  ) async {
    try {
      // Create user account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update display name
      if (userCredential.user != null && name.isNotEmpty) {
        await userCredential.user!.updateDisplayName(name);
        await userCredential.user!.reload();
        final updatedUser = _auth.currentUser;
        await updatedUser?.reload();
      }

      // Save user data locally
      if (userCredential.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUserEmail, email.trim());
        await prefs.setString(_keyUserName, name);
        if (kpssType != null) {
          await prefs.setString(_keyKpssType, kpssType);
        }

        // Save user data to Firestore
        await _saveUserToFirestore(
          uid: userCredential.user!.uid,
          name: name,
          email: email.trim(),
          kpssType: kpssType,
        );
      }

      return AuthResult.success(userCredential.user?.uid ?? '');
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Kayıt başarısız. Lütfen tekrar deneyin.';

      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Şifre çok zayıf. Daha güçlü bir şifre seçin.';
          break;
        case 'email-already-in-use':
          errorMessage = 'Bu e-posta adresi zaten kullanılıyor.';
          break;
        case 'invalid-email':
          errorMessage = 'Geçersiz e-posta adresi.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Bu işlem şu anda kullanılamıyor.';
          break;
        case 'network-request-failed':
          errorMessage = 'İnternet bağlantınızı kontrol edin.';
          break;
        default:
          errorMessage = 'Kayıt başarısız: ${e.message ?? "Bilinmeyen hata"}';
      }

      return AuthResult.failure(errorMessage);
    } catch (e) {
      return AuthResult.failure('Bir hata oluştu: ${e.toString()}');
    }
  }

  /// Logout user
  Future<void> logout() async {
    await _auth.signOut();
    ProgressService.clearStatsCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyKpssType);
  }

  /// Clear all user data
  Future<void> clearAllData() async {
    await logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Delete current user account and related data (Firestore + local cache)
  ///
  /// Notes:
  /// - Firebase requires "recent login" to delete a user, so we reauthenticate.
  /// - Deletes user-related documents under:
  ///   - userProgress/{uid} (and known subcollections)
  ///   - users/{uid}/subscription/current and users/{uid}
  Future<AuthResult> deleteAccount({required String password}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure(
          'Kullanıcı bulunamadı. Lütfen tekrar giriş yapın.',
        );
      }

      final email = user.email;
      if (email == null || email.isEmpty) {
        return AuthResult.failure(
          'E-posta bulunamadı. Lütfen tekrar giriş yapın.',
        );
      }

      // Re-authenticate (required for account deletion)
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      final uid = user.uid;

      // 1) Delete Firestore data first (while auth is still valid)
      await _deleteUserFirestoreData(uid);

      // 2) Delete auth user
      await user.delete();

      // 3) Clear local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Best-effort sign out (user may already be signed out after delete)
      try {
        await _auth.signOut();
      } catch (_) {}

      return AuthResult.success(uid, 'Hesabınız başarıyla silindi.');
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          return AuthResult.failure('Şifre hatalı. Lütfen tekrar deneyin.');
        case 'requires-recent-login':
          return AuthResult.failure(
            'Güvenlik nedeniyle tekrar giriş yapmanız gerekiyor. Lütfen çıkış yapıp tekrar giriş yaptıktan sonra deneyin.',
          );
        case 'user-mismatch':
        case 'user-not-found':
          return AuthResult.failure(
            'Kullanıcı doğrulanamadı. Lütfen tekrar giriş yapın.',
          );
        case 'network-request-failed':
          return AuthResult.failure('İnternet bağlantınızı kontrol edin.');
        default:
          return AuthResult.failure(
            'Hesap silme başarısız: ${e.message ?? "Bilinmeyen hata"}',
          );
      }
    } catch (e) {
      return AuthResult.failure(
        'Hesap silme sırasında hata oluştu: ${e.toString()}',
      );
    }
  }

  Future<void> _deleteUserFirestoreData(String uid) async {
    // userProgress/{uid} + subcollections
    final userProgressDoc = _firestore.collection('userProgress').doc(uid);
    const userProgressSubcollections = <String>[
      'videos',
      'podcasts',
      'tests',
      'flashCards',
      'testResults',
      'lessons',
      'savedCards',
      'weaknesses',
    ];

    for (final sub in userProgressSubcollections) {
      await _deleteSubcollection(parent: userProgressDoc, collectionName: sub);
    }

    // Delete the root progress doc (best-effort)
    try {
      await userProgressDoc.delete();
    } catch (_) {}

    // users/{uid}/subscription/current + users/{uid}
    final userDoc = _firestore.collection('users').doc(uid);
    try {
      await userDoc.collection('subscription').doc('current').delete();
    } catch (_) {}

    // If there are other user subcollections in the future, add them here.
    try {
      await userDoc.delete();
    } catch (_) {}
  }

  Future<void> _deleteSubcollection({
    required DocumentReference parent,
    required String collectionName,
  }) async {
    // Firestore batch limit is 500. Use 200 for safety.
    const batchSize = 200;
    Query query = parent.collection(collectionName).limit(batchSize);

    while (true) {
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Continue until empty
    }
  }

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success('Şifre sıfırlama e-postası gönderildi.');
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'E-posta gönderilemedi.';

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Bu e-posta adresine kayıtlı kullanıcı bulunamadı.';
          break;
        case 'invalid-email':
          errorMessage = 'Geçersiz e-posta adresi.';
          break;
        default:
          errorMessage =
              'E-posta gönderilemedi: ${e.message ?? "Bilinmeyen hata"}';
      }

      return AuthResult.failure(errorMessage);
    } catch (e) {
      return AuthResult.failure('Bir hata oluştu: ${e.toString()}');
    }
  }

  /// Save or update user data in Firestore
  Future<void> _saveUserToFirestore({
    required String uid,
    required String name,
    required String email,
    String? kpssType,
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(uid);

      final appUser = AppUser(
        uid: uid,
        name: name,
        email: email,
        kpssType: kpssType,
        createdAt: DateTime.now(), // Will be overwritten by serverTimestamp
      );

      await userDoc.set(appUser.toMap(), SetOptions(merge: true));
      debugPrint('✅ User data saved to Firestore for $uid');
    } catch (e) {
      debugPrint('❌ Error saving user data to Firestore: $e');
    }
  }

  /// Update user's last login timestamp
  Future<void> _updateUserLastLogin(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);

      // First check if doc exists to avoid overwriting missing fields if we weren't merge-setting
      final doc = await userDoc.get();
      if (!doc.exists) {
        // If user document doesn't exist (e.g. registered before this change), create it
        await _saveUserToFirestore(
          uid: user.uid,
          name: user.displayName ?? '',
          email: user.email ?? '',
          // kpssType is unknown here, but will be updated next time they set it
        );
      } else {
        await userDoc.update({
          'lastLogin': FieldValue.serverTimestamp(),
          // Ensure email and name are also there if they were missing
          'email': user.email,
          'name': user.displayName,
        });
      }
      debugPrint('✅ User last login updated for ${user.uid}');
    } catch (e) {
      debugPrint('❌ Error updating last login: $e');
    }
  }
}

/// Result class for authentication operations
class AuthResult {
  final bool success;
  final String message;
  final String? userId;

  AuthResult.success(this.userId, [this.message = '']) : success = true;

  AuthResult.failure(this.message) : success = false, userId = null;
}
