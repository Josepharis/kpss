import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/formatted_text.dart';

class GeographyLocation {
  final String id;
  final String name;
  final String type; // 'lake' or 'plain'
  final String region;
  final String description;
  final double x; // 0.0 - 1.0 (relative position on map)
  final double y; // 0.0 - 1.0 (relative position on map)
  final Color color;

  GeographyLocation({
    required this.id,
    required this.name,
    required this.type,
    required this.region,
    required this.description,
    required this.x,
    required this.y,
    this.color = AppColors.primaryBlue,
  });
}

class GeographySection {
  final String id;
  final String title;
  final String content;
  final List<String>? keyPoints;
  final bool isImportant;

  GeographySection({
    required this.id,
    required this.title,
    required this.content,
    this.keyPoints,
    this.isImportant = false,
  });
}

class GeographyExplanationPage extends StatefulWidget {
  final String topicName;

  const GeographyExplanationPage({super.key, required this.topicName});

  @override
  State<GeographyExplanationPage> createState() =>
      _GeographyExplanationPageState();
}

class _GeographyExplanationPageState extends State<GeographyExplanationPage> {
  int _selectedSectionIndex = 0;
  String? _selectedLocationId;
  final ScrollController _scrollController = ScrollController();

  List<GeographySection> get _sections {
    return [
      GeographySection(
        id: '1',
        title: 'Türkiye\'nin Gölleri',
        content: '''
Türkiye, göl bakımından zengin bir ülkedir. Ülkemizde yaklaşık 200 doğal göl bulunmaktadır. Göller, oluşum şekillerine göre tektonik, volkanik, karstik ve set gölleri olarak sınıflandırılır.

En önemli göllerimiz arasında Van Gölü (en büyük), Tuz Gölü (en tuzlu), Eğirdir Gölü ve Beyşehir Gölü yer almaktadır. Bu göller hem turizm hem de ekonomik açıdan önemlidir.
        ''',
        keyPoints: [
          'Türkiye\'de yaklaşık 200 doğal göl vardır',
          'En büyük göl: Van Gölü (3.713 km²)',
          'En tuzlu göl: Tuz Gölü',
          'Göller oluşum şekillerine göre sınıflandırılır',
        ],
        isImportant: true,
      ),
      GeographySection(
        id: '2',
        title: 'Türkiye\'nin Ovaları',
        content: '''
Türkiye\'de çok sayıda ova bulunmaktadır. Ovalar, tarımsal faaliyetlerin yoğunlaştığı alanlardır. En önemli ovalarımız arasında Çukurova, Konya Ovası, Bafra Ovası ve Çarşamba Ovası yer almaktadır.

Ovalar, akarsuların taşıdığı alüvyonların birikmesiyle oluşmuştur. Bu ovalar, Türkiye\'nin tarımsal üretiminde önemli bir yere sahiptir.
        ''',
        keyPoints: [
          'En büyük ova: Konya Ovası',
          'En verimli ova: Çukurova',
          'Ovalar tarımsal faaliyetlerin merkezidir',
          'Ovalar alüvyon birikimiyle oluşmuştur',
        ],
        isImportant: true,
      ),
      GeographySection(
        id: '3',
        title: 'Bölgesel Dağılım',
        content: '''
Göller ve ovalar Türkiye\'de bölgelere göre farklı dağılım gösterir. İç Anadolu Bölgesi\'nde Tuz Gölü ve Konya Ovası, Akdeniz Bölgesi\'nde Beyşehir Gölü ve Çukurova, Doğu Anadolu\'da Van Gölü öne çıkmaktadır.

Her bölgenin kendine özgü coğrafi özellikleri vardır ve bu özellikler o bölgenin ekonomik faaliyetlerini de etkiler.
        ''',
        keyPoints: [
          'İç Anadolu: Tuz Gölü, Konya Ovası',
          'Akdeniz: Beyşehir Gölü, Çukurova',
          'Doğu Anadolu: Van Gölü',
          'Karadeniz: Bafra, Çarşamba Ovaları',
        ],
      ),
      GeographySection(
        id: '4',
        title: 'Ekonomik Önemi',
        content: '''
Göller ve ovalar Türkiye ekonomisi için çok önemlidir. Ovalar tarımsal üretimin merkezidir. Göller ise balıkçılık, turizm ve enerji üretimi açısından değerlidir.

Özellikle Çukurova ve Konya Ovası, Türkiye\'nin tahıl ambarı olarak bilinir. Van Gölü ise inci kefali balığı ile ünlüdür.
        ''',
        keyPoints: [
          'Ovalar tarımsal üretimin merkezidir',
          'Göller balıkçılık ve turizm için önemlidir',
          'Çukurova ve Konya Ovası tahıl üretiminde öne çıkar',
          'Van Gölü inci kefali ile ünlüdür',
        ],
        isImportant: true,
      ),
    ];
  }

