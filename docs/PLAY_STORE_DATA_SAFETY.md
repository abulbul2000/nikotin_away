# Play Store Data Safety — Draft

Bu belge, Google Play Console'un "Data Safety" (Veri Güvenliği) formunu doldururken doğrudan referans alınmak üzere hazırlanmıştır. Play Console'daki kategori/soru yapısını birebir izler; buradaki her satır formdaki karşılığına kopyalanabilir. Kod tabanı taranarak (ağ çağrıları, native izinler, SQLite şeması) çıkarılmıştır — Faz 10 kapsamında, 2026-07-22.

**Önemli:** Bu bir taslaktır, Play Console'a gönderilmeden önce güncel kod durumuyla teyit edilmelidir (özellikle yeni bir izin/veri türü eklendiğinde bu dosya da güncellenmeli).

---

## 1) Genel Bakış

- Uygulama **tamamen cihaz-yerel** çalışır: kendi backend'i / bulut senkronizasyonu / kullanıcı hesabı sistemi yok.
- Tüm kalıcı veri SQLite (`no_smoke.db`) ve `SharedPreferences` içinde, cihazın kendi uygulama sanal alanında (`android:allowBackup="false"` — Android'in otomatik bulut yedeklemesine bile dahil edilmiyor).
- **Tek istisna:** nadir görülen bir cihaz dili seçildiğinde (uygulamanın önceden hazırladığı 39 dilin dışında bir dil), arayüz metinlerini çevirmek için `translate.googleapis.com`'a tek seferlik bir HTTP isteği gidiyor — bkz. Bölüm 4.
- Reklam SDK'sı, analitik SDK'sı (Firebase/Crashlytics/Sentry vb.), üçüncü parti çökme raporlama **yok**.

---

## 2) "Bu uygulama hangi veri türlerini topluyor?" (Play Console kategorileri)

| Play Console Kategorisi | Toplanıyor mu? | Detay |
|---|---|---|
| **Konum — Yaklaşık** | Hayır (bkz. not) | Ham konum SQLite'a **hiç yazılmıyor**. Sadece opt-in "Konum Zekası" açıkken, tek seferlik bir GPS örneği anlık olarak işlenip en fazla 8 "önemli yer" merkez-noktasına indirgeniyor; bu merkez noktalar + geofence giriş/çıkış zaman damgaları saklanıyor, ham rota/iz asla değil. |
| **Konum — Kesin** | Hayır | Aynı gerekçe — hiçbir zaman ham hassas koordinat kalıcı olarak tutulmuyor. |
| **Kişisel bilgiler — Ad** | Evet | Kullanıcının kendi girdiği isim (anket). Hesap/kimlik doğrulama amaçlı değil. |
| **Kişisel bilgiler — Diğer (yaş, cinsiyet, meslek)** | Evet | Anket verisi, risk skorlaması için. |
| **Sağlık ve fitness — Sağlık bilgileri** | Evet | Sigara alışkanlığı, nefes testi sonuçları, uyku tahmini (opt-in), nabız (opt-in, Health Connect), adım sayısı. |
| **Sağlık ve fitness — Fitness bilgileri** | Evet | Adım sayısı (donanım sensörü). |
| **Ses dosyaları — Ses kaydı** | **Hayır (işlenip atılıyor)** | Nefes testi mikrofonu kullanır ama ham ses **hiçbir zaman diske/veritabanına yazılmaz** — her ses parçası anlık enerji (RMS) değerine indirgenip bellekte hemen atılır. Play Console'da "toplanıyor ama saklanmıyor, anlık işleniyor" olarak işaretlenmeli. |
| **Uygulama etkinliği — Uygulama içi etkileşimler** | Evet | Görev tamamlama/erteleme, bildirim yanıtları — kişiselleştirme için. |
| **Uygulama bilgisi ve performansı** | Hayır | Çökme/tanılama verisi toplayan bir SDK yok. |
| **Cihaz veya diğer kimlikler** | Hayır | Reklam kimliği, cihaz kimliği okunmuyor/toplanmıyor. |
| **Finansal bilgiler, Mesajlar, Fotoğraf/Video, Kişiler, Takvim, Web geçmişi** | Hayır | Hiçbiri toplanmıyor. |

---

## 3) Veri Paylaşılıyor mu?

**Hayır** — hiçbir veri üçüncü bir şirkete satılmıyor veya reklam/analitik amacıyla paylaşılmıyor. Tek ağ çağrısı (Bölüm 4) kişisel veri içermez, sadece statik arayüz metni gönderir.

---

## 4) Ağ Kullanımı Detayı (Play Console "veri aktarımı şifreli mi" sorusu için)

- **Ne:** `lib/core/app_texts.dart` → `_translateBatch` → `https://translate.googleapis.com/translate_a/single` (HTTPS).
- **Ne zaman:** Sadece kullanıcının cihaz dili, önceden hazırlanmış 39 dilin **hiçbirine** denk gelmediğinde, o dilde İLK açılışta.
- **Ne gönderiliyor:** Uygulamanın kendi İngilizce arayüz metinleri (buton/etiket yazıları) — kullanıcıya ait hiçbir kişisel veri, anket cevabı veya sağlık verisi gönderilmiyor.
- **Sonuç nerede saklanıyor:** Çeviri sonucu cihazda `SharedPreferences`'a önbelleğe alınıyor, bir daha o dil için ağ çağrısı yapılmıyor.
- **Play Console'da işaretlenecek:** "Veri şifreli aktarılıyor mu" → Evet (HTTPS). "Bu veri paylaşımı" → Hayır (bu üçüncü-parti bir çeviri servisine tek seferlik bir istektir, kullanıcı verisi değil, kalıcı bir "veri paylaşımı ortaklığı" değil) — ama şeffaflık için gizlilik politikasında bu davranış açıkça belirtilmeli (şu an belirtilmiyor, bkz. Bölüm 6).

---

## 5) Kullanıcı Kontrolü

- Her opt-in özellik (Uyku Zekası, Konum Zekası, Bileklik Verisi) kendi ayrı aç/kapat düğmesine sahip — Ayarlar ekranında açıklama + "neden" metniyle birlikte.
- **Faz 10 ile eklendi:** her açma/kapama kararı artık `consent_events` tablosunda tarih + o anki açıklama-metni sürümüyle kalıcı olarak kaydediliyor (KVKK'nın "parçalı açık rıza" ve rıza-geri-çekme kaydı beklentisini karşılıyor).
- Settings → "Verilerimi Sıfırla" tüm SQLite tablolarını (rıza kayıtları dahil) ve ayarları siliyor — kullanıcı istediği zaman geri dönülemez şekilde silebiliyor.

---

## 6) Bulunan Eksik (Play Console gönderiminden önce tamamlanmalı)

- Uygulamanın ayrı bir **Gizlilik Politikası** (privacy policy) URL'si Play Console'a girilmesi zorunlu — bu proje deposunda böyle bir belge/URL bulunamadı. Bu belge (PLAY_STORE_DATA_SAFETY.md) o politikanın teknik kaynağı olarak kullanılabilir ama Play Console halka açık bir URL istiyor; bu ayrı bir iş kalemi (hosting + hukuki dil).
- Google Translate yedek mekanizması gizlilik politikasında açıkça belirtilmemiş (yukarıda not edildi).

---

## 7) Play Store "Health Apps" Ek Politikası (2026)

- Kullanılmayan izinler kaldırılmalı: mevcut `AndroidManifest.xml` izinleri (konum, aktivite tanıma, mikrofon, telefon durumu, bildirim, sağlık verisi) hepsi gerçekten kullanılan bir özelliğe bağlı — Faz 0/1'de zaten bu ilke uygulanmıştı (kullanılmayan konum izni önce kaldırılmış, sonra gerçek özellik eklenince geri konmuştu).
- Hassas sağlık verisi işe alım/sigorta amaçlı kullanılamaz kuralı — bu uygulamada zaten böyle bir kullanım yok, veri hiç cihaz dışına çıkmıyor.
