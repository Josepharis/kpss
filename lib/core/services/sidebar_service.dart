import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/sidebar_content.dart';

class SidebarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final SidebarService instance = SidebarService._internal();
  SidebarService._internal();

  // In-memory cache to prevent UI flicker on every sidebar open
  List<NewsItem>? _cachedNews;
  DailyInfo? _cachedDailyInfo;
  List<ExamDate>? _cachedExamDates;

  bool get hasCache => _cachedNews != null && _cachedDailyInfo != null && _cachedExamDates != null;

  /// Get live news from Firestore
  Future<List<NewsItem>> getNews({bool forceReload = false}) async {
    if (!forceReload && _cachedNews != null) return _cachedNews!;
    try {
      final snapshot = await _firestore
          .collection('news')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      if (snapshot.docs.isEmpty) {
        _cachedNews = _getFallbackNews();
        return _cachedNews!;
      }

      _cachedNews = snapshot.docs
          .map((doc) => NewsItem.fromMap(doc.id, doc.data()))
          .toList();
      return _cachedNews!;
    } catch (e) {
      debugPrint('Error fetching news: $e');
      _cachedNews = _getFallbackNews();
      return _cachedNews!;
    }
  }

  /// Get daily information (Biliyor muydunuz?)
  Future<DailyInfo> getDailyInfo({bool forceReload = false}) async {
    if (!forceReload && _cachedDailyInfo != null) return _cachedDailyInfo!;
    try {
      // Get the info for today or the latest one
      final snapshot = await _firestore
          .collection('daily_info')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _cachedDailyInfo = _getFallbackDailyInfo();
        return _cachedDailyInfo!;
      }

      _cachedDailyInfo = DailyInfo.fromMap(snapshot.docs.first.id, snapshot.docs.first.data());
      return _cachedDailyInfo!;
    } catch (e) {
      debugPrint('Error fetching daily info: $e');
      _cachedDailyInfo = _getFallbackDailyInfo();
      return _cachedDailyInfo!;
    }
  }

  /// Get upcoming exam dates
  Future<List<ExamDate>> getExamDates({bool forceReload = false}) async {
    if (!forceReload && _cachedExamDates != null) return _cachedExamDates!;
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('exam_dates')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('date', descending: false)
          .get();

      if (snapshot.docs.isEmpty) {
        _cachedExamDates = _getFallbackExamDates();
        return _cachedExamDates!;
      }

      _cachedExamDates = snapshot.docs
          .map((doc) => ExamDate.fromMap(doc.id, doc.data()))
          .toList();
      return _cachedExamDates!;
    } catch (e) {
      debugPrint('Error fetching exam dates: $e');
      _cachedExamDates = _getFallbackExamDates();
      return _cachedExamDates!;
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
    final examFacts = [
      'Türkiye Cumhuriyeti’nin ilk Başbakanı İsmet İnönü iken, ilk Meclis Başkanı Mustafa Kemal Atatürk’tür. Biliyor muydunuz?',
      'Osmanlı Devleti’nde Padişahın yetkilerinin ilk kez 1808 Sened-i İttifak ile kısıtlandığını biliyor muydunuz?',
      'Dünyanın en derin gölü olan Baykal Gölü, aynı zamanda dünyanın en büyük tatlı su rezervine sahiptir. Biliyor muydunuz?',
      'Osmanlı Devleti’nde "Reisül-Küttab" makamının 19. yüzyılda Dışişleri Bakanlığına dönüştüğünü biliyor muydunuz?',
      'Türkiye’nin en yüksek volkanik dağı olan Ağrı Dağı’nın aslında bir sönmüş yanardağ olduğunu biliyor muydunuz?',
      'Hukukta "Kuvvetler Birliği"nin; yasama, yürütme ve yargının tek organda toplanması olduğunu biliyor muydunuz?',
      'İlk Türk kadın tiyatro oyuncusu Afife Jale’nin ilk kez "Yamalar" oyununda sahne aldığını biliyor muydunuz?',
      'Karadeniz Bölgesi’nde en fazla yağış alan il Rize iken, en az yağış alan il Bayburt’tur. Biliyor muydunuz?',
      'Eski Türklerde devlet meselelerinin görüşüldüğü meclise "Kurultay" veya "Toy" denildiğini biliyor muydunuz?',
      'Osmanlı ordusunda haberleşme işlerini yürüten görevlilere "Turnalar" denildiğini biliyor muydunuz?',
      'Türkiye’nin en uzun kıyı şeridine sahip bölgesinin Ege Bölgesi olduğunu biliyor muydunuz?',
      'Milli Mücadele döneminde çıkarılan ilk resmi gazetenin "Ceride-i Resmiye" olduğunu biliyor muydunuz?',
      'Türkiye’nin ilk milli parkının Yozgat Çamlığı Milli Parkı olduğunu biliyor muydunuz?',
      'Sevr Antlaşması’nın geçersizliğini kabul eden ilk büyük Avrupa devletinin Sovyet Rusya olduğunu biliyor muydunuz?',
    ];
    
    // Perfect daily rotation: Calculate days since a fixed date (Jan 1, 2026)
    // This guarantees a different fact every single day for weeks
    final now = DateTime.now();
    final epoch = DateTime(2026, 1, 1);
    final daysSinceStart = now.difference(epoch).inDays;
    final selectedFact = examFacts[daysSinceStart % examFacts.length];

    return DailyInfo(
      id: 'daily_info_$daysSinceStart',
      title: 'BİLİYOR MUYDUNUZ?',
      content: selectedFact,
      date: DateTime.now(),
    );
  }

  List<ExamDate> _getFallbackExamDates() {
    return [
      ExamDate(
        id: 'ags_oabt',
        title: 'AGS & ÖABT (Genel Sınav)',
        date: DateTime(2026, 7, 12),
      ),
      ExamDate(
        id: 'kpss_lisans',
        title: 'KPSS Lisans (GY-GK)',
        date: DateTime(2026, 9, 6),
      ),
      ExamDate(
        id: 'kpss_alan',
        title: 'KPSS Alan Bilgisi',
        date: DateTime(2026, 9, 12),
      ),
      ExamDate(
        id: 'kpss_onlisans',
        title: 'KPSS Ön Lisans',
        date: DateTime(2026, 10, 4),
      ),
      ExamDate(
        id: 'kpss_ortaogretim',
        title: 'KPSS Ortaöğretim',
        date: DateTime(2026, 10, 25),
      ),
    ];
  }
}
