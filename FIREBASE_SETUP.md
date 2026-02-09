# Firebase Kurulum Kılavuzu

## 1. Firebase Console'da Proje Oluşturma

1. [Firebase Console](https://console.firebase.google.com/) adresine gidin
2. "Add project" butonuna tıklayın
3. Proje adını girin: **kpss-ags**
4. Google Analytics'i isteğe bağlı olarak etkinleştirin
5. "Create project" butonuna tıklayın
6. Proje oluşturulduktan sonra "Continue" butonuna tıklayın

## 2. FlutterFire CLI ile Otomatik Yapılandırma (Önerilen)

Firebase Console'da projeyi oluşturduktan sonra, terminalde şu komutları çalıştırın:

**Yöntem 1: Tam yol ile (Önerilen - Her zaman çalışır)**
```bash
# Proje dizinine git
cd /Users/yusuf/Desktop/fllutter/kpss_ags_2026

# FlutterFire yapılandırmasını başlat (tam yol ile)
$HOME/.pub-cache/bin/flutterfire configure
```

**Yöntem 2: PATH ile**
```bash
# Önce mevcut shell'de PATH'i yükle
source ~/.zshrc

# Veya manuel olarak export et
export PATH="$PATH":"$HOME/.pub-cache/bin"

# Proje dizinine git
cd /Users/yusuf/Desktop/fllutter/kpss_ags_2026

# FlutterFire yapılandırmasını başlat
flutterfire configure
```

Bu komut çalıştığında:
1. Firebase'e giriş yapmanız istenecek (tarayıcı açılacak)
2. Oluşturduğunuz **"kpss-ags"** projesini seçin
3. Android ve iOS platformlarını seçin
4. FlutterFire otomatik olarak gerekli dosyaları oluşturacak:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
   - `lib/firebase_options.dart`
   - Gerekli Gradle yapılandırmaları

**Not:** Eğer PATH hatası alırsanız, `.zshrc` dosyanıza şunu ekleyin:
```bash
echo 'export PATH="$PATH":"$HOME/.pub-cache/bin"' >> ~/.zshrc
source ~/.zshrc
```

## 3. Firebase Authentication'ı Etkinleştirme

1. Firebase Console'da **kpss-ags** projenizi açın
2. Sol menüden **"Authentication"** seçin
3. **"Get started"** butonuna tıklayın
4. **"Sign-in method"** sekmesine gidin
5. **"Email/Password"** seçeneğini etkinleştirin
6. **"Enable"** butonuna tıklayın
7. **"Save"** butonuna tıklayın

## 4. Main.dart'ı Güncelleme

FlutterFire CLI yapılandırması tamamlandıktan sonra, `lib/main.dart` dosyasını güncelleyin:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Bu dosya FlutterFire CLI tarafından oluşturulur

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase'i başlat
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // ... diğer kodlar
}
```

## 5. Test Etme

1. Uygulamayı çalıştırın:
   ```bash
   flutter run
   ```

2. Register sayfasından yeni bir hesap oluşturun
3. Login sayfasından giriş yapın
4. Uygulamayı kapatıp tekrar açın - otomatik giriş yapmalı
5. Firebase Console > Authentication > Users bölümünden kullanıcıyı görebilirsiniz

## Manuel Yapılandırma (FlutterFire CLI kullanmıyorsanız)

### Android Yapılandırması

1. Firebase Console'da projenizi açın
2. Android ikonuna tıklayın
3. Package name'i girin: `com.kadrox.app`
4. `google-services.json` dosyasını indirin
5. İndirilen dosyayı `android/app/` klasörüne kopyalayın

`android/build.gradle.kts` dosyasına ekleyin:
```kotlin
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}
```

`android/app/build.gradle.kts` dosyasının en üstüne ekleyin:
```kotlin
plugins {
    // ... mevcut pluginler
    id("com.google.gms.google-services")
}
```

### iOS Yapılandırması

1. Firebase Console'da projenizi açın
2. iOS ikonuna tıklayın
3. Bundle ID'yi girin (Xcode'dan bulabilirsiniz)
4. `GoogleService-Info.plist` dosyasını indirin
5. İndirilen dosyayı Xcode'da `ios/Runner/` klasörüne sürükleyin

`ios/Podfile` dosyasında platform versiyonunu kontrol edin (minimum iOS 12.0):
```ruby
platform :ios, '12.0'
```

Sonra terminalde çalıştırın:
```bash
cd ios
pod install
cd ..
```

## Notlar

- Firebase Authentication varsayılan olarak persistent (kalıcı) authentication kullanır
- Kullanıcı çıkış yapmadığı sürece otomatik giriş yapılacak
- Tüm hata mesajları Türkçe olarak gösterilir
- KPSS türü bilgisi kullanıcı kaydında saklanır
- FlutterFire CLI kullanmak en kolay ve önerilen yöntemdir