  List<GeographyLocation> get _locations {
    return [
      // Göller - Gerçek koordinatlara göre yerleştirildi
      GeographyLocation(
        id: 'van',
        name: 'Van Gölü',
        type: 'lake',
        region: 'Doğu Anadolu',
        description:
            'Türkiye\'nin en büyük gölü (3.713 km²). Sodalı bir göldür ve inci kefali balığı ile ünlüdür.',
        x: 0.82, // Doğu Anadolu - sağ üst
        y: 0.22,
        color: Colors.blue.shade600,
      ),
      GeographyLocation(
        id: 'tuz',
        name: 'Tuz Gölü',
        type: 'lake',
        region: 'İç Anadolu',
        description:
            'Türkiye\'nin en tuzlu gölü. Tuz üretimi yapılır. Yazın büyük ölçüde kurur.',
        x: 0.48, // İç Anadolu - merkez
        y: 0.42,
        color: Colors.blue.shade400,
      ),
      GeographyLocation(
        id: 'beysehir',
        name: 'Beyşehir Gölü',
        type: 'lake',
        region: 'Akdeniz',
        description:
            'Türkiye\'nin üçüncü büyük gölü. Tatlı su gölüdür ve balıkçılık yapılır.',
        x: 0.38, // Akdeniz - güneybatı
        y: 0.58,
        color: Colors.blue.shade500,
      ),
      GeographyLocation(
        id: 'egirdir',
        name: 'Eğirdir Gölü',
        type: 'lake',
        region: 'Akdeniz',
        description: 'Tatlı su gölü. Balıkçılık ve turizm açısından önemlidir.',
        x: 0.40, // Akdeniz - Beyşehir yakını
        y: 0.55,
        color: Colors.blue.shade500,
      ),
      // Ovalar - Gerçek koordinatlara göre yerleştirildi
      GeographyLocation(
        id: 'cukurova',
        name: 'Çukurova',
        type: 'plain',
        region: 'Akdeniz',
        description:
            'Türkiye\'nin en verimli ovası. Pamuk, turunçgil ve sebze üretiminde öne çıkar.',
        x: 0.52, // Akdeniz - güney, Adana bölgesi
        y: 0.72,
        color: Colors.green.shade600,
      ),
      GeographyLocation(
        id: 'konya',
        name: 'Konya Ovası',
        type: 'plain',
        region: 'İç Anadolu',
        description:
            'Türkiye\'nin en büyük ovası. Tahıl üretiminde önemli bir yere sahiptir.',
        x: 0.42, // İç Anadolu - Konya bölgesi
        y: 0.48,
        color: Colors.green.shade500,
      ),
      GeographyLocation(
        id: 'bafra',
        name: 'Bafra Ovası',
        type: 'plain',
        region: 'Karadeniz',
        description:
            'Kızılırmak\'ın oluşturduğu delta ovası. Tütün ve sebze üretimi yapılır.',
        x: 0.58, // Karadeniz - kuzey orta
        y: 0.18,
        color: Colors.green.shade500,
      ),
      GeographyLocation(
        id: 'carsamba',
        name: 'Çarşamba Ovası',
        type: 'plain',
        region: 'Karadeniz',
        description:
            'Yeşilırmak\'ın oluşturduğu delta ovası. Fındık ve çay üretimi yapılır.',
        x: 0.62, // Karadeniz - kuzey doğu
        y: 0.12,
        color: Colors.green.shade500,
      ),
    ];
  }

