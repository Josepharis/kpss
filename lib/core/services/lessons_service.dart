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
          progress: 0.0,
          order: index + 1,
          pdfUrl: null, // Konu detay sayfasında çekilecek
        );
        
        topics.add(topic);
        print('✅ Created topic: $topicName');
      }
      
      // Sıralama (zaten index'e göre sıralı)
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
      final konuAnlatimiPath = '$topicBasePath/konu';
      final konuAnlatimiPathAlt = '$topicBasePath/konu_anlatimi';
      final pdfPath = '$topicBasePath/pdf';
      
      // Dosya sayılarını paralel olarak say
      final counts = await Future.wait([
        _storageService.countFilesInFolder(videoPath),
        _storageService.countFilesInFolder(podcastPath),
        _storageService.countFilesInFolder(bilgikartiPath),
      ]);
      final videoCount = counts[0];
      final podcastCount = counts[1];
      final bilgikartiCount = counts[2];
      
      // PDF URL'ini bul
      String? pdfUrl;
      try {
        // Önce 'konu' klasöründen PDF ara
        try {
          final konuFiles = await _storageService.listFiles(konuAnlatimiPath);
          if (konuFiles.isNotEmpty) {
            final pdfFile = konuFiles.firstWhere(
              (url) => url.toLowerCase().endsWith('.pdf'),
              orElse: () => '',
            );
            if (pdfFile.isNotEmpty) {
              pdfUrl = pdfFile;
            } else if (konuFiles.isNotEmpty) {
              pdfUrl = konuFiles.first;
            }
          }
        } catch (e) {
          print('⚠️ Error loading from konu/ folder: $e');
        }
        
        // Eğer bulunamadıysa konu_anlatimi klasöründen ara
        if (pdfUrl == null || pdfUrl.isEmpty) {
          try {
            final konuAnlatimiFiles = await _storageService.listFiles(konuAnlatimiPathAlt);
            if (konuAnlatimiFiles.isNotEmpty) {
              final pdfFile = konuAnlatimiFiles.firstWhere(
                (url) => url.toLowerCase().endsWith('.pdf'),
                orElse: () => '',
              );
              if (pdfFile.isNotEmpty) {
                pdfUrl = pdfFile;
              } else if (konuAnlatimiFiles.isNotEmpty) {
                pdfUrl = konuAnlatimiFiles.first;
              }
            }
          } catch (e) {
            print('⚠️ Error loading from konu_anlatimi/ folder: $e');
          }
        }
        
        // Eğer hala bulunamadıysa pdf klasöründen ara
        if (pdfUrl == null || pdfUrl.isEmpty) {
          try {
            final pdfFiles = await _storageService.listFiles(pdfPath);
            if (pdfFiles.isNotEmpty) {
              final pdfFile = pdfFiles.firstWhere(
                (url) => url.toLowerCase().endsWith('.pdf'),
                orElse: () => '',
              );
              if (pdfFile.isNotEmpty) {
                pdfUrl = pdfFile;
              } else if (pdfFiles.isNotEmpty) {
                pdfUrl = pdfFiles.first;
              }
            }
          } catch (e) {
            print('⚠️ Error loading from pdf/ folder: $e');
          }
        }
      } catch (e) {
        print('⚠️ Error loading PDF for topic ${topic.name}: $e');
      }
      
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
        noteCount: bilgikartiCount,
        progress: topic.progress,
        order: topic.order,
        pdfUrl: pdfUrl,
      );
      
      print('✅ Updated topic: ${topic.name} (videos: $videoCount, podcasts: $podcastCount, bilgikarti: $bilgikartiCount)');
      return updatedTopic;
    } catch (e) {
      print('❌ Error fetching content counts for topic ${topic.name}: $e');
      return topic;
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

