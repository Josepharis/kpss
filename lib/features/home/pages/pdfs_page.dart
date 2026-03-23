import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/premium_snackbar.dart';
import '../../../core/models/topic.dart';
import '../../../core/services/pdf_download_service.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/floating_home_button.dart';
import 'topic_pdf_viewer_page.dart';

class PdfsPage extends StatefulWidget {
  final String topicName;
  final int pdfCount;
  final String topicId;
  final String lessonId;
  final Topic topic;

  const PdfsPage({
    super.key,
    required this.topicName,
    required this.pdfCount,
    required this.topicId,
    required this.lessonId,
    required this.topic,
  });

  @override
  State<PdfsPage> createState() => _PdfsPageState();
}

class _PdfsPageState extends State<PdfsPage> {
  final PdfDownloadService _downloadService = PdfDownloadService();
  final LessonsService _lessonsService = LessonsService();
  final StorageService _storageService = StorageService();
  List<Map<String, String>> _pdfs = [];
  bool _isLoading = true;
  bool _shouldRefresh = false;
  Map<String, bool> _downloadedPdfs = {}; // Track downloaded PDFs

  bool _isLoadingFromStorage = false;

  String _cleanTitle(String title) {
    if (title.isEmpty) return title;
    // Regex matches leading numbers followed by common separators like -, ., space, or underscore
    return title.replaceFirst(RegExp(r'^\d+[-.\s_]+'), '').trim();
  }

  @override
  void initState() {
    super.initState();
    // Önce cache'den hızlıca yükle
    _loadPdfsFromCache();
  }

  /// Cache'den PDF listesini hemen yükle (synchronous - çok hızlı)
  Future<void> _loadPdfsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'pdfs_list_${widget.topicId}';
      final cacheTimeKey = 'pdfs_list_time_${widget.topicId}';
      final cachedJson = prefs.getString(cacheKey);
      final cacheTime = prefs.getInt(cacheTimeKey);

      // Cache geçerlilik süresi: 7 gün (PDF listesi çok sık değişmez)
      const cacheValidDuration = Duration(days: 7);
      final now = DateTime.now().millisecondsSinceEpoch;
      final isCacheValid =
          cacheTime != null &&
          (now - cacheTime) < cacheValidDuration.inMilliseconds;

      if (cachedJson != null && cachedJson.isNotEmpty && isCacheValid) {
        try {
          final List<dynamic> cachedList = jsonDecode(cachedJson);
          final cachedPdfs = cachedList
              .map(
                (json) => {
                  'name': (json['name'] ?? '') as String,
                  'pdfUrl': (json['pdfUrl'] ?? '') as String,
                },
              )
              .cast<Map<String, String>>()
              .toList();

          if (cachedPdfs.isNotEmpty && mounted) {
            setState(() {
              _pdfs = cachedPdfs;
              _isLoading = false;
            });
            print(
              '✅ Loaded ${_pdfs.length} PDFs from cache (NO Storage request)',
            );
            _checkDownloadedPdfs();
            // Cache geçerliyse Storage'dan ÇEKME - hiç istek atma
            return;
          }
        } catch (e) {
          print('⚠️ Error parsing PDFs cache: $e');
        }
      } else if (cachedJson != null && cachedJson.isNotEmpty && !isCacheValid) {
        final daysOld = cacheTime != null
            ? ((now - cacheTime) / 86400000).toStringAsFixed(1)
            : "unknown";
        print(
          '⚠️ PDF cache expired ($daysOld days old), will refresh from Storage',
        );
      } else {
        print('⚠️ No PDF cache found, will load from Storage');
      }

