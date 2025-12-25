# Podcast Yükleme Rehberi

Bu rehber, podcast ses dosyalarını Firebase Storage'a yüklemek ve Firestore'a podcast dökümanı oluşturmak için hazırlanmıştır.

## 📋 Yapılan İşlemler

1. ✅ `firebase_storage` paketi eklendi
2. ✅ `Podcast` modeline `fromMap` ve `toMap` metodları eklendi
3. ✅ `PodcastsService` oluşturuldu
4. ✅ `StorageService` oluşturuldu (ses dosyası yükleme için)
5. ✅ `PodcastsPage` Firebase'den veri çekiyor
6. ✅ `uploadPodcast` script'i hazırlandı

## 🎙️ Podcast Yükleme

### Yöntem 1: Script ile Yükleme (Önerilen)

`lib/main.dart` dosyasına geçici olarak şu kodu ekleyin:

```dart
import 'dart:io';
import 'core/services/upload_podcast_script.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Ses dosyasının yolunu belirtin
  final audioFile = File('/path/to/your/audio.mp3');
  
  // Podcast yükle
  await uploadPodcast(
    audioFile: audioFile,
    title: 'İslamiyet Öncesi Türk Tarihi - Bölüm 1',
    description: 'Devlet yapısı ve yönetim anlayışı hakkında detaylı bilgiler',
    topicId: 'islamiyet_oncesi_turk_tarihi',
    lessonId: 'tarih_lesson',
    durationMinutes: 25, // Ses dosyasının süresi (dakika)
    podcastId: 'islamiyet_oncesi_turk_tarihi_podcast_1', // Opsiyonel
    order: 1,
  );
  
  runApp(const MyApp());
}
```

### Yöntem 2: Manuel Yükleme

#### Adım 1: Firebase Storage'a Ses Dosyası Yükleme

1. Firebase Console → **Storage** sekmesine gidin
2. **"Get started"** veya **"Add file"** butonuna tıklayın
3. Klasör yapısı: `podcasts/islamiyet_oncesi_turk_tarihi/`
4. Ses dosyanızı yükleyin (MP3 formatında önerilir)
5. Dosya yüklendikten sonra **"Copy URL"** ile download URL'ini kopyalayın

#### Adım 2: Firestore'a Podcast Dökümanı Oluşturma

1. Firebase Console → **Firestore Database** sekmesine gidin
2. **"Add collection"** butonuna tıklayın
3. Collection ID: `podcasts` yazın
4. **"Next"** butonuna tıklayın
5. Document ID: `islamiyet_oncesi_turk_tarihi_podcast_1` yazın
6. Aşağıdaki alanları ekleyin:

| Field | Type | Value |
|-------|------|-------|
| title | string | İslamiyet Öncesi Türk Tarihi - Bölüm 1 |
| description | string | Devlet yapısı ve yönetim anlayışı hakkında detaylı bilgiler |
| audioUrl | string | (Firebase Storage'dan kopyaladığınız URL) |
| durationMinutes | number | 25 |
| topicId | string | islamiyet_oncesi_turk_tarihi |
| lessonId | string | tarih_lesson |
| order | number | 1 |
| thumbnailUrl | string | (opsiyonel, boş bırakılabilir) |

7. **"Save"** butonuna tıklayın

## 📝 Notlar

- Ses dosyası formatı: MP3 önerilir (diğer formatlar da çalışabilir)
- Ses dosyası boyutu: Firebase Storage'ın ücretsiz planında 5GB limit var
- `durationMinutes`: Ses dosyasının toplam süresi (dakika cinsinden)
- `order`: Podcast'lerin sıralaması için kullanılır
- `topicId`: Podcast'in hangi konuya ait olduğunu belirtir

## ✅ Kontrol

Podcast yüklendikten sonra:

1. Uygulamayı çalıştırın
2. "Dersler" → "Tarih" → "İslamiyet Öncesi Türk Tarihi" → "Podcastler"
3. Yüklediğiniz podcast görünmeli
4. Podcast'e tıklayıp oynatabilmelisiniz

## 🐛 Sorun Giderme

Eğer podcast görünmüyorsa:

1. Firebase Console'da `podcasts` koleksiyonunu kontrol edin
2. `topicId` alanının doğru olduğundan emin olun
3. Firebase Storage'da dosyanın yüklendiğini kontrol edin
4. `audioUrl` alanının geçerli bir URL olduğunu kontrol edin

