import 'package:cloud_firestore/cloud_firestore.dart';
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
      print('Error fetching lessons: $e');
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
      print('Error fetching lessons by category: $e');
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
      print('Error fetching lesson: $e');
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
      print('Error fetching all topics: $e');
      return [];
    }
  }

  /// Get all topics for a lesson from Storage (sadece konu isimlerini çeker, içerik sayılarını çekmez)
  /// Storage yapısı: dersler/{lessonName}/{topicName}/video/, dersler/{lessonName}/{topicName}/podcast/, dersler/{lessonName}/{topicName}/bilgikarti/
  Future<List<Topic>> getTopicsByLessonId(String lessonId) async {
    try {
      print('🔍 Loading topic names from Storage for lesson: $lessonId');
      
      // Önce lesson'ı al ki name'ini bulalım
      final lesson = await getLessonById(lessonId);
      if (lesson == null) {
        print('⚠️ Lesson not found: $lessonId, trying Firestore fallback');
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
      print('📂 Looking for topics in: $konularPath');
      
      List<String> topicFolders = [];
      try {
        topicFolders = await _storageService.listFolders(konularPath);
        print('📊 Found ${topicFolders.length} topic folders in konular/ for lesson: ${lesson.name}');
      } catch (e) {
        print('⚠️ konular/ klasörü bulunamadı, alternatif yollar deneniyor: $e');
        // Fallback: dersler/{lessonName}/ altındaki klasörleri listele (konular hariç)
        final lessonPath = 'dersler/$lessonNameForPath';
        final allFolders = await _storageService.listFolders(lessonPath);
        // 'konular' klasörünü hariç tut
        topicFolders = allFolders.where((folder) => folder != 'konular').toList();
        print('📊 Found ${topicFolders.length} topic folders (excluding konular) for lesson: ${lesson.name}');
      }
      
      if (topicFolders.isEmpty) {
        print('⚠️ No topics found in storage for lesson: ${lesson.name}, trying Firestore fallback');
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
      for (int index = 0; index < topicFolders.length; index++) {
        final topicFolderName = topicFolders[index];
        
        // Klasör adından konu adını oluştur (alt çizgileri boşlukla değiştir, ilk harfleri büyük yap)
        final topicName = topicFolderName
            .split('_')
            .map((word) => word.isNotEmpty 
                ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                : word)
            .join(' ');
        
        // Topic ID oluştur (lessonId_topicFolderName formatında)
        final topicId = '${lessonId}_$topicFolderName';
        
        // Vatandaşlık dersi için özel sıralama
        int topicOrder = index + 1;
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
        print('✅ Created topic: $topicName (order: $topicOrder)');
      }
      
      // Sıralama (order'a göre)
      topics.sort((a, b) => a.order.compareTo(b.order));
      
      print('✅ Loaded ${topics.length} topic names from Storage for lesson: ${lesson.name}');
      return topics;
    } catch (e) {
      print('❌ Error fetching topics from Storage: $e');
      print('Error details: $e');
      
      // Fallback to Firestore
      return _getTopicsFromFirestore(lessonId);
    }
  }

  /// Get content counts for a specific topic (video, podcast, flashcard, PDF)
  /// Bu metod konu detay sayfasında kullanılır
  Future<Topic> getTopicContentCounts(Topic topic) async {
    try {
      print('🔍 Loading content counts for topic: ${topic.name}');
      
      // Topic zaten lessonId'yi içeriyor, direkt kullan
      final lessonId = topic.lessonId;
      
      // Topic ID'den topicFolderName'i çıkar
      // Format: lessonId_topicFolderName
      // Topic ID'den lessonId'yi çıkar (topic.lessonId uzunluğu kadar karakter + 1 alt çizgi)
      String topicFolderName;
      if (topic.id.startsWith('${lessonId}_')) {
        topicFolderName = topic.id.substring(lessonId.length + 1); // lessonId_ sonrasını al
      } else {
        // Fallback: Eğer format beklenen gibi değilse, topic ID'den lessonId'yi çıkar
        final parts = topic.id.split('_');
        if (parts.length < 2) {
          print('⚠️ Invalid topic ID format: ${topic.id}');
          return topic;
        }
        topicFolderName = parts.sublist(1).join('_');
      }
      
      // Lesson'ı al
      final lesson = await getLessonById(lessonId);
      if (lesson == null) {
        print('⚠️ Lesson not found: $lessonId (topic ID: ${topic.id})');
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
      
      // Konu klasörü path'ini oluştur
      // Önce konular klasörünü kontrol et
      String topicBasePath;
      try {
        final konularPath = 'dersler/$lessonNameForPath/konular';
        await _storageService.listFolders(konularPath);
        topicBasePath = 'dersler/$lessonNameForPath/konular/$topicFolderName';
      } catch (e) {
        // Fallback: direkt dersler/{lessonName}/{topicFolderName}
        topicBasePath = 'dersler/$lessonNameForPath/$topicFolderName';
      }
      
      final videoPath = '$topicBasePath/video';
      final podcastPath = '$topicBasePath/podcast';
      final bilgikartiPath = '$topicBasePath/bilgikarti';
      final notPath = '$topicBasePath/not';
      final notlarPath = '$topicBasePath/notlar';
      
      // Dosya sayılarını paralel olarak say (hızlı - sadece dosya sayısı)
      final counts = await Future.wait([
        _storageService.countFilesInFolder(videoPath).catchError((_) => 0),
        _storageService.countFilesInFolder(podcastPath).catchError((_) => 0),
        _storageService.countFilesInFolder(bilgikartiPath).catchError((_) => 0), // Hızlı: sadece dosya sayısı
        _storageService.countFilesInFolder(notPath).catchError((_) => 0),
        _storageService.countFilesInFolder(notlarPath).catchError((_) => 0),
        _countPdfsFast(topicBasePath), // PDF sayısını paralel hesapla
      ]);
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
      
      // Topic'i güncelle
      final updatedTopic = Topic(
        id: topic.id,
        lessonId: topic.lessonId,
        name: topic.name,
        subtitle: topic.subtitle,
        duration: topic.duration,
        averageQuestionCount: topic.averageQuestionCount,
        testCount: topic.testCount,
        podcastCount: podcastCount,
        videoCount: videoCount,
        noteCount: notCount, // Notlar ayrı
        flashCardCount: bilgikartiCount, // Bilgi kartı sayısı
        pdfCount: pdfCount, // PDF sayısı
        progress: topic.progress,
        order: topic.order,
        pdfUrl: pdfUrl,
      );
      
      print('✅ Updated topic: ${topic.name} (videos: $videoCount, podcasts: $podcastCount, bilgikarti: $bilgikartiCount, notlar: $notCount, pdfs: $pdfCount)');
      return updatedTopic;
    } catch (e) {
      print('❌ Error fetching content counts for topic ${topic.name}: $e');
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
      print('⚠️ Error counting PDFs: $e');
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
      print('❌ Error fetching topics from Firestore: $e');
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
      print('✅ Lesson "${lesson.name}" added/updated');
      return true;
    } catch (e) {
      print('❌ Error adding lesson: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');
      return false;
    }
  }

  /// Add a new topic (admin function)
  Future<bool> addTopic(Topic topic) async {
    try {
      await _topicsCollection.doc(topic.id).set(topic.toMap(), SetOptions(merge: true));
      print('✅ Topic "${topic.name}" added/updated');
      return true;
    } catch (e) {
      print('❌ Error adding topic: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');
      return false;
    }
  }

  /// Update topic progress
  Future<bool> updateTopicProgress(String topicId, double progress) async {
    try {
      await _topicsCollection.doc(topicId).update({'progress': progress});
      return true;
    } catch (e) {
      print('Error updating topic progress: $e');
      return false;
    }
  }
}

