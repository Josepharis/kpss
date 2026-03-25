import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/error_report.dart';
import '../../../core/services/error_report_service.dart';
import '../../../core/widgets/premium_snackbar.dart';

class AdminErrorReportsPage extends StatefulWidget {
  const AdminErrorReportsPage({super.key});

  @override
  State<AdminErrorReportsPage> createState() => _AdminErrorReportsPageState();
}

class _AdminErrorReportsPageState extends State<AdminErrorReportsPage> {
  final ErrorReportService _reportService = ErrorReportService();
  bool _showResolved = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text(
          'HATA BİLDİRİMLERİ',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16),
        ),
        actions: [
          Row(
            children: [
              Text(
                'Çözülenleri Göster',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
              ),
              Switch(
                value: _showResolved,
                onChanged: (val) => setState(() => _showResolved = val),
                activeColor: const Color(0xFF2563EB),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<ErrorReport>>(
        stream: _reportService.getAllReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
          }

          final reports = snapshot.data ?? [];
          final filteredReports = reports.where((r) => _showResolved ? true : !r.isResolved).toList();

          if (filteredReports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 64,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pırıl pırıl! Bildirim bulunamadı.',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredReports.length,
            itemBuilder: (context, index) {
              final report = filteredReports[index];
              return _buildReportCard(context, report, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, ErrorReport report, bool isDark) {
    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(report.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: report.isResolved 
            ? const Color(0xFF10B981).withOpacity(0.3)
            : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showReportDetails(context, report),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (report.contentType == 'flash_card' ? Colors.orange : Colors.blue).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        report.contentType == 'flash_card' ? 'BİLGİ KARTI' : 'SORU',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: report.contentType == 'flash_card' ? Colors.orange : Colors.blue,
                        ),
                      ),
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  report.errorType,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  report.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: isDark ? Colors.white38 : Colors.black38),
                    const SizedBox(width: 4),
                    Text(
                      report.userName,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                    ),
                    const Spacer(),
                    if (report.isResolved)
                      const Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text(
                            'Çözüldü',
                            style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReportDetails(BuildContext context, ErrorReport report) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.errorType,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${report.userName} tarafından bildirildi',
                        style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (report.isResolved)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'BAŞARIYLA ÇÖZÜLDÜ',
                      style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 10),
                    ),
                  ),
              ],
            ),
            const Divider(height: 32),
            const Text('İÇERİK ÖNİZLEME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Colors.blue)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                report.contentPreview ?? 'Önizleme yok',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 24),
            const Text('HATA DETAYI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Colors.redAccent)),
            const SizedBox(height: 8),
            Text(report.description, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 24),
            const Text('KONU BİLGİSİ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('${report.topicName} (${report.lessonId})'),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final success = await _reportService.deleteReport(report.id!);
                      if (success && context.mounted) {
                        Navigator.pop(context);
                        PremiumSnackBar.show(context, message: 'Bildirim silindi.', type: SnackBarType.success);
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Sil'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final success = await _reportService.resolveReport(report.id!, !report.isResolved);
                      if (success && context.mounted) {
                        Navigator.pop(context);
                        PremiumSnackBar.show(
                          context, 
                          message: report.isResolved ? 'Bildirim çözülmedi olarak işaretlendi.' : 'Bildirim çözüldü olarak işaretlendi.', 
                          type: SnackBarType.success
                        );
                      }
                    },
                    icon: Icon(report.isResolved ? Icons.undo : Icons.check),
                    label: Text(report.isResolved ? 'Geri Al' : 'Çözüldü'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: report.isResolved ? Colors.grey : const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