      // Cache yok veya geçersizse Storage'dan yükle (flag'i _loadPdfs() kendisi yönetir)
      if (mounted) {
        _loadPdfs();
        _checkDownloadedPdfs();
      }
    } catch (e) {
      print('⚠️ Error loading PDFs from cache: $e');
      // Hata olursa Storage'dan yükle (sadece bir kez)
      if (mounted) {
        _loadPdfs();
        _checkDownloadedPdfs();
      }
    }
  }

  Future<void> _checkDownloadedPdfs() async {
    for (final pdf in _pdfs) {
      if (pdf['pdfUrl'] != null && pdf['pdfUrl']!.isNotEmpty) {
        final isDownloaded = await _downloadService.isPdfDownloaded(
          pdf['pdfUrl']!,
        );
        if (mounted) {
          setState(() {
            _downloadedPdfs[pdf['pdfUrl']!] = isDownloaded;
          });
        }
      }
    }
  }

  Future<void> _loadPdfs() async {
    // Eğer zaten yükleniyorsa tekrar başlatma
    if (_isLoadingFromStorage) {
      print('⚠️ Already loading from Storage, skipping duplicate request');
      return;
    }
    _isLoadingFromStorage = true;

    try {
      // Cache kontrolü - eğer cache geçerliyse hiç Storage'dan çekme
      try {
        final prefs = await SharedPreferences.getInstance();
        final cacheKey = 'pdfs_list_${widget.topicId}';
        final cacheTimeKey = 'pdfs_list_time_${widget.topicId}';
        final cachedJson = prefs.getString(cacheKey);
        final cacheTime = prefs.getInt(cacheTimeKey);

        const cacheValidDuration = Duration(days: 7);
        final now = DateTime.now().millisecondsSinceEpoch;
        final isCacheValid =
            cacheTime != null &&
            (now - cacheTime) < cacheValidDuration.inMilliseconds;

        if (cachedJson != null && cachedJson.isNotEmpty && isCacheValid) {
          print('✅ Cache is valid, skipping Storage request');
          return;
        }
      } catch (e) {
        // Cache kontrolü başarısız, devam et
      }

      setState(() {
        _isLoading = true;
      });

      print(
        '🌐 Loading PDFs from Storage for topic: ${widget.topic.name} (cache miss or expired)',
      );
      print('⚠️ WARNING: This will make Storage requests and use MB!');

      // Lesson name'i al
      final lesson = await _lessonsService.getLessonById(widget.lessonId);
      if (lesson == null) {
        print('⚠️ Lesson not found: ${widget.lessonId}');
        // Fallback: sadece topic.pdfUrl'i kullan
        _pdfs = [];
        if (widget.topic.pdfUrl != null && widget.topic.pdfUrl!.isNotEmpty) {
          _pdfs.add({'name': 'Konu Anlatımı', 'pdfUrl': widget.topic.pdfUrl!});
        }
        setState(() {
          _isLoading = false;
        });
        _checkDownloadedPdfs();
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

      // Storage path'lerini oluştur (konu, konu_anlatimi, pdf klasörleri)
      final konuAnlatimiPath = '$basePath/konu';
      final konuAnlatimiPathAlt = '$basePath/konu_anlatimi';
      final pdfPath = '$basePath/pdf';

      // Tüm PDF'leri topla
      final List<String> allPdfUrls = [];
      final List<String> pdfNames = [];

      // Helper function: Extract file name from file info
      String extractFileName(Map<String, String> fileInfo) {
        // Önce 'name' field'ını kullan (en doğrusu)
        var fileName = fileInfo['name'] ?? '';
        if (fileName.isEmpty) {
          // 'name' yoksa, fullPath'ten çıkar
          final fullPath = fileInfo['fullPath'] ?? '';
          if (fullPath.isNotEmpty) {
            fileName = fullPath.split('/').last;
          } else {
            // fullPath de yoksa, URL'den çıkar
            final url = fileInfo['url'] ?? '';
            if (url.isNotEmpty) {
              try {
                final uri = Uri.parse(url);
                fileName = uri.pathSegments.last;
                fileName = fileName.split('?').first;
              } catch (e) {
                fileName = url.split('/').last.split('?').first;
              }
            }
          }
        }

        // Decode URL encoding
        try {
          fileName = Uri.decodeComponent(fileName);
        } catch (e) {
          // Decode edilemezse direkt kullan
        }

        // Uzantıyı kaldır ve formatla
        fileName = fileName.replaceAll('.pdf', '').replaceAll('_', ' ').trim();

        return _cleanTitle(fileName.isNotEmpty ? fileName : 'PDF');
      }

      // 1. konu/ klasöründen PDF'leri al (öncelikli)
      // ⚠️ DİKKAT: Bu Storage'dan dosya listesi çekiyor - sadece gerektiğinde çağrılmalı
      try {
        print('📡 Making Storage request to list files in: $konuAnlatimiPath');
        final konuFiles = await _storageService.listFilesWithPaths(
          konuAnlatimiPath,
        );
        // Sort by name to ensure consistent numbering
        konuFiles.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
        print('📄 Found ${konuFiles.length} files in konu/ folder');
        for (final fileInfo in konuFiles) {
          final url = fileInfo['url'] ?? '';
          final name = fileInfo['name'] ?? '';
          final urlLower = url.toLowerCase();
          final nameLower = name.toLowerCase();

          // PDF kontrolü yap
          if (urlLower.contains('.pdf') || nameLower.endsWith('.pdf')) {
            // Zaten eklenmişse atla (URL'ye göre)
            if (!allPdfUrls.contains(url)) {
              allPdfUrls.add(url);
              final fileName = extractFileName(fileInfo);
              pdfNames.add(fileName);
              print('  ✅ Added PDF: $fileName (from: $name)');
            }
          }
        }
      } catch (e) {
        print('⚠️ Error loading from konu/ folder: $e');
      }

      // 2. konu_anlatimi/ klasöründen PDF'leri al
      // ⚠️ DİKKAT: Bu Storage'dan dosya listesi çekiyor - sadece gerektiğinde çağrılmalı
      try {
        print(
          '📡 Making Storage request to list files in: $konuAnlatimiPathAlt',
        );
        final konuAnlatimiFiles = await _storageService.listFilesWithPaths(
          konuAnlatimiPathAlt,
        );
        // Sort by name to ensure consistent numbering
        konuAnlatimiFiles.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
        print(
          '📄 Found ${konuAnlatimiFiles.length} files in konu_anlatimi/ folder',
        );
        for (final fileInfo in konuAnlatimiFiles) {
          final url = fileInfo['url'] ?? '';
          final name = fileInfo['name'] ?? '';
          final urlLower = url.toLowerCase();
          final nameLower = name.toLowerCase();

          // PDF kontrolü yap
          if (urlLower.contains('.pdf') || nameLower.endsWith('.pdf')) {
            // Zaten eklenmişse atla (URL'ye göre)
            if (!allPdfUrls.contains(url)) {
              allPdfUrls.add(url);
              final fileName = extractFileName(fileInfo);
              pdfNames.add(fileName);
              print('  ✅ Added PDF: $fileName (from: $name)');
            }
          }
        }
      } catch (e) {
        print('⚠️ Error loading from konu_anlatimi/ folder: $e');
      }

      // 3. pdf/ klasöründen PDF'leri al
      // ⚠️ DİKKAT: Bu Storage'dan dosya listesi çekiyor - sadece gerektiğinde çağrılmalı
      try {
        print('📡 Making Storage request to list files in: $pdfPath');
        final pdfFiles = await _storageService.listFilesWithPaths(pdfPath);
        // Sort by name to ensure consistent numbering
        pdfFiles.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
        print('📄 Found ${pdfFiles.length} files in pdf/ folder');
        for (final fileInfo in pdfFiles) {
          final url = fileInfo['url'] ?? '';
          final name = fileInfo['name'] ?? '';
          final urlLower = url.toLowerCase();
          final nameLower = name.toLowerCase();

          // PDF kontrolü yap
          if (urlLower.contains('.pdf') || nameLower.endsWith('.pdf')) {
            // Zaten eklenmişse atla (URL'ye göre)
            if (!allPdfUrls.contains(url)) {
              allPdfUrls.add(url);
              final fileName = extractFileName(fileInfo);
              pdfNames.add(fileName);
              print('  ✅ Added PDF: $fileName (from: $name)');
            }
          }
        }
      } catch (e) {
        print('⚠️ Error loading from pdf/ folder: $e');
      }

      // PDF listesini oluştur
      _pdfs = [];
      print(
        '📊 Processing PDFs: ${allPdfUrls.length} URLs found, ${pdfNames.length} names',
      );

      if (allPdfUrls.isNotEmpty) {
        for (int i = 0; i < allPdfUrls.length; i++) {
          final pdfUrl = allPdfUrls[i];
          print('  🔍 Checking PDF ${i + 1}: $pdfUrl');

          // PDF URL'inin geçerli olduğunu kontrol et
          if (pdfUrl.isNotEmpty &&
              (pdfUrl.startsWith('http://') || pdfUrl.startsWith('https://'))) {
            final pdfName = i < pdfNames.length && pdfNames[i].isNotEmpty
                ? pdfNames[i]
                : 'PDF ${i + 1}';
            _pdfs.add({'name': pdfName, 'pdfUrl': pdfUrl});
            print('  ✅ Added PDF ${i + 1}: $pdfName');
            print('     URL: $pdfUrl');
          } else {
            print(
              '  ⚠️ Invalid PDF URL skipped: $pdfUrl (empty: ${pdfUrl.isEmpty}, starts with http: ${pdfUrl.startsWith('http://') || pdfUrl.startsWith('https://')})',
            );
          }
        }
        print(
          '✅ Loaded ${_pdfs.length} PDF files from Storage (total found: ${allPdfUrls.length})',
        );
      } else {
        print('⚠️ No PDF URLs found in allPdfUrls list');
        // Fallback: topic.pdfUrl'i kullan
        if (widget.topic.pdfUrl != null && widget.topic.pdfUrl!.isNotEmpty) {
          _pdfs.add({'name': 'Konu Anlatımı', 'pdfUrl': widget.topic.pdfUrl!});
          print(
            '⚠️ No PDFs found in Storage, using topic.pdfUrl: ${widget.topic.pdfUrl}',
          );
        } else {
          print('⚠️ No PDFs found for this topic (topic.pdfUrl is also null)');
        }
      }

      print('📋 Final PDF list: ${_pdfs.length} PDFs');
      for (int i = 0; i < _pdfs.length; i++) {
        print('  PDF ${i + 1}: ${_pdfs[i]['name']} - ${_pdfs[i]['pdfUrl']}');
      }

      // Cache'e kaydet (hızlı erişim için)
      try {
        final prefs = await SharedPreferences.getInstance();
        final cacheKey = 'pdfs_list_${widget.topicId}';
        final cacheTimeKey = 'pdfs_list_time_${widget.topicId}';
        final pdfsJson = jsonEncode(_pdfs);
        await prefs.setString(cacheKey, pdfsJson);
        await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
        print('✅ Saved ${_pdfs.length} PDFs to cache');
      } catch (e) {
        print('⚠️ Error saving PDFs to cache: $e');
      }

      setState(() {
        _isLoading = false;
      });

      // Check downloaded status
      _checkDownloadedPdfs();
    } catch (e) {
      print('❌ Error loading PDFs: $e');

      setState(() {
        _isLoading = false;
        _pdfs = [];
      });
    } finally {
      _isLoadingFromStorage = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenHeight < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : AppColors.backgroundLight,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: const FloatingHomeButton(),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isSmallScreen ? 70 : 80),
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFFFF9800), const Color(0xFFFF6B35)],
                  ),
            color: isDark ? const Color(0xFF1E1E1E) : null,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : const Color(0xFFFF9800).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isSmallScreen ? 8 : 10,
                  ),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pop(_shouldRefresh);
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: isSmallScreen ? 16 : 18,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Konu Anlatımı',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.topicName,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                                color: Colors.white.withValues(alpha: 0.85),
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
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pdfs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 64,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'PDF bulunamadı',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Debug: _pdfs.length = ${_pdfs.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              itemCount: _pdfs.length,
              itemBuilder: (context, index) {
                print('📋 Building PDF card ${index + 1}/${_pdfs.length}');
                final pdf = _pdfs[index];
                print('   PDF data: $pdf');
                return _buildPdfCard(pdf, index, isSmallScreen);
              },
            ),
    );
  }

  Widget _buildPdfCard(Map<String, String> pdf, int index, bool isSmallScreen) {
    print('🎨 Building PDF card widget');
    print('   PDF map: $pdf');
    final pdfUrl = pdf['pdfUrl'] ?? '';
    final pdfName = pdf['name'] ?? 'Unknown';
    final isDownloaded = _downloadedPdfs[pdfUrl] ?? false;

    print('   PDF Name: $pdfName');
    print('   PDF URL: $pdfUrl');
    print('   Is Downloaded: $isDownloaded');

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      elevation: 2,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          print('🖱️🖱️🖱️ PDF CARD TAPPED! 🖱️🖱️🖱️');
          print('   PDF data: $pdf');
          print('   PDF keys: ${pdf.keys}');
          final pdfUrl = pdf['pdfUrl'];
          final pdfName = pdf['name'];
          print('📄 Opening PDF: $pdfName');
          print('   URL: $pdfUrl');
          print('   URL is null: ${pdfUrl == null}');
          print('   URL is empty: ${pdfUrl?.isEmpty ?? true}');

          if (pdfUrl == null || pdfUrl.isEmpty) {
            print('❌ PDF URL is null or empty!');
            PremiumSnackBar.show(
              context,
              message: 'PDF URL bulunamadı.',
              type: SnackBarType.error,
            );
            return;
          }

          print('✅ PDF URL is valid, navigating to viewer...');

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TopicPdfViewerPage(
                topic: Topic(
                  id: widget.topic.id,
                  lessonId: widget.topic.lessonId,
                  name: pdfName ?? 'Konu Anlatımı',
                  subtitle: widget.topic.subtitle,
                  duration: widget.topic.duration,
                  averageQuestionCount: widget.topic.averageQuestionCount,
                  testCount: widget.topic.testCount,
                  podcastCount: widget.topic.podcastCount,
                  videoCount: widget.topic.videoCount,
                  noteCount: widget.topic.noteCount,
                  progress: widget.topic.progress,
                  order: widget.topic.order,
                  pdfUrl: pdfUrl,
                ),
              ),
            ),
          );
          if (result == true) {
            setState(() {
              _shouldRefresh = true;
            });
            // Recheck downloaded status
            _checkDownloadedPdfs();
          }
        },
        onTapDown: (_) {
          print('👆 PDF card onTapDown triggered!');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: Row(
            children: [
              // PDF thumbnail/icon - Shrunk to make room for text
              Container(
                width: isSmallScreen ? 48 : 56,
                height: isSmallScreen ? 48 : 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFFFF9800), const Color(0xFFFF6B35)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.white,
                      size: isSmallScreen ? 24 : 28,
                    ),
                    if (isDownloaded)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
              // PDF info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. $pdfName',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        height: 1.2,
                      ),
                      // Removed maxLines and ellipsis to allow full readability
                    ),
                    SizedBox(height: isSmallScreen ? 4 : 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'PDF Dosyası',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 13,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDownloaded)
                          Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.download_done,
                                  size: 14,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'İndirildi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              // Delete button (only show if downloaded)
              if (isDownloaded)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () =>
                        _handleDelete(pdfUrl, pdf['name'] ?? 'Konu Anlatımı'),
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
                        size: 20,
                      ),
                    ),
                  ),
                ),
              SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDelete(String pdfUrl, String pdfName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF\'yi Sil'),
        content: Text('$pdfName PDF\'sini silmek istediğinize emin misiniz?'),
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
      final deleted = await _downloadService.deletePdf(pdfUrl);
      if (deleted && mounted) {
        setState(() {
          _downloadedPdfs[pdfUrl] = false;
        });
        PremiumSnackBar.show(
          context,
          message: 'PDF başarıyla silindi.',
          type: SnackBarType.success,
        );
      }
    }
  }
}
