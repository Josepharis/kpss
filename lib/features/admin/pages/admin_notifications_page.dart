import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  
  String _targetSegment = 'topic'; // topic, everyone, active, inactive
  bool _isLoading = false;
  int _targetCount = 0;

  final List<Map<String, String>> _templates = [
    {
      'title': '📚 Günlük Hedefini Tamamla!',
      'body': 'KPSS yolunda bugün 50 soru çözmeye ne dersin? Haydi başlayalım!',
    },
    {
      'title': '🔥 Yeni Deneme Sınavı!',
      'body': 'Güncel AGS formatına uygun yeni sorular eklendi. Hemen çöz!',
    },
    {
      'title': '⏰ Unutma: Azim Başarı Getirir',
      'body': 'Biraz mola verdiysen şimdi tekrar derse dönme vakti. Başarılar!',
    },
    {
      'title': '💡 Önemli Bilgi Notu',
      'body': 'Güncel bilgiler kısmını bugün kontrol ettin mi? Yeni veriler var.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _updateTargetCount();
  }

  Future<void> _updateTargetCount() async {
    if (_targetSegment == 'topic') {
      setState(() => _targetCount = 0); // Topic doesn't need exact count for display
      return;
    }
    setState(() => _isLoading = true);
    try {
      final usersCollection = _firestore.collection('users');
      Query query = usersCollection;

      if (_targetSegment == 'active') {
        // Active: logged in last 7 days
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        query = query.where('lastLogin', isGreaterThan: Timestamp.fromDate(sevenDaysAgo));
      } else if (_targetSegment == 'inactive') {
        // Inactive: logged in more than 7 days ago
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        query = query.where('lastLogin', isLessThan: Timestamp.fromDate(sevenDaysAgo));
      }

      final countRes = await query.count().get();
      if (mounted) {
        setState(() {
          _targetCount = countRes.count ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error counting users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyTemplate(Map<String, String> template) {
    setState(() {
      _titleController.text = template['title']!;
      _bodyController.text = template['body']!;
    });
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen başlık ve mesaj içeriği giriniz.')),
      );
      return;
    }

    // Confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bildirim Gönder'),
        content: Text(_targetSegment == 'topic' 
          ? 'Tüm kayıtlı cihazlara anlık (Topic) bildirim gönderilecek. Onaylıyor musunuz?'
          : '$_targetCount kullanıcıya (Token bazlı) bildirim gönderilecek. Onaylıyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Evet, Gönder')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // Create a notification record in Firestore
      // A Cloud Function should listen to this collection to trigger FCM
      await _firestore.collection('notifications').add({
        'title': _titleController.text,
        'body': _bodyController.text,
        'target': _targetSegment,
        'topic': _targetSegment == 'topic' ? 'general' : null,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'targetCount': _targetCount,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildirim sıraya alındı! Cloud Function tetiklendiğinde gönderilecek.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            ),
          ),
        ),
        elevation: 0,
        title: const Text(
          'Bildirim Gönder',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Kime Gönderilecek?'),
            const SizedBox(height: 10),
            _buildSegmentSelector(isDark),
            const SizedBox(height: 30),
            _buildSectionTitle('Hazır Kalıplar'),
            const SizedBox(height: 10),
            _buildTemplatesList(isDark),
            const SizedBox(height: 30),
            _buildSectionTitle('Bildirim İçeriği'),
            const SizedBox(height: 10),
            _buildContentForm(isDark),
            const SizedBox(height: 40),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildSegmentSelector(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildSegmentOption(
            'topic',
            'Anlık Genel Bildirim (En Hızlı)',
            'Tüm kullanıcılara anında ulaşır (Ücretsiz)',
            Icons.flash_on_rounded,
            Colors.orange,
          ),
          const Divider(height: 1),
          _buildSegmentOption(
            'everyone',
            'Tüm Kullanıcılar',
            'Tek tek jeton bazlı gönderilir',
            Icons.groups_rounded,
            Colors.blue,
          ),
          const Divider(height: 1),
          _buildSegmentOption(
            'active',
            'Aktif Kullanıcılar',
            'Son 1 hafta içinde giriş yapanlar',
            Icons.bolt_rounded,
            Colors.amber,
          ),
          const Divider(height: 1),
          _buildSegmentOption(
            'inactive',
            'Pasif Kullanıcılar',
            '1 haftadan uzun süredir girmeyenler',
            Icons.snooze_rounded,
            Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentOption(String value, String title, String subtitle, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        setState(() => _targetSegment = value);
        _updateTargetCount();
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _targetSegment,
              onChanged: (v) {
                setState(() => _targetSegment = v!);
                _updateTargetCount();
              },
              activeColor: const Color(0xFF4F46E5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesList(bool isDark) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _templates.length,
        itemBuilder: (context, index) {
          final template = _templates[index];
          return Container(
            width: 180,
            margin: const EdgeInsets.only(right: 12),
            child: Material(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => _applyTemplate(template),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template['title']!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        template['body']!,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContentForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Bildirim Başlığı',
              hintText: 'Örn: Bugün ne durumdasın?',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _bodyController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Mesaj İçeriği',
              hintText: 'Örn: Çalışmaya devam et!',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _sendNotification,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded),
                  const SizedBox(width: 10),
                  Text(
                    '$_targetCount Kişiye Gönder',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }
}
