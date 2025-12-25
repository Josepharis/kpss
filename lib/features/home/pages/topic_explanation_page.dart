import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class TopicExplanationSection {
  final String id;
  final String title;
  final String content;
  final List<String>? keyPoints;
  final List<String>? examples;
  final bool isImportant;

  TopicExplanationSection({
    required this.id,
    required this.title,
    required this.content,
    this.keyPoints,
    this.examples,
    this.isImportant = false,
  });
}

class TopicExplanationPage extends StatefulWidget {
  final String topicName;

  const TopicExplanationPage({
    super.key,
    required this.topicName,
  });

  @override
  State<TopicExplanationPage> createState() => _TopicExplanationPageState();
}

class _TopicExplanationPageState extends State<TopicExplanationPage> {
  int _selectedSectionIndex = 0;
  final ScrollController _scrollController = ScrollController();

  List<TopicExplanationSection> get _sections {
    // Gerçek KPSS konusu örneği: "de/da Bağlacı ve Ekleri"
    return [
      TopicExplanationSection(
        id: '1',
        title: 'Giriş: "de/da" Kullanımı',
        content: '''
"de/da" Türkçede hem bağlaç hem de ek olarak kullanılır. Bu iki kullanımın ayırt edilmesi KPSS sınavında sıkça sorulan bir konudur.

Bağlaç olan "de/da" ayrı yazılır ve cümleye "dahi, bile, ayrıca" anlamı katar. Ek olan "-de/-da" ise bitişik yazılır ve bulunma durumu (lokatif) eki görevi görür.
        ''',
        keyPoints: [
          'Bağlaç "de/da" → Ayrı yazılır',
          'Ek "-de/-da" → Bitişik yazılır',
          'Bağlaç cümleden çıkarılırsa anlam bozulmaz',
        ],
        isImportant: true,
      ),
      TopicExplanationSection(
        id: '2',
        title: 'Bağlaç Olan "de/da"',
        content: '''
Bağlaç olan "de/da" her zaman ayrı yazılır. Cümleden çıkarıldığında cümlenin anlamı bozulmaz, sadece "dahi, bile, ayrıca" anlamı kaybolur.

Bağlaç "de/da"nın önüne gelen kelime ünlü uyumuna göre "de" veya "da" şeklinde yazılır. Ünsüz uyumuna uymaz, yani sert ünsüzden sonra "te/ta" olmaz.
        ''',
        keyPoints: [
          'Her zaman ayrı yazılır',
          'Cümleden çıkarılabilir',
          'Ünlü uyumuna uyar (de/da)',
          'Ünsüz uyumuna uymaz (te/ta olmaz)',
        ],
        examples: [
          'Doğru: "O da buraya gelecek." (Bağlaç - ayrı yazılır)',
          'Doğru: "Sen de mi gideceksin?" (Bağlaç - ayrı yazılır)',
          'Yanlış: "Bende bir şeyler var." → Doğrusu: "Bende de bir şeyler var."',
        ],
      ),
      TopicExplanationSection(
        id: '3',
        title: 'Ek Olan "-de/-da"',
        content: '''
Ek olan "-de/-da" bulunma durumu (lokatif) ekidir ve her zaman bitişik yazılır. Cümleden çıkarıldığında cümlenin anlamı bozulur.

Bu ek, kelimeye "nerede, nerede bulunduğu" anlamı katar. Ünlü ve ünsüz uyumlarına uyar, yani sert ünsüzden sonra "-te/-ta" şeklinde yazılır.
        ''',
        keyPoints: [
          'Her zaman bitişik yazılır',
          'Cümleden çıkarılamaz',
          'Ünlü ve ünsüz uyumlarına uyar',
          'Bulunma durumu eki görevi görür',
        ],
        examples: [
          'Doğru: "Evde kimse yok." (Ek - bitişik yazılır)',
          'Doğru: "Okulda ders var." (Ek - bitişik yazılır)',
          'Doğru: "İstanbul\'da yaşıyorum." (Ek - bitişik yazılır)',
        ],
        isImportant: true,
      ),
      TopicExplanationSection(
        id: '4',
        title: 'Ayırt Etme Yöntemleri',
        content: '''
"de/da"nın bağlaç mı ek mi olduğunu anlamak için pratik yöntemler:

1. Cümleden çıkarma testi: Cümleden "de/da"yı çıkarın. Anlam bozulmuyorsa bağlaç, bozuluyorsa ektir.

2. Yerine kelime koyma: "de/da" yerine "dahi, bile" kelimelerini koyabilirseniz bağlaçtır.

3. Yazım kontrolü: Ayrı yazılabiliyorsa bağlaç, bitişik yazılması gerekiyorsa ektir.
        ''',
        keyPoints: [
          'Cümleden çıkarma testi yapın',
          '"Dahi, bile" ile değiştirin',
          'Yazım şekline dikkat edin',
        ],
        examples: [
          'Test: "O da geldi." → "O geldi." (Anlam bozulmadı → Bağlaç)',
          'Test: "Evde kaldı." → "Ev kaldı." (Anlam bozuldu → Ek)',
          'Değiştirme: "O da geldi." → "O dahi geldi." (Mümkün → Bağlaç)',
        ],
        isImportant: true,
      ),
      TopicExplanationSection(
        id: '5',
        title: 'Sık Yapılan Hatalar',
        content: '''
KPSS sınavında en çok yapılan hatalar:

1. "Bende" yerine "Bende de" yazılması gereken durumlar
2. "Orada" gibi eklerin bağlaç sanılması
3. "de/da"nın her durumda ayrı yazılması gerektiğini düşünmek

Bu hatalardan kaçınmak için her cümleyi test etmek gerekir.
        ''',
        keyPoints: [
          '"Bende" hatası en yaygın hatadır',
          'Ek ve bağlaç karıştırılmamalı',
          'Her cümleyi test edin',
        ],
        examples: [
          'Yanlış: "Bende bir şeyler var." → Doğru: "Bende de bir şeyler var."',
          'Yanlış: "Orada da çalışıyor." → Doğru: "Orada çalışıyor." (Ek zaten var)',
          'Yanlış: "Ev de temiz." → Doğru: "Evde temiz." (Ek olmalı)',
        ],
      ),
      TopicExplanationSection(
        id: '6',
        title: 'Sınav İpuçları',
        content: '''
KPSS sınavında bu konudan soru çözerken:

1. Önce cümleden çıkarma testi yapın
2. "Dahi, bile" ile değiştirme testi uygulayın
3. Yazım hatası olan seçeneği bulun
4. En yaygın hata "bende" hatasıdır, önce ona bakın

Bu ipuçları sayesinde soruları hızlı ve doğru çözebilirsiniz.
        ''',
        keyPoints: [
          'Her zaman test yöntemini kullanın',
          '"Bende" hatasına dikkat edin',
          'Yazım kurallarını ezberleyin',
        ],
        isImportant: true,
      ),
    ];
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

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
                          widget.topicName,
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
                          'Bölüm ${_selectedSectionIndex + 1}/${_sections.length}',
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
      body: Row(
        children: [
          // Compact Sidebar
          if (isTablet)
            Container(
              width: 240,
              decoration: BoxDecoration(
                color: AppColors.backgroundWhite,
                border: Border(
                  right: BorderSide(
                    color: AppColors.textSecondary.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: _buildSidebar(isSmallScreen),
            ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Mobile Section Selector
                if (!isTablet)
                  Container(
                    height: 56,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundWhite,
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.textSecondary.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: _buildMobileSectionSelector(isSmallScreen),
                  ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isTablet ? 700 : double.infinity,
                      ),
                      child: _buildContent(isSmallScreen),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isSmallScreen) {
    return ListView(
      padding: EdgeInsets.symmetric(vertical: 12),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'İçindekiler',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Divider(height: 1),
        ...List.generate(_sections.length, (index) {
          final section = _sections[index];
          final isSelected = _selectedSectionIndex == index;
          return _buildSectionItem(section, index, isSelected, isSmallScreen);
        }),
      ],
    );
  }

  Widget _buildSectionItem(
    TopicExplanationSection section,
    int index,
    bool isSelected,
    bool isSmallScreen,
  ) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedSectionIndex = index;
        });
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF9800).withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected
                  ? const Color(0xFFFF9800)
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFFFF9800)
                    : AppColors.textSecondary.withValues(alpha: 0.3),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFFFF9800)
                          : AppColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (section.isImportant) ...[
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Önemli',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSectionSelector(bool isSmallScreen) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _sections.length,
      itemBuilder: (context, index) {
        final section = _sections[index];
        final isSelected = _selectedSectionIndex == index;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedSectionIndex = index;
            });
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          },
          child: Container(
            margin: EdgeInsets.only(right: 8),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        const Color(0xFFFF9800),
                        const Color(0xFFFF6B35),
                      ],
                    )
                  : null,
              color: isSelected ? null : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : AppColors.textSecondary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (section.isImportant)
                  Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: isSelected ? Colors.white : Colors.red.shade700,
                  ),
                if (section.isImportant) SizedBox(width: 6),
                Text(
                  '${index + 1}. ${section.title}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(bool isSmallScreen) {
    final section = _sections[_selectedSectionIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact Section Header
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF9800),
                const Color(0xFFFF6B35),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            section.title,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 18 : 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        if (section.isImportant)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Önemli',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
            ],
          ),
        ),
        SizedBox(height: 20),
        // Main Content - Compact
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.textSecondary.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content Text
              Text(
                section.content.trim(),
                style: TextStyle(
                  fontSize: isSmallScreen ? 15 : 16,
                  height: 1.7,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
              // Key Points
              if (section.keyPoints != null && section.keyPoints!.isNotEmpty) ...[
                SizedBox(height: 24),
                _buildKeyPointsSection(section.keyPoints!, isSmallScreen),
              ],
              // Examples
              if (section.examples != null && section.examples!.isNotEmpty) ...[
                SizedBox(height: 24),
                _buildExamplesSection(section.examples!, isSmallScreen),
              ],
            ],
          ),
        ),
        SizedBox(height: 16),
        // Compact Navigation
        _buildNavigationButtons(isSmallScreen),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildKeyPointsSection(List<String> keyPoints, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.lightbulb_rounded,
                color: const Color(0xFFFF9800),
                size: 18,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Önemli Noktalar',
              style: TextStyle(
                fontSize: isSmallScreen ? 15 : 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 14),
        ...keyPoints.map((point) => Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 6),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF9800),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 15,
                        height: 1.6,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildExamplesSection(List<String> examples, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primaryBlue,
                size: 18,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Örnekler',
              style: TextStyle(
                fontSize: isSmallScreen ? 15 : 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 14),
        ...examples.asMap().entries.map((entry) {
          final index = entry.key;
          final example = entry.value;
          final isCorrect = example.startsWith('Doğru');
          final isWrong = example.startsWith('Yanlış');
          return Container(
            margin: EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isCorrect
                  ? Colors.green.withValues(alpha: 0.05)
                  : isWrong
                      ? Colors.red.withValues(alpha: 0.05)
                      : AppColors.primaryBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCorrect
                    ? Colors.green.withValues(alpha: 0.3)
                    : isWrong
                        ? Colors.red.withValues(alpha: 0.3)
                        : AppColors.primaryBlue.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green
                        : isWrong
                            ? Colors.red
                            : AppColors.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    example,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 15,
                      height: 1.6,
                      color: AppColors.textPrimary,
                      fontWeight: isCorrect || isWrong ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNavigationButtons(bool isSmallScreen) {
    final canGoPrevious = _selectedSectionIndex > 0;
    final canGoNext = _selectedSectionIndex < _sections.length - 1;

    return Row(
      children: [
        // Previous Button
        Expanded(
          child: GestureDetector(
            onTap: canGoPrevious
                ? () {
                    setState(() {
                      _selectedSectionIndex--;
                    });
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                : null,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: canGoPrevious ? AppColors.backgroundWhite : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: canGoPrevious
                      ? const Color(0xFFFF9800)
                      : AppColors.textSecondary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_back_ios_rounded,
                    size: 16,
                    color: canGoPrevious
                        ? const Color(0xFFFF9800)
                        : AppColors.textSecondary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Önceki',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: canGoPrevious
                          ? const Color(0xFFFF9800)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        // Next Button
        Expanded(
          child: GestureDetector(
            onTap: canGoNext
                ? () {
                    setState(() {
                      _selectedSectionIndex++;
                    });
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                : null,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: canGoNext
                    ? LinearGradient(
                        colors: [
                          const Color(0xFFFF9800),
                          const Color(0xFFFF6B35),
                        ],
                      )
                    : null,
                color: canGoNext ? null : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                boxShadow: canGoNext
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF9800).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sonraki',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: canGoNext ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: canGoNext ? Colors.white : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
