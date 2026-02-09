# Paket Fiyatlandırma Analizi - Türkiye

## 📊 Senaryo B: Aşırı Aktif Kullanıcı Maliyetleri

**Kullanım:** ~7.87 GB/ay/kullanıcı

### Kullanıcı Başına Maliyetler:

| Kullanıcı Sayısı | Aylık Maliyet | Yıllık Maliyet | Kullanıcı Başına/Ay | Kullanıcı Başına/Yıl |
|------------------|---------------|----------------|---------------------|----------------------|
| 100 | $90.84 | $1,090.08 | $0.91 | $10.90 |
| 500 | $468.60 | $5,623.20 | $0.94 | $11.25 |
| 1,000 | $940.80 | $11,289.60 | $0.94 | $11.29 |
| 5,000 | $4,718.40 | $56,620.80 | $0.94 | $11.32 |
| 10,000 | $9,440.40 | $113,284.80 | $0.94 | $11.33 |

**Ortalama:** ~$0.94/ay/kullanıcı = **~31 TL/ay/kullanıcı** (1 USD = 33 TL)

---

## 💻 TÜM SUNUCU MALİYETLERİ (Firebase Servisleri)

### 1. Firebase Storage (Zaten Hesaplandı)
- **Download:** $0.12/GB
- **Storage:** $0.026/GB/ay
- Senaryo B için: **$0.94/ay/kullanıcı**

### 2. Firestore (Veritabanı) - YENİ EKLENEN

**Fiyatlandırma:**
- **Read işlemleri:** $0.06 per 100,000 reads
- **Write işlemleri:** $0.18 per 100,000 writes
- **Storage:** $0.18 per GB/ay

**Tahmini Kullanım (Aktif Kullanıcı/Ay):**
- **Read işlemleri:** 
  - Ders listesi: ~50 read
  - Konu listesi: ~100 read
  - Soru çözme: ~200 read
  - İlerleme takibi: ~150 read
  - Toplam: ~500 read/kullanıcı/ay
  - 1,000 kullanıcı: 500,000 read/ay = **$0.30/ay**

- **Write işlemleri:**
  - İlerleme kaydı: ~50 write
  - Test sonuçları: ~30 write
  - Kullanıcı ayarları: ~10 write
  - Toplam: ~90 write/kullanıcı/ay
  - 1,000 kullanıcı: 90,000 write/ay = **$0.16/ay**

- **Storage:**
  - Kullanıcı verileri: ~1 MB/kullanıcı
  - 1,000 kullanıcı: 1 GB = **$0.18/ay**

**Firestore Toplam (1,000 kullanıcı):** ~$0.64/ay = **$0.00064/kullanıcı/ay**

### 3. Firebase Authentication - ÜCRETSİZ ✅
- Email/Password authentication ücretsiz
- SMS authentication ücretli ama kullanılmıyor
- **Maliyet: $0**

### 4. Diğer Firebase Servisleri
- Firebase Hosting: Kullanılmıyor
- Firebase Functions: Kullanılmıyor
- Firebase Analytics: Ücretsiz
- **Maliyet: $0**

### 📊 TOPLAM SUNUCU MALİYETİ (Kullanıcı Başına/Ay):

| Servis | Maliyet/Kullanıcı/Ay | Açıklama |
|--------|---------------------|----------|
| **Firebase Storage** | $0.94 | Download + Storage |
| **Firestore** | $0.00064 | Read + Write + Storage |
| **Authentication** | $0 | Ücretsiz |
| **Diğer** | $0 | Kullanılmıyor |
| **TOPLAM** | **~$0.94/ay** | **~31 TL/ay** |

**Not:** Firestore maliyeti çok küçük olduğu için toplam maliyet yaklaşık aynı kalıyor.

---

## 💰 GÜNCELLENMİŞ TOPLAM MALİYET

**Kullanıcı Başına Aylık Maliyet:**
- Firebase Storage: 31 TL
- Firestore: 0.02 TL (ihmal edilebilir)
- **TOPLAM: ~31 TL/ay/kullanıcı**