  GeographyLocation? get _selectedLocation {
    if (_selectedLocationId == null) return null;
    return _locations.firstWhere(
      (loc) => loc.id == _selectedLocationId,
      orElse: () => _locations.first,
    );
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
                AppColors.gradientGreenStart,
                AppColors.gradientGreenEnd,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gradientGreenStart.withValues(alpha: 0.2),
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
          // Sidebar
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
                      child: _buildContent(isSmallScreen, isTablet),
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
    GeographySection section,
    int index,
    bool isSelected,
    bool isSmallScreen,
  ) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedSectionIndex = index;
          _selectedLocationId = null;
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
              ? AppColors.gradientGreenStart.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected
                  ? AppColors.gradientGreenStart
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
                    ? AppColors.gradientGreenStart
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
              child: Text(
                section.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? AppColors.gradientGreenStart
                      : AppColors.textPrimary,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
              _selectedLocationId = null;
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
                        AppColors.gradientGreenStart,
                        AppColors.gradientGreenEnd,
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
            child: Text(
              '${index + 1}. ${section.title}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(bool isSmallScreen, bool isTablet) {
    final section = _sections[_selectedSectionIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.gradientGreenStart,
                AppColors.gradientGreenEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.gradientGreenStart.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
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
            ],
          ),
        ),
        SizedBox(height: 20),
        // Interactive Map
        if (_selectedSectionIndex == 0 || _selectedSectionIndex == 1)
          _buildInteractiveMap(isSmallScreen, isTablet),
        // Content
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
              FormattedText(
                text: section.content.trim(),
                style: TextStyle(
                  fontSize: isSmallScreen ? 15 : 16,
                  height: 1.7,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
              if (section.keyPoints != null &&
                  section.keyPoints!.isNotEmpty) ...[
                SizedBox(height: 24),
                _buildKeyPointsSection(section.keyPoints!, isSmallScreen),
              ],
            ],
          ),
        ),
        // Selected Location Info
        if (_selectedLocation != null) ...[
          SizedBox(height: 16),
          _buildLocationInfo(_selectedLocation!, isSmallScreen),
        ],
        SizedBox(height: 16),
        // Navigation
        _buildNavigationButtons(isSmallScreen),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildInteractiveMap(bool isSmallScreen, bool isTablet) {
    final mapHeight = (isSmallScreen ? 300.0 : 350.0);
    final mapWidth =
        MediaQuery.of(context).size.width - (isTablet ? 40.0 : 32.0);

    return Container(
      height: mapHeight,
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Map Background - Real Turkey Map Image
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(color: Colors.grey.shade50),
              child: Image.network(
                'https://raw.githubusercontent.com/djaiss/mapsicon/master/all/turkey/turkey-vector.svg',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback: Try alternative map image
                  return Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b4/Flag_map_of_Turkey.svg/800px-Flag_map_of_Turkey.svg.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Final fallback to custom painter
                      return CustomPaint(
                        painter: TurkeyMapPainter(),
                        child: Container(),
                      );
                    },
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                      color: AppColors.gradientGreenStart,
                    ),
                  );
                },
              ),
            ),
            // Location Markers with Labels
            ..._locations
                .where((loc) {
                  if (_selectedSectionIndex == 0) return loc.type == 'lake';
                  if (_selectedSectionIndex == 1) return loc.type == 'plain';
                  return false;
                })
                .map((location) {
                  final isSelected = _selectedLocationId == location.id;
                  final markerX = location.x * mapWidth;
                  final markerY = location.y * mapHeight;

                  return Positioned(
                    left: markerX - (isSelected ? 40 : 30),
                    top: markerY - (isSelected ? 50 : 40),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedLocationId = isSelected ? null : location.id;
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Location Name Label
                          if (isSelected)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              margin: EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: location.color,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: location.color.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                location.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          // Marker
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isSelected ? 36 : 28,
                            height: isSelected ? 36 : 28,
                            decoration: BoxDecoration(
                              color: location.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: location.color.withValues(alpha: 0.6),
                                  blurRadius: isSelected ? 16 : 8,
                                  spreadRadius: isSelected ? 3 : 1,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                location.type == 'lake'
                                    ? Icons.water_drop
                                    : Icons.landscape,
                                color: Colors.white,
                                size: isSelected ? 20 : 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            // Legend
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade500,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Göl',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green.shade500,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Ova',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo(GeographyLocation location, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            location.color.withValues(alpha: 0.1),
            location.color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: location.color.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: location.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  location.type == 'lake' ? Icons.water_drop : Icons.landscape,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      location.region,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 20),
                onPressed: () {
                  setState(() {
                    _selectedLocationId = null;
                  });
                },
                color: AppColors.textSecondary,
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            location.description,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 15,
              height: 1.6,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
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
                color: AppColors.gradientGreenStart.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.lightbulb_rounded,
                color: AppColors.gradientGreenStart,
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
        ...keyPoints.map(
          (point) => Padding(
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
                    color: AppColors.gradientGreenStart,
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
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(bool isSmallScreen) {
    final canGoPrevious = _selectedSectionIndex > 0;
    final canGoNext = _selectedSectionIndex < _sections.length - 1;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: canGoPrevious
                ? () {
                    setState(() {
                      _selectedSectionIndex--;
                      _selectedLocationId = null;
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
                color: canGoPrevious
                    ? AppColors.backgroundWhite
                    : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: canGoPrevious
                      ? AppColors.gradientGreenStart
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
                        ? AppColors.gradientGreenStart
                        : AppColors.textSecondary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Önceki',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: canGoPrevious
                          ? AppColors.gradientGreenStart
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: canGoNext
                ? () {
                    setState(() {
                      _selectedSectionIndex++;
                      _selectedLocationId = null;
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
                          AppColors.gradientGreenStart,
                          AppColors.gradientGreenEnd,
                        ],
                      )
                    : null,
                color: canGoNext ? null : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                boxShadow: canGoNext
                    ? [
                        BoxShadow(
                          color: AppColors.gradientGreenStart.withValues(
                            alpha: 0.25,
                          ),
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

// Custom Painter for Turkey Map (Realistic Shape)
class TurkeyMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bgPaint = Paint()
      ..color = Colors.grey.shade50
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Turkey shape - more realistic outline
    final paint = Paint()
      ..color = Colors.green.shade100
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.green.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path();

    // Turkey's approximate shape (simplified but recognizable)
    // Starting from top-left (Thrace region)
    path.moveTo(size.width * 0.15, size.height * 0.08); // Thrace top

    // Top border (Thrace to Black Sea)
    path.lineTo(size.width * 0.25, size.height * 0.05);
    path.lineTo(size.width * 0.40, size.height * 0.03);
    path.lineTo(size.width * 0.55, size.height * 0.04);
    path.lineTo(size.width * 0.70, size.height * 0.06);
    path.lineTo(size.width * 0.85, size.height * 0.08);

    // Right border (Eastern border)
    path.lineTo(size.width * 0.92, size.height * 0.15);
    path.lineTo(size.width * 0.95, size.height * 0.30);
    path.lineTo(size.width * 0.93, size.height * 0.50);
    path.lineTo(size.width * 0.90, size.height * 0.70);
    path.lineTo(size.width * 0.88, size.height * 0.85);

    // Bottom border (Syrian border)
    path.lineTo(size.width * 0.75, size.height * 0.92);
    path.lineTo(size.width * 0.60, size.height * 0.95);
    path.lineTo(size.width * 0.45, size.height * 0.94);
    path.lineTo(size.width * 0.30, size.height * 0.90);

    // Left border (Aegean and Mediterranean)
    path.lineTo(size.width * 0.20, size.height * 0.85);
    path.lineTo(size.width * 0.12, size.height * 0.75);
    path.lineTo(size.width * 0.10, size.height * 0.60);
    path.lineTo(size.width * 0.12, size.height * 0.40);
    path.lineTo(size.width * 0.13, size.height * 0.20);

    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);

    // Add regional labels (subtle)
    final textPaint = TextPainter(
      text: TextSpan(
        text: 'TÜRKİYE',
        style: TextStyle(
          color: Colors.green.shade300,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPaint.layout();
    textPaint.paint(
      canvas,
      Offset(
        size.width * 0.5 - textPaint.width / 2,
        size.height * 0.5 - textPaint.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
