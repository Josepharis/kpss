import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/sidebar_content.dart';

class SidebarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final SidebarService instance = SidebarService._internal();
  SidebarService._internal();

  /// Get live news from Firestore
  Future<List<NewsItem>> getNews() async {
    try {
      final snapshot = await _firestore
          .collection('news')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      if (snapshot.docs.isEmpty) {
        return _getFallbackNews();
      }

      return snapshot.docs
          .map((doc) => NewsItem.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching news: $e');
      return _getFallbackNews();
    }
  }

  /// Get daily information (Biliyor muydunuz?)
  Future<DailyInfo> getDailyInfo() async {
    try {
      // Get the info for today or the latest one
      final snapshot = await _firestore
          .collection('daily_info')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return _getFallbackDailyInfo();
      }

      return DailyInfo.fromMap(snapshot.docs.first.id, snapshot.docs.first.data());
    } catch (e) {
      debugPrint('Error fetching daily info: $e');
      return _getFallbackDailyInfo();
    }
  }

  /// Get upcoming exam dates
  Future<List<ExamDate>> getExamDates() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('exam_dates')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('date', descending: false)
          .get();

      if (snapshot.docs.isEmpty) {
        return _getFallbackExamDates();
      }

      return snapshot.docs
          .map((doc) => ExamDate.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching exam dates: $e');
      return _getFallbackExamDates();
    }
  }

  // --- Fallback Data (Hardcoded defaults) ---

  List<NewsItem> _getFallbackNews() {
    return [
      NewsItem(
        id: 'default1',
        title: 'KPSS 2026 Başvuruları Başladı!',
        date: 'Bugün',
        url: 'https://www.osym.gov.tr',
        createdAt: DateTime.now(),
      ),
      NewsItem(
        id: 'default2',
        title: 'ÖSYM Sınav Takvimi Yayında',
        date: 'Dün',
        url: 'https://www.osym.gov.tr',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  DailyInfo _getFallbackDailyInfo() {
    return DailyInfo(
      id: 'default',
      title: 'Biliyor Muydunuz?',
      content: 'Lozan Barış Antlaşması’nın süresiz olduğunu ve herhangi bir gizli maddesi bulunmadığını biliyor muydunuz?',
      date: DateTime.now(),
    );
  }

  List<ExamDate> _getFallbackExamDates() {
    return [
      ExamDate(
        id: 'kpss_lisans',
        title: 'KPSS Lisans (Genel Yetenek-Kültür)',
        date: DateTime(2026, 7, 12),
      ),
      ExamDate(
        id: 'kpss_alan',
        title: 'KPSS Alan Bilgisi 1. Gün',
        date: DateTime(2026, 7, 18),
      ),
      ExamDate(
        id: 'kpss_oabt',
        title: 'KPSS ÖABT',
        date: DateTime(2026, 8, 2),
      ),
    ];
  }
}
