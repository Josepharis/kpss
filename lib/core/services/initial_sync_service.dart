import 'package:flutter/foundation.dart';

class InitialSyncService {
  static final InitialSyncService _instance = InitialSyncService._internal();

  factory InitialSyncService() {
    return _instance;
  }

  InitialSyncService._internal();

  /// Sadece haftada bir kez çalışıp tüm topics için verileri Storage/Firestore'dan çeker
  /// ve SharedPreferences (content_counts_) içine kaydeder.
  /// Bu metod artık devre dışı bırakıldı.
  /// Senkronizasyon artık Admin Paneli üzerinden manuel olarak yönetiliyor.
  Future<void> runInitialSync() async {
    // Artık Firestore-First yapısına geçildiği için bu ağır işlem iptal edildi.
    debugPrint('ℹ️ Haftalık initial sync artık devre dışı (Admin Panelinden yönetiliyor).');
  }
}
