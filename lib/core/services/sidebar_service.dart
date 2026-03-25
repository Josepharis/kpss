import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

  /// Get news from Firestore or Live sources
  Future<List<NewsItem>> getNews({bool forceReload = false}) async {
    if (!forceReload && _cachedNews != null) return _cachedNews!;

    try {
      // 1. Try to get LIVE news first (real-time from RSS feeds)
      final liveNews = await _getLiveNewsFromExternalSource();
      if (liveNews.isNotEmpty) {
        _cachedNews = liveNews;
        return _cachedNews!;
      }

      // 2. Fallback to Firestore
      final snapshot = await _firestore
          .collection('news')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _cachedNews = snapshot.docs
            .map((doc) => NewsItem.fromMap(doc.id, doc.data()))
            .toList();
        return _cachedNews!;
      }

      // 3. Last fallback: Generic hardcoded news
      _cachedNews = _getFallbackNews();
      return _cachedNews!;
    } catch (e) {
      debugPrint('Error fetching news: $e');
      _cachedNews = _getFallbackNews();
      return _cachedNews!;
    }
  }

  /// Fetches news from real education and KPSS sources
  Future<List<NewsItem>> _getLiveNewsFromExternalSource() async {
    final List<NewsItem> allNews = [];
    
    // Focused Sources (KPSS, OSYM, Kamu)
    final sources = [
      'https://www.osym.gov.tr/RSS/TumDuyurular.xml',
      'https://www.kamuajans.com/rss/kpss-haberleri',
      'https://www.kamubulteni.com/rss',
    ];

    for (final url in sources) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          String body;
          try {
            body = utf8.decode(response.bodyBytes);
          } catch (_) {
            body = latin1.decode(response.bodyBytes);
          }
          
          final items = _parseRss(body);
          allNews.addAll(items);
        }
      } catch (e) {
        debugPrint('Error fetching from $url: $e');
      }
    }

    // Sort by "freshness" and remove duplicates / irrelevant items (LGS, YKS, etc.)
    final seenTitles = <String>{};
    final keywordsToAvoid = ['lgs', 'yks', 'ayt', 'tyt', 'msü', 'ortaokul', 'lise', 'ilkokul', 'karne', 'tatil', 'okul', 'sınıf', 'öğrenci', 'meb'];
    final kpssKeywords = ['kpss', 'ösym', 'atama', 'memur', 'dgs', 'ales', 'yökdil', 'yds', 'mülakat', 'ags', 'öabt'];
    
    final uniqueNews = allNews.where((item) {
      final textToCheck = (item.title + (item.content ?? '')).toLowerCase();
      
      // 1. Avoid irrelevant exam types
      for (final badWord in keywordsToAvoid) {
        if (textToCheck.contains(badWord)) {
          // Exception: if it also contains KPSS, maybe it's a comparison or relevant
          if (!textToCheck.contains('kpss')) return false;
        }
      }
      
      // 2. Avoid duplicates
      if (seenTitles.contains(item.title)) return false;
      seenTitles.add(item.title);
      return true;
    }).toList();

    // 3. Prioritize items containing KPSS keywords
    uniqueNews.sort((a, b) {
      final aHasKpss = kpssKeywords.any((k) => a.title.toLowerCase().contains(k));
      final bHasKpss = kpssKeywords.any((k) => b.title.toLowerCase().contains(k));
      if (aHasKpss && !bHasKpss) return -1;
      if (!aHasKpss && bHasKpss) return 1;
      return 0;
    });

    return uniqueNews.take(10).toList();
  }

  /// Very simple RSS XML parser using RegExp to avoid heavy dependencies
  List<NewsItem> _parseRss(String xml) {
    final List<NewsItem> news = [];
    // Extract <item> blocks
    final itemRegex = RegExp(r'<item>(.*?)<\/item>', dotAll: true);
    final titleRegex = RegExp(r'<title>(.*?)<\/title>', dotAll: true);
    final linkRegex = RegExp(r'<link>(.*?)<\/link>', dotAll: true);
    final dateRegex = RegExp(r'<pubDate>(.*?)<\/pubDate>', dotAll: true);
    final descriptionRegex = RegExp(r'<description>(.*?)<\/description>', dotAll: true);

    final matches = itemRegex.allMatches(xml);
    for (final match in matches) {
      final itemContent = match.group(1) ?? '';
      
      String title = titleRegex.firstMatch(itemContent)?.group(1) ?? '';
      String link = linkRegex.firstMatch(itemContent)?.group(1) ?? '';
      String dateStr = dateRegex.firstMatch(itemContent)?.group(1) ?? '';
      String desc = descriptionRegex.firstMatch(itemContent)?.group(1) ?? '';

      // Clean up CDATA and HTML tags
      title = _cleanXmlContent(title);
      link = _cleanXmlContent(link);
      dateStr = _cleanXmlContent(dateStr);
      desc = _cleanXmlContent(desc);

      if (title.isNotEmpty) {
        news.add(NewsItem(
          id: link.isNotEmpty ? link : title.hashCode.toString(),
          title: title,
          date: _humanizeDate(dateStr),
          url: link,
          content: desc,
          createdAt: DateTime.now(), // Rss items are usually sorted in feed, we use local time for ordering fallback
        ));
      }
    }
    return news;
  }

  String _cleanXmlContent(String content) {
    return content
        .replaceAllMapped(RegExp(r'<!\[CDATA\[(.*?)\]\]>', dotAll: true), (match) => match.group(1) ?? '')
        .replaceAll(RegExp(r'<[^>]*>', dotAll: true), '') // Strip other HTML tags
        .trim();
  }

  String _humanizeDate(String dateStr) {
    // Basic date formatter for "Wed, 25 Mar 2026 12:00:00 +0300" -> "25 Mar"
    try {
      final parts = dateStr.split(' ');
      if (parts.length >= 4) {
        return '${parts[1]} ${parts[2]}';
      }
    } catch (_) {}
    return "Güncel";
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
        id: 'default_osym',
        title: 'ÖSYM Güncel Duyurular Sayfası',
        date: 'Bugün',
        url: 'https://www.osym.gov.tr',
        createdAt: DateTime.now(),
      ),
      NewsItem(
        id: 'default_meb',
        title: 'MEB Eğitim ve Sınav Haberleri',
        date: 'Bugün',
        url: 'https://www.meb.gov.tr',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
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
