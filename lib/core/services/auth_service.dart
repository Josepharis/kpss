import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authentication service for handling user login, registration, and session management
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
          errorMessage = 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.';
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
          errorMessage = 'E-posta gönderilemedi: ${e.message ?? "Bilinmeyen hata"}';
      }
      
      return AuthResult.failure(errorMessage);
    } catch (e) {
      return AuthResult.failure('Bir hata oluştu: ${e.toString()}');
    }
  }
}

/// Result class for authentication operations
class AuthResult {
  final bool success;
  final String message;
  final String? userId;

  AuthResult.success(this.userId, [this.message = ''])
      : success = true;

  AuthResult.failure(this.message)
      : success = false,
        userId = null;
}
