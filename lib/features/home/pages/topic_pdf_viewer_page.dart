import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/topic.dart';
import '../../../core/services/pdf_cache_service.dart';

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
  bool _isLoading = true;
  String? _errorMessage;
  String? _localPdfPath; // Cached PDF path
  bool _isLoadingPdf = false; // Prevent multiple simultaneous loads

  @override
  void initState() {
    super.initState();
    _checkPdfUrl();
  }

  void _checkPdfUrl() {
    if (!mounted) return;
    
    if (widget.topic.pdfUrl == null || widget.topic.pdfUrl!.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Bu konu için PDF dosyası bulunamadı.';
      });
    } else {
      _loadPdfWithCache();
    }
  }

  /// Load PDF with optimal strategy:
  /// - If cached: Use file mode (NO storage usage, reads from local cache)
  /// - If not cached: Use network mode (fast streaming) + cache in background
  /// This minimizes storage usage while maintaining speed
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
      
      // Check if PDF is cached
      final isCached = await PdfCacheService.isCached(widget.topic.pdfUrl!);
      
      if (isCached) {
        // Use cached file (NO storage usage - reads from local disk)
        print('📂 PDF is cached, using file mode (no storage usage)...');
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
          print('✅ PDF loaded from cache (no storage used): $cachedPath');
          _isLoadingPdf = false;
          return;
        }
      }
      
      // Not cached - use network mode for fast initial load
      // Network mode streams pages, so first pages appear quickly
      print('🌐 PDF not cached, using network mode (fast streaming)...');
      
      if (!mounted) {
        _isLoadingPdf = false;
        return;
      }
      
      // Use network mode (faster - streams pages)
      setState(() {
        _localPdfPath = null; // null means use network
        _isLoading = false;
      });
      
      // Cache in background (non-blocking, saves storage for next time)
      _cachePdfInBackground(widget.topic.pdfUrl!);
      
      print('✅ PDF loading from network (will cache in background)');
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

  /// Cache PDF in background without blocking UI
  Future<void> _cachePdfInBackground(String pdfUrl) async {
    try {
      // Don't await - let it run in background
      PdfCacheService.cachePdf(pdfUrl).then((path) {
        if (path != null) {
          print('✅ PDF cached in background: $path');
          print('💾 Next time this PDF will load from cache (no storage usage)');
        }
      }).catchError((e) {
        print('⚠️ Background caching failed: $e');
      });
    } catch (e) {
      print('⚠️ Error starting background cache: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isSmallScreen ? 56 : 64),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF9800),
                const Color(0xFFFF6B35),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF9800).withValues(alpha: 0.2),
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
                ],
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
                color: Colors.grey.shade400,
              ),
              SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Lütfen daha sonra tekrar deneyin.',
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
                color: Colors.grey.shade400,
              ),
              SizedBox(height: 16),
              Text(
                'PDF dosyası bulunamadı',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Builder(
          builder: (context) {
            try {
              // Strategy:
              // - If _localPdfPath is set: Use file mode (NO storage usage, reads from local cache)
              // - If _localPdfPath is null: Use network mode (fast streaming, uses storage)
              if (_localPdfPath != null) {
                // Use cached file - NO storage usage, reads from local disk
                // File mode may be slightly slower initially but saves storage bandwidth
                return SfPdfViewer.file(
                  File(_localPdfPath!),
                  key: _pdfViewerKey,
                  onDocumentLoaded: (PdfDocumentLoadedDetails details) {
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
              } else {
                // Use network mode for fast initial load (streaming)
                // This uses storage but is faster - will cache for next time
              return SfPdfViewer.network(
                widget.topic.pdfUrl!,
                key: _pdfViewerKey,
                onDocumentLoaded: (PdfDocumentLoadedDetails details) {
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
              }
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
        ),
        if (_isLoading)
          Container(
            color: AppColors.backgroundLight,
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
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

