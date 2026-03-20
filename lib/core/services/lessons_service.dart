import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/lesson.dart';
import '../models/topic.dart';
import 'storage_service.dart';
import 'questions_service.dart';
import 'flash_card_cache_service.dart';

/// Service for managing lessons and topics from Firestore
class LessonsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();

  // Collection references
  CollectionReference get _lessonsCollection =>
      _firestore.collection('lessons');
  CollectionReference get _topicsCollection => _firestore.collection('topics');

  String normalizeForStoragePath(String input) {
    return input
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }

  /// Get all lessons
  Future<List<Lesson>> getAllLessons() async {
    try {
      final snapshot = await _lessonsCollection.get();
      final lessons = snapshot.docs
          .map(
            (doc) => Lesson.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
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
          .map(
            (doc) => Lesson.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
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
      // 1. Try Cache first
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'lesson_cache_$lessonId';
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
        try {
          final decoded = jsonDecode(cachedJson);
          if (decoded is Map) {
            return Lesson.fromMap(Map<String, dynamic>.from(decoded), lessonId);
          }
        } catch (_) {}
      }

      // 2. Fetch from Firestore
      final doc = await _lessonsCollection.doc(lessonId).get();
      if (doc.exists) {
        final data = doc.data()! as Map<String, dynamic>;
        // Save to cache - Handle potential Timestamp objects
        final encodableData = _makeEncodable(data);
        await prefs.setString(cacheKey, jsonEncode(encodableData));
        return Lesson.fromMap(data, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching lesson: $e');
      return null;
    }
  }

  /// Helper to make a map encodable by converting Timestamps to strings
  Map<String, dynamic> _makeEncodable(Map<String, dynamic> data) {
    final Map<String, dynamic> encodable = {};
    data.forEach((key, value) {
      if (value is Timestamp) {
        encodable[key] = value.toDate().toIso8601String();
      } else if (value is Map<String, dynamic>) {
        encodable[key] = _makeEncodable(value);
      } else if (value is List) {
        encodable[key] = value.map((e) {
          if (e is Map<String, dynamic>) return _makeEncodable(e);
          if (e is Timestamp) return e.toDate().toIso8601String();
          return e;
        }).toList();
      } else {
        encodable[key] = value;
      }
    });
    return encodable;
  }

  /// Get all topics
  Future<List<Topic>> getAllTopics() async {
    try {
      final snapshot = await _topicsCollection.get();
      final topics = snapshot.docs
          .map(
            (doc) => Topic.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
      // Sort by order on client side
      topics.sort((a, b) => a.order.compareTo(b.order));
      return topics;
    } catch (e) {
      debugPrint('Error fetching all topics: $e');
      return [];
    }
  }

  /// Get all hidden topic IDs
  Future<List<String>> getHiddenTopics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cache
      final cachedJson = prefs.getString('hidden_topics_cache');
      if (cachedJson != null) {
        return List<String>.from(jsonDecode(cachedJson));
      }
      
      // Firestore
      final doc = await _firestore.collection('settings').doc('topics_visibility').get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final hidden = List<String>.from(data['hidden'] ?? []);
        await prefs.setString('hidden_topics_cache', jsonEncode(hidden));
        return hidden;
      }
      return []; // Return empty if not created yet (all topics visible by default)
    } catch (e) {
      debugPrint('Error getting hidden topics: $e');
      return [];
    }
  }

  /// Toggle topic hidden status
  Future<void> toggleTopicHiddenStatus(String topicId, bool isHidden) async {
    try {
      final docRef = _firestore.collection('settings').doc('topics_visibility');
      if (isHidden) {
        await docRef.set({
          'hidden': FieldValue.arrayUnion([topicId])
        }, SetOptions(merge: true));
      } else {
        await docRef.set({
          'hidden': FieldValue.arrayRemove([topicId])
        }, SetOptions(merge: true));
      }
      
      // Update cache
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('hidden_topics_cache');
      List<String> currentHidden = [];
      if (cachedJson != null) {
        currentHidden = List<String>.from(jsonDecode(cachedJson));
      } else {
        final doc = await docRef.get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          currentHidden = List<String>.from(data['hidden'] ?? []);
        }
      }

      if (isHidden && !currentHidden.contains(topicId)) {
        currentHidden.add(topicId);
      } else if (!isHidden && currentHidden.contains(topicId)) {
        currentHidden.remove(topicId);
      }
      await prefs.setString('hidden_topics_cache', jsonEncode(currentHidden));
    } catch (e) {
      debugPrint('Error toggling topic hidden status: $e');
    }
  }

  /// Get all topics for a lesson from Storage (sadece konu isimlerini çeker, içerik sayılarını çekmez)
  /// Storage yapısı: dersler/{lessonName}/{topicName}/video/, dersler/{lessonName}/{topicName}/podcast/, dersler/{lessonName}/{topicName}/bilgikarti/
  Future<List<Topic>> getTopicsByLessonId(String lessonId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'topics_cache_$lessonId';
      final cacheTimeKey = 'topics_cache_time_$lessonId';

      // 1. Önce Yerel Cache Kontrolü
      final cachedJson = prefs.getString(cacheKey);
      final cacheTime = prefs.getInt(cacheTimeKey);
      final now = DateTime.now().millisecondsSinceEpoch;

      if (cachedJson != null &&
          cacheTime != null &&
          (now - cacheTime) < 1000 * 60 * 60 * 24 * 3) {
        try {
          final List<dynamic> list = jsonDecode(cachedJson);
          return list
              .where((item) => item is Map)
              .map(
                (item) =>
                    Topic.fromMap(Map<String, dynamic>.from(item as Map), item['id'] ?? ''),
              )
              .toList();
        } catch (_) {}
      }

      // 2. Cache yoksa önce FIRESTORE Kontrolü
      final firestoreTopics = await _getTopicsFromFirestore(lessonId);
      if (firestoreTopics.isNotEmpty) {
        // Firestore'da veri varsa cache'le ve döndür
        await prefs.setString(
          cacheKey,
          jsonEncode(firestoreTopics.map((t) => t.toMap()..['id'] = t.id).toList()),
        );
        await prefs.setInt(cacheTimeKey, now);
        debugPrint('🔥 Topics loaded from Firestore for lesson: $lessonId');
        return firestoreTopics;
      }

      // 3. Firestore boşsa (Fallback), STORAGE üzerinden tara (Sadece Admin sync yapmamışsa çalışır)
      final lesson = await getLessonById(lessonId);
      if (lesson == null) {
        return _getTopicsFromFirestore(lessonId);
      }

      // Storage path'i için birden fazla aday dene:
      // - lesson.name -> guncel_bilgiler
      // - lessonId     -> guncel_bilgiler_lesson (bazı projelerde storage bu şekilde tutuluyor)
      // - lessonId (_lesson suffix stripped) -> guncel_bilgiler
      final lessonNameForPath = normalizeForStoragePath(lesson.name);
      final lessonIdForPath = normalizeForStoragePath(lessonId);
      final strippedLessonIdForPath = lessonIdForPath.endsWith('_lesson')
          ? lessonIdForPath.replaceFirst(RegExp(r'_lesson$'), '')
          : lessonIdForPath;

      final candidates = <String>{
        lessonNameForPath,
        lessonIdForPath,
        strippedLessonIdForPath,
      }.where((e) => e.trim().isNotEmpty).toList();

      List<String> topicFolders = [];
      for (final candidate in candidates) {
        // 1) dersler/{candidate}/konular
        try {
          final konularPath = 'dersler/$candidate/konular';
          topicFolders = await _storageService.listFolders(konularPath);
        } catch (_) {}

        // 2) dersler/{candidate} (konular klasörü yoksa / farklı yapı varsa)
        if (topicFolders.isEmpty) {
          try {
            final lessonPath = 'dersler/$candidate';
            final allFolders = await _storageService.listFolders(lessonPath);
            topicFolders = allFolders
                .where((folder) => folder != 'konular')
                .toList();
          } catch (_) {}
        }

        if (topicFolders.isNotEmpty) {
          break;
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
              .map(
                (word) => word.isNotEmpty
                    ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                    : word,
              )
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
            .replaceAll(
              RegExp(r'^\d+[-.]?\s*'),
              '',
            ); // Sayısal prefix'i temizle

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
              if (normalizedTopicName.toLowerCase().contains(
                    entry.key.toLowerCase(),
                  ) ||
                  entry.key.toLowerCase().contains(
                    normalizedTopicName.toLowerCase(),
                  )) {
                topicOrder = entry.value;
                break;
              }
            }
          }
        }

        // Topic oluştur (içerik sayıları 0, konu detay sayfasında çekilecek)
        topics.add(
          Topic(
            id: topicId,
            lessonId: lessonId,
            name: topicName,
            subtitle: '$topicName konusu',
            duration: '0h 0min',
            averageQuestionCount: 0,
            testCount: 0,
            podcastCount: 0,
            videoCount: 0,
            noteCount: 0,
            order: topicOrder,
          ),
        );
      }
      // Sıralama (order'a göre)
      topics.sort((a, b) => a.order.compareTo(b.order));

      // 3. Save to Cache
      try {
        await prefs.setString(
          cacheKey,
          jsonEncode(topics.map((t) => t.toMap()..['id'] = t.id).toList()),
        );
        await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
      } catch (e) {
        debugPrint('⚠️ Error saving topics to cache: $e');
      }

      return topics;
    } catch (e) {
      debugPrint('Error getting topics: $e');
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
          .replaceAll(
            RegExp(r'^\d+[-.]?\s*'),
            '',
          ); // Sayısal prefix'i temizle (eğer varsa)

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
            .replaceAll(
              RegExp(r'^\d+[-.]?\s*'),
              '',
            ); // Sayısal prefix'i temizle

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
        if (normalizedFolder.length > 5 &&
            normalizedTopicFolderNameNoApostrophe.length > 5) {
          if (normalizedFolder.contains(
                normalizedTopicFolderNameNoApostrophe,
              ) ||
              normalizedTopicFolderNameNoApostrophe.contains(
                normalizedFolder,
              )) {
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
          final filteredDirectFolders = directFolders
              .where((folder) => folder != 'konular')
              .toList();

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

            if (normalizedFolderNoApostrophe ==
                normalizedTopicFolderNameNoApostrophe) {
              return folder;
            }

            // Partial matching
            if (normalizedFolder.length > 5 &&
                normalizedTopicFolderNameNoApostrophe.length > 5) {
              if (normalizedFolder.contains(
                    normalizedTopicFolderNameNoApostrophe,
                  ) ||
                  normalizedTopicFolderNameNoApostrophe.contains(
                    normalizedFolder,
                  )) {
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
  Future<Topic> getTopicContentCounts(
    Topic topic, {
    bool syncPdfs = true,
    bool syncPodcasts = true,
    bool syncNotes = true,
    bool syncFlashCards = true,
    bool syncTests = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'content_counts_${topic.id}';
      final cacheTimeKey = 'content_counts_time_${topic.id}';

      // 0. Firestore'dan mevcut verileri çek (Eksik alanları korumak için)
      final topicSnapshot = await _topicsCollection.doc(topic.id).get();
      Map<String, dynamic> currentData = {};
      if (topicSnapshot.exists) {
        currentData = topicSnapshot.data() as Map<String, dynamic>? ?? {};
      }

      // 1. Yerel Cache Kontrolü
      final cachedJson = prefs.getString(cacheKey);
      final cacheTime = prefs.getInt(cacheTimeKey);
      final now = DateTime.now().millisecondsSinceEpoch;

      if (cachedJson != null &&
          cacheTime != null &&
          (now - cacheTime) < 1000 * 60 * 60 * 24 * 1) {
        try {
          final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
          return Topic(
            id: topic.id,
            lessonId: topic.lessonId,
            name: topic.name,
            subtitle: topic.subtitle,
            duration: topic.duration,
            averageQuestionCount: (decoded['testQuestionCount'] ?? 0) as int,
            testCount: (decoded['testCount'] ?? 0) as int,
            podcastCount: (decoded['podcastCount'] ?? 0) as int,
            videoCount: (decoded['videoCount'] ?? 0) as int,
            noteCount: (decoded['noteCount'] ?? 0) as int,
            flashCardCount: (decoded['flashCardCount'] ?? 0) as int,
            pdfCount: (decoded['pdfCount'] ?? 0) as int,
            progress: topic.progress,
            order: topic.order,
          );
        } catch (_) {}
      }

      // 2. FIRESTORE "Global Sync" Kontrolü
      if (currentData.containsKey('lastGlobalSync')) {
          final updatedTopic = Topic.fromMap(currentData, topic.id);
          
          await prefs.setString(cacheKey, jsonEncode({
            'videoCount': updatedTopic.videoCount,
            'podcastCount': updatedTopic.podcastCount,
            'flashCardCount': updatedTopic.flashCardCount,
            'noteCount': updatedTopic.noteCount,
            'pdfCount': updatedTopic.pdfCount,
            'testQuestionCount': updatedTopic.averageQuestionCount,
            'testCount': updatedTopic.testCount,
          }));
          await prefs.setInt(cacheTimeKey, now);
          
          return updatedTopic;
      }

      // 3. STORAGE üzerinden say (Sadece sync istenenleri tara)
      final lessonId = topic.lessonId;
      final lesson = await getLessonById(lessonId);
      if (lesson == null) return topic;

      final lessonNameForPath = normalizeForStoragePath(lesson.name);
      final topicBasePath = await getTopicBasePath(
        lessonId: lessonId,
        topicId: topic.id,
        lessonNameForPath: lessonNameForPath,
      );

      int podcastCount = currentData['podcastCount'] ?? 0;
      if (syncPodcasts) {
        try {
          podcastCount = await _storageService.countFilesInFolder('$topicBasePath/podcast');
        } catch (_) {}
      }

      int flashCardCount = currentData['flashCardCount'] ?? 0;
      if (syncFlashCards) {
        flashCardCount = await _countFlashCardsTotal(topic.id, '$topicBasePath/bilgikarti');
      }

      int noteCount = currentData['noteCount'] ?? 0;
      if (syncNotes) {
        try {
          final n1 = await _storageService.countFilesInFolder('$topicBasePath/not');
          final n2 = await _storageService.countFilesInFolder('$topicBasePath/notlar');
          noteCount = n1 + n2;
        } catch (_) {}
      }

      int pdfCount = currentData['pdfCount'] ?? 0;
      if (syncPdfs) {
        pdfCount = await _countPdfsFast(topicBasePath);
      }

      int testCount = currentData['testCount'] ?? 0;
      if (syncTests) {
        try {
          final testFiles = await _storageService.listJsonFiles('$topicBasePath/soru');
          testCount = testFiles.length;
        } catch (_) {}
      }

      int testQuestionCount = currentData['averageQuestionCount'] ?? 0;
      if (syncTests) {
        try {
          final qService = QuestionsService();
          final availableTests = await qService.getAvailableTestsByTopic(topic.id, topic.lessonId);
          int totalQ = 0;
          for (final test in availableTests) {
            totalQ += (test['questionCount'] as int? ?? 0);
          }
          testQuestionCount = totalQ;
        } catch (_) {}
      }

      final updatedTopic = Topic(
        id: topic.id,
        lessonId: topic.lessonId,
        name: topic.name,
        subtitle: topic.subtitle,
        duration: topic.duration,
        averageQuestionCount: testQuestionCount,
        testCount: testCount,
        podcastCount: podcastCount,
        videoCount: 0,
        noteCount: noteCount,
        flashCardCount: flashCardCount,
        pdfCount: pdfCount,
        progress: topic.progress,
        order: topic.order,
      );

      // Firestore ve Cache Güncelleme
      try {
        final Map<String, dynamic> dataToLocal = {
          'videoCount': 0,
          'podcastCount': podcastCount,
          'flashCardCount': flashCardCount,
          'noteCount': noteCount,
          'pdfCount': pdfCount,
          'testQuestionCount': testQuestionCount,
          'testCount': testCount,
        };

        await prefs.setString(cacheKey, jsonEncode(dataToLocal));
        await prefs.setInt(cacheTimeKey, now);

        await _topicsCollection.doc(topic.id).set({
          ...dataToLocal,
          'averageQuestionCount': testQuestionCount, // rename for consistency if needed
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      return updatedTopic;
    } catch (e) {
      debugPrint('❌ Error in getTopicContentCounts: $e');
      return topic;
    }
  }

  /// Helper method to count PDFs quickly
  Future<int> _countPdfsFast(String topicBasePath) async {
    int totalPdfCount = 0;
    final folderPaths = [
      '$topicBasePath/konu',
      '$topicBasePath/konu_anlatimi',
      '$topicBasePath/pdf',
    ];

    for (final folderPath in folderPaths) {
      try {
        final fileNames = await _storageService.listFileNames(folderPath);
        totalPdfCount += fileNames.where((n) => n.toLowerCase().endsWith('.pdf')).length;
      } catch (_) {}
    }
    return totalPdfCount;
  }

  /// Helper method to get topics from Firestore
  Future<List<Topic>> _getTopicsFromFirestore(String lessonId) async {
    try {
      final snapshot = await _topicsCollection
          .where('lessonId', isEqualTo: lessonId)
          .get();
      final topics = snapshot.docs
          .map(
            (doc) => Topic.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
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
    return _lessonsCollection.snapshots().map((snapshot) {
      final lessons = snapshot.docs
          .map(
            (doc) => Lesson.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
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
              .map(
                (doc) =>
                    Lesson.fromMap(doc.data() as Map<String, dynamic>, doc.id),
              )
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
      await _lessonsCollection
          .doc(lesson.id)
          .set(lesson.toMap(), SetOptions(merge: true));
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
      await _topicsCollection
          .doc(topic.id)
          .set(topic.toMap(), SetOptions(merge: true));
      debugPrint('✅ Topic "${topic.name}" added/updated');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding topic: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error details: ${e.toString()}');
      return false;
    }
  }

  Future<bool> updateTopicProgress(String topicId, double progress) async {
    try {
      await _topicsCollection.doc(topicId).update({'progress': progress});
      return true;
    } catch (e) {
      debugPrint('Error updating topic progress: $e');
      return false;
    }
  }

  /// Toplam bilgi kartı sayısını hesaplar (CSV içindeki satırları sayar)
  Future<int> _countFlashCardsTotal(String topicId, String folderPath) async {
    try {
      final files = await _storageService.listFilesWithPaths(folderPath);
      if (files.isEmpty) return 0;

      int totalCount = 0;
      for (final file in files) {
        final filePath = file['fullPath']!;
        final fileUrl = file['url']!;
        
        // 1. Önce cache'de var mı bak
        if (await FlashCardCacheService.isCachedByPath(filePath)) {
          final cachedCards = await FlashCardCacheService.getCachedCardsByPath(filePath);
          totalCount += cachedCards.length;
        } else {
          // 2. Cache'de yoksa, indir ve parse et (indirirken cache'ler)
          final cards = await FlashCardCacheService.cacheFlashCardsByPath(
            fileUrl, 
            filePath,
          );
          totalCount += cards.length;
        }
      }
      return totalCount;
    } catch (e) {
      debugPrint('Error counting total flashcards for $topicId: $e');
      return 0;
    }
  }
}
