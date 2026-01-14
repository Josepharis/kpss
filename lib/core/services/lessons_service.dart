import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/lesson.dart';
import '../models/topic.dart';
import 'storage_service.dart';

/// Service for managing lessons and topics from Firestore
class LessonsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();

  // Collection references
  CollectionReference get _lessonsCollection => _firestore.collection('lessons');
  CollectionReference get _topicsCollection => _firestore.collection('topics');

  /// Get all lessons
  Future<List<Lesson>> getAllLessons() async {
    try {
      final snapshot = await _lessonsCollection.get();
      final lessons = snapshot.docs
          .map((doc) => Lesson.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      // Sort by order on client side
      lessons.sort((a, b) => a.order.compareTo(b.order));
      return lessons;
    } catch (e) {
      debugPrint('Error fetching lessons: $e');
      return [];
    }
  }

  /// Get lessons by category
  Future<List<Lesson>> getLessonsByCategory(String category) async {
    try {
      final snapshot = await _lessonsCollection
          .where('category', isEqualTo: category)
          .get();
      final lessons = snapshot.docs
          .map((doc) => Lesson.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      // Sort by order on client side
      lessons.sort((a, b) => a.order.compareTo(b.order));
      return lessons;
    } catch (e) {
      debugPrint('Error fetching lessons by category: $e');
      return [];
    }
  }

  /// Get a single lesson by ID
  Future<Lesson?> getLessonById(String lessonId) async {
    try {
      final doc = await _lessonsCollection.doc(lessonId).get();
      if (doc.exists) {
        return Lesson.fromMap(doc.data()! as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching lesson: $e');
      return null;
    }
  }

  /// Get all topics
  Future<List<Topic>> getAllTopics() async {
    try {
      final snapshot = await _topicsCollection.get();
      final topics = snapshot.docs
          .map((doc) => Topic.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      // Sort by order on client side
      topics.sort((a, b) => a.order.compareTo(b.order));
      return topics;
    } catch (e) {
      debugPrint('Error fetching all topics: $e');
      return [];
    }
  }

  /// Get all topics for a lesson from Storage (sadece konu isimlerini çeker, içerik sayılarını çekmez)
  /// Storage yapısı: dersler/{lessonName}/{topicName}/video/, dersler/{lessonName}/{topicName}/podcast/, dersler/{lessonName}/{topicName}/bilgikarti/
  Future<List<Topic>> getTopicsByLessonId(String lessonId) async {
    try {
      // Önce lesson'ı al ki name'ini bulalım
      final lesson = await getLessonById(lessonId);
      if (lesson == null) {
        return _getTopicsFromFirestore(lessonId);
      }
      
      // Lesson name'i storage path'ine çevir (küçük harf, boşlukları alt çizgi ile değiştir)
      final lessonNameForPath = lesson.name
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll('ı', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c');
      
      // Storage'dan dersler/{lessonName}/konular/ klasöründeki konu klasörlerini listele
      // Önce konular klasörünü kontrol et
      final konularPath = 'dersler/$lessonNameForPath/konular';
      
      List<String> topicFolders = [];
      try {
        topicFolders = await _storageService.listFolders(konularPath);
      } catch (e) {
        // Silent error handling
      }
      
      // Eğer konular/ klasöründe klasör yoksa veya exception varsa, direkt ders altından dene
      if (topicFolders.isEmpty) {
        try {
          final lessonPath = 'dersler/$lessonNameForPath';
          final allFolders = await _storageService.listFolders(lessonPath);
          
          // 'konular' klasörünü hariç tut
          topicFolders = allFolders.where((folder) => folder != 'konular').toList();
        } catch (e) {
          // Silent error handling
        }
      }
      
      if (topicFolders.isEmpty) {
        return _getTopicsFromFirestore(lessonId);
      }
      
      // Vatandaşlık dersi için özel konu sıralaması
      final Map<String, int> vatandaslikTopicOrder = {
        'Hukukun Temel Kavramları': 1,
        'Devlet Biçimleri Demokrasi Ve Kuvvetler Ayrılığı': 2,
        'Anayasa Hukukuna Giriş Temel Kavramlar Ve Türk Anayasa Tarihi': 3,
        '1982 Anayasasının Temel İlkeleri': 4,
        'Yasama': 5,
        'Yürütme': 6,
        'Yargı': 7,
        'Temel Hak Ve Hürriyetler': 8,
        'İdare Hukuku Ve': 9,
        'Uluslararası Kuruluşlar': 10,
      };
      
      // Her konu klasörü için Topic oluştur (sadece isim, içerik sayıları 0)
      final List<Topic> topics = [];
      
      // Klasörleri sırala (sayısal prefix varsa ona göre)
      final sortedFolders = List<String>.from(topicFolders);
      sortedFolders.sort((a, b) {
        // Sayısal prefix'i çıkar ve karşılaştır
        final aMatch = RegExp(r'^(\d+)[-.]?\s*(.*)').firstMatch(a);
        final bMatch = RegExp(r'^(\d+)[-.]?\s*(.*)').firstMatch(b);
        
        if (aMatch != null && bMatch != null) {
          final aNum = int.tryParse(aMatch.group(1) ?? '') ?? 0;
          final bNum = int.tryParse(bMatch.group(1) ?? '') ?? 0;
          if (aNum != bNum) return aNum.compareTo(bNum);
        }
        
        return a.compareTo(b);
      });
      
      for (int index = 0; index < sortedFolders.length; index++) {
        final topicFolderName = sortedFolders[index];
        
        // Klasör adından konu adını oluştur
        // Önce sayısal prefix'i ve tireyi temizle (örn: "1-Türkiye'nin..." -> "Türkiye'nin...")
        String topicName = topicFolderName;
        
        // Sayısal prefix ve tireyi temizle
        topicName = topicName.replaceFirst(RegExp(r'^\d+[-.]?\s*'), '');
        
        // Eğer alt çizgi varsa boşlukla değiştir, yoksa direkt kullan
        if (topicName.contains('_')) {
          topicName = topicName
              .split('_')
              .map((word) => word.isNotEmpty 
                  ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                  : word)
              .join(' ');
        } else {
          // Alt çizgi yoksa, sadece ilk harfi büyük yap (zaten boşluklu format olabilir)
          if (topicName.isNotEmpty) {
            topicName = topicName[0].toUpperCase() + topicName.substring(1);
          }
        }
        
        // Topic ID oluştur (lessonId_topicFolderName formatında)
        // topicFolderName'i normalize et (Türkçe karakterleri dönüştür)
        final normalizedFolderName = topicFolderName
            .toLowerCase()
            .replaceAll(' ', '_')
            .replaceAll('ı', 'i')
            .replaceAll('ğ', 'g')
            .replaceAll('ü', 'u')
            .replaceAll('ş', 's')
            .replaceAll('ö', 'o')
            .replaceAll('ç', 'c')
            .replaceAll(RegExp(r'^\d+[-.]?\s*'), ''); // Sayısal prefix'i temizle
        
        final topicId = '${lessonId}_$normalizedFolderName';
        
        // Klasör ismindeki sayısal prefix'i order olarak kullan
        int topicOrder = index + 1;
        final orderMatch = RegExp(r'^(\d+)').firstMatch(topicFolderName);
        if (orderMatch != null) {
          final orderNum = int.tryParse(orderMatch.group(1) ?? '');
          if (orderNum != null && orderNum > 0) {
            topicOrder = orderNum;
          }
        }
        if (lessonId == 'vatandaslik_lesson' || lesson.name == 'Vatandaşlık') {
          // Konu adını normalize et (karşılaştırma için)
          final normalizedTopicName = topicName.trim();
          if (vatandaslikTopicOrder.containsKey(normalizedTopicName)) {
            topicOrder = vatandaslikTopicOrder[normalizedTopicName]!;
          } else {
            // Eğer listede yoksa, benzer isimleri kontrol et
            for (final entry in vatandaslikTopicOrder.entries) {
              if (normalizedTopicName.toLowerCase().contains(entry.key.toLowerCase()) ||
                  entry.key.toLowerCase().contains(normalizedTopicName.toLowerCase())) {
                topicOrder = entry.value;
                break;
              }
            }
          }
        }
        
        // Topic oluştur (içerik sayıları 0, konu detay sayfasında çekilecek)
        final topic = Topic(
          id: topicId,
          lessonId: lessonId,
          name: topicName,
          subtitle: '$topicName konusu',
          duration: '0h 0min', // Varsayılan
          averageQuestionCount: 0, // Varsayılan
          testCount: 0, // Varsayılan
          podcastCount: 0, // Konu detay sayfasında çekilecek
          videoCount: 0, // Konu detay sayfasında çekilecek
          noteCount: 0, // Konu detay sayfasında çekilecek
          flashCardCount: 0, // Konu detay sayfasında çekilecek
          pdfCount: 0, // Konu detay sayfasında çekilecek
          progress: 0.0,
          order: topicOrder,
          pdfUrl: null, // Konu detay sayfasında çekilecek
        );
        
        topics.add(topic);
      }
      
      // Sıralama (order'a göre)
      topics.sort((a, b) => a.order.compareTo(b.order));
      
      return topics;
    } catch (e) {
      // Silent error handling
      
      // Fallback to Firestore
      return _getTopicsFromFirestore(lessonId);
    }
  }

  /// Helper method: Get topic base path (with fallback)
  /// Önce konular/ klasörü altına bakar, yoksa direkt ders altına bakar
  Future<String> getTopicBasePath({
    required String lessonId,
    required String topicId,
    required String lessonNameForPath,
  }) async {
    final actualTopicFolderName = await getActualTopicFolderName(
      lessonId: lessonId,
      topicId: topicId,
      lessonNameForPath: lessonNameForPath,
    );
    
    // Önce konular klasörünü kontrol et
    try {
      final konularPath = 'dersler/$lessonNameForPath/konular';
      final folders = await _storageService.listFolders(konularPath);
      if (folders.isNotEmpty) {
        // Konular klasöründe topic var mı kontrol et
        final normalizedTopicFolderName = actualTopicFolderName
            .toLowerCase()
            .replaceAll(' ', '_')
            .replaceAll('ı', 'i')
            .replaceAll('ğ', 'g')
            .replaceAll('ü', 'u')
            .replaceAll('ş', 's')
            .replaceAll('ö', 'o')
            .replaceAll('ç', 'c')
            .replaceAll(RegExp(r'^\d+[-.]?\s*'), '');
        
        for (final folder in folders) {
          final normalizedFolder = folder
              .toLowerCase()
              .replaceAll(' ', '_')
              .replaceAll('ı', 'i')
              .replaceAll('ğ', 'g')
              .replaceAll('ü', 'u')
              .replaceAll('ş', 's')
              .replaceAll('ö', 'o')
              .replaceAll('ç', 'c')
              .replaceAll(RegExp(r'^\d+[-.]?\s*'), '');
          
          if (normalizedFolder == normalizedTopicFolderName) {
            return 'dersler/$lessonNameForPath/konular/$folder';
          }
        }
      }
    } catch (e) {
      // Silent error handling
    }
    
    // Konular klasöründe bulunamadıysa, direkt ders altından kullan
    return 'dersler/$lessonNameForPath/$actualTopicFolderName';
  }

  /// Helper method: Get actual topic folder name from storage
  /// Topic ID'de normalize edilmiş folder name var, ama storage'da gerçek klasör ismi farklı olabilir
  /// Bu yüzden storage'dan tüm klasörleri listele ve eşleştir
  Future<String> getActualTopicFolderName({
    required String lessonId,
    required String topicId,
    required String lessonNameForPath,
  }) async {
    try {
      // Topic ID'den topicFolderName'i çıkar
      String topicFolderName;
      if (topicId.startsWith('${lessonId}_')) {
        topicFolderName = topicId.substring(lessonId.length + 1);
      } else {
        final parts = topicId.split('_');
        if (parts.length < 2) {
          return topicId;
        }
        topicFolderName = parts.sublist(1).join('_');
      }
      
      // Önce konular klasörünü kontrol et, yoksa veya içinde konu bulunamazsa direkt ders altından bak
      List<String> folders = [];
      bool useDirectLessonPath = false;
      
      try {
        // Önce konular klasörünü kontrol et
        final konularPath = 'dersler/$lessonNameForPath/konular';
        folders = await _storageService.listFolders(konularPath);
        
        // Eğer konular/ klasörü boşsa, direkt ders altından bak
        if (folders.isEmpty) {
          useDirectLessonPath = true;
        }
      } catch (e) {
        // Konular klasörü yoksa, direkt ders altından bak
        // Silent error handling
        useDirectLessonPath = true;
      }
      
      // Eğer konular/ klasörü boşsa veya yoksa, direkt ders altından bak
      if (useDirectLessonPath || folders.isEmpty) {
        try {
          final lessonPath = 'dersler/$lessonNameForPath';
          folders = await _storageService.listFolders(lessonPath);
          // 'konular' klasörünü hariç tut (eğer varsa)
          folders = folders.where((folder) => folder != 'konular').toList();
          } catch (e2) {
          // Silent error handling
        }
      }
      
      if (folders.isEmpty) {
        // Klasör bulunamadıysa, normalize edilmiş ismi kullan
        return topicFolderName;
      }
      
      // Normalize edilmiş folder name ile eşleşen gerçek klasör ismini bul
      // Topic ID'den çıkarılan name zaten normalize edilmiş, ama yine de normalize et (tutarlılık için)
      final normalizedTopicFolderName = topicFolderName
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll('ı', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c')
          .replaceAll(RegExp(r'^\d+[-.]?\s*'), ''); // Sayısal prefix'i temizle (eğer varsa)
      
      
      for (final folder in folders) {
        final normalizedFolder = folder
            .toLowerCase()
            .replaceAll(' ', '_')
            .replaceAll('ı', 'i')
            .replaceAll('ğ', 'g')
            .replaceAll('ü', 'u')
            .replaceAll('ş', 's')
            .replaceAll('ö', 'o')
            .replaceAll('ç', 'c')
            .replaceAll(RegExp(r'^\d+[-.]?\s*'), ''); // Sayısal prefix'i temizle
        
        
        if (normalizedFolder == normalizedTopicFolderName) {
          return folder; // Gerçek klasör ismini döndür
        }
      }
      
      
      // Eğer tam eşleşme yoksa, fuzzy matching dene (apostrof karakterlerini yok say)
      final normalizedTopicFolderNameNoApostrophe = normalizedTopicFolderName
          .replaceAll("'", '')
          .replaceAll("'", '') // Farklı apostrof karakteri
          .replaceAll("'", ''); // Başka bir apostrof karakteri
      
      for (final folder in folders) {
        final normalizedFolder = folder
            .toLowerCase()
            .replaceAll(' ', '_')
            .replaceAll('ı', 'i')
            .replaceAll('ğ', 'g')
            .replaceAll('ü', 'u')
            .replaceAll('ş', 's')
            .replaceAll('ö', 'o')
            .replaceAll('ç', 'c')
            .replaceAll(RegExp(r'^\d+[-.]?\s*'), '') // Sayısal prefix'i temizle
            .replaceAll("'", '') // Apostrof'u temizle
            .replaceAll("'", '') // Farklı apostrof karakteri
            .replaceAll("'", ''); // Başka bir apostrof karakteri
        
        if (normalizedFolder == normalizedTopicFolderNameNoApostrophe) {
          return folder; // Gerçek klasör ismini döndür
        }
        
        // Son çare: içerik kontrolü (birbirini içeriyorsa)
        if (normalizedFolder.length > 5 && normalizedTopicFolderNameNoApostrophe.length > 5) {
          if (normalizedFolder.contains(normalizedTopicFolderNameNoApostrophe) || 
              normalizedTopicFolderNameNoApostrophe.contains(normalizedFolder)) {
            return folder;
          }
        }
      }
      
      // Eğer konular/ klasöründe eşleşme bulunamadıysa ve direkt ders altından bakmadıysak, şimdi direkt ders altından bak
      if (!useDirectLessonPath) {
        try {
          final lessonPath = 'dersler/$lessonNameForPath';
          final directFolders = await _storageService.listFolders(lessonPath);
          // 'konular' klasörünü hariç tut (eğer varsa)
          final filteredDirectFolders = directFolders.where((folder) => folder != 'konular').toList();
          
          // Direkt ders altından eşleşme ara
          for (final folder in filteredDirectFolders) {
            final normalizedFolder = folder
                .toLowerCase()
                .replaceAll(' ', '_')
                .replaceAll('ı', 'i')
                .replaceAll('ğ', 'g')
                .replaceAll('ü', 'u')
                .replaceAll('ş', 's')
                .replaceAll('ö', 'o')
                .replaceAll('ç', 'c')
                .replaceAll(RegExp(r'^\d+[-.]?\s*'), '');
            
            if (normalizedFolder == normalizedTopicFolderName) {
              return folder;
            }
            
            // Fuzzy matching
            final normalizedFolderNoApostrophe = normalizedFolder
                .replaceAll("'", '')
                .replaceAll("'", '')
                .replaceAll("'", '');
            
            if (normalizedFolderNoApostrophe == normalizedTopicFolderNameNoApostrophe) {
              return folder;
            }
            
            // Partial matching
            if (normalizedFolder.length > 5 && normalizedTopicFolderNameNoApostrophe.length > 5) {
              if (normalizedFolder.contains(normalizedTopicFolderNameNoApostrophe) || 
                  normalizedTopicFolderNameNoApostrophe.contains(normalizedFolder)) {
                return folder;
              }
            }
          }
        } catch (e) {
          // Silent error handling
        }
      }
      
      // Eşleşme bulunamadıysa, normalize edilmiş ismi kullan
      return topicFolderName;
    } catch (e) {
      // Silent error handling
      // Topic ID'den direkt çıkar
      if (topicId.startsWith('${lessonId}_')) {
        return topicId.substring(lessonId.length + 1);
      }
      return topicId;
    }
  }

  /// Get content counts for a specific topic (video, podcast, flashcard, PDF)
  /// Bu metod konu detay sayfasında kullanılır
  Future<Topic> getTopicContentCounts(Topic topic) async {
    try {
      
      // Topic zaten lessonId'yi içeriyor, direkt kullan
      final lessonId = topic.lessonId;
      
      // Lesson'ı al
      final lesson = await getLessonById(lessonId);
      if (lesson == null) {
        // Silent error handling
        return topic;
      }
      
      // Lesson name'i storage path'ine çevir
      final lessonNameForPath = lesson.name
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll('ı', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c');
      
      // Konu klasörü path'ini oluştur (önce konular/ altına bakar, yoksa direkt ders altına bakar)
      final topicBasePath = await getTopicBasePath(
        lessonId: lessonId,
        topicId: topic.id,
        lessonNameForPath: lessonNameForPath,
      );
      
      final videoPath = '$topicBasePath/video';
      final podcastPath = '$topicBasePath/podcast';
      final bilgikartiPath = '$topicBasePath/bilgikarti';
      final notPath = '$topicBasePath/not';
      final notlarPath = '$topicBasePath/notlar';
      
      // Dosya sayılarını paralel olarak say (hızlı - sadece dosya sayısı)
      // Test soru sayısı ayrı hesaplanacak (cache'den hızlı)
      final counts = await Future.wait([
        _storageService.countFilesInFolder(videoPath).catchError((_) => 0),
        _storageService.countFilesInFolder(podcastPath).catchError((_) => 0),
        _storageService.countFilesInFolder(bilgikartiPath).catchError((_) => 0), // Hızlı: sadece dosya sayısı
        _storageService.countFilesInFolder(notPath).catchError((_) => 0),
        _storageService.countFilesInFolder(notlarPath).catchError((_) => 0),
        _countPdfsFast(topicBasePath), // PDF sayısını paralel hesapla
      ]);
      
      // Test soru sayısını ayrı hesapla (cache'den çok hızlı - non-blocking)
      // Arka planda hesapla, sayfa açılışını engelleme
      int testQuestionCount = 0;
      try {
        // Hızlı: Sadece cache'den sayıyı al (parse etmeden - çok hızlı)
        final prefs = await SharedPreferences.getInstance();
        final cacheKey = 'questions_${topic.id}';
        final cachedJson = prefs.getString(cacheKey);
        
        if (cachedJson != null && cachedJson.isNotEmpty) {
          // Çok hızlı: Sadece '{' karakterlerini say (parse etmeden)
          // Her soru bir object olduğu için '{' sayısı soru sayısını verir
          int braceCount = 0;
          for (int i = 0; i < cachedJson.length; i++) {
            if (cachedJson[i] == '{') braceCount++;
          }
          testQuestionCount = braceCount;
          if (testQuestionCount > 0) {
          }
        }
      } catch (e) {
        // Hata olursa 0 döndür, sayfa açılsın
        // Silent error handling
      }
      final videoCount = counts[0];
      final podcastCount = counts[1];
      final bilgikartiFileCount = counts[2]; // Dosya sayısı (hızlı)
      final notCount = counts[3] + counts[4];
      final pdfCount = counts[5]; // PDF sayısı
      
      // Bilgi kartı sayısı: Dosya sayısını direkt kullan (hızlı - cache kontrolü yok)
      int bilgikartiCount = bilgikartiFileCount;
      
      // PDF URL'ini bul (ilk PDF için - lazy load, sadece gerektiğinde)
      // Şu an sadece sayıları gösteriyoruz, URL'ye gerek yok
      String? pdfUrl;
      // PDF URL'i lazy load edilecek (kullanıcı PDF sayfasına girdiğinde)
      
      // Test sayısı: Eğer soru varsa 1 test olarak say (soru sayısını göster)
      // testCount aslında test sayısı değil, soru sayısı olarak kullanılacak
      final testCount = testQuestionCount > 0 ? 1 : 0;
      
      // Topic'i güncelle
      final updatedTopic = Topic(
        id: topic.id,
        lessonId: topic.lessonId,
        name: topic.name,
        subtitle: topic.subtitle,
        duration: topic.duration,
        averageQuestionCount: testQuestionCount, // Soru sayısını buraya kaydet
        testCount: testCount, // Test sayısı (soru varsa 1)
        podcastCount: podcastCount,
        videoCount: videoCount,
        noteCount: notCount, // Notlar ayrı
        flashCardCount: bilgikartiCount, // Bilgi kartı sayısı
        pdfCount: pdfCount, // PDF sayısı
        progress: topic.progress,
        order: topic.order,
        pdfUrl: pdfUrl,
      );
      
      // Sayıları cache'e kaydet (hızlı erişim için)
      try {
        final prefs = await SharedPreferences.getInstance();
        final cacheKey = 'content_counts_${topic.id}';
        await prefs.setString(cacheKey, jsonEncode({
          'videoCount': videoCount,
          'podcastCount': podcastCount,
          'flashCardCount': bilgikartiCount,
          'noteCount': notCount,
          'pdfCount': pdfCount,
          'testQuestionCount': testQuestionCount,
        }));
        
        // Soru sayısını ayrı bir key ile de kaydet (lesson_card için hızlı erişim)
        if (testQuestionCount > 0) {
          await prefs.setInt('questions_count_${topic.id}', testQuestionCount);
        }
      } catch (e) {
        // Silent error handling
      }
      
      return updatedTopic;
    } catch (e) {
      debugPrint('❌ Error fetching content counts for topic ${topic.name}: $e');
      return topic;
    }
  }


  /// Helper method to count PDFs quickly (sadece dosya isimlerine bak, URL almadan)
  Future<int> _countPdfsFast(String topicBasePath) async {
    try {
      final konuAnlatimiPath = '$topicBasePath/konu';
      final konuAnlatimiPathAlt = '$topicBasePath/konu_anlatimi';
      final pdfPath = '$topicBasePath/pdf';
      
      // PDF dosyalarını filtrele (sadece dosya isimlerine bak, URL almadan - çok hızlı)
      int totalPdfCount = 0;
      
      // konu/ klasöründen PDF sayısı
      try {
        final fileNames = await _storageService.listFileNames(konuAnlatimiPath);
        totalPdfCount += fileNames.where((name) => name.toLowerCase().endsWith('.pdf')).length;
      } catch (e) {
        // Hata olursa devam et
      }
      
      // konu_anlatimi/ klasöründen PDF sayısı
      try {
        final fileNames = await _storageService.listFileNames(konuAnlatimiPathAlt);
        totalPdfCount += fileNames.where((name) => name.toLowerCase().endsWith('.pdf')).length;
      } catch (e) {
        // Hata olursa devam et
      }
      
      // pdf/ klasöründen PDF sayısı
      try {
        final fileNames = await _storageService.listFileNames(pdfPath);
        totalPdfCount += fileNames.where((name) => name.toLowerCase().endsWith('.pdf')).length;
      } catch (e) {
        // Hata olursa devam et
      }
      
      return totalPdfCount;
    } catch (e) {
      // Silent error handling
      return 0;
    }
  }

  /// Helper method to get topics from Firestore
  Future<List<Topic>> _getTopicsFromFirestore(String lessonId) async {
    try {
      final snapshot = await _topicsCollection
          .where('lessonId', isEqualTo: lessonId)
          .get();
      final topics = snapshot.docs
          .map((doc) => Topic.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      topics.sort((a, b) => a.order.compareTo(b.order));
      return topics;
    } catch (e) {
      debugPrint('❌ Error fetching topics from Firestore: $e');
      return [];
    }
  }

  /// Stream all lessons (real-time updates)
  Stream<List<Lesson>> streamAllLessons() {
    return _lessonsCollection
        .snapshots()
        .map((snapshot) {
          final lessons = snapshot.docs
              .map((doc) => Lesson.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          // Sort by order on client side
          lessons.sort((a, b) => a.order.compareTo(b.order));
          return lessons;
        });
  }

  /// Stream lessons by category (real-time updates)
  Stream<List<Lesson>> streamLessonsByCategory(String category) {
    return _lessonsCollection
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) {
          final lessons = snapshot.docs
              .map((doc) => Lesson.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          // Sort by order on client side
          lessons.sort((a, b) => a.order.compareTo(b.order));
          return lessons;
        });
  }

  /// Stream topics for a lesson (sadece bir defa çeker, sürekli çekmez)
  /// Note: Storage-based topics don't support real-time updates, bu yüzden sadece bir defa çekiyoruz
  Stream<List<Topic>> streamTopicsByLessonId(String lessonId) async* {
    // Sadece bir defa çek (performans için)
    yield await getTopicsByLessonId(lessonId);
  }

  /// Add a new lesson (admin function)
  Future<bool> addLesson(Lesson lesson) async {
    try {
      await _lessonsCollection.doc(lesson.id).set(lesson.toMap(), SetOptions(merge: true));
      debugPrint('✅ Lesson "${lesson.name}" added/updated');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding lesson: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error details: ${e.toString()}');
      return false;
    }
  }

  /// Add a new topic (admin function)
  Future<bool> addTopic(Topic topic) async {
    try {
      await _topicsCollection.doc(topic.id).set(topic.toMap(), SetOptions(merge: true));
      debugPrint('✅ Topic "${topic.name}" added/updated');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding topic: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error details: ${e.toString()}');
      return false;
    }
  }

  /// Update topic progress
  Future<bool> updateTopicProgress(String topicId, double progress) async {
    try {
      await _topicsCollection.doc(topicId).update({'progress': progress});
      return true;
    } catch (e) {
      debugPrint('Error updating topic progress: $e');
      return false;
    }
  }
}

