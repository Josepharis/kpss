import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
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
import '../../../../main.dart';

class PodcastsPage extends StatefulWidget {
  final String topicName;
  final int podcastCount;
  final String topicId; // Storage'dan podcast çekmek için
  final String lessonId; // Ders ID'si (Storage yolunu oluşturmak için)
  final String? initialAudioUrl; // Anasayfadan geliyorsa, cache'den direkt yükle
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
  late AnimationController _waveController;
  late AnimationController _pulseController;
  Timer? _progressSaveTimer;
  Map<String, bool> _downloadedPodcasts = {}; // Track downloaded podcasts
  Map<String, double> _downloadProgress = {}; // Track download progress
  Map<String, bool> _downloadingPodcasts = {}; // Track podcasts being downloaded
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
      debugPrint('🔍 Loading podcasts from local cache for topicId: ${widget.topicId}');
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'podcasts_${widget.topicId}';
      final cachedJson = prefs.getString(cacheKey);
      
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> cachedList = jsonDecode(cachedJson);
        _podcasts = cachedList.map((json) => Podcast.fromMap(json, json['id'] ?? '')).toList();
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
      final jsonList = podcasts.map((p) => {
        'id': p.id,
        'title': p.title,
        'description': p.description,
        'audioUrl': p.audioUrl,
        'durationMinutes': p.durationMinutes,
        'thumbnailUrl': p.thumbnailUrl,
        'topicId': p.topicId,
        'lessonId': p.lessonId,
        'order': p.order,
      }).toList();
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
      debugPrint('🔍 Loading podcasts from Firestore for topicId: ${widget.topicId}');
      
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      
      // Firestore'dan podcast'leri çek
      final podcasts = await _podcastsService.getPodcastsByTopicId(widget.topicId);
      
      if (podcasts.isEmpty) {
        debugPrint('⚠️ No podcasts found in Firestore, trying Storage fallback...');
        // Firestore'da yoksa, Storage'dan çek (eski yöntem)
        await _loadPodcastsFromStorage();
        return;
      }
      
      debugPrint('✅ Found ${podcasts.length} podcasts from Firestore');
      
      // Cache'e kaydet
      await _savePodcastsToLocalCache(podcasts);
      
