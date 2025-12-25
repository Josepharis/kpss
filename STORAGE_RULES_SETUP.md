# Firebase Storage Rules Kurulumu

Firebase Storage'dan dosya okumak için Security Rules'ı güncellemeniz gerekiyor.

## Yöntem 1: Firebase Console'dan (Hızlı)

1. Firebase Console → **Storage** sekmesine gidin
2. **"Rules"** sekmesine tıklayın
3. Aşağıdaki kuralları yapıştırın:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow read access to all files (for development)
    match /{allPaths=**} {
      allow read: if true;
      allow write: if true; // For development - restrict in production
    }
  }
}
```

4. **"Publish"** butonuna tıklayın

## Yöntem 2: Firebase CLI ile (Önerilen)

Eğer Firebase CLI kuruluysa:

```bash
firebase deploy --only storage
```

## Notlar

- Bu kurallar development için tüm dosyalara okuma/yazma izni verir
- Production'da daha kısıtlayıcı kurallar kullanmalısınız
- `storage.rules` dosyası projeye eklendi, Firebase CLI ile deploy edebilirsiniz

