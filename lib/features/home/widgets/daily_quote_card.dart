import 'package:flutter/material.dart';
import 'dart:ui';

class DailyQuoteCard extends StatelessWidget {
  final String quote;
  final bool isSmallScreen;
  final bool isCompactLayout;

  const DailyQuoteCard({
    super.key,
    required this.quote,
    this.isSmallScreen = false,
    this.isCompactLayout = false,
  });

  String _getQuoteOfDay() {
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year, 1, 1))
        .inDays;
    final quotes = [
      'Zorluklar, başarının değerini artıran süslerdir. Vazgeçme, çünkü en karanlık an, güneşin doğuşuna en yakın andır.',
      'Bugün döktüğün ter, yarın kazanacağın zaferin müjdecisidir. Sabret, emeklerin asla boşa gitmeyecek.',
      'Başarı, sadece yola çıkanların ve yoldan dönmeyenlerin ödülüdür. Sen o ödüle her gün biraz daha yaklaşıyorsun.',
      'Kendi geleceğini yazmak senin elinde. Kalemin ise bugün çözdüğün sorular ve gösterdiğin azimdir.',
      'Başkalarının "yapamazsın" dediği her şey, senin "neler yapabileceğini" kanıtlaman için birer fırsattır.',
      'Büyük başarılar, küçük başlangıçların ve sarsılmaz bir kararlılığın sonucudur. Bugün attığın o küçük adım, yarın devleşecek.',
      'Sınav sadece bilgini değil, karakterini ve dayanıklılığını da ölçer. Dik dur, sen bu yoldan galip çıkacaksın.',
      'Yorulabilirsin, ama asla vazgeçme. Unutma; zirveye çıkan yollar her zaman diktir.',
      'Bir gün geriye dönüp baktığında, iyi ki "pes etmemişim" diyeceksin. O gün bugün, devam et!',
      'Korkuların seni durdurmasın, hayallerin seni yönlendirsin. Sen sandığından çok daha güçlüsün.',
      'Dünya "vazgeç" dediğinde, umut fısıldar: "Bir kez daha dene!" Sen o sese kulak ver.',
      'Okuduğun her sayfa, çözdüğün her problem, seni hayallerindeki o kapıya bir adım daha yaklaştırıyor.',
      'Başarı bir varış noktası değil, bir yolculuktur. Bu yolculukta her gün yeni bir zafer kazanıyorsun.',
      'Zeka seni bir yere kadar götürür ama disiplin seni bitiş çizgisine ulaştırır. Disiplinli ol, kazanan sen ol.',
      'İstikbalin bugünkü uykusuz gecelerinde ve yorgun gözlerinde saklı. Geleceğin için bugün parlamaya devam et.',
      'Yapabileceğine inanmak, başarmanın yarısıdır. Diğer yarısı ise o inançla ter dökmektir.',
      'Engeller seni durdurmak için değil, ne kadar kararlı olduğunu test etmek içindir. Geç onları!',
      'Gelecek, bugünden ona hazırlananlara aittir. Sen geleceğin mimarısın.',
      'Her sabah uyandığında iki seçeneğin var: Ya hayallerinle uyumaya devam edersin ya da uyanıp onları kovalarsın.',
      'Başarı konfor alanının dışındadır. Sınırlarını zorla, mucizelerin orada gerçekleştiğini göreceksin.',
      'Dün geçti, yarın henüz gelmedi. Elinde sadece bugün var. Bugünün hakkını ver!',
      'Kaybetmekten korkma, denemekten vazgeçmekten kork. En büyük hata, hata yapma korkusuyla hiç başlamamaktır.',
      'Şampiyonlar, antrenman yaparken değil; kimse izlemiyorken çalıştıkları anlarda şampiyon olurlar.',
      'Zaman en kıymetli hazinen. Onu şikayet ederek değil, hayallerine giden yolu inşa ederek harca.',
      'Sabır ağrılıdır ama meyvesi tatlıdır. Hasat zamanı geldiğinde tüm yorgunluğun son bulacak.',
      'Senin tek rakibin dünkü sensin. Her gün bir önceki günden daha iyi olmaya odaklan.',
      'İrade, "yapamam" dediğin anda "bir kez daha" diyebilme gücüdür.',
      'Zor yollar genellikle güzel yerlere çıkar. Bu zorlukların seni nereye taşıyacağını hayal et.',
      'Hayallerin, yorgunluğundan daha büyük olsun. Ancak o zaman hedefine ulaşırsın.',
      'Başarı tesadüf değildir; çok çalışma, kararlılık, öğrenme ve en önemlisi yaptığın işi sevme işidir.',
      'Bugün yaptığın fedakarlıklar, yarın yaşayacağın özgürlüğün bedelidir.',
    ];
    return quotes[dayOfYear % quotes.length];
  }

  @override
  Widget build(BuildContext context) {
    final quoteText = quote.isNotEmpty ? quote : _getQuoteOfDay();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF6366F1))
                .withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withOpacity(0.65)
                  : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFF6366F1).withOpacity(0.12),
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.format_quote_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GÜNÜN İLHAMI',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? const Color(0xFF818CF8)
                                : const Color(0xFF4F46E5),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          quoteText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white.withOpacity(0.9)
                                : const Color(0xFF1E293B),
                            height: 1.2,
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
    );
  }
}
