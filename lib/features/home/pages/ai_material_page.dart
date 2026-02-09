import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ai_material.dart';
import '../../../core/services/ai_content_service.dart';

class AiMaterialPage extends StatefulWidget {
  final String topicId;
  final String topicName;

  const AiMaterialPage({
    super.key,
    required this.topicId,
    required this.topicName,
  });

  @override
  State<AiMaterialPage> createState() => _AiMaterialPageState();
}

class _AiMaterialPageState extends State<AiMaterialPage> {
  bool _loading = true;
  AiMaterial? _material;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final material = await AiContentService.instance.getMaterial(widget.topicId);
    if (!mounted) return;
    setState(() {
      _material = material;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    await AiContentService.instance.clearMaterial(widget.topicId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF9800),
        elevation: 0,
        title: Text(
          'AI Konu Metni • ${widget.topicName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_material != null)
            IconButton(
              tooltip: 'Temizle',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('AI Konu Metnini Sil'),
                    content: const Text('Bu konuya ait kaydedilmiş AI metni silinsin mi?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Vazgeç'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sil'),
                      ),
                    ],
                  ),
                );
                if (ok == true) await _clear();
              },
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _material == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.picture_as_pdf_rounded, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Bu konu için AI konu metni yok',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : _buildContent(isDark),
    );
  }

  Widget _buildContent(bool isDark) {
    final m = _material!;
    final dt = DateTime.fromMillisecondsSinceEpoch(m.createdAtMillis);
    final formatted = DateFormat('dd.MM.yyyy HH:mm').format(dt);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFF9800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      m.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Oluşturulma: $formatted',
                style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.18),
            ),
          ),
          child: SelectableText(
            m.content,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimary,
              height: 1.5,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

