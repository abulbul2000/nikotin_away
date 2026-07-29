# Çeviri boşluğu raporu

Referans: İngilizce tabloda **1027** anahtar.
Desteklenen dil: **39**.
Toplam eksik giriş: **24.727**.

Eksik anahtar İngilizceye düşer — uygulama çalışır, ama kullanıcı
cümlenin ortasında dil değiştirir. Çalışma anı çevirisi kaldırıldığı
için bu boşluk artık ağdan kapatılmıyor, elle kapatılacak.

| Dil | Mevcut | Eksik | Kapsam |
|---|---:|---:|---:|
| `uk` | 0 | 1027 | %0 |
| `ro` | 0 | 1027 | %0 |
| `el` | 0 | 1027 | %0 |
| `hu` | 0 | 1027 | %0 |
| `cs` | 0 | 1027 | %0 |
| `sv` | 0 | 1027 | %0 |
| `da` | 0 | 1027 | %0 |
| `no` | 0 | 1027 | %0 |
| `fi` | 0 | 1027 | %0 |
| `nl` | 0 | 1027 | %0 |
| `be` | 0 | 1027 | %0 |
| `sr` | 0 | 1027 | %0 |
| `hr` | 0 | 1027 | %0 |
| `de` | 553 | 474 | %54 |
| `ar` | 553 | 474 | %54 |
| `fr` | 553 | 474 | %54 |
| `es` | 553 | 474 | %54 |
| `pt` | 553 | 474 | %54 |
| `it` | 553 | 474 | %54 |
| `pl` | 553 | 474 | %54 |
| `ru` | 553 | 474 | %54 |
| `ja` | 553 | 474 | %54 |
| `zh` | 553 | 474 | %54 |
| `ko` | 553 | 474 | %54 |
| `hi` | 553 | 474 | %54 |
| `bn` | 553 | 474 | %54 |
| `pa` | 553 | 474 | %54 |
| `te` | 553 | 474 | %54 |
| `mr` | 553 | 474 | %54 |
| `ta` | 553 | 474 | %54 |
| `gu` | 553 | 474 | %54 |
| `kn` | 553 | 474 | %54 |
| `ml` | 553 | 474 | %54 |
| `th` | 553 | 474 | %54 |
| `vi` | 553 | 474 | %54 |
| `id` | 553 | 474 | %54 |
| `ms` | 553 | 474 | %54 |
| `tr` | 1027 | 0 | %100 |
| `en` | 1027 | 0 | %100 |

## Sıra önerisi

1. Hiç verisi olmayan diller (kapsam %1): tamamı İngilizce görünüyor.
2. Kısmi diller: eksik anahtarlar kullanıcının kaçamadığı ekranlarda.
3. Her parti sonrası `flutter test test/translation_coverage_test.dart`.