**1,000 Kullanıcı İçin:**
- Firebase Storage: 31,000 TL/ay
- Firestore: 20 TL/ay
- **TOPLAM: ~31,020 TL/ay**

---

## 💰 Platform Komisyonları ve Vergiler

### Google Play Store:
- **İlk $1M gelir için:** %15 komisyon
- **$1M üzeri:** %30 komisyon
- **Türkiye KDV:** %20 (dijital ürünler)

### Apple App Store:
- **İlk $1M gelir için:** %15 komisyon (Small Business Program)
- **$1M üzeri:** %30 komisyon
- **Türkiye KDV:** %20 (dijital ürünler)

### Hesaplama Formülü:
```
Satış Fiyatı = X TL
Platform Komisyonu (%15) = 0.15X
KDV (%20) = 0.20X
Net Gelir = X - 0.15X - 0.20X = 0.65X
Maliyet = 31 TL/ay
Kar = 0.65X - 31 TL
```

---

## 🎯 İdeal Paket Fiyatları (Türkiye)

### Senaryo 1: Düşük Kar Marjı (%40-50) - Rekabetçi Fiyatlandırma

**Hedef:** Geniş kullanıcı kitlesi, düşük kar marjı

| Paket | Aylık Fiyat | 6 Aylık Fiyat | Yıllık Fiyat | Aylık Maliyet | Kar Marjı |
|-------|-------------|---------------|--------------|---------------|-----------|
| **Aylık** | **79 TL** | - | - | 31 TL | %48 |
| **6 Aylık** | **69 TL/ay** | **414 TL** | - | 31 TL | %55 |
| **Yıllık** | **59 TL/ay** | - | **708 TL** | 31 TL | %62 |

**Hesaplama Örneği (Aylık 79 TL):**
- Satış: 79 TL
- Platform komisyonu (%15): 11.85 TL
- KDV (%20): 15.8 TL
- Net gelir: 51.35 TL
- Maliyet: 31 TL
- Kar: 20.35 TL (%40 kar marjı)

---

### Senaryo 2: Orta Kar Marjı (%50-60) - Dengeli Fiyatlandırma

**Hedef:** Sağlıklı kar marjı, rekabetçi fiyat

| Paket | Aylık Fiyat | 6 Aylık Fiyat | Yıllık Fiyat | Aylık Maliyet | Kar Marjı |
|-------|-------------|---------------|--------------|---------------|-----------|
| **Aylık** | **99 TL** | - | - | 31 TL | %58 |
| **6 Aylık** | **89 TL/ay** | **534 TL** | - | 31 TL | %63 |
| **Yıllık** | **79 TL/ay** | - | **948 TL** | 31 TL | %68 |

**Hesaplama Örneği (Aylık 99 TL):**
- Satış: 99 TL
- Platform komisyonu (%15): 14.85 TL
- KDV (%20): 19.8 TL
- Net gelir: 64.35 TL
- **Sunucu maliyeti: 31 TL** (Storage + Firestore)
- Kar: 33.35 TL (%52 kar marjı)

---

### Senaryo 3: Yüksek Kar Marjı (%60-70) - Premium Fiyatlandırma

**Hedef:** Yüksek kalite algısı, yüksek kar marjı

| Paket | Aylık Fiyat | 6 Aylık Fiyat | Yıllık Fiyat | Aylık Maliyet | Kar Marjı |
|-------|-------------|---------------|--------------|---------------|-----------|
| **Aylık** | **129 TL** | - | - | 31 TL | %68 |
| **6 Aylık** | **119 TL/ay** | **714 TL** | - | 31 TL | %72 |
| **Yıllık** | **109 TL/ay** | - | **1,308 TL** | 31 TL | %76 |

**Hesaplama Örneği (Aylık 129 TL):**
- Satış: 129 TL
- Platform komisyonu (%15): 19.35 TL
- KDV (%20): 25.8 TL
- Net gelir: 83.85 TL
- Maliyet: 31 TL
- Kar: 52.85 TL (%63 kar marjı)

