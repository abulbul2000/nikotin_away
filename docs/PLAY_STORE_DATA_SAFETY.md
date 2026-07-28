# Play Store Data Safety — Draft

Bu belge, Google Play Console'un "Data Safety" (Veri Güvenliği) formunu doldururken doğrudan referans alınmak üzere hazırlanmıştır. Play Console'daki kategori/soru yapısını birebir izler; buradaki her satır formdaki karşılığına kopyalanabilir. Kod tabanı taranarak (ağ çağrıları, native izinler, SQLite şeması) çıkarılmıştır — Faz 10 kapsamında, 2026-07-22.

**Önemli:** Bu bir taslaktır, Play Console'a gönderilmeden önce güncel kod durumuyla teyit edilmelidir (özellikle yeni bir izin/veri türü eklendiğinde bu dosya da güncellenmeli).

---

## 1) Genel Bakış

- Uygulama **varsayılan olarak cihaz-yerel** çalışır: kendi backend'i yok, kullanıcı hesabı sistemi yok.
- Tüm kalıcı veri SQLite (`no_smoke.db`) ve `SharedPreferences` içinde, cihazın kendi uygulama sanal alanında (`android:allowBackup="false"` — Android'in otomatik bulut yedeklemesine bile dahil edilmiyor).
- **Google Translate:** nadir görülen bir cihaz dili seçildiğinde (uygulamanın önceden hazırladığı 39 dilin dışında bir dil), arayüz metinlerini çevirmek için `translate.googleapis.com`'a tek seferlik bir HTTP isteği gidiyor — bkz. Bölüm 4.
- **Firebase Crashlytics:** uygulama çöktüğünde, kişisel veri içermeyen teknik hata raporu (hata türü, stack trace, cihaz modeli) otomatik olarak gönderiliyor — bkz. Bölüm 4.
- **Firebase Storage (isteğe bağlı bulut yedekleme):** kullanıcı Ayarlar → Bulut Yedekleme'yi kendi belirlediği bir şifreyle açarsa, tüm yerel veritabanı cihaz üzerinde şifrelenip (AES-256-GCM) Firebase Storage'a yükleniyor. Şifre sunucuya hiç gönderilmiyor — bkz. Bölüm 4.
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
| **Finansal bilgiler, Mesajlar, Fotoğraf/Video, Kişiler, Takvim, Web geçmişi** | Hayır | Hiçbiri toplanmıyor. |

---

## 3) Veri Paylaşılıyor mu?

Kullanıcı verisi **hiçbir zaman satılmıyor veya reklam amacıyla paylaşılmıyor.** Google/Firebase ile paylaşılan tek iki şey:
1. **Çökme raporları** (Firebase Crashlytics) — kişisel veri içermez, yalnızca teknik hata bilgisi. Google'ın [Firebase hizmet şartları](https://firebase.google.com/terms) kapsamında bir "hizmet sağlayıcı" paylaşımıdır, reklam/pazarlama amaçlı değildir.
2. **Şifreli yedek dosyası** (Firebase Storage) — yalnızca kullanıcı bulut yedeklemeyi kendi isteğiyle açarsa. Yüklenen dosya cihaz üzerinde şifrelenmiştir; Google (ya da biz) şifreyi bilmediği için içeriği okuyamaz.

Çeviri isteği (Bölüm 4) kişisel veri içermez, sadece statik arayüz metni gönderir.

---

## 4) Ağ Kullanımı Detayı (Play Console "veri aktarımı şifreli mi" sorusu için)

- **Çeviri:** `lib/core/app_texts.dart` → `_translateBatch` → `https://translate.googleapis.com/translate_a/single` (HTTPS). Sadece kullanıcının cihaz dili, önceden hazırlanmış 39 dilin **hiçbirine** denk gelmediğinde, o dilde İLK açılışta. Uygulamanın kendi İngilizce arayüz metinleri dışında hiçbir şey gönderilmiyor. Sonuç cihazda `SharedPreferences`'a önbelleğe alınıyor. Play Console: "Veri şifreli aktarılıyor mu" → Evet (HTTPS); "veri paylaşımı" değil, kullanıcı verisi içermiyor.
- **Crashlytics:** `lib/main.dart` → `FirebaseCrashlytics` — uygulama çöktüğünde otomatik, HTTPS üzerinden. Kişisel veri göndermez.
- **Bulut yedekleme:** `lib/services/cloud_backup_service.dart` → Firebase Storage — yalnızca kullanıcı Ayarlar'dan açıp bir yedekleme/geri yükleme başlattığında, HTTPS üzerinden. Gönderilen içerik AES-256-GCM ile cihaz üzerinde önceden şifrelenmiştir; şifreleme anahtarı kullanıcının girdiği şifreden türetilir ve sunucuya hiçbir zaman gönderilmez.

---

## 5) Kullanıcı Kontrolü

- Her opt-in özellik (Uyku Zekası, Konum Zekası, Bileklik Verisi) kendi ayrı aç/kapat düğmesine sahip — Ayarlar ekranında açıklama + "neden" metniyle birlikte.
- **Faz 10 ile eklendi:** her açma/kapama kararı artık `consent_events` tablosunda tarih + o anki açıklama-metni sürümüyle kalıcı olarak kaydediliyor (KVKK'nın "parçalı açık rıza" ve rıza-geri-çekme kaydı beklentisini karşılıyor).
- Settings → "Verilerimi Sıfırla" tüm SQLite tablolarını (rıza kayıtları dahil) ve ayarları siliyor — kullanıcı istediği zaman geri dönülemez şekilde silebiliyor.

---

## 6) Bulunan Eksik (Play Console gönderiminden önce tamamlanmalı)

- Uygulamanın ayrı bir **Gizlilik Politikası** (privacy policy) URL'si Play Console'a girilmesi zorunlu — `docs/PRIVACY_POLICY.md` bu politikanın metnini içeriyor ama Play Console halka açık bir URL istiyor; bu ayrı bir iş kalemi (hosting + `[GELİŞTİRİCİ ADI]`/`[İLETİŞİM E-POSTASI]` gibi hâlâ doldurulmamış alanlar + hukuki gözden geçirme).

---

## 7) Play Store "Health Apps" Ek Politikası (2026)

- Kullanılmayan izinler kaldırılmalı: mevcut `AndroidManifest.xml` izinleri (konum, aktivite tanıma, mikrofon, telefon durumu, bildirim, sağlık verisi) hepsi gerçekten kullanılan bir özelliğe bağlı — Faz 0/1'de zaten bu ilke uygulanmıştı (kullanılmayan konum izni önce kaldırılmış, sonra gerçek özellik eklenince geri konmuştu).
- Hassas sağlık verisi işe alım/sigorta amaçlı kullanılamaz kuralı — bu uygulamada zaten böyle bir kullanım yok, veri hiç cihaz dışına çıkmıyor.
