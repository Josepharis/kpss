# Firebase Veri Yükleme Rehberi

Bu rehber, Tarih dersi ve İslamiyet Öncesi Türk Tarihi konusuna ait soruları Firebase'e yüklemek için hazırlanmıştır.

## 📋 Yapılan İşlemler

1. ✅ `cloud_firestore` paketi eklendi
2. ✅ `Lesson`, `Topic` ve `TestQuestion` modellerine `fromMap` ve `toMap` metodları eklendi
3. ✅ `LessonsService` ve `QuestionsService` oluşturuldu
4. ✅ `FirebaseDataUploader` servisi hazırlandı
5. ✅ 25 soru parse edildi ve yükleme için hazırlandı

## 🚀 Verileri Firebase'e Yükleme

### Yöntem 1: Script ile Yükleme (Önerilen)

`lib/main.dart` dosyasına geçici olarak şu kodu ekleyin:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'core/services/upload_data_script.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Verileri yükle (sadece bir kez çalıştırın!)
  await uploadData();
  
  runApp(const MyApp());
}
```

**ÖNEMLİ:** Veriler yüklendikten sonra bu kodu kaldırın!

### Yöntem 2: Manuel Yükleme

Firebase Console'dan manuel olarak şu koleksiyonları oluşturun:

#### 1. `lessons` Koleksiyonu

Döküman ID: `tarih_lesson`

```json
{
  "name": "Tarih",
  "category": "genel_kultur",
  "icon": "history",
  "color": "red",
  "topicCount": 1,
  "questionCount": 25,
  "description": "Türk tarihi, Osmanlı tarihi ve dünya tarihi",
  "order": 1
}
```

#### 2. `topics` Koleksiyonu

Döküman ID: `islamiyet_oncesi_turk_tarihi`

```json
{
  "lessonId": "tarih_lesson",
  "name": "İslamiyet Öncesi Türk Tarihi",
  "subtitle": "Türklerin İslamiyet öncesi dönemdeki devlet yapısı, kültürü ve yaşamı",
  "duration": "4h 30min",
  "averageQuestionCount": 25,
  "testCount": 1,
  "podcastCount": 0,
  "videoCount": 0,
  "noteCount": 0,
  "progress": 0.0,
  "order": 1
}
```

#### 3. `questions` Koleksiyonu

25 soru için `questions` koleksiyonuna dökümanlar ekleyin. Her soru için:

- Döküman ID: `islamiyet_oncesi_turk_tarihi_1`, `islamiyet_oncesi_turk_tarihi_2`, ... `islamiyet_oncesi_turk_tarihi_25`
- Format: `lib/core/services/firebase_data_uploader.dart` dosyasındaki `_getIslamiyetOncesiTurkTarihiQuestions()` metoduna bakın

## 🔥 Firestore Index'leri

Firestore'da şu index'lerin oluşturulması gerekebilir (Firebase Console otomatik önerecektir):

1. `questions` koleksiyonu:
   - `topicId` (Ascending) + `order` (Ascending)
   - `lessonId` (Ascending) + `order` (Ascending)

2. `lessons` koleksiyonu:
   - `category` (Ascending) + `order` (Ascending)

3. `topics` koleksiyonu:
   - `lessonId` (Ascending) + `order` (Ascending)

## 📝 Notlar

- Döküman tekrar eden sorular içeriyor (1-4 arası sorular tekrar ediyor). Tüm 25 soru yüklenecek.
- Veriler yüklendikten sonra uygulama otomatik olarak Firebase'den verileri çekecektir.
- `LessonsPage` ve `LessonDetailPage` artık Firebase'den gerçek zamanlı veri çekiyor.

## ✅ Kontrol

Veriler yüklendikten sonra:

1. Uygulamayı çalıştırın
2. "Dersler" sekmesine gidin
3. "Tarih" dersini görüntüleyin
4. "İslamiyet Öncesi Türk Tarihi" konusunu açın
5. Soruların göründüğünü kontrol edin

## 🐛 Sorun Giderme

Eğer veriler görünmüyorsa:

1. Firebase Console'da koleksiyonların oluşturulduğunu kontrol edin
2. Firestore Rules'ın okuma izni verdiğinden emin olun
3. Console'da hata mesajlarını kontrol edin
4. Index'lerin oluşturulduğunu kontrol edin