---

## 📊 ÖNERİLEN PAKET FİYATLARI (En İdeal)

### 🎯 Senaryo 2: Orta Kar Marjı - **ÖNERİLEN**

**Gerekçe:**
- Rekabetçi fiyat (Türkiye pazarı için uygun)
- Sağlıklı kar marjı (%50-60)
- Kullanıcı dostu fiyatlandırma
- Sürdürülebilir iş modeli

| Paket | Fiyat | Aylık Maliyet | Kar Marjı | Özellikler |
|-------|-------|---------------|-----------|------------|
| **Aylık** | **99 TL** | 31 TL | %58 | Esnek ödeme |
| **6 Aylık** | **534 TL** (89 TL/ay) | 31 TL | %63 | 1 ay bedava |
| **Yıllık** | **948 TL** (79 TL/ay) | 31 TL | %68 | 3 ay bedava |

**Tasarruf Oranları:**
- 6 Aylık: %10 indirim (1 ay bedava)
- Yıllık: %20 indirim (3 ay bedava)

---

## 💡 Alternatif Fiyatlandırma Stratejileri

### Strateji 1: Aşamalı Fiyatlandırma (Önerilen)

**İlk 1,000 kullanıcı için özel fiyat:**
- Aylık: 79 TL (erken kullanıcı indirimi)
- 6 Aylık: 414 TL (69 TL/ay)
- Yıllık: 708 TL (59 TL/ay)

**1,000+ kullanıcı için normal fiyat:**
- Aylık: 99 TL
- 6 Aylık: 534 TL (89 TL/ay)
- Yıllık: 948 TL (79 TL/ay)

### Strateji 2: Öğrenci İndirimi

**Öğrenci doğrulaması ile:**
- Aylık: 69 TL (%30 indirim)
- 6 Aylık: 354 TL (59 TL/ay)
- Yıllık: 648 TL (54 TL/ay)

### Strateji 3: Yıllık Abonelik Odaklı

**Yıllık aboneliği teşvik et:**
- Aylık: 129 TL (yüksek fiyat)
- 6 Aylık: 714 TL (119 TL/ay)
- Yıllık: 948 TL (79 TL/ay) - **%39 indirim**

---

## 📈 Farklı Kullanıcı Senaryolarına Göre Fiyatlandırma

### Senaryo A: Normal Kullanıcı (0.667 GB/ay)
**Maliyet:** ~22 TL/ay/kullanıcı

| Paket | Önerilen Fiyat | Kar Marjı |
|-------|----------------|-----------|
| Aylık | 69 TL | %60 |
| 6 Aylık | 354 TL (59 TL/ay) | %65 |
| Yıllık | 648 TL (54 TL/ay) | %70 |

### Senaryo B: Aşırı Aktif (7.87 GB/ay) - **MEVCUT**
**Maliyet:** ~31 TL/ay/kullanıcı

| Paket | Önerilen Fiyat | Kar Marjı |
|-------|----------------|-----------|
| Aylık | 99 TL | %58 |
| 6 Aylık | 534 TL (89 TL/ay) | %63 |
| Yıllık | 948 TL (79 TL/ay) | %68 |

### Senaryo C: Kötü Durum (16 GB/ay)
**Maliyet:** ~63 TL/ay/kullanıcı

| Paket | Önerilen Fiyat | Kar Marjı |
|-------|----------------|-----------|
| Aylık | 149 TL | %58 |
| 6 Aylık | 804 TL (134 TL/ay) | %63 |
| Yıllık | 1,428 TL (119 TL/ay) | %68 |

---

## 🎯 SONUÇ VE ÖNERİLER

### ✅ Önerilen Paket Fiyatları (Senaryo B için):

| Paket | Fiyat | Aylık Eşdeğer | Tasarruf |
|-------|-------|--------------|----------|
| **Aylık** | **99 TL** | 99 TL | - |
| **6 Aylık** | **534 TL** | 89 TL/ay | %10 (1 ay bedava) |
| **Yıllık** | **948 TL** | 79 TL/ay | %20 (3 ay bedava) |

