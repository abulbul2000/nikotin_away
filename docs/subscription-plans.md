# Nicotine Away abonelik planları

## Ürün planları

Nicotine Away, ücretsiz temel özellikler ve üç ücretli AI planı kullanır. Ücretli planlar otomatik yenilenen aylık abonelik olarak Play Console'da oluşturulmalıdır.

| Ürün kimliği | Mağaza adı | Aylık fiyat | Günlük AI limiti | Aylık AI limiti |
| --- | --- | ---: | ---: | ---: |
| `no_smoke_starter` | Nicotine Away Starter | 4.99 USD | 10 mesaj | 300 mesaj |
| `no_smoke_plus` | Nicotine Away Plus | 9.99 USD | 30 mesaj | 900 mesaj |
| `no_smoke_pro` | Nicotine Away Pro | 19.99 USD | 60 mesaj | 1.800 mesaj |

Fiyatlar Google Play'de USD temel fiyatı olarak belirlenebilir; Play Console'un ülke ve bölge fiyat ayarlarıyla kullanıcıya yerel para birimi gösterilir. Ürün kimlikleri yayınlandıktan sonra değiştirilmemelidir.

## Erişim kuralları

`flutter run` ile çalışan debug sürümü abonelik istemeden AI'yi kullanır. Bu sürüm yalnızca ayrı geliştirme Firebase projesine bağlanmalıdır. Geliştirme Functions ortamında `AI_DEBUG_BYPASS=true` kullanılabilir ve debug istemcisi `debugClient=true` gönderir. Debug bypass üretim Firebase projesinde kesinlikle etkinleştirilmemelidir.

Play Store release sürümü `kDebugMode` false olduğu için debug bypass göndermez. Üretim `aiChat` Function'ı, kullanıcıya kaydedilmiş Google Play satın alma tokenını Google Play Developer API ile yeniden doğrular. Aktif ürün `no_smoke_starter`, `no_smoke_plus` veya `no_smoke_pro` değilse AI reddedilir.

## Maliyet koruması

Kota istemci tarafında değil, Cloud Function içinde iki sayaçla uygulanır: kullanıcı/gün ve kullanıcı/ay. İstemci değiştirilse bile günlük ve aylık limit aşılamaz. Gemini çağrısında sohbet geçmişi ve çıktı uzunluğu da sınırlandırılmalıdır. Uygulama mağazası açıklamasında AI kullanımının plan kotasına tabi olduğu açıkça belirtilmelidir; sınırsız AI vaadi yapılmamalıdır.

## Dağıtım sırası

Önce Play Console'da üç abonelik oluşturulmalı ve her biri için otomatik yenilenen aylık temel plan etkinleştirilmelidir. Sonra üretim Firebase Functions'a `GEMINI_API_KEY` secret'ı yüklenmeli, Google Play Developer API için Functions hizmet hesabına gerekli erişim verilmelidir. En son release AAB kapalı test kanalına yüklenmelidir.

Debug testinde `flutter run` ayrı geliştirme Firebase projesiyle çalıştırılmalı; üretim testinde Play Store kapalı testten yüklenen release AAB kullanılmalıdır. Flutter SDK bu sandbox ortamında kurulu olmadığı için Dart/Flutter analizinin yerelde veya CI'da ayrıca çalıştırılması gerekir.
