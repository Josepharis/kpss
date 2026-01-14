# Yeni Dersler Yükleme Rehberi

Bu rehber, yeni eklenen dersleri Firebase'e yüklemek için hazırlanmıştır.

## 📋 Eklenen Dersler

### Genel Kültür
1. **Tarih** ✅ (Zaten mevcut)
2. **Vatandaşlık** ✅ (Zaten mevcut)
3. **Coğrafya** 🆕 (Yeni)
4. **Güncel Bilgiler** 🆕 (Yeni)

### Genel Yetenek
1. **Türkçe** 🆕 (Yeni) - *Konu anlatımı ve video kartı yok*
2. **Matematik** 🆕 (Yeni) - *Sadece test ve not kartı var*

## 🚀 Firebase'e Yükleme

### Otomatik Yükleme (Önerilen)

`lib/main.dart` dosyasına geçici olarak şu kodu ekleyin:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'core/services/upload_data_script.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Yeni dersleri yükle (sadece bir kez çalıştırın!)
  await uploadAllNewLessonsData();
  
  runApp(const MyApp());
}
```

**ÖNEMLİ:** Dersler yüklendikten sonra bu kodu kaldırın!

### Alternatif: Sadece Tek Bir Ders Yükleme

```dart
// Coğrafya için
final uploader = FirebaseDataUploader();
await uploader.uploadCografyaLessonData();

// Güncel Bilgiler için
await uploader.uploadGuncelBilgilerLessonData();

// Türkçe için
await uploader.uploadTurkceLessonData();

// Matematik için
await uploader.uploadMatematikLessonData();
```

## 📂 Firebase Storage Yapısı

Her ders için Storage'da şu yapı kullanılmalıdır:

```
dersler/
  ├── tarih/
  │   └── konular/
  │       └── {konu_adi}/
  │           ├── konu_anlatimi/ (PDF'ler)
  │           ├── podcast/
  │           ├── video/
  │           ├── bilgi_kartlari/
  │           └── notlar/
  ├── vatandaslik/
  │   └── konular/
  ├── cografya/
  │   └── konular/
  ├── guncel_bilgiler/
  │   └── konular/
  ├── turkce/
  │   └── konular/
  │       └── {konu_adi}/
  │           ├── podcast/
  │           ├── bilgi_kartlari/
  │           └── notlar/
  │           (NOT: konu_anlatimi ve video klasörleri YOK)
  └── matematik/
      └── konular/
          └── {konu_adi}/
              ├── testler/ (Sorular)
              └── notlar/
              (NOT: Sadece test ve not var, diğer klasörler YOK)
```

## 🎯 Özel Durumlar

### Türkçe Dersi
- **Gösterilmeyecek Kartlar:**
  - ❌ Konu Anlatımı (PDF)
  - ❌ Videolar

- **Gösterilecek Kartlar:**
  - ✅ Çıkmış Sorular
  - ✅ Testler
  - ✅ Podcastler
  - ✅ Bilgi Kartları
  - ✅ Notlar

### Matematik Dersi
- **Gösterilecek Kartlar (SADECE):**
  - ✅ Testler
  - ✅ Notlar

- **Gösterilmeyecek Kartlar:**
  - ❌ Konu Anlatımı (PDF)
  - ❌ Çıkmış Sorular
  - ❌ Podcastler
  - ❌ Videolar
  - ❌ Bilgi Kartları

### Diğer Dersler (Tarih, Vatandaşlık, Coğrafya, Güncel Bilgiler)
- **Tüm kartlar gösterilir:**
  - ✅ Konu Anlatımı (PDF)
  - ✅ Çıkmış Sorular
  - ✅ Testler
  - ✅ Podcastler
  - ✅ Videolar
  - ✅ Bilgi Kartları
  - ✅ Notlar

## 📊 Firestore Koleksiyonları

### lessons Koleksiyonu

Her ders için bir döküman:

```json
{
  "id": "cografya_lesson",
  "name": "Coğrafya",
  "category": "genel_kultur",
  "icon": "map",
  "color": "green",
  "topicCount": 0,
  "questionCount": 0,
  "description": "Türkiye ve dünya coğrafyası",
  "order": 3
}
```

### topics Koleksiyonu

Konular Storage'dan otomatik olarak yüklenecek. Storage'da klasör olarak eklemeniz yeterli.

## ✅ Kontrol Listesi

- [ ] Firebase'e yeni dersleri yükle
- [ ] Storage'da her ders için klasör yapısını oluştur
- [ ] Her konu için içerik dosyalarını yükle
- [ ] Uygulamayı test et
- [ ] main.dart'taki upload kodunu kaldır

## 🔍 Sorun Giderme

### Dersler Görünmüyor
- Firebase Console'dan `lessons` koleksiyonunu kontrol edin
- `category` alanının doğru olduğundan emin olun (genel_kultur veya genel_yetenek)

### Konular Yüklenmiyor
- Storage'da klasör yapısının doğru olduğundan emin olun
- Klasör adlarının Türkçe karakter içermemesi gerekir (veya encode edilmeli)

### Kartlar Yanlış Gösteriliyor
- `topic_detail_page.dart` dosyasında `lessonName` kontrollerini kontrol edin
- Ders adları tam olarak "Türkçe" ve "Matematik" olmalı (büyük-küçük harf duyarlı DEĞİL)

## 💡 Notlar

- Tüm konular Storage'dan otomatik olarak yüklenir
- Manuel olarak `topics` koleksiyonuna ekleme yapmanıza gerek yoktur
- Storage path'leri direkt string olarak kullanılır, encode etmeye gerek yoktur
- Dosya adları Türkçe karakter içerebilir
