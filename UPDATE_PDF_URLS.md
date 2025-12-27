# PDF URL Güncelleme Rehberi

Firebase Storage'a yüklediğiniz PDF dosyalarının URL'lerini Firestore'daki topic document'lerine eklemek için bu script'i kullanabilirsiniz.

## Kullanım

### Yöntem 1: Otomatik Güncelleme (Tüm Topic'ler)

Tüm topic'ler için PDF URL'lerini otomatik olarak güncellemek için:

```dart
import 'package:kpss_ags_2026/core/services/update_topic_pdf_urls.dart';

// main.dart veya bir admin sayfasında
final updater = UpdateTopicPdfUrls();
await updater.updateAllTopicPdfUrls();
```

Bu script:
1. Firestore'daki tüm topic'leri alır
2. Firebase Storage'daki PDF dosyalarını tarar
3. Topic ID'lerine göre eşleştirme yapar
4. Firestore'daki topic document'lerine `pdfUrl` field'ını ekler

### Yöntem 2: Manuel Güncelleme (Tekil Topic)

Belirli bir topic için PDF URL'ini manuel olarak güncellemek için:

```dart
final updater = UpdateTopicPdfUrls();
await updater.updateTopicPdfUrl(
  topicId: 'islamiyet_oncesi_turk_tarihi',
  storagePath: 'topics/tarih/islamiyet_oncesi_turk_tarihi.pdf',
);
```

## Storage Yapısı

Script şu yapıları destekler:

1. **Klasörlü Yapı:**
   ```
   topics/
     └── tarih/
         └── islamiyet_oncesi_turk_tarihi.pdf
   ```

2. **Düz Yapı:**
   ```
   topics/
     └── islamiyet_oncesi_turk_tarihi.pdf
   ```

3. **Alternatif Klasör:**
   ```
   pdfs/
     └── islamiyet_oncesi_turk_tarihi.pdf
   ```

## Eşleştirme Mantığı

Script şu sırayla eşleştirme yapar:

1. `topics/{lessonName}/{topicId}.pdf` - Ders adına göre klasör
2. `topics/{topicId}.pdf` - Doğrudan topic ID
3. Topic ID'yi içeren herhangi bir PDF dosyası

## Örnek Kullanım Senaryosu

### Senaryo 1: Tüm PDF'leri Otomatik Eşleştir

```dart
// main.dart içinde veya bir admin sayfasında
void updateAllPdfs() async {
  final updater = UpdateTopicPdfUrls();
  await updater.updateAllTopicPdfUrls();
}
```

### Senaryo 2: Belirli Bir Topic İçin

```dart
void updateSpecificTopic() async {
  final updater = UpdateTopicPdfUrls();
  final success = await updater.updateTopicPdfUrl(
    topicId: 'islamiyet_oncesi_turk_tarihi',
    storagePath: 'topics/tarih/islamiyet_oncesi_turk_tarihi.pdf',
  );
  
  if (success) {
    print('PDF URL başarıyla güncellendi!');
  }
}
```

## Notlar

- PDF dosyalarının Storage'da yüklü olduğundan emin olun
- Topic ID'lerinin Firestore'da doğru olduğundan emin olun
- Script çalıştıktan sonra console'da hangi topic'lerin güncellendiğini görebilirsiniz
- Eşleşmeyen topic'ler için uyarı mesajları gösterilir

## Sorun Giderme

### PDF Bulunamadı Hatası

Eğer bir topic için PDF bulunamazsa:
1. Storage'daki dosya yolunu kontrol edin
2. Topic ID'nin doğru olduğundan emin olun
3. Manuel olarak `updateTopicPdfUrl` metodunu kullanın

### Eşleştirme Çalışmıyor

Eğer otomatik eşleştirme çalışmıyorsa:
- Storage yapınızı kontrol edin
- Topic ID'lerinin dosya adlarında geçtiğinden emin olun
- Manuel güncelleme yöntemini kullanın