### 📊 Karşılaştırma (Mevcut vs Önerilen):

| Paket | Mevcut Fiyat | Önerilen Fiyat | Fark |
|-------|--------------|----------------|------|
| Aylık | 149 TL | 99 TL | -50 TL (%34 düşüş) |
| 6 Aylık | 799 TL | 534 TL | -265 TL (%33 düşüş) |
| Yıllık | 1,299 TL | 948 TL | -351 TL (%27 düşüş) |

### 💡 Öneriler:

1. **Fiyat Düşürme:**
   - Mevcut fiyatlar yüksek görünüyor
   - Önerilen fiyatlar daha rekabetçi
   - Daha fazla kullanıcı çekebilir

2. **Yıllık Abonelik Teşviki:**
   - Yıllık pakete %20 indirim
   - Daha düşük iptal oranı
   - Öngörülebilir gelir

3. **Aşamalı Fiyatlandırma:**
   - İlk 1,000 kullanıcı için özel fiyat
   - Viral büyüme için teşvik
   - Sonra normal fiyata geçiş

4. **Öğrenci İndirimi:**
   - Öğrenci doğrulaması ile %30 indirim
   - Genç kitleyi çekme
   - Uzun vadeli müşteri kazanma

---

## ⚠️ ÖNEMLİ NOTLAR

1. **Platform Komisyonları:**
   - İlk $1M gelir için %15 (daha avantajlı)
   - Sonrası %30 (daha yüksek maliyet)
   - İlk dönemde daha iyi kar marjı

2. **KDV:**
   - Türkiye'de dijital ürünler için %20 KDV
   - Fiyatlara dahil edilmeli
   - Platform otomatik hesaplıyor

3. **Döviz Kuru:**
   - 1 USD = 33 TL (güncel)
   - Kurlar değişebilir, esnek olunmalı
   - Düzenli güncelleme gerekli

4. **Maliyet Artışı:**
   - Kullanıcı sayısı arttıkça maliyet artar
   - Fiyatlandırmayı düzenli gözden geçirin
   - Ölçek ekonomisi avantajları değerlendirin

---

## 📊 Gelir Projeksiyonları (1,000 Kullanıcı)

### Senaryo 2 Fiyatlandırması ile:

**Dağılım Varsayımı:**
- %40 Aylık (400 kullanıcı)
- %30 6 Aylık (300 kullanıcı)
- %30 Yıllık (300 kullanıcı)

**Aylık Gelir:**
- Aylık: 400 × 99 TL = 39,600 TL
- 6 Aylık: 300 × 89 TL = 26,700 TL
- Yıllık: 300 × 79 TL = 23,700 TL
- **Toplam: 90,000 TL/ay**

**Net Gelir (Komisyon ve KDV sonrası):**
- Platform komisyonu (%15): 13,500 TL
- KDV (%20): 18,000 TL
- **Net Gelir: 58,500 TL/ay**

**Maliyet:**
- Firebase Storage: 31,000 TL/ay (1,000 kullanıcı × 31 TL)
- Firestore: 20 TL/ay (1,000 kullanıcı × 0.02 TL)
- **Toplam Sunucu Maliyeti: 31,020 TL/ay**
- **Kar: 27,480 TL/ay (%47 kar marjı)**

**Yıllık:**
- Gelir: 1,080,000 TL
- Net Gelir: 702,000 TL
- Maliyet: 372,000 TL
- **Kar: 330,000 TL/yıl**

---

## 🎯 Final Öneri

**Önerilen Paket Fiyatları:**
- **Aylık:** 99 TL
- **6 Aylık:** 534 TL (89 TL/ay)
- **Yıllık:** 948 TL (79 TL/ay)

**Gerekçe:**
- Rekabetçi fiyat
- Sağlıklı kar marjı (%50-60)
- Türkiye pazarına uygun
- Sürdürülebilir iş modeli
- Kullanıcı dostu
