# Play Console denetim kaynakları — 2026-08

## Yeni kişisel hesap test şartı

Kaynak: https://support.google.com/googleplay/android-developer/answer/14151465?hl=tr

13 Kasım 2023'ten sonra oluşturulan yeni kişisel geliştirici hesapları üretime erişmeden önce kapalı test çalıştırmalıdır. Üretim erişimi için başvuruda kapalı teste kesintisiz son 14 gündür kayıtlı en az 12 test kullanıcısı bulunmalıdır. Dahili test isteğe bağlıdır; kapalı test zorunlu ön koşuldur. Üretim başvurusunda test süreci, uygulama ve üretime hazırlık hakkında sorular yanıtlanır.

## Sağlık uygulaması beyanı

Kaynak: https://support.google.com/googleplay/android-developer/answer/13996367?hl=tr

Sigara bırakma ve sağlık/yaşam koçluğu uygulamaları sağlık uygulaması kapsamına girebilir. Play Console > Politika > Uygulama içeriği bölümündeki Health Apps declaration formu doldurulmalıdır. Uygulamanın sağlık amacı, kullanılan sağlık izinleri ve veri kullanım amacı doğru açıklanmalıdır.

## Hesap ve veri silme

Kaynak: https://support.google.com/googleplay/android-developer/answer/13327111?hl=tr

Uygulama hesap oluşturuyorsa kullanıcıya uygulama içinden hesap ve ilişkili verileri silme yolu ve ayrıca mağaza girişinde paylaşılabilecek bir web bağlantısı sağlanmalıdır. Veri güvenliği formundaki veri silme soruları yanıtlanmalıdır. Uygulama hesap oluşturmayı desteklemiyorsa bu özel hesap silme şartının kapsamı farklı olabilir; yine de veri silme ve saklama beyanları gerçek uygulama davranışıyla uyumlu olmalıdır.

## Denetim sırasında görülen proje durumu

- Son GitHub: `90d74c4`.
- `pubspec.yaml`: `version: 1.0.0+1`; Play yüklemesi için ileride versionCode artırılmalıdır.
- `applicationId`: `com.nikotinaway.app`.
- `targetSdk`: 37.
- `android/key.properties` ve release keystore çalışma alanında yok; mevcut Gradle ayarı keystore yoksa debug imzasına düşüyor. Bu AAB Play Store'a yüklenmemelidir.
- Çalışma alanında yalnızca `downloads/no_smoke-release.apk` bulunuyor; imzalı `.aab` yok.
- Flutter/Dart komutları sandbox'ta yok; yerel Flutter build/test gerekir.
- Veri güvenliği, gizlilik politikası ve izin gerekçesi dokümanları mevcut; bunların Play Console formuyla gerçek kod davranışı üzerinden son kontrolü gerekir.