      // Cache'deki dosyaları kontrol et ve file:// URL'lerini güncelle
      _podcasts = podcasts;
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
        final localPath = await _downloadService.getLocalFilePath(podcast.audioUrl);
        if (localPath != null) {
          // Cache'de var, file:// URL'ini kullan
          updatedPodcasts.add(Podcast(
            id: podcast.id,
            title: podcast.title,
            description: podcast.description,
            audioUrl: 'file://$localPath',
            durationMinutes: podcast.durationMinutes,
            thumbnailUrl: podcast.thumbnailUrl,
            topicId: podcast.topicId,
            lessonId: podcast.lessonId,
            order: podcast.order,
          ));
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
      
      debugPrint('🔍 Loading podcasts from Storage (fallback) for topicId: ${widget.topicId}');
      
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
      final cachedPodcasts = _podcasts.where((p) => p.audioUrl.startsWith('file://')).toList();
      final networkPodcasts = _podcasts.where((p) => !p.audioUrl.startsWith('file://')).toList();
      
      debugPrint('📊 Before adding: Cached podcasts: ${cachedPodcasts.length}, Network podcasts: ${networkPodcasts.length}');
      
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
      final existingNetworkUrls = networkPodcasts.map((p) => p.audioUrl).toSet();
      
      // Yeni podcast'leri ekle (cache'de olmayanlar)
      if (cachedPodcasts.isNotEmpty) {
        // Cache'den yüklenen podcast'ler var, onları koru ve yeni olanları ekle
        _podcasts = List<Podcast>.from(cachedPodcasts); // Cache'den yüklenenleri koru
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
                fileName = segments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
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
              debugPrint('  ⏭️ Skipping duplicate podcast (already in cache): $normalizedFileName');
              continue;
            }
            
            // Title oluştur
            final title = fileName
                .replaceAll('.m4a', '')
                .replaceAll('.mp3', '')
                .replaceAll('.mp4', '')
                .replaceAll('_', ' ')
                .replaceAll('%20', ' ')
                .trim();
            
            _podcasts.add(Podcast(
              id: 'podcast_${widget.topicId}_$newIndex',
              title: title.isNotEmpty ? title : 'Podcast ${newIndex + 1}',
              description: '${widget.topicName} podcast',
              audioUrl: url,
              durationMinutes: 0,
              topicId: widget.topicId,
              lessonId: widget.lessonId,
              order: newIndex,
            ));
            newIndex++;
            debugPrint('  ✅ Added new podcast: $title');
          } catch (e) {
            debugPrint('⚠️ Error processing podcast $index: $e');
            _podcasts.add(Podcast(
              id: 'podcast_${widget.topicId}_$newIndex',
              title: 'Podcast ${newIndex + 1}',
              description: '${widget.topicName} podcast',
              audioUrl: url,
              durationMinutes: 0,
              topicId: widget.topicId,
              lessonId: widget.lessonId,
              order: newIndex,
            ));
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
                fileName = segments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
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
            final title = fileName
                .replaceAll('.m4a', '')
                .replaceAll('.mp3', '')
                .replaceAll('.mp4', '')
                .replaceAll('_', ' ')
                .replaceAll('%20', ' ')
                .trim();
            
            _podcasts.add(Podcast(
              id: 'podcast_${widget.topicId}_$index',
              title: title.isNotEmpty ? title : 'Podcast ${index + 1}',
              description: '${widget.topicName} podcast',
              audioUrl: url,
              durationMinutes: 0, // Arka planda yüklenecek
              topicId: widget.topicId,
              lessonId: widget.lessonId,
              order: index,
            ));
            debugPrint('  ✅ Added podcast ${index + 1}: $title');
          } catch (e) {
            debugPrint('⚠️ Error processing podcast $index: $e');
            _podcasts.add(Podcast(
              id: 'podcast_${widget.topicId}_$index',
              title: 'Podcast ${index + 1}',
              description: '${widget.topicName} podcast',
              audioUrl: url,
              durationMinutes: 0,
              topicId: widget.topicId,
              lessonId: widget.lessonId,
              order: index,
            ));
          }
        }
      }
      
      // Listeyi HEMEN göster (anında açılış için)
      debugPrint('📊 Total podcasts after loading: ${_podcasts.length}');
      for (int i = 0; i < _podcasts.length; i++) {
        debugPrint('  Podcast ${i + 1}: ${_podcasts[i].title} (${_podcasts[i].audioUrl})');
      }
      
      // Cache'e kaydet (bir sonraki açılışta kullanılmak üzere)
      await _savePodcastsToLocalCache(_podcasts);
      
      // Cache'deki dosyaları kontrol et ve file:// URL'lerini güncelle
      await _updateCachedFileUrls();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          // _podcasts listesi zaten güncellendi, sadece UI'ı yenile
        });
      }
      
      // Check downloaded status for all podcasts (arka planda)
      _checkDownloadedPodcasts();
      
      // Arka planda duration'ları yükle (non-blocking)
      _loadDurationsInBackground();
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
        _downloadedPodcasts = cachedMap.map((key, value) => MapEntry(key, value as bool));
        debugPrint('✅ Loaded ${_downloadedPodcasts.length} downloaded podcast statuses from cache');
        
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
      debugPrint('✅ Saved ${_downloadedPodcasts.length} downloaded podcast statuses to cache');
    } catch (e) {
      debugPrint('⚠️ Error saving downloaded podcast statuses: $e');
    }
  }
  
  Future<void> _checkDownloadedPodcasts() async {
    for (final podcast in _podcasts) {
      final isDownloaded = await _downloadService.isPodcastDownloaded(podcast.audioUrl);
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
        await PodcastCacheService.saveDuration(podcast.audioUrl, duration.inMinutes);
        
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
    _processingStateSubscription = _audioService.processingStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isBuffering = (state == ProcessingState.loading || state == ProcessingState.buffering);
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
      final cachedMinutes = await PodcastCacheService.getDuration(currentPodcast.audioUrl);
      if (cachedMinutes != null && cachedMinutes > 0) {
        total = Duration(minutes: cachedMinutes);
        // UI'a zorla setState yapma; sadece local list'i güncelle (save için yeterli).
        if (currentPodcast.durationMinutes == 0 && _selectedPodcastIndex < _podcasts.length) {
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
    if (_podcasts.isNotEmpty && 
        _selectedPodcastIndex < _podcasts.length) {
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
        if (_currentPosition == Duration.zero || _audioService.processingState == ProcessingState.completed) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Podcast bulunamadı'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    final currentPodcast = _podcasts[_selectedPodcastIndex];
    
    if (currentPodcast.audioUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Podcast ses dosyası bulunamadı'),
            backgroundColor: Colors.red,
          ),
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
        final cached = await PodcastCacheService.getDuration(currentPodcast.audioUrl);
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
      final savedProgress = await _progressService.getPodcastProgress(currentPodcast.id);
      
      // Check if podcast is downloaded locally (cache kontrolü - hızlı)
      // Eğer audioUrl file:// ile başlıyorsa, bu cache'den yüklenen bir podcast'tir
      String? finalLocalPath;
      if (currentPodcast.audioUrl.startsWith('file://')) {
        // Cache'den yüklenen podcast - local path'i direkt kullan
        finalLocalPath = currentPodcast.audioUrl.substring(7); // 'file://' prefix'ini kaldır
        debugPrint('📁 Using cached podcast (instant): $finalLocalPath');
      } else {
        // Normal podcast - cache kontrolü yap
        final localFilePath = await _downloadService.getLocalFilePath(currentPodcast.audioUrl);
        finalLocalPath = localFilePath;
        
        // Eğer indirilmemişse, streaming ile çal (hızlı, tam indirme yok)
        if (localFilePath == null) {
          debugPrint('🌐 Podcast not downloaded, using streaming mode (fast, no full download)...');
          // Streaming ile çal, arka planda cache'le
          finalLocalPath = null; // Network streaming kullan
          
          // Arka planda indir (cache için - non-blocking)
          _downloadService.downloadPodcast(
            audioUrl: currentPodcast.audioUrl,
            podcastId: currentPodcast.id,
            onProgress: (progress) {
              debugPrint('📊 Background download progress: ${(progress * 100).toStringAsFixed(0)}%');
            },
          ).then((downloadedPath) {
            if (downloadedPath != null && mounted) {
              debugPrint('✅ Podcast cached in background: $downloadedPath');
              setState(() {
                _downloadedPodcasts[currentPodcast.id] = true;
              });
              // Durumu kaydet (kalıcı olması için)
              _saveDownloadedPodcastsStatus();
              // Next time will use cache
            }
          }).catchError((e) {
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
        initialPosition: (savedProgress != null && savedProgress.inSeconds > 5) ? savedProgress : null,
      );
      
      // Update last access time if playing from local file
      if (finalLocalPath != null) {
        await _cleanupService.updateLastAccessTime(currentPodcast.audioUrl);
      }
      
      if (savedProgress != null && savedProgress.inSeconds > 5) {
        debugPrint('✅ Starting podcast from saved position: ${savedProgress.inMinutes}m');
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
        final errorMessage = '''
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SingleChildScrollView(
              child: Text(
                errorMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Kapat',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _reset() async {
    // Stop çağırma - sadece pozisyonu sıfırla ve pause yap
    // Böylece cache korunur ve tekrar play'e basınca hemen başlar
    await _audioService.pause();
    await _audioService.seek(Duration.zero);
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _currentPosition = Duration.zero;
        // _currentPlayingUrl'i temizleme - cache'i koru
      });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Son podcast\'e ulaşıldı'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Play previous podcast in the list (called from notification)
  Future<void> _playPreviousPodcast() async {
    if (_podcasts.isEmpty) return;
    
    final previousIndex = _selectedPodcastIndex - 1;
    if (previousIndex >= 0) {
      debugPrint('⏮️ Playing previous podcast: ${_podcasts[previousIndex].title}');
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İlk podcast\'e ulaşıldı'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
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
        final isVerySmallScreen = screenWidth < 360;

        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        if (_isLoading) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
            floatingActionButton: const FloatingHomeButton(),
            appBar: AppBar(
              backgroundColor: AppColors.gradientPurpleStart,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () async {
                  // Save progress before leaving
                  if (_podcasts.isNotEmpty && 
                      _selectedPodcastIndex < _podcasts.length && 
                      _totalDuration != null && 
                      _totalDuration!.inSeconds > 0) {
                    await _saveProgress();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('İlerlemeniz kaydediliyor...'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.green,
                        ),
                      );
                      // Wait for message to be visible
                      await Future.delayed(const Duration(milliseconds: 1500));
                    }
                  }
                  if (mounted) {
                    Navigator.of(context).pop(true);
                    // MainScreen'e refresh sinyali gönder
                    final mainScreen = MainScreen.of(context);
                    if (mainScreen != null) {
                      mainScreen.refreshHomePage();
                    }
                  }
                },
              ),
              title: Text(
                widget.topicName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (_podcasts.isEmpty) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
            floatingActionButton: const FloatingHomeButton(),
            appBar: AppBar(
              backgroundColor: AppColors.gradientPurpleStart,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () async {
                  // Save progress before leaving
                  if (_podcasts.isNotEmpty && 
                      _selectedPodcastIndex < _podcasts.length && 
                      _totalDuration != null && 
                      _totalDuration!.inSeconds > 0) {
                    await _saveProgress();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('İlerlemeniz kaydediliyor...'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.green,
                        ),
                      );
                      // Wait for message to be visible
                      await Future.delayed(const Duration(milliseconds: 1500));
                    }
                  }
                  if (mounted) {
                    Navigator.of(context).pop(true);
                    // MainScreen'e refresh sinyali gönder
                    final mainScreen = MainScreen.of(context);
                    if (mainScreen != null) {
                      mainScreen.refreshHomePage();
                    }
                  }
                },
              ),
              title: Text(
                widget.topicName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.podcasts_outlined,
                    size: 64,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bu konu için henüz podcast eklenmemiş',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final currentPodcast = _podcasts[_selectedPodcastIndex];

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: const FloatingHomeButton(),
          extendBodyBehindAppBar: false,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(isSmallScreen ? 80 : 90),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: Builder(
                builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? null
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.gradientPurpleStart,
                                AppColors.gradientPurpleEnd,
                              ],
                            ),
                      color: isDark ? const Color(0xFF1E1E1E) : null,
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : AppColors.gradientPurpleStart.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Watermark
                          Positioned(
                            top: -10,
                            right: -10,
                            child: Transform.rotate(
                              angle: -0.5,
                              child: Text(
                                'PODCAST',
                                style: TextStyle(
                                  fontSize: isVerySmallScreen ? 40 : 50,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white.withValues(alpha: 0.08),
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                          // Content
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 20 : 14,
                              vertical: isSmallScreen ? 6 : 8,
                            ),
                            child: Row(
                              children: [
                                // Back button
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      // Save progress before leaving
                                      if (_podcasts.isNotEmpty && 
                                          _selectedPodcastIndex < _podcasts.length && 
                                          _totalDuration != null && 
                                          _totalDuration!.inSeconds > 0) {
                                        await _saveProgress();
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('İlerlemeniz kaydediliyor...'),
                                              duration: Duration(seconds: 2),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          // Wait for message to be visible
                                          await Future.delayed(const Duration(milliseconds: 2000));
                                        }
                                      }
                                      if (mounted) {
                                        Navigator.of(context).pop(true);
                                        // MainScreen'e refresh sinyali gönder
                                        final mainScreen = MainScreen.of(context);
                                        if (mainScreen != null) {
                                          mainScreen.refreshHomePage();
                                        }
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: EdgeInsets.all(isSmallScreen ? 5 : 7),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        color: Colors.white,
                                        size: isSmallScreen ? 14 : 16,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 10 : 12),
                                // Title
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Podcastler',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 10 : 11,
                                          color: Colors.white.withValues(alpha: 0.85),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        widget.topicName,
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 14 : 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          body: Column(
            children: [
              // Premium Player Card
              Container(
                margin: EdgeInsets.fromLTRB(
                  isTablet ? 20 : 12,
                  isSmallScreen ? 10 : 12,
                  isTablet ? 20 : 12,
                  isSmallScreen ? 10 : 12,
                ),
                constraints: BoxConstraints(
                  maxHeight: isSmallScreen ? 280 : 320,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.gradientPurpleStart,
                      AppColors.gradientPurpleEnd,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gradientPurpleStart.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Background Pattern
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.topRight,
                              radius: 1.5,
                              colors: [
                                Colors.white.withValues(alpha: 0.15),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Decorative circles
                      Positioned(
                        top: -20,
                        right: -20,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Podcast Title
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        currentPodcast.title,
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 15 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: isSmallScreen ? 4 : 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time_rounded,
                                            size: isSmallScreen ? 12 : 14,
                                            color: Colors.white.withValues(alpha: 0.9),
                                          ),
                                          SizedBox(width: 4),
                                          Flexible(
                                            child: _isBuffering
                                                ? Text(
                                                    'Podcast hazırlanıyor...',
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen ? 11 : 12,
                                                      color: Colors.white.withValues(alpha: 0.9),
                                                      fontWeight: FontWeight.w500,
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  )
                                                : Text(
                                                    '${currentPodcast.durationMinutes} dk',
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen ? 11 : 12,
                                                      color: Colors.white.withValues(alpha: 0.9),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 8 : 10),
                                // Waveform visualization
                                AnimatedBuilder(
                                  animation: _waveController,
                                  builder: (context, child) {
                                    return SizedBox(
                                      width: isSmallScreen ? 45 : 55,
                                      height: isSmallScreen ? 30 : 38,
                                      child: CustomPaint(
                                        painter: WaveformPainter(
                                          isPlaying: _isPlaying,
                                          animationValue: _waveController.value,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),
                            // Progress Section
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isSmallScreen ? 8 : 10,
                                          vertical: isSmallScreen ? 3 : 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          _formatTime(_currentPosition),
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 10 : 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isSmallScreen ? 8 : 10,
                                          vertical: isSmallScreen ? 3 : 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          _totalDuration != null 
                                              ? _formatTime(_totalDuration!)
                                              : '--:--',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 10 : 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 10),
                                // Custom Progress Bar
                                Container(
                                  height: isSmallScreen ? 5 : 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                  child: Stack(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 100),
                                        width: double.infinity,
                                        child: FractionallySizedBox(
                                          widthFactor: _totalDuration != null && _totalDuration!.inSeconds > 0
                                              ? (_currentPosition.inSeconds / _totalDuration!.inSeconds).clamp(0.0, 1.0)
                                              : 0.0,
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white,
                                                  Colors.white.withValues(alpha: 0.8),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.white.withValues(alpha: 0.5),
                                                  blurRadius: 6,
                                                  spreadRadius: 0.5,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),
                            // Controls
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isVerySmall = constraints.maxWidth < 320;
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Rewind 10s
                                      _buildControlButton(
                                        icon: Icons.replay_10_rounded,
                                        onPressed: () {
                                          final newPosition = Duration(
                                            seconds: math.max(0, _currentPosition.inSeconds - 10),
                                          );
                                          _seekTo(newPosition);
                                        },
                                        isSmallScreen: isSmallScreen,
                                      ),
                                      SizedBox(width: isVerySmall ? 6 : isSmallScreen ? 8 : 10),
                                      // Reset
                                      _buildControlButton(
                                        icon: Icons.restart_alt_rounded,
                                        onPressed: _reset,
                                        isSmallScreen: isSmallScreen,
                                      ),
                                      SizedBox(width: isVerySmall ? 8 : isSmallScreen ? 12 : 16),
                                      // Play/Pause - Main Button
                                      AnimatedBuilder(
                                        animation: _pulseController,
                                        builder: (context, child) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.white.withValues(
                                                    alpha: _isPlaying ? 0.6 : 0.3,
                                                  ),
                                                  blurRadius: _isPlaying
                                                      ? 15 + (_pulseController.value * 8)
                                                      : 10,
                                                  spreadRadius: _isPlaying
                                                      ? _pulseController.value * 3
                                                      : 0,
                                                ),
                                              ],
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: _togglePlayPause,
                                                borderRadius: BorderRadius.circular(50),
                                                child: Container(
                                                  width: isSmallScreen ? 52 : 60,
                                                  height: isSmallScreen ? 52 : 60,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                      colors: [
                                                        AppColors.gradientPurpleStart,
                                                        AppColors.gradientPurpleEnd,
                                                      ],
                                                    ),
                                                  ),
                                                  child: _isBuffering
                                                      ? SizedBox(
                                                          width: isSmallScreen ? 26 : 30,
                                                          height: isSmallScreen ? 26 : 30,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2.5,
                                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                          ),
                                                        )
                                                      : Icon(
                                                          _isPlaying
                                                              ? Icons.pause_rounded
                                                              : Icons.play_arrow_rounded,
                                                          color: Colors.white,
                                                          size: isSmallScreen ? 26 : 30,
                                                        ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      SizedBox(width: isVerySmall ? 8 : isSmallScreen ? 12 : 16),
                                      // Forward 10s
                                      _buildControlButton(
                                        icon: Icons.forward_10_rounded,
                                        onPressed: () {
                                          if (_totalDuration != null) {
                                            final newPosition = Duration(
                                              seconds: math.min(
                                                _totalDuration!.inSeconds,
                                                _currentPosition.inSeconds + 10,
                                              ),
                                            );
                                            _seekTo(newPosition);
                                          }
                                        },
                                        isSmallScreen: isSmallScreen,
                                      ),
                                      SizedBox(width: isVerySmall ? 6 : isSmallScreen ? 8 : 10),
                                      // Speed Control - PopupMenuButton
                                      PopupMenuButton<double>(
                                        initialValue: _playbackSpeed,
                                        onSelected: (value) {
                                          _changeSpeed(value);
                                        },
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        color: Colors.white,
                                        child: Container(
                                          constraints: BoxConstraints(
                                            minWidth: isVerySmall ? 60 : isSmallScreen ? 70 : 80,
                                            maxWidth: isVerySmall ? 70 : isSmallScreen ? 80 : 90,
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isVerySmall ? 5 : isSmallScreen ? 6 : 8,
                                            vertical: isSmallScreen ? 5 : 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.4),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.speed_rounded,
                                                color: Colors.white,
                                                size: isVerySmall ? 11 : isSmallScreen ? 12 : 14,
                                              ),
                                              SizedBox(width: isVerySmall ? 2 : 3),
                                              Flexible(
                                                child: Text(
                                                  '${_playbackSpeed}x',
                                                  style: TextStyle(
                                                    fontSize: isVerySmall ? 9 : isSmallScreen ? 10 : 11,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0.2,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              SizedBox(width: isVerySmall ? 1 : 2),
                                              Icon(
                                                Icons.arrow_drop_down_rounded,
                                                color: Colors.white,
                                                size: isVerySmall ? 12 : isSmallScreen ? 14 : 16,
                                              ),
                                            ],
                                          ),
                                        ),
                                        itemBuilder: (context) {
                                          return [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                                              .map((speed) {
                                            return PopupMenuItem<double>(
                                              value: speed,
                                              child: Row(
                                                children: [
                                                  if (_playbackSpeed == speed)
                                                    Icon(
                                                      Icons.check_rounded,
                                                      color: AppColors.gradientPurpleStart,
                                                      size: 18,
                                                    )
                                                  else
                                                    SizedBox(width: 18),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    '${speed}x',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: _playbackSpeed == speed
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: _playbackSpeed == speed
                                                          ? AppColors.gradientPurpleStart
                                                          : AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList();
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Podcast List
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(
                    left: isTablet ? 20 : 12,
                    right: isTablet ? 20 : 12,
                    bottom: isSmallScreen ? 12 : 16,
                  ),
                  itemCount: _podcasts.length,
                  itemBuilder: (context, index) {
                    final podcast = _podcasts[index];
                    final isSelected = index == _selectedPodcastIndex;
                    return GestureDetector(
                      onTap: () => _selectPodcast(index),
                      child: Container(
                        margin: EdgeInsets.only(
                          bottom: isSmallScreen ? 8 : 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.gradientPurpleStart.withValues(alpha: 0.15),
                                    AppColors.gradientPurpleEnd.withValues(alpha: 0.1),
                                  ],
                                )
                              : null,
                          color: isSelected ? null : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.gradientPurpleStart.withValues(alpha: 0.3)
                                : Colors.grey.withValues(alpha: 0.15),
                            width: isSelected ? 2 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? AppColors.gradientPurpleStart.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.08),
                              blurRadius: isSelected ? 12 : 8,
                              offset: Offset(0, isSelected ? 4 : 2),
                              spreadRadius: isSelected ? 1 : 0,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                          child: Row(
                            children: [
                              // Thumbnail
                              Container(
                                width: isSmallScreen ? 48 : 56,
                                height: isSmallScreen ? 48 : 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.gradientPurpleStart,
                                      AppColors.gradientPurpleEnd,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.gradientPurpleStart
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(
                                      Icons.podcasts_rounded,
                                      color: Colors.white,
                                      size: isSmallScreen ? 24 : 28,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        bottom: 2,
                                        right: 2,
                                        child: Container(
                                          padding: EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.gradientPurpleStart,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(width: isSmallScreen ? 10 : 12),
                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      podcast.title,
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 13 : 15,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? AppColors.gradientPurpleStart
                                            : (isDark ? Colors.white : AppColors.textPrimary),
                                        letterSpacing: 0.1,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: isSmallScreen ? 4 : 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: isSmallScreen ? 12 : 14,
                                          color: isSelected
                                              ? AppColors.gradientPurpleStart
                                              : (isDark ? Colors.grey.shade400 : AppColors.textSecondary),
                                        ),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '${podcast.durationMinutes} dk',
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 11 : 12,
                                              color: isSelected
                                                  ? AppColors.gradientPurpleStart
                                                  : (isDark ? Colors.grey.shade400 : AppColors.textSecondary),
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (_downloadedPodcasts[podcast.id] == true)
                                          Padding(
                                            padding: EdgeInsets.only(left: 8),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.download_done,
                                                  size: 12,
                                                  color: Colors.green,
                                                ),
                                                SizedBox(width: 2),
                                                Text(
                                                  'İndirildi',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (_downloadingPodcasts[podcast.id] == true)
                                      Padding(
                                        padding: EdgeInsets.only(top: 6),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            LinearProgressIndicator(
                                              value: _downloadProgress[podcast.id] ?? 0.0,
                                              backgroundColor: Colors.grey.shade300,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                AppColors.gradientPurpleStart,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'İndiriliyor: ${((_downloadProgress[podcast.id] ?? 0.0) * 100).toStringAsFixed(0)}%',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isDark ? Colors.grey.shade400 : AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              // Delete button (only show if downloaded)
                              if (_downloadedPodcasts[podcast.id] == true)
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _handleDelete(podcast),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_downloadedPodcasts[podcast.id] == true) SizedBox(width: isSmallScreen ? 8 : 10),
                              // Play Icon
                              Container(
                                padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.gradientPurpleStart
                                      : AppColors.gradientPurpleStart
                                          .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isSelected
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.gradientPurpleStart,
                                  size: isSmallScreen ? 18 : 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleDelete(Podcast podcast) async {
    // Delete podcast
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Podcast\'i Sil'),
        content: Text('${podcast.title} podcast\'ini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final deleted = await _downloadService.deletePodcast(podcast.audioUrl);
      if (deleted && mounted) {
        setState(() {
          _downloadedPodcasts[podcast.id] = false;
        });
        // Durumu kaydet (kalıcı olması için)
        await _saveDownloadedPodcastsStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Podcast silindi. Tekrar açıldığında otomatik indirilecek.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isSmallScreen,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: isSmallScreen ? 18 : 20,
          ),
        ),
      ),
    );
  }
}

// Waveform Painter
class WaveformPainter extends CustomPainter {
  final bool isPlaying;
  final double animationValue;

  WaveformPainter({
    required this.isPlaying,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final barWidth = 2.5;
    final barSpacing = 3.5;
    final maxHeight = size.height;
    final minHeight = maxHeight * 0.3;

    final barCount = ((size.width - barSpacing) / (barWidth + barSpacing)).floor();

    for (int i = 0; i < barCount; i++) {
      final normalizedIndex = i / barCount;
      double height;

      if (isPlaying) {
        final wave = math.sin((normalizedIndex * 2 * math.pi) +
            (animationValue * 2 * math.pi));
        height = minHeight + (maxHeight - minHeight) * ((wave + 1) / 2);
      } else {
        height = minHeight + (maxHeight - minHeight) * (1 - normalizedIndex * 0.3);
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
