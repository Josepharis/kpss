import 'package:flutter/material.dart';
import '../../../core/models/test_question.dart';
import '../../../core/services/questions_service.dart';

class AdminEditQuestionPage extends StatefulWidget {
  final String topicId;
  final String lessonId;
  final TestQuestion? question;

  const AdminEditQuestionPage({
    super.key,
    required this.topicId,
    required this.lessonId,
    this.question,
  });

  @override
  State<AdminEditQuestionPage> createState() => _AdminEditQuestionPageState();
}

class _AdminEditQuestionPageState extends State<AdminEditQuestionPage> {
  final QuestionsService _questionsService = QuestionsService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _questionController;
  late TextEditingController _explanationController;
  late List<TextEditingController> _optionControllers;
  late int _correctAnswerIndex;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.question?.question ?? '');
    _explanationController = TextEditingController(text: widget.question?.explanation ?? '');
    
    _optionControllers = List.generate(
      5,
      (index) {
        final text = (widget.question != null && index < widget.question!.options.length)
            ? widget.question!.options[index]
            : '';
        return TextEditingController(text: text);
      },
    );
    
    _correctAnswerIndex = widget.question?.correctAnswerIndex ?? 0;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final options = _optionControllers.map((c) => c.text).toList();
    
    final newQuestion = TestQuestion(
      id: widget.question?.id ?? '',
      question: _questionController.text,
      options: options,
      correctAnswerIndex: _correctAnswerIndex,
      explanation: _explanationController.text,
      timeLimitSeconds: widget.question?.timeLimitSeconds ?? 60,
      topicId: widget.topicId,
      lessonId: widget.lessonId,
      order: widget.question?.order ?? 0,
    );

    bool success;
    if (widget.question == null) {
      success = await _questionsService.addSingleQuestion(newQuestion);
    } else {
      success = await _questionsService.updateQuestion(newQuestion);
    }

    setState(() => _isSaving = false);

    if (success && mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.question == null ? 'Soru başarıyla eklendi' : 'Soru başarıyla güncellendi'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bir hata oluştu. Lütfen tekrar deneyin.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        title: Text(
          widget.question == null ? 'Yeni Soru' : 'Soruyu Düzenle',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModernCard(
                title: 'Soru İçeriği',
                icon: Icons.quiz_rounded,
                isDark: isDark,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _questionController,
                      maxLines: 5,
                      hint: 'Soru metnini detaylıca yazın...',
                      icon: Icons.edit_note_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildModernCard(
                title: 'Seçenekler',
                icon: Icons.checklist_rounded,
                isDark: isDark,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 15),
                      child: Text(
                        'Doğru yanıtı yanındaki butondan işaretlemeyi unutmayın.',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ),
                    ...List.generate(5, (index) => _buildOptionRow(index, isDark)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildModernCard(
                title: 'Çözüm ve Açıklama',
                icon: Icons.lightbulb_outline_rounded,
                isDark: isDark,
                child: _buildTextField(
                  controller: _explanationController,
                  maxLines: 4,
                  hint: 'Sorunun çözümünü ve mantığını açıklayın...',
                  icon: Icons.description_rounded,
                ),
              ),
              const SizedBox(height: 35),
              _buildSubmitButton(isDark),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernCard({
    required String title,
    required IconData icon,
    required Widget child,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    int maxLines = 1,
    required String hint,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, height: 1.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Bu alan zorunludur' : null,
    );
  }

  Widget _buildOptionRow(int index, bool isDark) {
    final optionChar = String.fromCharCode(65 + index);
    final isSelected = _correctAnswerIndex == index;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => setState(() => _correctAnswerIndex = index),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Center(
                child: isSelected 
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                  : Text(
                      optionChar,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _optionControllers[index],
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Seçenek $optionChar',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Seçenek boş olamaz' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSaving ? null : _save,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.question == null ? Icons.add_task_rounded : Icons.save_rounded, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        widget.question == null ? 'Soruyu Sisteme Ekle' : 'Değişiklikleri Kaydet',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
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
