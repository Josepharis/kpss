import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/podcast.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/podcast_cache_service.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/services/podcast_download_service.dart';
import '../../../core/services/storage_cleanup_service.dart';
import '../../../core/services/podcasts_service.dart';
import '../../../core/widgets/floating_home_button.dart';
import '../../../core/widgets/premium_snackbar.dart';

class PodcastsPage extends StatefulWidget {
  final String topicName;
  final int podcastCount;
  final String topicId; // Storage'dan podcast çekmek için
  final String lessonId; // Ders ID'si (Storage yolunu oluşturmak için)
  final String?
  initialAudioUrl; // Anasayfadan geliyorsa, cache'den direkt yükle
  final String? initialPodcastId; // Devam eden podcast'ten geliyorsa direkt seç

  const PodcastsPage({
    super.key,
    required this.topicName,
    required this.podcastCount,
    required this.topicId,
    required this.lessonId,
    this.initialAudioUrl, // Opsiyonel: anasayfadan ongoing podcast'ten geliyorsa
    this.initialPodcastId,
  });

  @override
  State<PodcastsPage> createState() => _PodcastsPageState();
}

class _PodcastsPageState extends State<PodcastsPage>
    with TickerProviderStateMixin {
  final AudioPlayerService _audioService = AudioPlayerService();
  final StorageService _storageService = StorageService();
  final LessonsService _lessonsService = LessonsService();
  final ProgressService _progressService = ProgressService();
  final PodcastDownloadService _downloadService = PodcastDownloadService();
  final StorageCleanupService _cleanupService = StorageCleanupService();
  final PodcastsService _podcastsService = PodcastsService();
  List<Podcast> _podcasts = [];
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isBuffering = false; // Podcast yükleniyor mu?
  String? _currentPlayingUrl; // Şu anda çalan podcast URL'i (cache için)
  bool _ignoreStreamUpdate = false;
  double _playbackSpeed = 1.0;
  Duration _currentPosition = Duration.zero;
  Duration? _totalDuration;
  int _selectedPodcastIndex = 0;
  late final AnimationController _waveController;
  late final AnimationController _pulseController;

  String _cleanTitle(String title) {
    if (title.isEmpty) return title;
    // Regex matches leading numbers followed by common separators like -, ., space, or underscore
    return title.replaceFirst(RegExp(r'^\d+[-.\s_]+'), '').trim();
  }
  Timer? _progressSaveTimer;
  Map<String, bool> _downloadedPodcasts = {}; // Track downloaded podcasts

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<ProcessingState>? _processingStateSubscription;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Cache kontrolünü önce yap ve TAMAMLANMASINI BEKLE (anında açılış için)
    _initializePodcasts();
  }

  /// Initialize podcasts - optimize edilmiş yükleme
  Future<void> _initializePodcasts() async {
    // Önce local cache'den kontrol et (Firestore'dan çekilmiş podcast listesi)
    await _loadPodcastsFromLocalCache();

    // Eğer cache'den yüklenmediyse, Firestore'dan çek ve cache'e kaydet
    if (_podcasts.isEmpty) {
      await _loadPodcastsFromFirestore();
    } else {
      // Cache'den yüklendi, cache'deki dosyaları kontrol et ve file:// URL'lerini güncelle
      await _updateCachedFileUrls();
    }

    // Filter hidden podcasts
    final hiddenItems = await _lessonsService.getHiddenItems();
    if (mounted) {
      setState(() {
        _podcasts = _podcasts.where((p) {
          // Use filename from URL as item ID suffix
          final fileName = p.audioUrl.split('/').last.split('?').first;
          final itemId = 'podcast_${widget.topicId}_$fileName';
          return !hiddenItems.contains(itemId);
        }).toList();
      });
    }

    // İndirilen podcast durumlarını yükle (kalıcı olması için)
    await _loadDownloadedPodcastsStatus();

    // Audio'yu initialize et
    await _initializeAudio();

    // Eğer devam eden podcast'ten gelindiyse, o podcast'i seçip direkt başlat.
    await _applyInitialSelectionAndAutoplayIfNeeded();
  }

  Future<void> _applyInitialSelectionAndAutoplayIfNeeded() async {
    final initialId = widget.initialPodcastId;
    final initialUrl = widget.initialAudioUrl;
    if ((initialId == null || initialId.isEmpty) &&
        (initialUrl == null || initialUrl.isEmpty)) {
      return;
    }
    if (_podcasts.isEmpty) return;

    int index = -1;
    if (initialId != null && initialId.isNotEmpty) {
      index = _podcasts.indexWhere((p) => p.id == initialId);
    }
    // Fallback: URL ile eşle (id bulunamazsa)
    if (index < 0 && initialUrl != null && initialUrl.isNotEmpty) {
      index = _podcasts.indexWhere((p) => p.audioUrl == initialUrl);
    }
    if (index < 0 || index >= _podcasts.length) return;

    if (mounted) {
      setState(() {
        _selectedPodcastIndex = index;
        _isPlaying = false;
        _isBuffering = false;
        _currentPosition = Duration.zero;
        _totalDuration = null;
        _currentPlayingUrl = null;
      });
    } else {
      _selectedPodcastIndex = index;
    }

    await _loadAndPlayCurrentPodcast();
  }

  /// Load podcasts from local cache (Firestore'dan çekilmiş podcast listesi)
  Future<void> _loadPodcastsFromLocalCache() async {
    try {
      debugPrint(
        '🔍 Loading podcasts from local cache for topicId: ${widget.topicId}',
      );
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'podcasts_${widget.topicId}';
      final cachedJson = prefs.getString(cacheKey);

      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> cachedList = jsonDecode(cachedJson);
        _podcasts = cachedList
            .map((json) {
              final p = Podcast.fromMap(json, json['id'] ?? '');
              return Podcast(
                id: p.id,
                title: _cleanTitle(p.title),
                description: p.description,
                audioUrl: p.audioUrl,
                durationMinutes: p.durationMinutes,
                thumbnailUrl: p.thumbnailUrl,
                topicId: p.topicId,
                lessonId: p.lessonId,
                order: p.order,
              );
            })
            .toList();
        debugPrint('✅ Loaded ${_podcasts.length} podcasts from local cache');

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        debugPrint('❌ No podcasts found in local cache');
      }
    } catch (e) {
      debugPrint('⚠️ Error loading podcasts from local cache: $e');
    }
  }

  /// Save podcasts to local cache
  Future<void> _savePodcastsToLocalCache(List<Podcast> podcasts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'podcasts_${widget.topicId}';
      final jsonList = podcasts
          .map(
            (p) => {
              'id': p.id,
              'title': p.title,
              'description': p.description,
              'audioUrl': p.audioUrl,
              'durationMinutes': p.durationMinutes,
              'thumbnailUrl': p.thumbnailUrl,
              'topicId': p.topicId,
              'lessonId': p.lessonId,
              'order': p.order,
            },
          )
          .toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(cacheKey, jsonString);
      debugPrint('✅ Saved ${podcasts.length} podcasts to local cache');
    } catch (e) {
      debugPrint('⚠️ Error saving podcasts to local cache: $e');
    }
  }

  /// Load podcasts from Firestore and cache them
  Future<void> _loadPodcastsFromFirestore() async {
    try {
      debugPrint(
        '🔍 Loading podcasts from Firestore for topicId: ${widget.topicId}',
      );

      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // Firestore'dan podcast'leri çek
      final podcasts = await _podcastsService.getPodcastsByTopicId(
        widget.topicId,
      );

      if (podcasts.isEmpty) {
        debugPrint(
          '⚠️ No podcasts found in Firestore, trying Storage fallback...',
        );
        // Firestore'da yoksa, Storage'dan çek (eski yöntem)
        await _loadPodcastsFromStorage();
        return;
      }

      debugPrint('✅ Found ${podcasts.length} podcasts from Firestore');

      // Cache'e kaydet
      await _savePodcastsToLocalCache(podcasts);

      // Cache'deki dosyaları kontrol et ve file:// URL'lerini güncelle
      _podcasts = podcasts.map((p) => Podcast(
        id: p.id,
        title: _cleanTitle(p.title),
        description: p.description,
        audioUrl: p.audioUrl,
        durationMinutes: p.durationMinutes,
        thumbnailUrl: p.thumbnailUrl,
        topicId: p.topicId,
        lessonId: p.lessonId,
        order: p.order,
      )).toList();
      await _updateCachedFileUrls();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error loading podcasts from Firestore: $e');
      // Hata durumunda Storage'dan çek (fallback)
      await _loadPodcastsFromStorage();
    }
  }

  /// Update cached file URLs (check if files are cached and update URLs to file://)
  Future<void> _updateCachedFileUrls() async {
    try {
      debugPrint('🔍 Updating cached file URLs...');
      final updatedPodcasts = <Podcast>[];

      for (final podcast in _podcasts) {
        // Eğer zaten file:// ile başlıyorsa, atla
        if (podcast.audioUrl.startsWith('file://')) {
          updatedPodcasts.add(podcast);
          continue;
        }

        // Cache'de dosya var mı kontrol et
        final localPath = await _downloadService.getLocalFilePath(
          podcast.audioUrl,
        );
        if (localPath != null) {
          // Cache'de var, file:// URL'ini kullan
          updatedPodcasts.add(
            Podcast(
              id: podcast.id,
              title: podcast.title,
              description: podcast.description,
              audioUrl: 'file://$localPath',
              durationMinutes: podcast.durationMinutes,
              thumbnailUrl: podcast.thumbnailUrl,
              topicId: podcast.topicId,
              lessonId: podcast.lessonId,
              order: podcast.order,
            ),
          );
          debugPrint('  ✅ Updated URL to cached file: ${podcast.title}');
        } else {
          // Cache'de yok, orijinal URL'i kullan
          updatedPodcasts.add(podcast);
        }
      }

      _podcasts = updatedPodcasts;

      if (mounted) {
        setState(() {});
      }

      debugPrint('✅ Updated ${updatedPodcasts.length} podcast URLs');
    } catch (e) {
      debugPrint('⚠️ Error updating cached file URLs: $e');
    }
  }

  /// Load podcasts from Storage (fallback method - eski yöntem, Firestore'da yoksa kullanılır)
  Future<void> _loadPodcastsFromStorage() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      debugPrint(
        '🔍 Loading podcasts from Storage (fallback) for topicId: ${widget.topicId}',
      );

      // Lesson name'i al
      final lesson = await _lessonsService.getLessonById(widget.lessonId);
      if (lesson == null) {
        debugPrint('⚠️ Lesson not found: ${widget.lessonId}');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
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

      // Topic base path'i bul (önce konular/ altına bakar, yoksa direkt ders altına bakar)
      final basePath = await _lessonsService.getTopicBasePath(
        lessonId: widget.lessonId,
        topicId: widget.topicId,
        lessonNameForPath: lessonNameForPath,
      );

      // Storage yolunu oluştur
      String storagePath = '$basePath/podcast';

      // Storage'dan dosyaları listele (hızlı - sadece URL listesi)
      final audioUrls = await _storageService.listAudioFiles(storagePath);

      debugPrint('✅ Found ${audioUrls.length} podcasts from Storage');
      debugPrint('📊 Current podcasts before adding: ${_podcasts.length}');

      // Cache'den yüklenen podcast'lerin dosya adlarını çıkar (duplicate kontrolü için)
      final cachedPodcasts = _podcasts
          .where((p) => p.audioUrl.startsWith('file://'))
          .toList();
      final networkPodcasts = _podcasts
          .where((p) => !p.audioUrl.startsWith('file://'))
          .toList();

      debugPrint(
        '📊 Before adding: Cached podcasts: ${cachedPodcasts.length}, Network podcasts: ${networkPodcasts.length}',
      );

      // Cache'deki podcast'lerin dosya adlarını çıkar (normalize edilmiş)
      final cachedFileNames = <String>{};
      for (final cachedPodcast in cachedPodcasts) {
        try {
          // file:// URL'den dosya adını çıkar
          String fileName = cachedPodcast.audioUrl;
          if (fileName.startsWith('file://')) {
            fileName = fileName.substring(7); // "file://" kısmını kaldır
          }
          // Dosya yolundan sadece dosya adını al
          fileName = fileName.replaceAll('\\', '/').split('/').last;
          // Uzantıyı kaldır ve normalize et
          fileName = fileName
              .replaceAll('.m4a', '')
              .replaceAll('.mp3', '')
              .replaceAll('.mp4', '')
              .toLowerCase()
              .trim();
          if (fileName.isNotEmpty) {
            cachedFileNames.add(fileName);
            debugPrint('  📁 Cached file name: $fileName');
          }
        } catch (e) {
          debugPrint('⚠️ Error extracting cached file name: $e');
        }
      }

      // Firebase Storage'dan gelen podcast'lerin URL'lerini topla
      final existingNetworkUrls = networkPodcasts
          .map((p) => p.audioUrl)
          .toSet();

      // Yeni podcast'leri ekle (cache'de olmayanlar)
      if (cachedPodcasts.isNotEmpty) {
        // Cache'den yüklenen podcast'ler var, onları koru ve yeni olanları ekle
        _podcasts = List<Podcast>.from(
          cachedPodcasts,
        ); // Cache'den yüklenenleri koru
        int newIndex = cachedPodcasts.length;

        for (int index = 0; index < audioUrls.length; index++) {
          final url = audioUrls[index];

          // Eğer bu URL zaten network podcast'lerinde varsa, atla
          if (existingNetworkUrls.contains(url)) {
            debugPrint('  ⏭️ Skipping already loaded network podcast: $url');
            continue;
          }

          // URL'den dosya adını çıkar ve cache'deki dosya adlarıyla karşılaştır
          try {
            String fileName = '';
            try {
              final uri = Uri.parse(url);
              final pathWithoutQuery = uri.path;
              if (pathWithoutQuery.isNotEmpty) {
                final segments = pathWithoutQuery.split('/');
                fileName = segments.lastWhere(
                  (s) => s.isNotEmpty,
                  orElse: () => '',
                );
              }
              if (fileName.isEmpty && uri.pathSegments.isNotEmpty) {
                fileName = uri.pathSegments.last;
              }
              if (fileName.isEmpty) {
                final parts = url.split('/');
                fileName = parts.isNotEmpty ? parts.last : '';
                if (fileName.contains('?')) {
                  fileName = fileName.split('?').first;
                }
              }
              try {
                fileName = Uri.decodeComponent(fileName);
              } catch (e) {
                // Decode edilemezse direkt kullan
              }
            } catch (e) {
              final parts = url.split('/');
              fileName = parts.isNotEmpty ? parts.last : '';
              if (fileName.contains('?')) {
                fileName = fileName.split('?').first;
              }
            }

            fileName = fileName.replaceAll('\\', '/').split('/').last;

            // Normalize edilmiş dosya adını oluştur (cache ile karşılaştırma için)
            final normalizedFileName = fileName
                .replaceAll('.m4a', '')
                .replaceAll('.mp3', '')
                .replaceAll('.mp4', '')
                .toLowerCase()
                .trim();

            // Eğer bu dosya adı cache'de varsa, atla (duplicate)
            if (cachedFileNames.contains(normalizedFileName)) {
              debugPrint(
                '  ⏭️ Skipping duplicate podcast (already in cache): $normalizedFileName',
              );
              continue;
            }

            // Title oluştur ve temizle
            final rawTitle = fileName
                .replaceAll('.m4a', '')
                .replaceAll('.mp3', '')
                .replaceAll('.mp4', '')
                .replaceAll('_', ' ')
                .replaceAll('%20', ' ')
                .trim();
            final title = _cleanTitle(rawTitle);

            _podcasts.add(
              Podcast(
                id: 'podcast_${widget.topicId}_$newIndex',
                title: title.isNotEmpty ? title : 'Podcast ${newIndex + 1}',
                description: '${widget.topicName} podcast',
                audioUrl: url,
                durationMinutes: 0,
                topicId: widget.topicId,
                lessonId: widget.lessonId,
                order: newIndex,
              ),
            );
            newIndex++;
            debugPrint('  ✅ Added new podcast: $title');
          } catch (e) {
            debugPrint('⚠️ Error processing podcast $index: $e');
            _podcasts.add(
              Podcast(
                id: 'podcast_${widget.topicId}_$newIndex',
                title: 'Podcast ${newIndex + 1}',
                description: '${widget.topicName} podcast',
                audioUrl: url,
                durationMinutes: 0,
                topicId: widget.topicId,
                lessonId: widget.lessonId,
                order: newIndex,
              ),
            );
            newIndex++;
          }
        }
      } else {
        // Cache'den yüklenen podcast yok, tüm podcast'leri ekle
        _podcasts = [];
        for (int index = 0; index < audioUrls.length; index++) {
          final url = audioUrls[index];

          try {
            // URL'den sadece dosya adını çıkar (hızlı)
            String fileName = '';
            try {
              final uri = Uri.parse(url);
              final pathWithoutQuery = uri.path;
              if (pathWithoutQuery.isNotEmpty) {
                final segments = pathWithoutQuery.split('/');
                fileName = segments.lastWhere(
                  (s) => s.isNotEmpty,
                  orElse: () => '',
                );
              }
              if (fileName.isEmpty && uri.pathSegments.isNotEmpty) {
                fileName = uri.pathSegments.last;
              }
              if (fileName.isEmpty) {
                final parts = url.split('/');
                fileName = parts.isNotEmpty ? parts.last : '';
                if (fileName.contains('?')) {
                  fileName = fileName.split('?').first;
                }
              }
              try {
                fileName = Uri.decodeComponent(fileName);
              } catch (e) {
                // Decode edilemezse direkt kullan
              }
            } catch (e) {
              final parts = url.split('/');
              fileName = parts.isNotEmpty ? parts.last : 'Podcast ${index + 1}';
              if (fileName.contains('?')) {
                fileName = fileName.split('?').first;
              }
            }

            fileName = fileName.replaceAll('\\', '/').split('/').last;
            final rawTitle = fileName
                .replaceAll('.m4a', '')
                .replaceAll('.mp3', '')
                .replaceAll('.mp4', '')
                .replaceAll('_', ' ')
                .replaceAll('%20', ' ')
                .trim();
            final title = _cleanTitle(rawTitle);

            _podcasts.add(
              Podcast(
                id: 'podcast_${widget.topicId}_$index',
                title: title.isNotEmpty ? title : 'Podcast ${index + 1}',
                description: '${widget.topicName} podcast',
                audioUrl: url,
                durationMinutes: 0, // Arka planda yüklenecek
                topicId: widget.topicId,
                lessonId: widget.lessonId,
                order: index,
              ),
            );
            debugPrint('  ✅ Added podcast ${index + 1}: $title');
          } catch (e) {
            debugPrint('⚠️ Error processing podcast $index: $e');
            _podcasts.add(
              Podcast(
                id: 'podcast_${widget.topicId}_$index',
                title: 'Podcast ${index + 1}',
                description: '${widget.topicName} podcast',
                audioUrl: url,
                durationMinutes: 0,
                topicId: widget.topicId,
                lessonId: widget.lessonId,
                order: index,
              ),
            );
          }
        }
      }

      // Listeyi HEMEN göster (anında açılış için)
      debugPrint('📊 Total podcasts after loading: ${_podcasts.length}');
      
      // 🚀 Arka planda Firestore'a kaydet (Sync)
      _syncDiscoveredPodcastsToFirestore(_podcasts);

      // Cache'e kaydet (bir sonraki açılışta kullanılmak üzere)
      await _savePodcastsToLocalCache(_podcasts);

      // Cache'deki dosyaları kontrol et ve file:// URL'lerini güncelle
      await _updateCachedFileUrls();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // Check downloaded status for all podcasts (arka planda)
      _checkDownloadedPodcasts();

      // Arka planda duration'ları yükle (non-blocking)
      await _loadDurationsInBackground();
      
      // 🚀 Duration'lar yüklendikten sonra Firestore'u tekrar güncelle
      _syncDiscoveredPodcastsToFirestore(_podcasts);
    } catch (e) {
      debugPrint('❌ Error loading podcasts: $e');
      debugPrint('Error stack: ${e.toString()}');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Load downloaded podcasts status from SharedPreferences
  Future<void> _loadDownloadedPodcastsStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'downloaded_podcasts_${widget.topicId}';
      final cachedJson = prefs.getString(cacheKey);

      if (cachedJson != null && cachedJson.isNotEmpty) {
        final Map<String, dynamic> cachedMap = jsonDecode(cachedJson);
        _downloadedPodcasts = cachedMap.map(
          (key, value) => MapEntry(key, value as bool),
        );
        debugPrint(
          '✅ Loaded ${_downloadedPodcasts.length} downloaded podcast statuses from cache',
        );

        if (mounted) {
          setState(() {});
        }
      } else {
        debugPrint('❌ No downloaded podcast statuses found in cache');
      }
    } catch (e) {
      debugPrint('⚠️ Error loading downloaded podcast statuses: $e');
    }
  }

  /// Save downloaded podcasts status to SharedPreferences
  Future<void> _saveDownloadedPodcastsStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'downloaded_podcasts_${widget.topicId}';
      final jsonString = jsonEncode(_downloadedPodcasts);
      await prefs.setString(cacheKey, jsonString);
      debugPrint(
        '✅ Saved ${_downloadedPodcasts.length} downloaded podcast statuses to cache',
      );
    } catch (e) {
      debugPrint('⚠️ Error saving downloaded podcast statuses: $e');
    }
  }

  Future<void> _checkDownloadedPodcasts() async {
    for (final podcast in _podcasts) {
      final isDownloaded = await _downloadService.isPodcastDownloaded(
        podcast.audioUrl,
      );
      if (mounted) {
        setState(() {
          _downloadedPodcasts[podcast.id] = isDownloaded;
        });
      }
    }

    // Durumları kaydet (kalıcı olması için)
    await _saveDownloadedPodcastsStatus();
  }

  // Arka planda duration'ları paralel yükle (çok daha hızlı)
  Future<void> _loadDurationsInBackground() async {
    final futures = <Future<void>>[];

    for (int index = 0; index < _podcasts.length; index++) {
      final podcast = _podcasts[index];
      if (podcast.durationMinutes > 0) continue; // Zaten yüklenmiş

      futures.add(_loadDurationForPodcast(index, podcast));
    }

    // Tüm duration'ları paralel yükle
    await Future.wait(futures);
  }

  // Tek bir podcast için duration yükle
  Future<void> _loadDurationForPodcast(int index, Podcast podcast) async {
    // Eğer zaten cache'de varsa, tekrar yükleme
    if (podcast.durationMinutes > 0) {
      final cached = await PodcastCacheService.getDuration(podcast.audioUrl);
      if (cached != null && cached > 0) {
        return; // Zaten cache'de var
      }
    }

    try {
      final audioPlayer = AudioPlayer();
      // Sadece metadata'yı yükle
      if (podcast.audioUrl.startsWith('file://')) {
        // Cache'den gelen yerel dosya
        await audioPlayer.setFilePath(podcast.audioUrl.substring(7));
      } else {
        await audioPlayer.setUrl(podcast.audioUrl);
      }

      // Duration'ı bekle (maksimum 2 saniye - daha hızlı)
      Duration? duration;
      try {
        duration = await audioPlayer.durationStream
            .firstWhere((d) => d != null)
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        duration = audioPlayer.duration;
      }

      if (duration != null && duration.inMinutes > 0) {
        // Cache'e kaydet
        await PodcastCacheService.saveDuration(
          podcast.audioUrl,
          duration.inMinutes,
        );

        if (mounted) {
          final updatedPodcast = Podcast(
            id: podcast.id,
            title: podcast.title,
            description: podcast.description,
            audioUrl: podcast.audioUrl,
            durationMinutes: duration.inMinutes,
            topicId: podcast.topicId,
            lessonId: podcast.lessonId,
            order: podcast.order,
          );
          _podcasts[index] = updatedPodcast;
          setState(() {}); // UI'ı güncelle
        }
      }
      await audioPlayer.dispose();
    } catch (e) {
      debugPrint('⚠️ Could not get duration for ${podcast.title}: $e');
    }
  }

  Future<void> _initializeAudio() async {
    await _audioService.initialize();

    // Register callbacks for next/previous podcast navigation
    _audioService.setOnNextPodcast(_playNextPodcast);
    _audioService.setOnPreviousPodcast(_playPreviousPodcast);

    // Listen to position updates
    _positionSubscription = _audioService.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    // Listen to duration updates
    _durationSubscription = _audioService.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    // Listen to playing state
    _playingSubscription = _audioService.playingStream.listen((playing) {
      if (mounted) {
        if (!_ignoreStreamUpdate) {
          setState(() {
            _isPlaying = playing;
          });
        }
      }
    });

    // Listen to processing state for buffering
    _processingStateSubscription = _audioService.processingStateStream.listen((
      state,
    ) {
      if (mounted) {
        setState(() {
          _isBuffering =
              (state == ProcessingState.loading ||
              state == ProcessingState.buffering);
        });
      }
    });
  }

  void _startProgressSaveTimer() {
    _progressSaveTimer?.cancel();
    // Save progress every 5 seconds
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_podcasts.isNotEmpty && _selectedPodcastIndex < _podcasts.length) {
        // Duration bazen geç geliyor (özellikle streaming'de).
        // Bu yüzden duration kontrolünü _saveProgress içinde çözüyoruz.
        _saveProgress(allowDurationLoad: false);
      }
    });
  }

  Future<void> _saveProgress({bool allowDurationLoad = true}) async {
    if (_podcasts.isEmpty || _selectedPodcastIndex >= _podcasts.length) return;

    final currentPodcast = _podcasts[_selectedPodcastIndex];
    final position = _audioService.position;

    Duration? total = _audioService.duration ?? _totalDuration;
    if (total == null || total.inSeconds == 0) {
      if (currentPodcast.durationMinutes > 0) {
        total = Duration(minutes: currentPodcast.durationMinutes);
      }
    }

    // Cache'den duration çek (streaming'de duration null kalabiliyor)
    if (total == null || total.inSeconds == 0) {
      final cachedMinutes = await PodcastCacheService.getDuration(
        currentPodcast.audioUrl,
      );
      if (cachedMinutes != null && cachedMinutes > 0) {
        total = Duration(minutes: cachedMinutes);
        // UI'a zorla setState yapma; sadece local list'i güncelle (save için yeterli).
        if (currentPodcast.durationMinutes == 0 &&
            _selectedPodcastIndex < _podcasts.length) {
          _podcasts[_selectedPodcastIndex] = Podcast(
            id: currentPodcast.id,
            title: currentPodcast.title,
            description: currentPodcast.description,
            audioUrl: currentPodcast.audioUrl,
            durationMinutes: cachedMinutes,
            thumbnailUrl: currentPodcast.thumbnailUrl,
            topicId: currentPodcast.topicId,
            lessonId: currentPodcast.lessonId,
            order: currentPodcast.order,
          );
        }
      }
    }

    // Eğer hala duration yoksa, (özellikle podcast değiştirirken) hızlıca metadata yüklemeyi dene
    if ((total == null || total.inSeconds == 0) && allowDurationLoad) {
      await _loadDurationForPodcast(_selectedPodcastIndex, currentPodcast);
      if (_selectedPodcastIndex < _podcasts.length) {
        final updated = _podcasts[_selectedPodcastIndex];
        if (updated.durationMinutes > 0) {
          total = Duration(minutes: updated.durationMinutes);
        }
      }
    }

    if (total == null || total.inSeconds == 0) return;

    // Güvenli clamp: hatalı/yuvarlanmış duration yüzünden "tamamlandı" sayılıp silinmesin
    final safeMaxPosSeconds = math.max(0, total.inSeconds - 1);
    final safePosSeconds = position.inSeconds.clamp(0, safeMaxPosSeconds);
    final safePosition = Duration(seconds: safePosSeconds);

    await _progressService.savePodcastProgress(
      podcastId: currentPodcast.id,
      podcastTitle: currentPodcast.title,
      topicId: currentPodcast.topicId,
      lessonId: currentPodcast.lessonId,
      topicName: widget.topicName,
      currentPosition: safePosition,
      totalDuration: total,
    );
  }

  @override
  void dispose() {
    _progressSaveTimer?.cancel();

    // Save final progress before disposing
    if (_podcasts.isNotEmpty && _selectedPodcastIndex < _podcasts.length) {
      // Dispose içinde pahalı metadata yüklemeye girme.
      _saveProgress(allowDurationLoad: false);
    }

    // Clear callbacks
    _audioService.setOnNextPodcast(null);
    _audioService.setOnPreviousPodcast(null);

    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _processingStateSubscription?.cancel();
    _waveController.dispose();
    _pulseController.dispose();
    // Don't dispose audio service here - it should persist for background playback
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    // Eğer buffering varsa, butona basmayı engelle
    if (_isBuffering) {
      return;
    }

    // Optimistic update - immediately update UI
    final wasPlaying = _isPlaying;
    setState(() {
      _isPlaying = !_isPlaying;
    });
    _ignoreStreamUpdate = true;

    try {
      if (wasPlaying) {
        await _audioService.pause();
      } else {
        if (_currentPosition == Duration.zero ||
            _audioService.processingState == ProcessingState.completed) {
          // Hemen başlat - await yap, setUrl tamamlanmasını bekle
          await _loadAndPlayCurrentPodcast();
        } else {
          await _audioService.resume();
        }
      }
      // Reset flag after operation completes
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _ignoreStreamUpdate = false;
          });
        }
      });
    } catch (e) {
      // Revert on error
      setState(() {
        _isPlaying = wasPlaying;
        _isBuffering = false;
        _ignoreStreamUpdate = false;
      });
    }
  }

  Future<void> _loadAndPlayCurrentPodcast() async {
    if (_podcasts.isEmpty || _selectedPodcastIndex >= _podcasts.length) {
      if (mounted) {
        PremiumSnackBar.show(
          context,
          message: 'Podcast yüklenirken hata oluştu',
          type: SnackBarType.error,
        );
      }
      return;
    }

    final currentPodcast = _podcasts[_selectedPodcastIndex];

    if (currentPodcast.audioUrl.isEmpty) {
      if (mounted) {
        PremiumSnackBar.show(
          context,
          message: 'Podcast ses dosyası bulunamadı',
          type: SnackBarType.error,
        );
      }
      return;
    }

    // Cache kontrolü - aynı podcast ise yeniden yükleme
    if (_currentPlayingUrl == currentPodcast.audioUrl) {
      // Aynı podcast zaten yüklü (cache'de)
      if (_isPlaying) {
        // Çalıyorsa sadece resume et
        await _audioService.resume();
        return;
      } else {
        // Pause durumundaysa, sadece play et (yeniden yükleme yok)
        // Pozisyonu koru, sadece play et
        await _audioService.resume();
        if (mounted) {
          setState(() {
            _isPlaying = true;
            _isBuffering = false;
          });
        }
        return;
      }
    }

    try {
      // Buffering durumunu göster
      if (mounted) {
        setState(() {
          _isBuffering = true;
          _currentPlayingUrl = currentPodcast.audioUrl;
        });
      }

      // Önce cache'den duration'ı kontrol et (eğer podcast'te yoksa)
      int? durationMinutes = currentPodcast.durationMinutes;
      if (durationMinutes == 0) {
        final cached = await PodcastCacheService.getDuration(
          currentPodcast.audioUrl,
        );
        if (cached != null && cached > 0) {
          durationMinutes = cached;
          // Podcast'i güncelle
          final updatedPodcast = Podcast(
            id: currentPodcast.id,
            title: currentPodcast.title,
            description: currentPodcast.description,
            audioUrl: currentPodcast.audioUrl,
            durationMinutes: cached,
            topicId: currentPodcast.topicId,
            lessonId: currentPodcast.lessonId,
            order: currentPodcast.order,
          );
          _podcasts[_selectedPodcastIndex] = updatedPodcast;
          if (mounted) {
            setState(() {});
          }
        }
      }

      // Duration'ı hesapla
      final duration = durationMinutes > 0
          ? Duration(minutes: durationMinutes)
          : null;

      // Load saved progress (we will seek BEFORE starting playback)
      final savedProgress = await _progressService.getPodcastProgress(
        currentPodcast.id,
      );

      // Check if podcast is downloaded locally (cache kontrolü - hızlı)
      // Eğer audioUrl file:// ile başlıyorsa, bu cache'den yüklenen bir podcast'tir
      String? finalLocalPath;
      if (currentPodcast.audioUrl.startsWith('file://')) {
        // Cache'den yüklenen podcast - local path'i direkt kullan
        finalLocalPath = currentPodcast.audioUrl.substring(
          7,
        ); // 'file://' prefix'ini kaldır
        debugPrint('📁 Using cached podcast (instant): $finalLocalPath');
      } else {
        // Normal podcast - cache kontrolü yap
        final localFilePath = await _downloadService.getLocalFilePath(
          currentPodcast.audioUrl,
        );
        finalLocalPath = localFilePath;

        // Eğer indirilmemişse, streaming ile çal (hızlı, tam indirme yok)
        if (localFilePath == null) {
          debugPrint(
            '🌐 Podcast not downloaded, using streaming mode (fast, no full download)...',
          );
          // Streaming ile çal, arka planda cache'le
          finalLocalPath = null; // Network streaming kullan

          // Arka planda indir (cache için - non-blocking)
          _downloadService
              .downloadPodcast(
                audioUrl: currentPodcast.audioUrl,
                podcastId: currentPodcast.id,
                onProgress: (progress) {
                  debugPrint(
                    '📊 Background download progress: ${(progress * 100).toStringAsFixed(0)}%',
                  );
                },
              )
              .then((downloadedPath) {
                if (downloadedPath != null && mounted) {
                  debugPrint('✅ Podcast cached in background: $downloadedPath');
                  setState(() {
                    _downloadedPodcasts[currentPodcast.id] = true;
                  });
                  // Durumu kaydet (kalıcı olması için)
                  _saveDownloadedPodcastsStatus();
                  // Next time will use cache
                }
              })
              .catchError((e) {
                debugPrint('⚠️ Background download failed: $e');
              });
        }
      }

      // Oynat - yerel dosya varsa onu kullan, yoksa network'ten (fallback)
      await _audioService.play(
        currentPodcast.audioUrl,
        title: currentPodcast.title,
        artist: widget.topicName,
        duration: duration,
        localFilePath: finalLocalPath,
        initialPosition: (savedProgress != null && savedProgress.inSeconds > 5)
            ? savedProgress
            : null,
      );

      // Update last access time if playing from local file
      if (finalLocalPath != null) {
        await _cleanupService.updateLastAccessTime(currentPodcast.audioUrl);
      }

      if (savedProgress != null && savedProgress.inSeconds > 5) {
        debugPrint(
          '✅ Starting podcast from saved position: ${savedProgress.inMinutes}m',
        );
      }

      // Start progress save timer
      _startProgressSaveTimer();

      // Eğer duration hala yoksa, arka planda yükle
      if (duration == null || durationMinutes == 0) {
        _loadDurationForPodcast(_selectedPodcastIndex, currentPodcast);
      }
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ ERROR IN _loadAndPlayCurrentPodcast ❌❌❌');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error message: $e');
      debugPrint('Full error: ${e.toString()}');
      debugPrint('Stack trace:');
      debugPrint(stackTrace.toString());

      if (mounted) {
        setState(() {
          _isBuffering = false;
          _isPlaying = false;
        });

        // Detaylı hata mesajı göster
        final errorMessage =
            '''
HATA DETAYLARI:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Hata Tipi: ${e.runtimeType}
Hata Mesajı: $e
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Tam Hata: ${e.toString()}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Stack Trace (ilk 500 karakter):
${stackTrace.toString().substring(0, stackTrace.toString().length > 500 ? 500 : stackTrace.toString().length)}...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        ''';

        debugPrint(errorMessage);
        PremiumSnackBar.show(
          context,
          message: 'Podcast yüklenirken bir hata oluştu.',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _selectPodcast(int index) async {
    if (_selectedPodcastIndex == index) {
      // Aynı podcast'e tekrar tıklandıysa, eğer durdurulmuşsa oynat
      if (!_isPlaying) {
        await _loadAndPlayCurrentPodcast();
      }
      return;
    }

    // Kaydet: podcast değiştirirken ilerleme kaybolmasın.
    _progressSaveTimer?.cancel();
    await _saveProgress();

    // Stop yerine pause: notification tarafında "eski podcast'in" yeniden resume edilmesini
    // ve geçiş sırasında yanlış state'leri azaltır.
    await _audioService.pause();
    setState(() {
      _selectedPodcastIndex = index;
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _totalDuration = null;
      _currentPlayingUrl = null;
    });

    // Seçilen podcast'i otomatik olarak oynat
    if (index < _podcasts.length) {
      final podcast = _podcasts[index];
      if (podcast.audioUrl.isNotEmpty) {
        // Her durumda otomatik oynat (indirilmiş olsun veya olmasın)
        await _loadAndPlayCurrentPodcast();
      }
    }
  }

  /// Play next podcast in the list (called from notification)
  Future<void> _playNextPodcast() async {
    if (_podcasts.isEmpty) return;

    final nextIndex = _selectedPodcastIndex + 1;
    if (nextIndex < _podcasts.length) {
      debugPrint('⏭️ Playing next podcast: ${_podcasts[nextIndex].title}');
      // Save current progress before switching
      _progressSaveTimer?.cancel();
      await _saveProgress();
      await _audioService.pause();
      setState(() {
        _selectedPodcastIndex = nextIndex;
        _isPlaying = false;
        _currentPosition = Duration.zero;
        _totalDuration = null;
        _currentPlayingUrl = null;
      });
      // Always play the next podcast (whether downloaded or not)
      await _loadAndPlayCurrentPodcast();
    } else {
      debugPrint('⚠️ No next podcast available (at end of list)');
      if (mounted) {
        PremiumSnackBar.show(
          context,
          message: 'Son podcast\'e ulaşıldı',
          type: SnackBarType.info,
        );
      }
    }
  }

  /// Play previous podcast in the list (called from notification)
  Future<void> _playPreviousPodcast() async {
    if (_podcasts.isEmpty) return;

    final previousIndex = _selectedPodcastIndex - 1;
    if (previousIndex >= 0) {
      debugPrint(
        '⏮️ Playing previous podcast: ${_podcasts[previousIndex].title}',
      );
      // Save current progress before switching
      _progressSaveTimer?.cancel();
      await _saveProgress();
      await _audioService.pause();
      setState(() {
        _selectedPodcastIndex = previousIndex;
        _isPlaying = false;
        _currentPosition = Duration.zero;
        _totalDuration = null;
        _currentPlayingUrl = null;
      });
      // Always play the previous podcast (whether downloaded or not)
      await _loadAndPlayCurrentPodcast();
    } else {
      debugPrint('⚠️ No previous podcast available (at beginning of list)');
      // If at beginning, seek to beginning of current podcast
      await _audioService.seek(Duration.zero);
      if (mounted) {
        PremiumSnackBar.show(
          context,
          message: 'İlk podcast\'e ulaşıldı',
          type: SnackBarType.info,
        );
      }
    }
  }

  Future<void> _seekTo(Duration position) async {
    await _audioService.seek(position);
  }

  Future<void> _changeSpeed(double speed) async {
    await _audioService.setSpeed(speed);
    setState(() {
      _playbackSpeed = speed;
    });
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final isTablet = screenWidth > 600;
        final isSmallScreen = screenHeight < 700;

        final isDark = Theme.of(context).brightness == Brightness.dark;

        if (_isLoading) {
          return Scaffold(
            backgroundColor: isDark
                ? const Color(0xFF0F0F1A)
                : const Color(0xFFF8FAFF),
            body: Stack(
              children: [
                _buildMeshBackground(isDark, screenWidth),
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (_podcasts.isEmpty) {
          return Scaffold(
            backgroundColor: isDark
                ? const Color(0xFF0F0F1A)
                : const Color(0xFFF8FAFF),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
            floatingActionButton: const FloatingHomeButton(),
            body: Stack(
              children: [
                _buildMeshBackground(isDark, screenWidth),
                Column(
                  children: [
                    _buildPremiumAppBar(
                      context,
                      isDark,
                      isSmallScreen,
                      isTablet,
                    ),
                    const Spacer(),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.podcasts_outlined,
                            size: 64,
                            color: isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Bu konu için henüz podcast eklenmemiş',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
          );
        }

        final currentPodcast = _podcasts[_selectedPodcastIndex];

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: isDark
                ? const Color(0xFF0F0F1A)
                : const Color(0xFFF8FAFF),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
            floatingActionButton: const FloatingHomeButton(),
            body: Stack(
              children: [
                _buildMeshBackground(isDark, screenWidth),
                Column(
                  children: [
                    _buildPremiumAppBar(
                      context,
                      isDark,
                      isSmallScreen,
                      isTablet,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 32 : 16,
                          vertical: 16,
                        ),
                        child: Column(
                          children: [
                            _buildPodcastPlayerCard(
                              currentPodcast,
                              isDark,
                              isSmallScreen,
                              isTablet,
                            ),
                            const SizedBox(height: 24),
                            _buildPodcastPlaylist(
                              isDark,
                              isSmallScreen,
                              isTablet,
                            ),
                            const SizedBox(
                              height: 100,
                            ), // Spacing for floating button
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumAppBar(
    BuildContext context,
    bool isDark,
    bool isSmallScreen,
    bool isTablet,
  ) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0F0F1A) : Colors.white).withOpacity(
          0.8,
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: [
              IconButton(
                onPressed: () async {
                  if (_podcasts.isNotEmpty &&
                      _selectedPodcastIndex < _podcasts.length &&
                      _totalDuration != null &&
                      _totalDuration!.inSeconds > 0) {
                    await _saveProgress();
                  }
                  if (mounted) Navigator.pop(context, true);
                },
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03),
                  padding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PODCAST DİNLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2563EB),
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      widget.topicName,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildPodcastCountPill(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodcastCountPill(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.podcasts_rounded,
            size: 14,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(width: 6),
          Text(
            '${_podcasts.length}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodcastPlayerCard(
    Podcast currentPodcast,
    bool isDark,
    bool isSmallScreen,
    bool isTablet,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: (isDark ? Colors.white.withOpacity(0.06) : Colors.white)
            .withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildPlayerThumbnail(isDark, isSmallScreen),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selectedPodcastIndex + 1}. ${currentPodcast.title}',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentPodcast.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildPlaybackProgress(isDark),
                const SizedBox(height: 16),
                _buildPlayerControls(isDark, isSmallScreen),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerThumbnail(bool isDark, bool isSmallScreen) {
    final size = isSmallScreen ? 80.0 : 100.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: _isPlaying
            ? AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    child: CustomPaint(
                      size: Size(size * 0.6, size * 0.6),
                      painter: WaveformPainter(
                        isPlaying: _isPlaying,
                        animationValue: _waveController.value,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              )
            : Icon(
                Icons.podcasts_rounded,
                size: size * 0.5,
                color: Colors.white.withOpacity(0.9),
              ),
      ),
    );
  }

  Widget _buildPlaybackProgress(bool isDark) {
    final progress = (_totalDuration != null && _totalDuration!.inSeconds > 0)
        ? (_currentPosition.inSeconds / _totalDuration!.inSeconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return Row(
      children: [
        Text(
          _formatTime(_currentPosition),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: const Color(0xFF2563EB),
              inactiveTrackColor: (isDark ? Colors.white : Colors.black)
                  .withOpacity(0.08),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 6,
                elevation: 3,
              ),
              overlayColor: const Color(0xFF2563EB).withOpacity(0.1),
              trackShape: const RectangularSliderTrackShape(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Slider(
              value: progress,
              onChanged: (value) {
                if (_totalDuration != null) {
                  final newPos = Duration(
                    seconds: (value * _totalDuration!.inSeconds).toInt(),
                  );
                  _seekTo(newPos);
                }
              },
            ),
          ),
        ),
        Text(
          _totalDuration != null ? _formatTime(_totalDuration!) : '--:--',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerControls(bool isDark, bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCircleControlButton(
          icon: Icons.restart_alt_rounded,
          onPressed: () => _seekTo(Duration.zero),
          isDark: isDark,
          size: 40,
        ),
        const SizedBox(width: 16),
        _buildCircleControlButton(
          icon: Icons.replay_10_rounded,
          onPressed: () {
            final newPos = Duration(
              seconds: math.max(0, _currentPosition.inSeconds - 10),
            );
            _seekTo(newPos);
          },
          isDark: isDark,
          size: 48,
        ),
        const SizedBox(width: 24),
        _buildMainPlayButton(isDark),
        const SizedBox(width: 24),
        _buildCircleControlButton(
          icon: Icons.forward_10_rounded,
          onPressed: () {
            if (_totalDuration != null) {
              final newPos = Duration(
                seconds: math.min(
                  _totalDuration!.inSeconds,
                  _currentPosition.inSeconds + 10,
                ),
              );
              _seekTo(newPos);
            }
          },
          isDark: isDark,
          size: 48,
        ),
        const SizedBox(width: 16),
        _buildSpeedControl(isDark),
      ],
    );
  }

  Widget _buildMainPlayButton(bool isDark) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: _isBuffering
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
        ),
      ),
    );
  }

  Widget _buildCircleControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDark,
    double size = 44,
  }) {
    return Material(
      color: Colors.transparent,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: size * 0.5,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        ),
        style: IconButton.styleFrom(
          backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(
            0.04,
          ),
          fixedSize: Size(size, size),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildSpeedControl(bool isDark) {
    return PopupMenuButton<double>(
      initialValue: _playbackSpeed,
      onSelected: _changeSpeed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '${_playbackSpeed}x',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
      itemBuilder: (context) => [
        0.5,
        0.75,
        1.0,
        1.25,
        1.5,
        2.0,
      ].map((s) => PopupMenuItem(value: s, child: Text('${s}x'))).toList(),
    );
  }

  Widget _buildPodcastPlaylist(bool isDark, bool isSmallScreen, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 16),
          child: Text(
            'DİĞER BÖLÜMLER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF2563EB),
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...List.generate(_podcasts.length, (index) {
          final podcast = _podcasts[index];
          final isSelected = index == _selectedPodcastIndex;
          return _buildPlaylistTile(podcast, index, isSelected, isDark);
        }),
      ],
    );
  }

  Widget _buildPlaylistTile(
    Podcast podcast,
    int index,
    bool isSelected,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF2563EB).withOpacity(0.08)
            : (isDark
                  ? Colors.white.withOpacity(0.02)
                  : Colors.white.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF2563EB).withOpacity(0.3)
              : (isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.03)),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: () => _selectPodcast(index),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isSelected ? Icons.headset_rounded : Icons.play_arrow_rounded,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white60 : Colors.black45),
            size: 18,
          ),
        ),
        title: Text(
          '${index + 1}. ${podcast.title}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          '${podcast.durationMinutes} dakika dinle',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.bar_chart_rounded, color: Color(0xFF2563EB))
            : (_downloadedPodcasts[podcast.id] == true
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 18,
                    )
                  : null),
      ),
    );
  }

  Widget _buildMeshBackground(bool isDark, double screenWidth) {
    return Positioned.fill(
      child: Container(
        color: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8FAFF),
        child: Stack(
          children: [
            _buildBlurCircle(
              -screenWidth * 0.2,
              -screenWidth * 0.2,
              screenWidth * 0.8,
              const Color(0xFF2563EB).withOpacity(isDark ? 0.12 : 0.08),
            ),
            _buildBlurCircle(
              screenWidth * 0.4,
              screenWidth * 0.1,
              screenWidth * 0.7,
              const Color(0xFF7C3AED).withOpacity(isDark ? 0.1 : 0.06),
            ),
            _buildBlurCircle(
              screenWidth * 0.1,
              screenWidth * 0.6,
              screenWidth * 0.9,
              const Color(0xFF2563EB).withOpacity(isDark ? 0.08 : 0.05),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlurCircle(double top, double left, double size, Color color) {
    return Positioned(
      top: top,
      left: left,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }

  /// Arka planda keşfedilen podcast'leri Firestore'a senkronize eder
  Future<void> _syncDiscoveredPodcastsToFirestore(List<Podcast> podcasts) async {
    try {
      final podcastService = PodcastsService();
      int syncCount = 0;
      for (final podcast in podcasts) {
        // file:// URL'lerini Firestore'a kaydetme
        if (podcast.audioUrl.startsWith('file://')) continue;
        
        await podcastService.addPodcast(podcast);
        syncCount++;
      }
      debugPrint('✅ Synced $syncCount podcasts to Firestore');
      
      // Topic dokümanını da güncelle (podcastCount için)
      if (podcasts.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('topics')
            .doc(widget.topicId)
            .update({'podcastCount': podcasts.length});
      }
    } catch (e) {
      debugPrint('⚠️ Error syncing podcasts to Firestore: $e');
    }
  }
}

// Waveform Painter
class WaveformPainter extends CustomPainter {
  final bool isPlaying;
  final double animationValue;
  final Color color;

  WaveformPainter({
    required this.isPlaying,
    required this.animationValue,
    this.color = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final barWidth = 2.5;
    final barSpacing = 3.5;
    final maxHeight = size.height;
    final minHeight = maxHeight * 0.3;

    final barCount = ((size.width - barSpacing) / (barWidth + barSpacing))
        .floor();

    for (int i = 0; i < barCount; i++) {
      final normalizedIndex = i / barCount;
      double height;

      if (isPlaying) {
        final wave = math.sin(
          (normalizedIndex * 2 * math.pi) + (animationValue * 2 * math.pi),
        );
        height = minHeight + (maxHeight - minHeight) * ((wave + 1) / 2);
      } else {
        height =
            minHeight + (maxHeight - minHeight) * (1 - normalizedIndex * 0.3);
      }

      final x = i * (barWidth + barSpacing);
      final rect = Rect.fromLTWH(
        x,
        (size.height - height) / 2,
        barWidth,
        height,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.isPlaying != isPlaying ||
        oldDelegate.animationValue != animationValue;
  }
}
