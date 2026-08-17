# Faz 2 — Mevcut Kod, Firebase ve Play Console Denetimi

## Denetim sonucu

Mevcut proje çalışır bir Flutter/Firebase temeline sahip ve AI, abonelik, ses, konum, uyku, görev, bildirim ve sağlık özellikleri için geniş bir kod altyapısı bulunuyor. Faz 2 kapsamında işlevsel kod değiştirilmedi; bu rapor mevcut durum ve sonraki fazlarda ele alınacak riskleri kaydeder.

## 1. Firebase ortamı

Uygulamanın Flutter ve Android yapılandırmaları şu anda `no-smoke-7dd2e` Firebase projesini gösteriyor. `firebase.json`, `lib/firebase_options.dart` ve Android Google Services yapılandırması aynı proje kimliğine bağlı.

İş planında Development ve Production projeleri ayrı olarak tanımlanmış olsa da, bu depo içindeki varsayılan istemci yapılandırmasında açık bir flavor veya ayrı Production Firebase seçimi bulunmadığı görüldü. Faz 3’te Development/Production ayrımı, release yapılandırması ve Cloud Functions dağıtım hedefi kesinleştirilecek.

## 2. AI ve abonelik kapısı

Flutter tarafında debug derlemesi `kDebugMode` ile ücretsiz erişime izin veriyor. Üretim tarafında abonelik durumu kontrol ediliyor. Sunucu tarafında AI çağrısı kimlik doğrulaması, plan kontrolü, Play abonelik doğrulaması ve günlük/aylık kota ile korunuyor.

Sunucuda üç plan tanımı bulundu:

| Plan | Günlük kota | Aylık kota |
|---|---:|---:|
| Starter | 10 | 300 |
| Plus | 30 | 900 |
| Pro | 60 | 1800 |

AI anahtarı kaynak koda gömülmemiş; Firebase Secret Manager üzerinden `GEMINI_API_KEY` olarak kullanılıyor. Model adı mevcut kodda `gemini-3.6-flash` olarak görünüyor.

Faz 6’da üretim ve debug ayrımı gerçek release senaryosunda test edilecek. Ayrıca Play Console ürün kimliklerinin gerçek abonelik ürünleriyle birebir eşleştiği doğrulanacak.

## 3. App Check ve kimlik doğrulama

Debug derlemesinde App Check yalnızca açıkça debug token verilirse etkinleştiriliyor; geliştirme Cloud Functions tarafında App Check zorlaması kapalı tutuluyor. Release derlemesinde Android Play Integrity sağlayıcısı etkinleştiriliyor.

Uygulama başlangıçta Firebase anonim girişini deniyor. Google ve e-posta hesabı akışlarının anonim kullanıcıdan kalıcı UID’ye geçerken yerel ve bulut verilerini kaybetmeden birleştirmesi Faz 3’te ayrıca test edilmelidir.

## 4. Firestore ve Storage güvenliği

Firestore kuralları kullanıcı verilerini UID ile sınırlandırıyor; `user_data/{uid}` ağacına yalnızca aynı UID’ye sahip doğrulanmış kullanıcı erişebiliyor. Bununla birlikte Firestore ve Storage kurallarının canlı Firebase projelerinde gerçekten dağıtılmış ve test edilmiş olması Faz 3 ve Faz 10’da doğrulanacak.

## 5. Android izin ve Play Console yüzeyi

Manifest; bildirim, konum ve arka plan konumu, mikrofon, foreground microphone service, overlay, exact alarm, Health Connect uyku ve kalp atışı, activity recognition, boot receiver, battery optimization, usage stats ve foreground service izinlerini içeriyor.

Bu izinlerin tamamı Play Console açısından hassas kabul edilebilecek bir yüzey oluşturuyor. Faz 10’da her iznin gerçekten gerekli olup olmadığı, uygulama içi açıklaması, runtime izin sırası, Data Safety beyanı, Health Apps declaration ve SYSTEM_ALERT_WINDOW gerekçesi ayrı ayrı doğrulanacak.

## 6. Uyku ve ses analizi

Uygulamada gece ses/horlama yakalama servisi ve uyku zekâsı altyapısı bulunuyor. Ürün kararı doğrultusunda mevcut testler içindeki horlama testi kaldırılmalı; kullanıcı uyandığında kısa ve yumuşak uyku özeti bildirimi kullanılmalı. Ham sesin saklanmaması, izin akışı ve tıbbi tanı iddiası bulunmaması Faz 4, 8 ve 10’da doğrulanacak.

## 7. Play Store hazırlığı

Veri güvenliği çalışma taslağı mevcut; ancak gerçek Firebase, Storage, AI sağlayıcısı ve hesap silme davranışıyla son kez eşleştirilmesi gerekiyor. Hesap silme web bağlantısı, herkese açık gizlilik politikası, Health Apps declaration ve hassas izin açıklamaları AAB öncesi tamamlanmalı.

Android release yapılandırmasında imzalama anahtarı yoksa debug imzalama yapılandırmasına düşme riski ayrıca kontrol edilmelidir. Release AAB oluşturulmadan önce zorunlu imzalama anahtarı doğrulanmalıdır.

## Faz 2 kararı

Mevcut mimari, sonraki geliştirmeler için yeterli temel sunuyor. Ancak en önemli sonraki çalışma alanları şunlardır:

1. Development/Production Firebase ayrımını net ve güvenli hâle getirmek.
2. Google, e-posta ve anonim kullanıcı verilerini kayıpsız birleştirmek.
3. Bulut yedekleme ve Firestore/Storage canlı kurallarını doğrulamak.
4. Onaylanan ekran ve uyku zekâsı tasarımlarını uygulamak.
5. Play Console hassas izin ve sağlık beyanlarını gerçek davranışla eşleştirmek.

Bu raporla Faz 2 denetimi tamamlanmıştır; kod değişikliği yapılmamıştır.
