import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/topic.dart';
import '../../../core/services/pdf_cache_service.dart';
import '../../../core/services/pdf_download_service.dart';
import '../../../core/services/storage_cleanup_service.dart';

class TopicPdfViewerPage extends StatefulWidget {
  final Topic topic;

  const TopicPdfViewerPage({
    super.key,
    required this.topic,
  });

  @override
  State<TopicPdfViewerPage> createState() => _TopicPdfViewerPageState();
}

class _TopicPdfViewerPageState extends State<TopicPdfViewerPage> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final PdfDownloadService _downloadService = PdfDownloadService();
  final StorageCleanupService _cleanupService = StorageCleanupService();
  bool _isLoading = true;
  String? _errorMessage;
  String? _localPdfPath; // Cached PDF path
  bool _isLoadingPdf = false; // Prevent multiple simultaneous loads
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _cacheCheckComplete = false; // Cache kontrolü tamamlandı mı?

  @override
  void initState() {
    super.initState();
    // Cache kontrolünü önce yap ve TAMAMLANMASINI BEKLE (anında açılış için)
    _initializePdf();
  }
  
  /// Initialize PDF - cache kontrolü tamamlanana kadar bekle
  Future<void> _initializePdf() async {
    // Önce cache kontrolü yap (await et - tamamlanmasını bekle)
    await _checkCacheImmediately();
    
    // Cache kontrolü tamamlandı
    if (mounted) {
      setState(() {
        _cacheCheckComplete = true;
      });
    }
    
    // Sonra diğer kontrolleri yap
    _checkPdfUrl();
    _checkDownloadedStatus();
  }
  
  /// Check cache immediately (synchronous check for instant loading)
  Future<void> _checkCacheImmediately() async {
    if (widget.topic.pdfUrl == null || widget.topic.pdfUrl!.isEmpty) return;
    
    print('🔍 Checking cache immediately for instant loading...');
    
    try {
      // Önce downloaded kontrolü
      final downloadedPath = await _downloadService.getLocalFilePath(widget.topic.pdfUrl!);
      if (downloadedPath != null && await File(downloadedPath).exists()) {
        print('📁 PDF is downloaded (instant check)');
        if (mounted) {
          setState(() {
            _localPdfPath = downloadedPath;
            _isDownloaded = true;
            _isLoading = false;
          });
          print('✅ PDF path set from download (instant): $downloadedPath');
        }
        return;
      }
      
      // Sonra cache kontrolü
      final isCached = await PdfCacheService.isCached(widget.topic.pdfUrl!);
      if (isCached) {
        print('📂 PDF is cached (instant check)');
        final cachedPath = await PdfCacheService.getCachedPath(widget.topic.pdfUrl!);
        if (cachedPath != null) {
          // Dosyanın gerçekten var olduğunu kontrol et
          final file = File(cachedPath);
          if (await file.exists()) {
            print('✅ PDF file exists in cache: $cachedPath');
            if (mounted) {
              setState(() {
                _localPdfPath = cachedPath;
                _isLoading = false;
              });
              print('✅ PDF path set from cache (instant): $cachedPath');
            }
          } else {
            print('⚠️ Cache file does not exist: $cachedPath');
          }
        } else {
          print('⚠️ Cache path is null');
        }
      } else {
        print('❌ PDF is not cached');
      }
    } catch (e) {
      print('⚠️ Error checking cache in initState: $e');
    }
  }
  
  Future<void> _checkDownloadedStatus() async {
    if (widget.topic.pdfUrl != null && widget.topic.pdfUrl!.isNotEmpty) {
      final isDownloaded = await _downloadService.isPdfDownloaded(widget.topic.pdfUrl!);
      if (mounted) {
        setState(() {
          _isDownloaded = isDownloaded;
        });
      }
    }
  }

  Future<void> _checkPdfUrl() async {
    if (!mounted) return;
    
    if (widget.topic.pdfUrl == null || widget.topic.pdfUrl!.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Bu konu için PDF dosyası bulunamadı.';
      });
    } else {
      // Önce cache kontrolü yap (bekle)
      await _checkCacheImmediately();
      
      // Eğer cache'den yüklendiyse _loadPdfWithCache çağırma (zaten yüklendi)
      if (_localPdfPath == null || _localPdfPath!.isEmpty) {
        print('⚠️ PDF not in cache, loading with _loadPdfWithCache...');
        _loadPdfWithCache();
      } else {
        print('✅ PDF already loaded from cache, skipping _loadPdfWithCache');
      }
    }
  }

  /// Load PDF with optimal strategy:
  /// - If cached: Use file mode (instant, reads from local cache)
  /// - If not cached: Use network mode (streaming - fast, no full download) + cache in background
  /// This minimizes wait time while maintaining speed
  Future<void> _loadPdfWithCache() async {
    // Prevent multiple simultaneous loads
    if (_isLoadingPdf) {
      print('⚠️ PDF is already loading, skipping...');
      return;
    }

    try {
      if (!mounted) return;
      
      _isLoadingPdf = true;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('📄 Loading PDF: ${widget.topic.pdfUrl}');
      
      // First check if PDF is downloaded
      final downloadedPath = await _downloadService.getLocalFilePath(widget.topic.pdfUrl!);
      
      if (downloadedPath != null && await File(downloadedPath).exists()) {
        // Use downloaded file (instant - reads from local disk)
        print('📁 PDF is downloaded, using file mode (instant)...');
        
        if (!mounted) {
          _isLoadingPdf = false;
          return;
        }
        
        setState(() {
          _localPdfPath = downloadedPath;
          _isLoading = false;
          _isDownloaded = true;
        });
        print('✅ PDF loaded from download (instant): $downloadedPath');
        await _cleanupService.updateLastAccessTime(widget.topic.pdfUrl!);
        _isLoadingPdf = false;
        return;
      }
      
      // Check if PDF is cached
      final isCached = await PdfCacheService.isCached(widget.topic.pdfUrl!);
      
      if (isCached) {
        // Use cached file (instant - reads from local disk)
        print('📂 PDF is cached, using file mode (instant)...');
        final cachedPath = await PdfCacheService.getCachedPath(widget.topic.pdfUrl!);
        
        if (!mounted) {
          _isLoadingPdf = false;
          return;
        }
        
        if (cachedPath != null) {
          setState(() {
            _localPdfPath = cachedPath;
            _isLoading = false;
          });
          print('✅ PDF loaded from cache (instant): $cachedPath');
          await _cleanupService.updateLastAccessTime(widget.topic.pdfUrl!);
          _isLoadingPdf = false;
          return;
        }
      }
      
      // Not cached - use streaming mode (fast, no full download needed)
      // PDF viewer will stream from network, we cache in background
      print('🌐 PDF not cached, using streaming mode (fast, no full download)...');
      
      if (!mounted) {
        _isLoadingPdf = false;
        return;
      }
      
      // Set to network mode (streaming - very fast)
      setState(() {
        _localPdfPath = null; // Use network mode
        _isLoading = false; // PDF viewer will handle loading
      });
      print('✅ PDF will stream from network (no download needed)');
      
      // Cache in background (non-blocking)
      PdfCacheService.cachePdf(widget.topic.pdfUrl!).then((cachedPath) {
        if (cachedPath != null && mounted) {
          print('✅ PDF cached in background: $cachedPath');
          // Next time will use cache
        }
      }).catchError((e) {
        print('⚠️ Background cache failed: $e');
      });
      
      _isLoadingPdf = false;
    } catch (e) {
      print('❌ Error loading PDF: $e');
      if (!mounted) {
        _isLoadingPdf = false;
        return;
      }
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'PDF yüklenirken bir hata oluştu: $e';
      });
    } finally {
      _isLoadingPdf = false;
    }
  }

  Future<void> _handleDelete() async {
    if (widget.topic.pdfUrl == null || widget.topic.pdfUrl!.isEmpty) {
      return;
    }
    
    // Delete PDF
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF\'yi Sil'),
        content: Text('${widget.topic.name} PDF\'sini silmek istediğinize emin misiniz?'),
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
      final deleted = await _downloadService.deletePdf(widget.topic.pdfUrl!);
      if (deleted && mounted) {
        setState(() {
          _isDownloaded = false;
          _localPdfPath = null;
        });
        // Reload PDF (will download again automatically)
        _loadPdfWithCache();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF silindi. Tekrar açıldığında otomatik indirilecek.'),
            backgroundColor: Colors.green,
          ),
        );
      }
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
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isSmallScreen ? 56 : 64),
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFF9800),
                      const Color(0xFFFF6B35),
                    ],
                  ),
            color: isDark ? const Color(0xFF1E1E1E) : null,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : const Color(0xFFFF9800).withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 12),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.topic.name,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Konu Anlatımı',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Delete button (only show if downloaded)
                  if (widget.topic.pdfUrl != null && widget.topic.pdfUrl!.isNotEmpty && _isDownloaded)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _handleDelete,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 64,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
              SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Lütfen daha sonra tekrar deneyin.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (widget.topic.pdfUrl == null || widget.topic.pdfUrl!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 64,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
              SizedBox(height: 16),
              Text(
                'PDF dosyası bulunamadı',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    Widget pdfViewer = Builder(
      builder: (context) {
        // Cache kontrolü tamamlanana kadar bekle
        if (!_cacheCheckComplete) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }
        
        try {
          // Strategy:
          // - If _localPdfPath is set: Use file mode (INSTANT, reads from local cache)
          // - If _localPdfPath is null: Use network mode (streaming)
          if (_localPdfPath != null && _localPdfPath!.isNotEmpty) {
            // Use cached file - INSTANT, reads from local disk
            final file = File(_localPdfPath!);
            if (file.existsSync()) {
              print('📄 Using file mode (cache): $_localPdfPath');
              return SfPdfViewer.file(
                file,
                key: _pdfViewerKey,
                onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                  print('✅ PDF loaded from file (cache) - INSTANT!');
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                },
                onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                  print('❌ PDF file load failed: ${details.error}');
                  if (mounted) {
                    setState(() {
                      _localPdfPath = null; // Fallback to network
                      _isLoading = false;
                      _errorMessage = 'PDF yüklenirken bir hata oluştu: ${details.error}';
                    });
                  }
                },
              );
            } else {
              print('⚠️ Cache file does not exist, using network mode');
              // File doesn't exist, use network
              _localPdfPath = null;
            }
          }
          
          // Use network mode for streaming (when not cached or file doesn't exist)
          print('📄 Using network mode (streaming): ${widget.topic.pdfUrl}');
          return SfPdfViewer.network(
            widget.topic.pdfUrl!,
            key: _pdfViewerKey,
            onDocumentLoaded: (PdfDocumentLoadedDetails details) {
              print('✅ PDF loaded from network (streaming)');
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = 'PDF yüklenirken bir hata oluştu: ${details.error}';
                });
              }
            },
          );
        } catch (e) {
          // Handle plugin exception
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'PDF görüntüleyici başlatılamadı. Lütfen uygulamayı tamamen kapatıp yeniden açın.';
              });
            }
          });
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.orange.shade400,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'PDF görüntüleyici başlatılamadı',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Lütfen uygulamayı tamamen kapatıp yeniden açın.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
      },
    );

    return Stack(
      children: [
        // PDF Viewer
        pdfViewer,
        // Download progress overlay
        if (_isDownloading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'PDF indiriliyor...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Loading overlay
        if (_isLoading)
          Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                color: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFFFF9800),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'PDF yükleniyor...',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
