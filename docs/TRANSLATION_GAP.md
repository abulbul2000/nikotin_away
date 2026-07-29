# Çeviri boşluğu raporu

Referans: İngilizce tabloda **1027** anahtar.
Desteklenen dil: **39**.
Toplam eksik giriş: **22.519**.

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
| `de` | 645 | 382 | %63 |
| `ar` | 645 | 382 | %63 |
| `fr` | 645 | 382 | %63 |
| `es` | 645 | 382 | %63 |
| `pt` | 645 | 382 | %63 |
| `it` | 645 | 382 | %63 |
| `pl` | 645 | 382 | %63 |
| `ru` | 645 | 382 | %63 |
| `ja` | 645 | 382 | %63 |
| `zh` | 645 | 382 | %63 |
| `ko` | 645 | 382 | %63 |
| `hi` | 645 | 382 | %63 |
| `bn` | 645 | 382 | %63 |
| `pa` | 645 | 382 | %63 |
| `te` | 645 | 382 | %63 |
| `mr` | 645 | 382 | %63 |
| `ta` | 645 | 382 | %63 |
| `gu` | 645 | 382 | %63 |
| `kn` | 645 | 382 | %63 |
| `ml` | 645 | 382 | %63 |
| `th` | 645 | 382 | %63 |
| `vi` | 645 | 382 | %63 |
| `id` | 645 | 382 | %63 |
| `ms` | 645 | 382 | %63 |
| `tr` | 1027 | 0 | %100 |
| `en` | 1027 | 0 | %100 |

## Sıra önerisi

1. Hiç verisi olmayan diller (kapsam %1): tamamı İngilizce görünüyor.
2. Kısmi diller: eksik anahtarlar kullanıcının kaçamadığı ekranlarda.
3. Her parti sonrası `flutter test test/translation_coverage_test.dart`.
