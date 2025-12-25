# Firebase Manuel Veri Yükleme Rehberi

Platform channel hatası nedeniyle otomatik yükleme çalışmıyorsa, verileri Firebase Console'dan manuel olarak yükleyebilirsiniz.

## Adım 1: Firebase Console'a Giriş

1. [Firebase Console](https://console.firebase.google.com/) adresine gidin
2. Projenizi seçin: **kpss-ags-son**
3. Sol menüden **Firestore Database** seçin

## Adım 2: Lessons Koleksiyonunu Oluşturma

1. **"Start collection"** veya **"Add collection"** butonuna tıklayın
2. Collection ID: `lessons` yazın
3. **"Next"** butonuna tıklayın
4. Document ID: `tarih_lesson` yazın
5. Aşağıdaki alanları ekleyin:

| Field | Type | Value |
|-------|------|-------|
| name | string | Tarih |
| category | string | genel_kultur |
| icon | string | history |
| color | string | red |
| topicCount | number | 1 |
| questionCount | number | 25 |
| description | string | Türk tarihi, Osmanlı tarihi ve dünya tarihi |
| order | number | 1 |

6. **"Save"** butonuna tıklayın

## Adım 3: Topics Koleksiyonunu Oluşturma

1. **"Add collection"** butonuna tıklayın
2. Collection ID: `topics` yazın
3. **"Next"** butonuna tıklayın
4. Document ID: `islamiyet_oncesi_turk_tarihi` yazın
5. Aşağıdaki alanları ekleyin:

| Field | Type | Value |
|-------|------|-------|
| lessonId | string | tarih_lesson |
| name | string | İslamiyet Öncesi Türk Tarihi |
| subtitle | string | Türklerin İslamiyet öncesi dönemdeki devlet yapısı, kültürü ve yaşamı |
| duration | string | 4h 30min |
| averageQuestionCount | number | 25 |
| testCount | number | 1 |
| podcastCount | number | 0 |
| videoCount | number | 0 |
| noteCount | number | 0 |
| progress | number | 0.0 |
| order | number | 1 |

6. **"Save"** butonuna tıklayın

## Adım 4: Questions Koleksiyonunu Oluşturma

1. **"Add collection"** butonuna tıklayın
2. Collection ID: `questions` yazın
3. Her soru için ayrı bir döküman oluşturun

### Soru 1:
- Document ID: `islamiyet_oncesi_turk_tarihi_1`
- Fields:

| Field | Type | Value |
|-------|------|-------|
| question | string | İslamiyet öncesi Türklerde devlet anlayışını ifade eden kavram aşağıdakilerden hangisidir? |
| options | array | ["Boy", "İl", "Toy", "Kut", "Töre"] |
| correctAnswerIndex | number | 1 |
| explanation | string | İslamiyet öncesi Türklerde devlet kavramı 'il' sözcüğüyle ifade edilmiştir. İl; siyasi egemenliğe sahip, bağımsız ve teşkilatlanmış yapıyı anlatır. Boy ve oba daha küçük sosyal birimlerdir, toy meclistir, kut yönetme yetkisini, töre ise hukuk sistemini ifade eder. |
| timeLimitSeconds | number | 60 |
| topicId | string | islamiyet_oncesi_turk_tarihi |
| lessonId | string | tarih_lesson |
| order | number | 1 |

### Soru 2:
- Document ID: `islamiyet_oncesi_turk_tarihi_2`
- Fields: (Soru 2'nin verileri - `firebase_data_uploader.dart` dosyasından bakabilirsiniz)

### Soru 3-25:
- Benzer şekilde devam edin
- Document ID'ler: `islamiyet_oncesi_turk_tarihi_3` ... `islamiyet_oncesi_turk_tarihi_25`

## Hızlı Yükleme İçin

Tüm soruları tek tek eklemek yerine, `lib/core/services/firebase_data_uploader.dart` dosyasındaki `_getIslamiyetOncesiTurkTarihiQuestions()` metoduna bakarak tüm soruları görebilirsiniz.

## Notlar

- `options` field'ı bir array olmalı (Firebase Console'da array olarak ekleyin)
- `correctAnswerIndex` 0'dan başlar (A=0, B=1, C=2, D=3, E=4)
- Tüm sorular için `topicId` ve `lessonId` aynı kalmalı
- `order` field'ı sıralama için kullanılır

## Alternatif: Firebase CLI ile Yükleme

Eğer Firebase CLI kuruluysa, JSON dosyaları ile toplu yükleme yapabilirsiniz (daha gelişmiş bir yöntem).

