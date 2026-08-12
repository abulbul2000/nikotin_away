# Play Store Data Safety — Draft

Bu belge, Google Play Console'un "Data Safety" (Veri Güvenliği) formunu doldururken doğrudan referans alınmak üzere hazırlanmıştır. Play Console'daki kategori/soru yapısını birebir izler; buradaki her satır formdaki karşılığına kopyalanabilir. Kod tabanı taranarak (ağ çağrıları, native izinler, SQLite şeması) çıkarılmıştır — Faz 10 kapsamında, 2026-07-22. Abonelik/satın alma bölümü PARÇA 4 (14 gün deneme + zorunlu abonelik) kapsamında 2026-08-13'te eklendi.

**Önemli:** Bu bir taslaktır, Play Console'a gönderilmeden önce güncel kod durumuyla teyit edilmelidir (özellikle yeni bir izin/veri türü eklendiğinde bu dosya da güncellenmeli).

---

## 1) Genel Bakış

- Uygulama **varsayılan olarak cihaz-yerel** çalışır: kendi backend'i yok, kullanıcı hesabı sistemi yok.
- Tüm kalıcı veri SQLite (`no_smoke.db`) ve `SharedPreferences` içinde, cihazın kendi uygulama sanal alanında (`android:allowBackup="false"` — Android'in otomatik bulut yedeklemesine bile dahil edilmiyor).
- **Arayüz metinleri hiçbir ağ çağrısı yapmıyor.** Uygulama eskiden, hazır çevirisi olmayan bir cihaz dili seçildiğinde arayüz metinlerini `translate.googleapis.com`'dan çekiyordu; bu yol tamamen kaldırıldı (2026-07-29). Tüm diller uygulamanın içine gömülü tablodan çözülüyor, çevirisi eksik anahtarlar İngilizceye düşüyor. `lib/core/app_texts.dart` artık hiçbir I/O yapmıyor ve bunu bir test koruyor (`test/translation_coverage_test.dart`).
- **Firebase Crashlytics:** uygulama çöktüğünde, kişisel veri içermeyen teknik hata raporu (hata türü, stack trace, cihaz modeli) otomatik olarak gönderiliyor — bkz. Bölüm 4.
- **Firebase Storage (isteğe bağlı bulut yedekleme):** kullanıcı Ayarlar → Bulut Yedekleme'yi kendi belirlediği bir şifreyle açarsa, tüm yerel veritabanı cihaz üzerinde şifrelenip (AES-256-GCM) Firebase Storage'a yükleniyor. Şifre sunucuya hiç gönderilmiyor — bkz. Bölüm 4.
- **Yapay Zeka Mentörü (isteğe bağlı, kullanıcı sohbeti başlattığında):** `lib/pages/ai_chat_page.dart` kullanıcının yazdığı mesajı Firebase Functions (`functions/index.js`, `aiChat`) üzerinden bir üçüncü taraf AI sağlayıcısına (NVIDIA API, `nvidia/nemotron` modeli) iletiyor ve yanıtı gösteriyor. Bu, uygulamanın **tek kişisel-veri-içerikli** ağ yolu — bkz. Bölüm 4. Kullanıcı bu ekranı hiç açmazsa bu yol hiç tetiklenmez.
- **Abonelik doğrulama (Parça 4, Faz 3):** `lib/services/subscription_service.dart` cihaz üzerinde Google Play Billing (`in_app_purchase`) ile abonelik satın alıyor; `functions/subscription.js`'teki `verifyPlaySubscription` bu satın almanın `purchaseToken`'ını Google'ın `androidpublisher` API'siyle doğruluyor. Firestore'a veya başka bir kalıcı depoya **yazılmıyor** (stateless) — yalnızca doğrulama sonucu (aktif/süresi dolmuş) cihaza dönüyor. Bkz. Bölüm 2 ve 4.
- Reklam SDK'sı veya kullanıcı davranışı izleyen bir analitik SDK'sı **yok**.

---

## 2) "Bu uygulama hangi veri türlerini topluyor?" (Play Console kategorileri)

| Play Console Kategorisi | Toplanıyor mu? | Detay |
|---|---|---|
| **Konum — Yaklaşık** | Hayır (bkz. not) | Ham konum SQLite'a **hiç yazılmıyor**. Sadece opt-in "Konum Zekası" açıkken, tek seferlik bir GPS örneği anlık olarak işlenip en fazla 8 "önemli yer" merkez-noktasına indirgeniyor; bu merkez noktalar + geofence giriş/çıkış zaman damgaları saklanıyor, ham rota/iz asla değil. **Ek olarak** (opt-in "Sigara İçtim" butonu açıkken) her sigara kaydına, o an bu 8 yerden hangisine yakın olunduğunu gösteren bir **yer kimliği** yazılıyor — koordinat değil, mevcut bir merkez noktaya referans. Hiçbir yere yakın değilse boş kalıyor. |
| **Konum — Kesin** | Hayır | Aynı gerekçe — hiçbir zaman ham hassas koordinat kalıcı olarak tutulmuyor. Sigara kaydındaki yer bilgisi de koordinat değil, var olan bir merkez noktanın kimliği. |
| **Kişisel bilgiler — Ad** | Evet | Kullanıcının kendi girdiği isim (anket). Hesap/kimlik doğrulama amaçlı değil. |
| **Kişisel bilgiler — Diğer (yaş, cinsiyet, meslek)** | Evet | Anket verisi, risk skorlaması için. |
| **Sağlık ve fitness — Sağlık bilgileri** | Evet | Sigara alışkanlığı, nefes testi sonuçları, uyku tahmini (opt-in), nabız (opt-in, Health Connect), adım sayısı. |
| **Sağlık ve fitness — Fitness bilgileri** | Evet | Adım sayısı (donanım sensörü). |
| **Ses dosyaları — Ses kaydı** | **Hayır (işlenip atılıyor)** | Nefes testi mikrofonu kullanır ama ham ses **hiçbir zaman diske/veritabanına yazılmaz** — her ses parçası anlık enerji (RMS) değerine indirgenip bellekte hemen atılır. Play Console'da "toplanıyor ama saklanmıyor, anlık işleniyor" olarak işaretlenmeli. |
| **Uygulama etkinliği — Uygulama içi etkileşimler** | Evet | Görev tamamlama/erteleme, bildirim yanıtları — kişiselleştirme için. |
| **Uygulama bilgisi ve performansı — Çökme günlükleri** | Evet | Firebase Crashlytics ile otomatik gönderiliyor. Kullanıcı adı, anket cevabı veya sağlık verisi içermez — yalnızca teknik hata bilgisi. |
| **Cihaz veya diğer kimlikler** | Evet (sınırlı) | Firebase Crashlytics, çökme raporlarını cihazlar arasında ayırt edebilmek için anonim bir Firebase yükleme kimliği (installation ID) kullanır — reklam kimliği veya kişiyi tanımlayan bir kimlik değildir. |
| **Finansal bilgiler — Satın alma geçmişi** | Evet | Google Play Billing üzerinden abonelik durumu (ürün kimliği, satın alma jetonu) sunucu tarafında (`verifyPlaySubscription`) doğrulanmak üzere Google'ın kendi `androidpublisher` API'sine iletiliyor. Kart numarası/ödeme bilgisi uygulamaya hiç ulaşmıyor — ödeme tamamen Google Play tarafından yönetiliyor. Doğrulama sonucu kalıcı olarak sunucuda saklanmıyor. |
| **Mesajlar, Fotoğraf/Video, Kişiler, Takvim, Web geçmişi** | Hayır | Hiçbiri toplanmıyor. |
| **Uygulama etkinliği — Diğer eylemler (AI sohbet mesajları)** | Evet (isteğe bağlı) | Kullanıcı Yapay Zeka Mentörü ekranını açıp mesaj yazarsa, mesaj metni ve sohbet geçmişi (son ~20 mesaj) Firebase Functions üzerinden NVIDIA'nın AI API'sine işlenmek için gönderiliyor. Sohbet geçmişi yalnızca cihazda (bellekte, sayfa kapanınca silinir) tutuluyor; sunucu tarafında kalıcı olarak saklanmıyor (bkz. Bölüm 4). |

---

## 3) Veri Paylaşılıyor mu?

Kullanıcı verisi **hiçbir zaman satılmıyor veya reklam amacıyla paylaşılmıyor.** Google/Firebase/üçüncü taraf ile paylaşılan dört şey:
1. **Çökme raporları** (Firebase Crashlytics) — kişisel veri içermez, yalnızca teknik hata bilgisi. Google'ın [Firebase hizmet şartları](https://firebase.google.com/terms) kapsamında bir "hizmet sağlayıcı" paylaşımıdır, reklam/pazarlama amaçlı değildir.
2. **Şifreli yedek dosyası** (Firebase Storage) — yalnızca kullanıcı bulut yedeklemeyi kendi isteğiyle açarsa. Yüklenen dosya cihaz üzerinde şifrelenmiştir; Google (ya da biz) şifreyi bilmediği için içeriği okuyamaz.
3. **AI sohbet mesajları** (NVIDIA API, Firebase Functions üzerinden) — yalnızca kullanıcı Yapay Zeka Mentörü ekranını kendi isteğiyle açıp mesaj yazarsa. Mesaj metni işlenmek üzere NVIDIA'nın sunucularına gidiyor; bu bir "hizmet sağlayıcı" paylaşımıdır, reklam/pazarlama amaçlı değildir. **Play Console gönderiminden önce NVIDIA'nın veri saklama/işleme politikası incelenip bu bölüme eklenmeli.**
4. **Abonelik satın alma jetonu** (Google Play Billing → `androidpublisher` API) — abonelik durumu her kontrol edildiğinde. Bu paylaşım zaten Google'ın kendi ekosistemi içinde kalıyor (Play Billing → Play Developer API), üçüncü bir tarafa gitmiyor.

Bunların dışında uygulama hiçbir sunucuya bağlanmıyor.

---

## 4) Ağ Kullanımı Detayı (Play Console "veri aktarımı şifreli mi" sorusu için)

Uygulamanın **yalnızca dört** ağ yolu var, hepsi HTTPS:

- **Crashlytics:** `lib/main.dart` → `FirebaseCrashlytics` — uygulama çöktüğünde otomatik, HTTPS üzerinden. Kişisel veri göndermez.
- **Bulut yedekleme:** `lib/services/cloud_backup_service.dart` → Firebase Storage — yalnızca kullanıcı Ayarlar'dan açıp bir yedekleme/geri yükleme başlattığında, HTTPS üzerinden. Gönderilen içerik AES-256-GCM ile cihaz üzerinde önceden şifrelenmiştir; şifreleme anahtarı kullanıcının girdiği şifreden türetilir ve sunucuya hiçbir zaman gönderilmez.
- **AI sohbet:** `lib/services/ai_service.dart` → Firebase Functions (`aiChat`, `europe-west1`) → NVIDIA API — yalnızca kullanıcı Yapay Zeka Mentörü ekranını açıp mesaj gönderdiğinde, HTTPS üzerinden. Sohbet geçmişi cihazda yalnızca bellekte tutuluyor (sayfa kapanınca kaybolur), SQLite'a hiç yazılmıyor. Firebase Functions tarafı mesajı NVIDIA'ya iletmekten başka bir şey yapmıyor, kendi tarafında kalıcı log tutmuyor. AI'ın önerdiği ayar değişiklikleri (Koç Modu, ilaç saatleri) sunucu tarafında **uygulanmıyor** — yalnızca bir öneri olarak cihaza dönüyor, kullanıcı sohbette "Uygula" demeden hiçbir ayar değişmiyor; değiştiğinde de değişiklik doğrudan cihazdaki SQLite'a yazılıyor, sunucuya geri bildirilmiyor.
- **Abonelik doğrulama:** `lib/services/subscription_service.dart` → Firebase Functions (`verifySubscription`) → `functions/subscription.js`'teki `verifyPlaySubscription` → Google'ın `androidpublisher` API'si — abonelik durumu her kontrol edildiğinde (uygulama açılışı/resume, en fazla birkaç dakikada bir), HTTPS üzerinden. Gönderilen veri yalnızca ürün kimliği ve Play Billing'in verdiği satın alma jetonu; sunucu tarafı stateless, Firestore'a veya başka bir veritabanına yazmıyor, yalnızca doğrulama sonucunu (aktif/süresi dolmuş/deneme) cihaza döndürüyor.

---

## 5) Kullanıcı Kontrolü

- Her opt-in özellik (Uyku Zekası, Konum Zekası, Bileklik Verisi) kendi ayrı aç/kapat düğmesine sahip — Ayarlar ekranında açıklama + "neden" metniyle birlikte.
- **Faz 10 ile eklendi:** her açma/kapama kararı artık `consent_events` tablosunda tarih + o anki açıklama-metni sürümüyle kalıcı olarak kaydediliyor (KVKK'nın "parçalı açık rıza" ve rıza-geri-çekme kaydı beklentisini karşılıyor).
- Settings → "Verilerimi Sıfırla" tüm SQLite tablolarını (rıza kayıtları dahil) ve ayarları siliyor — kullanıcı istediği zaman geri dönülemez şekilde silebiliyor.

---

## 6) Bulunan Eksik (Play Console gönderiminden önce tamamlanmalı)

- Uygulamanın ayrı bir **Gizlilik Politikası** (privacy policy) URL'si Play Console'a girilmesi zorunlu — `docs/PRIVACY_POLICY.md` bu politikanın metnini içeriyor ama Play Console halka açık bir URL istiyor; bu ayrı bir iş kalemi (hosting + `[GELİŞTİRİCİ ADI]`/`[İLETİŞİM E-POSTASI]` gibi hâlâ doldurulmamış alanlar + hukuki gözden geçirme).
- **Play Console formunda manuel olarak yapılması gereken:** "Finansal bilgiler → Satın alma geçmişi" kategorisi işaretlenmeli (bkz. Bölüm 2, satır eklendi 2026-08-13). Bu belge referans olarak hazır ama formun kendisi Play Console arayüzünden elle doldurulmalı — bu iş dışarıdan otomatikleştirilemez.

---

## 7) Play Store "Health Apps" Ek Politikası (2026)

- Kullanılmayan izinler kaldırılmalı: mevcut `AndroidManifest.xml` izinleri (konum, aktivite tanıma, mikrofon, telefon durumu, bildirim, sağlık verisi) hepsi gerçekten kullanılan bir özelliğe bağlı — Faz 0/1'de zaten bu ilke uygulanmıştı (kullanılmayan konum izni önce kaldırılmış, sonra gerçek özellik eklenince geri konmuştu).
- Hassas sağlık verisi işe alım/sigorta amaçlı kullanılamaz kuralı — bu uygulamada zaten böyle bir kullanım yok, veri hiç cihaz dışına çıkmıyor.
