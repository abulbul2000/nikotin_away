# Çeviri boşluğu raporu

Referans: İngilizce tabloda **1294** anahtar (`app_texts.dart` `_en`).
Desteklenen dil: **40** (`tr`/`en` hariç 38 hedef dil).
Toplam eksik giriş: **25.172**.

Eksik anahtar İngilizceye düşer — uygulama çalışır, ama kullanıcı
cümlenin ortasında dil değiştirir. Çalışma anı çevirisi kaldırıldığı
için bu boşluk artık ağdan kapatılmıyor, elle kapatılacak.

Not: bu rapor `test/_dump_translation_keys_test.dart` (geçici, tekrar
üretilebilir) ile `generatedLanguageData` içeriği canlı okunarak
üretildi — önceki rapor (2026-07-29) elle takip edilmiyordu ve
`app_texts.dart`'a sonradan eklenen anahtarları yansıtmıyordu.

| Dil | Mevcut | Eksik | Kapsam |
|---|---:|---:|---:|
| `fil` | 0 | 1294 | %0 |
| `uk` | 0 | 1294 | %0 |
| `ro` | 0 | 1294 | %0 |
| `el` | 0 | 1294 | %0 |
| `hu` | 0 | 1294 | %0 |
| `cs` | 0 | 1294 | %0 |
| `sv` | 0 | 1294 | %0 |
| `da` | 0 | 1294 | %0 |
| `no` | 0 | 1294 | %0 |
| `fi` | 0 | 1294 | %0 |
| `nl` | 0 | 1294 | %0 |
| `be` | 0 | 1294 | %0 |
| `sr` | 0 | 1294 | %0 |
| `hr` | 0 | 1294 | %0 |
| `hi` | 741 | 553 | %57.3 |
| `bn` | 741 | 553 | %57.3 |
| `pa` | 741 | 553 | %57.3 |
| `te` | 741 | 553 | %57.3 |
| `mr` | 741 | 553 | %57.3 |
| `ta` | 741 | 553 | %57.3 |
| `gu` | 741 | 553 | %57.3 |
| `kn` | 741 | 553 | %57.3 |
| `ml` | 741 | 553 | %57.3 |
| `vi` | 741 | 553 | %57.3 |
| `id` | 741 | 553 | %57.3 |
| `ms` | 741 | 553 | %57.3 |
| `de` | 1259 | 35 | %97.3 |
| `ar` | 1259 | 35 | %97.3 |
| `fr` | 1259 | 35 | %97.3 |
| `es` | 1259 | 35 | %97.3 |
| `pt` | 1259 | 35 | %97.3 |
| `it` | 1259 | 35 | %97.3 |
| `pl` | 1259 | 35 | %97.3 |
| `ru` | 1259 | 35 | %97.3 |
| `ja` | 1259 | 35 | %97.3 |
| `zh` | 1259 | 35 | %97.3 |
| `ko` | 1259 | 35 | %97.3 |
| `th` | 1259 | 35 | %97.3 |
| `tr` | 1294 | 0 | %100 |
| `en` | 1294 | 0 | %100 |

## Üç ayrı durum, üç ayrı iş

1. **14 dil, %0 kapsam** (`fil, uk, ro, el, hu, cs, sv, da, no, fi, nl, be,
   sr, hr`): `generatedLanguageData` içinde bu diller için hiç blok yok.
   Sadece `app_texts.dart`'taki küçük `_data` onboarding alt kümesi (dil
   seçimi, "devam", "evet/hayır" gibi ~15 anahtar) kendi dilinde, geri kalan
   1294 anahtarın tamamı İngilizceye düşüyor. En büyük iş kalemi: her biri
   sıfırdan 1294 anahtarlık tam çeviri gerektiriyor.
2. **12 dil, %57.3 kapsam** (`hi, bn, pa, te, mr, ta, gu, kn, ml, vi, id,
   ms`): 741/1294 anahtar var, 553 eksik. Muhtemelen daha önceki bir toplu
   çeviri turunda bu 12 dil ara sırada bırakılmış (`de/ar/fr/.../th` grubu
   tamamlanmışken bunlar tamamlanmamış). İkinci öncelik.
3. **12 dil, %97.3 kapsam** (`de, ar, fr, es, pt, it, pl, ru, ja, zh, ko,
   th`): sadece 35 anahtar eksik — hepsi en yakın zamanda eklenen
   özelliklere ait (`channelName*` bildirim kanalları, `breathInsight*`,
   `registration*Failed`, `barrierStartedInstruction`, `back`,
   `weeklySurveyGeneralStatus`, `copdDisclaimerNotDiagnostic`,
   `taskOverlay*`). En hızlı kapanacak grup — 12 dil × 35 anahtar = 420
   girdi, tek oturumda bitebilir.

## Sıra önerisi

1. Grup 3 (12 dil × 35 anahtar = 420 girdi) — en düşük efor, en hızlı kazanç.
2. Grup 2 (12 dil × 553 anahtar = 6636 girdi) — orta ölçekli, mevcut 24-dil
   enjeksiyon script deseni (bkz. mentor_message_builder.dart çalışması,
   commit cd402ce) doğrudan uygulanabilir.
3. Grup 1 (14 dil × 1294 anahtar = 18116 girdi) — en büyük iş, muhtemelen
   birden fazla oturuma/ajan koşusuna bölünmeli.
4. Her parti sonrası `flutter analyze` + `flutter test`
   (`test/translation_coverage_test.dart` critical-key kontrolünü kapsıyor).
