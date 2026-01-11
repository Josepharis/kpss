import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/podcast.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/podcast_cache_service.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/services/podcast_download_service.dart';
import '../../../core/services/storage_cleanup_service.dart';

class PodcastsPage extends StatefulWidget {
  final String topicName;
  final int podcastCount;
  final String topicId; // Storage'dan podcast çekmek için
  final String lessonId; // Ders ID'si (Storage yolunu oluşturmak için)
  final String? initialAudioUrl; // Anasayfadan geliyorsa, cache'den direkt yükle

  const PodcastsPage({
    super.key,
    required this.topicName,
    required this.podcastCount,
    required this.topicId,
    required this.lessonId,
    this.initialAudioUrl, // Opsiyonel: anasayfadan ongoing podcast'ten geliyorsa
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
    // Önce cache'den kontrol et (anında açılış için)
    await _checkCacheImmediately();
    
    // Eğer cache'den yüklenmediyse, Firebase Storage'dan yükle
    if (_podcasts.isEmpty) {
      await _loadPodcasts();
    } else {
      // Cache'den yüklendiyse, Firebase Storage çağrısını arka planda yap (güncelleme için)
      _loadPodcasts(); // await etme - arka planda çalışsın
    }
    
    // Audio'yu initialize et
    _initializeAudio();
  }
  
  /// Check cache immediately (synchronous check for instant loading - PDF gibi)
  Future<void> _checkCacheImmediately() async {
    print('🔍 Checking podcasts cache immediately for instant loading...');
    
    // Eğer initialAudioUrl varsa, bu podcast zaten cache'de var demektir
    if (widget.initialAudioUrl != null && widget.initialAudioUrl!.isNotEmpty) {
      print('📁 Initial audio URL provided, checking cache...');
      final localPath = await _downloadService.getLocalFilePath(widget.initialAudioUrl!);
      if (localPath != null) {
        print('✅ Initial podcast is cached: $localPath');
        // Cache'den tüm podcast'leri yükle
        await _loadPodcastsFromCache();
        return;
      }
    }
    
    // Cache'den tüm podcast'leri kontrol et
    await _loadPodcastsFromCache();
  }
  
  /// Load podcasts from cache (hızlı - Firebase Storage'dan sadece dosya adları çekilir)
  Future<void> _loadPodcastsFromCache() async {
    try {
      // Önce Firebase Storage'dan dosya adlarını çek (hızlı - URL çekmeden)
      final lesson = await _lessonsService.getLessonById(widget.lessonId);
      if (lesson == null) {
        print('⚠️ Lesson not found: ${widget.lessonId}');
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
      
      // Topic name'i storage path'ine çevir
      final topicFolderName = widget.topicId.startsWith('${widget.lessonId}_')
          ? widget.topicId.substring('${widget.lessonId}_'.length)
          : widget.topicName;
      
      // Storage yolunu oluştur
      String storagePath = 'dersler/$lessonNameForPath/konular/$topicFolderName/podcast';
      
      // Firebase Storage'dan sadece dosya adlarını çek (hızlı - URL çekmeden)
      List<String> fileNames = [];
      try {
        fileNames = await _storageService.listFileNames(storagePath);
        if (fileNames.isEmpty) {
          // Alternatif path'i dene
          storagePath = 'dersler/$lessonNameForPath/$topicFolderName/podcast';
          fileNames = await _storageService.listFileNames(storagePath);
        }
      } catch (e) {
        print('⚠️ Error getting file names from Storage: $e');
      }
      
      if (fileNames.isEmpty) {
        print('❌ No podcast files found in Storage');
        return;
      }
      
      // Cache dizinindeki tüm dosyaları listele
      final podcastDir = await _downloadService.getPodcastDirectory();
      if (!await podcastDir.exists()) {
        print('❌ Podcast cache directory does not exist');
        return;
      }
      
      final files = podcastDir.listSync();
      final cachedFiles = files.whereType<File>().toList();
      
      // Her Storage dosyası için cache'deki dosyayı bul
      final cachedPodcasts = <Podcast>[];
      
      for (int i = 0; i < fileNames.length; i++) {
        final fileName = fileNames[i];
        
        // Sadece audio dosyalarını al
        if (!fileName.toLowerCase().endsWith('.mp3') && !fileName.toLowerCase().endsWith('.m4a')) {
          continue;
        }
        
        // Storage path'inden URL oluştur (tam URL değil, sadece path)
        final filePath = '$storagePath/$fileName';
        
        // Dosya adından başlık oluştur (gerçek ad)
        final title = fileName
            .replaceAll('.mp3', '')
            .replaceAll('.m4a', '')
            .replaceAll('_', ' ')
            .trim();
        
        // Cache'deki dosyayı bul (URL'den hash oluşturup kontrol et)
        File? cachedFile;
        try {
          // Her Storage dosyası için, olası URL'leri oluşturup hash'ini hesaplayalım
          // Firebase Storage URL formatı: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encodedPath}?alt=media
          // Path'i encode et
          final encodedPath = filePath.replaceAll('/', '%2F');
          
          // Olası URL formatlarını dene
          final possibleUrls = [
            'https://firebasestorage.googleapis.com/v0/b/kpss-ags-2026.appspot.com/o/$encodedPath?alt=media',
            'https://firebasestorage.googleapis.com/v0/b/kpss-ags-2026/o/$encodedPath?alt=media',
            filePath, // Direkt path olarak da dene
          ];
          
          // Her URL için hash oluşturup cache'deki dosyayı bul
          for (final url in possibleUrls) {
            final hash = _getHashFromUrl(url);
            final extension = fileName.contains('.') ? '.${fileName.split('.').last}' : '.mp3';
            final expectedFileName = '$hash$extension';
            
            // Cache'deki dosyaları kontrol et
            for (final file in cachedFiles) {
              final cacheFileName = file.path.split('/').last;
              if (cacheFileName == expectedFileName) {
                cachedFile = file;
                break;
              }
            }
            
            if (cachedFile != null) break;
          }
          
          // Eğer hala bulunamadıysa, sırayla eşleştir (fallback)
          if (cachedFile == null && i < cachedFiles.length) {
            cachedFile = cachedFiles[i];
          }
        } catch (e) {
          print('⚠️ Error finding cached file for $fileName: $e');
          // Fallback: sırayla eşleştir
          if (i < cachedFiles.length) {
            cachedFile = cachedFiles[i];
          }
        }
        
        if (cachedFile != null) {
          cachedPodcasts.add(Podcast(
            id: 'podcast_${widget.topicId}_$i',
            title: title.isNotEmpty ? title : 'Podcast ${i + 1}',
            description: '${widget.topicName} podcast',
            audioUrl: 'file://${cachedFile.path}', // Local path'i URL formatında sakla
            durationMinutes: 0,
            topicId: widget.topicId,
            lessonId: widget.lessonId,
            order: i,
          ));
        }
      }
      
      print('📊 Found ${cachedPodcasts.length} cached podcast files with real names');
      
      // Cache'den yüklenenleri HEMEN göster (anında açılış - PDF gibi)
      if (cachedPodcasts.isNotEmpty) {
        print('📂 Loading ${cachedPodcasts.length} podcasts from cache (instant)...');
        _podcasts = cachedPodcasts;
        
        if (mounted) {
          setState(() {
            _isLoading = false; // Hemen göster
          });
        }
        print('✅ Podcasts displayed instantly from cache with real names');
      } else {
        print('❌ No cached podcasts found');
      }
    } catch (e) {
      print('⚠️ Error checking podcasts cache in initState: $e');
    }
  }
  
  /// Get hash from URL (same as PodcastDownloadService)
  String _getHashFromUrl(String url) {
    final bytes = utf8.encode(url);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<void> _loadPodcasts() async {
    // Eğer cache'den zaten yüklendiyse, Firebase Storage çağrısını atla (güncelleme için arka planda çalışabilir)
    if (_podcasts.isNotEmpty && !_isLoading) {
      print('📂 Podcasts already loaded from cache, skipping redundant Firebase Storage call');
      // Arka planda güncelleme yap (opsiyonel)
      return;
    }
    
    try {
      // Sadece cache'den yüklenmediyse loading göster
      if (_podcasts.isEmpty) {
        setState(() {
          _isLoading = true;
        });
      }
      
      print('🔍 Loading podcasts from Storage for topicId: ${widget.topicId}');
      
      // Lesson name'i al
      final lesson = await _lessonsService.getLessonById(widget.lessonId);
      if (lesson == null) {
        print('⚠️ Lesson not found: ${widget.lessonId}');
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
      
      // Topic name'i storage path'ine çevir (topicId'den topic folder name'i çıkar)
      // TopicId formatı: {lessonId}_{topicFolderName}
      // lessonId'yi tam olarak çıkar (çünkü lessonId'de de alt çizgi olabilir)
      // topicFolderName zaten storage'daki gerçek klasör adı, direkt kullan (Firebase Storage path'leri direkt string)
      final topicFolderName = widget.topicId.startsWith('${widget.lessonId}_')
          ? widget.topicId.substring('${widget.lessonId}_'.length)
          : widget.topicName; // Fallback: topic name'i direkt kullan
      
      // Storage yolunu oluştur: önce konular/ altından dene, yoksa direkt ders altından
      // Firebase Storage path'leri direkt string olarak kullanılır, encode etmeye gerek yok
      String storagePath = 'dersler/$lessonNameForPath/konular/$topicFolderName/podcast';
      try {
        print('📂 Trying storage path: $storagePath');
        final testResult = await _storageService.listAudioFiles(storagePath);
        if (testResult.isEmpty) {
          // Konular altında yoksa, direkt ders altından dene
          storagePath = 'dersler/$lessonNameForPath/$topicFolderName/podcast';
          print('📂 Trying alternative path: $storagePath');
        }
      } catch (e) {
        // Hata varsa alternatif path'i dene
        storagePath = 'dersler/$lessonNameForPath/$topicFolderName/podcast';
        print('📂 Using fallback path: $storagePath');
      }
      
      // Storage'dan dosyaları listele (hızlı - sadece URL listesi)
      final audioUrls = await _storageService.listAudioFiles(storagePath);
      
      print('✅ Found ${audioUrls.length} podcasts from Storage');
      
      // Önce hızlıca podcast listesini oluştur (duration olmadan - anında göster)
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
        } catch (e) {
          print('⚠️ Error processing podcast $index: $e');
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
      
      // Listeyi HEMEN göster (anında açılış için)
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      // Check downloaded status for all podcasts (arka planda)
      _checkDownloadedPodcasts();
      
      // Arka planda duration'ları yükle (non-blocking)
      _loadDurationsInBackground();
    } catch (e) {
      print('❌ Error loading podcasts: $e');
      print('Error stack: ${e.toString()}');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      await audioPlayer.setUrl(podcast.audioUrl);
      
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
      print('⚠️ Could not get duration for ${podcast.title}: $e');
    }
  }

  Future<void> _initializeAudio() async {
    await _audioService.initialize();
    
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
      if (_podcasts.isNotEmpty && 
          _selectedPodcastIndex < _podcasts.length && 
          _totalDuration != null && 
          _totalDuration!.inSeconds > 0) {
        _saveProgress();
      }
    });
  }

  Future<void> _saveProgress() async {
    if (_podcasts.isEmpty || _selectedPodcastIndex >= _podcasts.length) return;
    if (_totalDuration == null || _totalDuration!.inSeconds == 0) return;
    
    final currentPodcast = _podcasts[_selectedPodcastIndex];
    await _progressService.savePodcastProgress(
      podcastId: currentPodcast.id,
      podcastTitle: currentPodcast.title,
      topicId: currentPodcast.topicId,
      lessonId: currentPodcast.lessonId,
      topicName: widget.topicName,
      currentPosition: _currentPosition,
      totalDuration: _totalDuration!,
    );
  }

  @override
  void dispose() {
    _progressSaveTimer?.cancel();
    
    // Save final progress before disposing
    if (_podcasts.isNotEmpty && 
        _selectedPodcastIndex < _podcasts.length && 
        _totalDuration != null && 
        _totalDuration!.inSeconds > 0) {
      _saveProgress();
    }
    
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
      
      // Load saved progress and seek to that position
      final savedProgress = await _progressService.getPodcastProgress(currentPodcast.id);
      
      // Check if podcast is downloaded locally (cache kontrolü - hızlı)
      // Eğer audioUrl file:// ile başlıyorsa, bu cache'den yüklenen bir podcast'tir
      String? finalLocalPath;
      if (currentPodcast.audioUrl.startsWith('file://')) {
        // Cache'den yüklenen podcast - local path'i direkt kullan
        finalLocalPath = currentPodcast.audioUrl.substring(7); // 'file://' prefix'ini kaldır
        print('📁 Using cached podcast (instant): $finalLocalPath');
      } else {
        // Normal podcast - cache kontrolü yap
        final localFilePath = await _downloadService.getLocalFilePath(currentPodcast.audioUrl);
        finalLocalPath = localFilePath;
        
        // Eğer indirilmemişse, streaming ile çal (hızlı, tam indirme yok)
        if (localFilePath == null) {
          print('🌐 Podcast not downloaded, using streaming mode (fast, no full download)...');
          // Streaming ile çal, arka planda cache'le
          finalLocalPath = null; // Network streaming kullan
          
          // Arka planda indir (cache için - non-blocking)
          _downloadService.downloadPodcast(
            audioUrl: currentPodcast.audioUrl,
            podcastId: currentPodcast.id,
            onProgress: (progress) {
              print('📊 Background download progress: ${(progress * 100).toStringAsFixed(0)}%');
            },
          ).then((downloadedPath) {
            if (downloadedPath != null && mounted) {
              print('✅ Podcast cached in background: $downloadedPath');
              setState(() {
                _downloadedPodcasts[currentPodcast.id] = true;
              });
              // Next time will use cache
            }
          }).catchError((e) {
            print('⚠️ Background download failed: $e');
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
      );
      
      // Update last access time if playing from local file
      if (finalLocalPath != null) {
        await _cleanupService.updateLastAccessTime(currentPodcast.audioUrl);
      }
      
      // Seek to saved position if available
      if (savedProgress != null && savedProgress.inSeconds > 5) {
        // Only resume if saved position is more than 5 seconds
        await _audioService.seek(savedProgress);
        print('✅ Resuming podcast from saved position: ${savedProgress.inMinutes}m');
      }
      
      // Start progress save timer
      _startProgressSaveTimer();
      
      // Eğer duration hala yoksa, arka planda yükle
      if (duration == null || durationMinutes == 0) {
        _loadDurationForPodcast(_selectedPodcastIndex, currentPodcast);
      }
    } catch (e, stackTrace) {
      print('❌❌❌ ERROR IN _loadAndPlayCurrentPodcast ❌❌❌');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Full error: ${e.toString()}');
      print('Stack trace:');
      print(stackTrace);
      
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
    if (_selectedPodcastIndex == index) return;
    
    await _audioService.stop();
    setState(() {
      _selectedPodcastIndex = index;
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _totalDuration = null;
    });
    
    // Seçilen podcast'i kontrol et - eğer indirilmişse hemen aç
    if (index < _podcasts.length) {
      final podcast = _podcasts[index];
      if (podcast.audioUrl.isNotEmpty) {
        // Önce indirme kontrolü yap (cache kontrolü - hızlı)
        final localFilePath = await _downloadService.getLocalFilePath(podcast.audioUrl);
        
        if (localFilePath != null) {
          // İndirilmiş - hemen aç (PDF'lerdeki gibi anında açılış)
          print('📁 Podcast is downloaded, opening immediately: $localFilePath');
          await _loadAndPlayCurrentPodcast();
        } else {
          // İndirilmemiş - arka planda önceden yükle (preload)
          _preloadPodcast(podcast.audioUrl);
        }
      }
    }
  }
  
  // Podcast'i önceden yükle (preload)
  Future<void> _preloadPodcast(String audioUrl) async {
    try {
      // just_audio'da preload için setUrl çağır ama play() çağırma
      // Bu sayede dosya önceden yüklenir ve play'e basınca hemen başlar
      final audioPlayer = AudioPlayer();
      await audioPlayer.setUrl(audioUrl);
      // Preload tamamlandı, dispose et
      await audioPlayer.dispose();
    } catch (e) {
      print('⚠️ Error preloading podcast: $e');
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

        if (_isLoading) {
          return Scaffold(
            backgroundColor: AppColors.backgroundLight,
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
                    Navigator.of(context).pop(true); // Return true to indicate refresh needed
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
            backgroundColor: AppColors.backgroundLight,
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
                    Navigator.of(context).pop(true); // Return true to indicate refresh needed
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
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bu konu için henüz podcast eklenmemiş',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final currentPodcast = _podcasts[_selectedPodcastIndex];

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          extendBodyBehindAppBar: false,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(isSmallScreen ? 80 : 90),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.gradientPurpleStart,
                    AppColors.gradientPurpleEnd,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gradientPurpleStart.withValues(alpha: 0.3),
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
                                  Navigator.of(context).pop(true); // Return true to indicate refresh needed
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
                          color: isSelected ? null : Colors.white,
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
                                            : AppColors.textPrimary,
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
                                              : AppColors.textSecondary,
                                        ),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '${podcast.durationMinutes} dk',
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 11 : 12,
                                              color: isSelected
                                                  ? AppColors.gradientPurpleStart
                                                  : AppColors.textSecondary,
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
                                                color: AppColors.textSecondary,
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
