# Depolama Yönetimi ve Otomatik Temizleme

## 🎯 Sorun

30-40 GB'lık bir projede, tüm içerikler indirildiğinde cihaz depolama alanı dolacak. Bu kullanıcı için kötü bir deneyim.

## ✅ Çözüm: Otomatik Temizleme Sistemi

### 1. **Zaman Bazlı Temizleme** (Time-Based Cleanup)
- Varsayılan: **7 gün** (1 hafta)
- Son erişim tarihinden itibaren belirlenen süre geçen dosyalar otomatik silinir
- Kullanıcı ayarlanabilir: 1 gün, 3 gün, 7 gün, 14 gün, 30 gün

### 2. **Depolama Limiti** (Storage Limit - LRU)
- Varsayılan: **5 GB**
- Depolama limiti aşıldığında, en az kullanılan (LRU) dosyalar otomatik silinir
- Kullanıcı ayarlanabilir: 1 GB, 3 GB, 5 GB, 10 GB, 20 GB, Sınırsız

### 3. **Last Access Time Tracking**
- Her içerik oynatıldığında/okunduğunda son erişim zamanı güncellenir
- LRU (Least Recently Used) algoritması için kullanılır
- En az kullanılan içerikler önce silinir

## 🔧 Nasıl Çalışır?

### Otomatik Temizleme
1. Uygulama açıldığında arka planda çalışır
2. Önce depolama limiti kontrol edilir (LRU)
3. Sonra zaman bazlı temizleme yapılır
4. Kullanıcı etkilenmez (non-blocking)

### Last Access Time Güncelleme
- Video oynatıldığında → Güncellenir
- Podcast dinlendiğinde → Güncellenir
- PDF okunduğunda → Güncellenir

## 📊 Varsayılan Ayarlar

- **Otomatik Temizleme**: Açık ✅
- **Temizleme Süresi**: 7 gün
- **Maksimum Depolama**: 5 GB

## 🎨 Kullanıcı Ayarları (Gelecek)

Kullanıcı Profile/Settings sayfasından şunları ayarlayabilir:
- Otomatik temizlemeyi aç/kapat
- Temizleme süresini değiştir (1-30 gün)
- Maksimum depolama limitini ayarla (1-20 GB veya sınırsız)
- Mevcut depolama kullanımını görüntüle
- Manuel temizleme yap

## 💡 Örnek Senaryolar

### Senaryo 1: Normal Kullanım
- Kullanıcı 10 video izliyor (her biri 100 MB = 1 GB)
- 7 gün sonra kullanılmayan videolar otomatik silinir
- Sık kullanılan videolar korunur

### Senaryo 2: Depolama Limiti
- Kullanıcı 50 video indiriyor (5 GB)
- Limit aşıldığında en az kullanılan videolar silinir
- Yeni videolar için yer açılır

### Senaryo 3: Manuel Yönetim
- Kullanıcı karttan direkt silebilir
- Silinen içerik tekrar açıldığında otomatik indirilir

## 🚀 Teknik Detaylar

### Servis Özellikleri
- ✅ Zaman bazlı temizleme
- ✅ LRU (Least Recently Used) algoritması
- ✅ Depolama limiti kontrolü
- ✅ Last access time tracking
- ✅ Kullanıcı tercihleri (SharedPreferences)
- ✅ Arka planda çalışma (non-blocking)

### Dosya Yapısı
```
lib/
  core/
    services/
      storage_cleanup_service.dart  # Otomatik temizleme servisi
```

## 📈 Beklenen Sonuçlar

### Önceki Durum:
- 30-40 GB içerik → Tüm cihaz depolama alanı dolu
- Kullanıcı manuel silmek zorunda

### Yeni Durum:
- Otomatik temizleme → Depolama kontrol altında
- En fazla 5 GB kullanım (ayarlanabilir)
- Kullanıcı hiçbir şey yapmadan çalışır

## ⚙️ Gelecek İyileştirmeler

- [ ] Settings sayfasına depolama yönetimi ekle
- [ ] Depolama kullanımı görselleştirme
- [ ] Bildirim sistemi (depolama dolmadan önce uyarı)
- [ ] Hızlı temizleme butonu
- [ ] Kategori bazlı temizleme (sadece videolar, sadece podcastler vb.)

