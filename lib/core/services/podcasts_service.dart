import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/podcast.dart';

/// Service for managing podcasts from Firestore
class PodcastsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference get _podcastsCollection => _firestore.collection('podcasts');

  /// Get all podcasts for a topic
  Future<List<Podcast>> getPodcastsByTopicId(String topicId) async {
    try {
      print('🔍 Querying podcasts with topicId: $topicId');
      final snapshot = await _podcastsCollection
          .where('topicId', isEqualTo: topicId)
          .get();
      print('📊 Found ${snapshot.docs.length} documents');
      final podcasts = snapshot.docs
          .map((doc) {
            print('📄 Processing podcast: ${doc.id}');
            return Podcast.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          })
          .toList();
      // Sort by order on client side
      podcasts.sort((a, b) => a.order.compareTo(b.order));
      print('✅ Returning ${podcasts.length} podcasts');
      return podcasts;
    } catch (e) {
      print('❌ Error fetching podcasts: $e');
      print('Error type: ${e.runtimeType}');
      return [];
    }
  }

  /// Get all podcasts for a lesson
  Future<List<Podcast>> getPodcastsByLessonId(String lessonId) async {
    try {
      final snapshot = await _podcastsCollection
          .where('lessonId', isEqualTo: lessonId)
          .get();
      final podcasts = snapshot.docs
          .map((doc) => Podcast.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      // Sort by order on client side
      podcasts.sort((a, b) => a.order.compareTo(b.order));
      return podcasts;
    } catch (e) {
      print('Error fetching podcasts: $e');
      return [];
    }
  }

  /// Stream podcasts for a topic (real-time updates)
  Stream<List<Podcast>> streamPodcastsByTopicId(String topicId) {
    return _podcastsCollection
        .where('topicId', isEqualTo: topicId)
        .snapshots()
        .map((snapshot) {
          final podcasts = snapshot.docs
              .map((doc) => Podcast.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          // Sort by order on client side
          podcasts.sort((a, b) => a.order.compareTo(b.order));
          return podcasts;
        });
  }

  /// Add a new podcast (admin function)
  Future<bool> addPodcast(Podcast podcast) async {
    try {
      await _podcastsCollection.doc(podcast.id).set(podcast.toMap());
      return true;
    } catch (e) {
      print('Error adding podcast: $e');
      return false;
    }
  }
}

