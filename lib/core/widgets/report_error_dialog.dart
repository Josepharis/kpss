import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/models/error_report.dart';
import '../../core/services/error_report_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/premium_snackbar.dart';

class ReportErrorDialog extends StatefulWidget {
  final String contentId;
  final String contentType;
  final String topicId;
  final String topicName;
  final String lessonId;
  final String contentPreview;

  const ReportErrorDialog({
    super.key,
    required this.contentId,
    required this.contentType,
    required this.topicId,
    required this.topicName,
    required this.lessonId,
    required this.contentPreview,
  });

  @override
  State<ReportErrorDialog> createState() => _ReportErrorDialogState();
}

class _ReportErrorDialogState extends State<ReportErrorDialog> {
  final _descriptionController = TextEditingController();
  final _errorReportService = ErrorReportService();
  final _authService = AuthService();
  ErrorType _selectedErrorType = ErrorType.contentError;
  bool _isSubmitting = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Lütfen hata detaylarını yazın.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final userId = _authService.getUserId() ?? 'unknown';
      final userName = await _authService.getUserName() ?? 'Anonim';

      final report = ErrorReport(
        userId: userId,
        userName: userName,
        contentId: widget.contentId,
        contentType: widget.contentType,
        errorType: _selectedErrorType.getLabel(widget.contentType),
        description: description,
        topicId: widget.topicId,
        topicName: widget.topicName,
        lessonId: widget.lessonId,
        timestamp: DateTime.now(),
        contentPreview: widget.contentPreview.length > 100 
          ? '${widget.contentPreview.substring(0, 100)}...' 
          : widget.contentPreview,
      );

      final success = await _errorReportService.submitReport(report);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          // This snackbar is fine because dialog is popped
          PremiumSnackBar.show(
            context,
            message: 'Hata bildirimi başarıyla gönderildi. Teşekkür ederiz!',
            type: SnackBarType.success,
          );
        } else {
          setState(() {
            _hasError = true;
            _errorMessage = 'Hata bildirimi gönderilemedi. Lütfen tekrar deneyin.';
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          width: screenWidth > 500 ? 500 : double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(28, 24, 20, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2563EB).withOpacity(0.1),
                        const Color(0xFF2563EB).withOpacity(0.02),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.report_problem_rounded,
                          color: Color(0xFF2563EB),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'HATA BİLDİR',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2563EB),
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              'Hatalı içeriği bildirin',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white60 : Colors.black45,
                          size: 20,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.05),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HATA TİPİ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white54 : Colors.black54,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withAlpha(20),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                          ),
                        ),
                        child: Column(
                          children: ErrorType.values.where((type) {
                            if (widget.contentType == 'flash_card') {
                              return type != ErrorType.optionError && 
                                     type != ErrorType.multipleCorrect;
                            }
                            return true;
                          }).map((type) {
                            final isSelected = _selectedErrorType == type;
                            return InkWell(
                              onTap: () {
                                setState(() => _selectedErrorType = type);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  border: type != ErrorType.values.last
                                      ? Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)))
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF2563EB) : Colors.grey,
                                          width: isSelected ? 5 : 1.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      type.getLabel(widget.contentType),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected 
                                          ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                          : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Text(
                        'DETAYLI AÇIKLAMA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white54 : Colors.black54,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 4,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Hata hakkında detaylı bilgi verin...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withAlpha(20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: _hasError 
                                ? Colors.redAccent 
                                : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                              width: _hasError ? 1.5 : 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: _hasError ? Colors.redAccent : const Color(0xFF2563EB),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          if (_hasError && val.trim().isNotEmpty) {
                            setState(() {
                              _hasError = false;
                              _errorMessage = null;
                            });
                          }
                        },
                      ),
                      
                      if (_hasError && _errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12, left: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'İptal',
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitReport,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isSubmitting
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'GÖNDERİLİYOR...',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'HATAYI GÖNDER',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
