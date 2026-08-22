

## 2. Veri, davranış motoru ve arka plan akışları — ara bulgular

### Olumlu bulgular

`StorageService.loadReductionProgress` artık yalnızca `smoking_events` ve görev sonuçları gibi kanıtlardan streak hesaplıyor; geçmişte veri olmayan günleri başarı saymıyor. Kaçınılan sigara hesabı ise yalnızca akşam rutiniyle kaydedilen doğrulanmış günlük toplamdan (`verifiedSmokingByDay`) yapılıyor. Bu, kullanıcının hızlı kayıt düğmesine basmamasını otomatik olarak “sigara içmedi” diye yorumlamıyor.

Görev planlayıcı, başarı/erteleme/sigara içildi/missed sonuçlarına göre öz-denetim, zorluk, kapasite ve hareketli başarı oranını güncelliyor. Plan üretiminde 4–8 görev aralığı, riskli saatler, uyku ve engelli zaman pencereleri hesaba katılıyor; yalnızca geçen takvim gününe göre ilerleme verme hatası için koruma yorumları mevcut.

`DailyPlanRefreshService` günlük 00:05 civarında planı uygulama açılmadan yenilemeyi hedefliyor ve yeniden başlatma sonrası tekrar kurulacak şekilde tanımlanmış. Görev tetikleyicileri ve watchdog yeniden denemeleri native receiver katmanında tutuluyor; bu, yalnızca Flutter UI yaşam döngüsüne bağımlı olmaktan daha sağlam.

### Kritik riskler / onarım adayları

1. **Uyku probu çok sık ve exact wakeup kullanıyor.** Native `SleepProbeReceiver` varsayılan 5 dakikalık aralıkla `setExactAndAllowWhileIdle` çağırıyor. Bu, uyku penceresinde gece başına yaklaşık 100 civarı alarm/sensör uyanışı anlamına gelebilir. Her probda yaklaşık 600 ms accelerometer örneklemesi düşük maliyetli olsa da exact + wakeup + Doze kırılması pil dostu varsayılanla çelişiyor. Uyku zekâsı için daha seyrek örnekleme, inexact alarm veya Health Connect/wearable verisi olan cihazlarda probu kapatma değerlendirilmeli.

2. **Günlük plan yenilemesi de `exact: true` ve `wakeup: true` kullanıyor.** 00:05 plan yenilemesi kullanıcı açısından saniyesi kritik bir alarm değil. Android resmi rehberleri bu tür işler için inexact alarm/WorkManager yaklaşımını öneriyor; exact alarm izni reddedildiğinde fallback davranışının gerçek cihazda ayrıca doğrulanması gerekiyor.

3. **Tam ekran overlay mağaza/politika riski taşıyor.** Android 14+ full-screen intent arama ve alarm uygulamalarıyla sınırlandırılıyor. Nicotine Away görev/mentor overlay'i tam ekran kullanıyorsa, Android 14/15/16'da izin reddedildiğinde güvenli heads-up fallback kesin olarak test edilmeli; Play Console deklarasyonu da ürünün gerçek alarm işleviyle uyumlu olmalı.

4. **Bildirim arşivi ve bildirim silme politikasının kod yolları çapraz doğrulanmalı.** Kullanıcı gereksinimi her bildirimin uygulama içi arşive alınması ve 24 saat sonra silinmesi. Notification history yazma, payload açılışı, background action ve cleanup noktalarının tüm bildirim türlerinde aynı kapsama sahip olduğu henüz kanıtlanmış değil.

5. **Sağlık tavsiyesi havuzunda ürün gereksinimi ile kod isimleri arasında belirsizlik var.** Kullanıcı 7 genel + 8 koşula özel istemişti. Kodda `_healthTipGeneralCount = 7`, fakat koşulsuz kullanıcıda 15 slot; 7 genel + 8 smoking/condition-neutral slot olarak dağıtılıyor. Koşullu kullanıcıda ilk 7 genel, kalan 8 hastalık tavsiyesi oluyor. Bu mantık gereksinimle uyumlu görünüyor; ancak `_healthTipsGeneralCount = 5` ve `_healthTipsGeneralDiseaseCount = 10` gibi eski havuz sabitleri de dosyada duruyor ve yanlışlıkla başka çağrı yolunda kullanılıp kullanılmadığı test edilmeli.

6. **Dil sayısı 38 değil 40.** `LanguageService.supportedLanguages` içinde 40 kod var: `tr,en,de,ar,fr,es,pt,it,pl,ru,ja,zh,ko,hi,bn,pa,te,mr,ta,gu,kn,ml,th,vi,id,ms,fil,uk,ro,el,hu,cs,sv,da,no,fi,nl,be,sr,hr`. Bu tek başına hata olmayabilir, fakat mağaza metinleri, TTS/STT ve tüm sağlık/uyku bildirimi anahtarları için resmi destek matrisiyle netleştirilmeli.

### Doğrulama sınırı

Sandbox ortamında Flutter/Dart SDK bulunmadığından `flutter analyze`, `flutter test` ve release APK build'i burada çalıştırılamadı. Bu aşamadaki bulgular statik kaynak incelemesine dayanıyor; Windows ortamında gerçek cihaz matrisiyle doğrulama zorunlu.


### Bildirim arşivi için kritik yeni bulgu

`NotificationService._zonedSchedule` planlama işlemi tamamlandıktan hemen sonra `_recordNotificationHistory` çağırıyor. `NotificationHistoryService.record` varsayılan `receivedAt` olarak o anki zamanı kullanıyor ve `expiresAt = receivedAt + 24 saat` hesaplıyor. Dolayısıyla planlanan bildirim, kullanıcıya gerçekten gösterilmeden saatler önce arşive yazılıyor ve 24 saatlik saklama süresi teslimattan değil planlama anından başlıyor. Ayrıca `_show` ve `_zonedSchedule` aynı ortak dedupe mantığını kullanıyor; günlük tekrar eden bildirimlerde planlama ve gerçek gösterim kayıtlarının nasıl birleştiği test edilmeli. Gereksinim kesin olarak “teslimattan itibaren 24 saat” ise planlanmış bildirimler için teslim zamanı ayrı tutulmalı veya native/background teslim callback'i arşivlemeli; mevcut haliyle bu madde yayın öncesi P0/P1 onarım adayıdır.


### Görev motoru için ek değerlendirme

Görev saatleri `Random()` ve riskli saat profilleriyle değişken üretiliyor; sabit dakika değerine kilitlenmiş tek bir planlayıcı görünmüyor. Buna karşın gerçek teslimatta iki ayrı katman var: Dart tarafındaki plan/bildirim zamanlaması ve native `TaskTriggerReceiver`. Her iki katmanın aynı plan kimliği, iptal ve yeniden kurma davranışını release APK'da doğrulamak gerekiyor. Özellikle gün içinde ayar değiştirildiğinde eski native PendingIntent'lerin kalıp yeni planla üst üste binmemesi kritik.

Dart `NotificationService._resolveAndroidScheduleMode` exact alarm iznini sorgulayıp inexact fallback veriyor. Ancak `DailyPlanRefreshService` doğrudan `AndroidAlarmManager.periodic(... exact: true, wakeup: true)` kullandığından bu korumadan geçmiyor. Native `StepProbeReceiver` de doğrudan `setExactAndAllowWhileIdle` çağırıyor; exact alarm izninin reddedildiği yeni Android kurulumunda exception veya sessiz plan kaybı olasılığı test edilmelidir.

`StorageService` hızlı sigara kayıtlarını günlük toplam yerine alt sınır kanıtı olarak görüyor; bu doğru. Ancak kullanıcı akşam doğrulamasını hiç tamamlamazsa uygulama `cigarettesAvoided` değerini artırmamalı ve UI bunu açıkça “doğrulanmadı” olarak göstermeli. Bu davranışın Home, Personal Progress, Reports, AI Mentor ve notification body yollarında aynı olup olmadığı uçtan uca test edilmelidir.


## 3. AI Mentor, Uyku Zekâsı ve dil kapsamı — ara bulgular

### AI Mentor

Sunucu `SUPPORTED_AI_LANGUAGES` kümesinde 40 dil kodu bulunuyor; ancak Flutter `ai_service.dart` içindeki `_allowedResponseLanguages` yalnızca 14 dili (`tr,en,de,ar,fr,es,pt,it,pl,ru,ja,zh,ko,hi`) kabul ediyor. Sunucu 26 ek dilde doğru cevap verse bile istemci bunu “desteklenmeyen dil” sayıp kullanıcıya göstermeyebilir. Bu, 38 dil gereksinimiyle doğrudan uyumsuz ve yayın öncesi P0 düzeyinde düzeltilmelidir. Tek bir ortak dil manifestosu veya istemci kümesinin sunucuyla birebir eşitlenmesi önerilir.

`sendMessageToAI` release build içinde doğrudan reddediliyor; server tarafında da debug bypass yalnızca development Firebase projesi/debugClient koşuluna bağlanmış, üretimde App Check ve Play abonelik doğrulaması var. Bu ayrım güvenlik açısından doğru yönde. Ancak kullanıcının AI Mentor’un release APK’da hiç çalışmaması bilinçli bir ürün kararıysa UI metni bunu açıkça belirtmeli; release’te AI’nin abonelikle çalışması isteniyorsa istemci tarafındaki `!kDebugMode` kesinlikle ürün gereksinimiyle yeniden mutabık kalınmalı.

AI eylemleri sayım, koç modu, ilaç saatleri ve izin açma ile sınırlı; istemci argüman doğrulaması mevcut. Buna rağmen 38 dilde eylem onay mesajlarının, ilaç adının hassas sağlık verisi olarak saklanmasının ve eylem başarısızlığında kullanıcıya doğru hata verilmesinin uçtan uca testleri eksik görünüyor. Kullanıcının talep ettiği `mehmet.bulbul0663@gmail.com` hesabı için Firebase/Playground kimlik doğrulaması bu statik denetimden doğrulanamaz; hesap bağımlılığını kaynak koda gömmemek gerekir.

### Uyku Zekâsı

Uyku özelliği opt-in, ekran/şarj durumundan pencere öğreniyor ve tatil modu probu iptal ediyor. Sabah raporu planlanan uyanıştan bir saat sonra gönderiliyor; rapor payload ile uygulama açılıp overlay gösteriyor. Ancak aynı özellik varsayılan 5 dakikalık gece probuna bağlı ve her probda wakeup alarmı/sensör örneklemesi çalıştığı için pil riski hem işlevsel hem de kullanıcı güveni açısından önem taşıyor. Ayrıca gerçek uyanış ile anketteki planlanan uyanış arasındaki farkın “rapor gönderim saati”ne ne zaman uygulandığı senaryolarla doğrulanmalı.

Horlama tespiti aktifse mikrofon foreground service’i devreye giriyor. Metinler bunun cihaz üzerinde ve kısa örneklerle çalıştığını söylüyor; fakat Android 14+ foreground-service/mikrofon izin reddi, gece boyunca kilitli ekran, üretici arka plan kısıtlaması ve kullanıcı servisi zorla durdurduğunda raporun davranışı release cihazlarda test edilmelidir.


### Çeviri denetiminin kesin sonucu

Otomatik karşılaştırmada İngilizce referans haritasında 1.564 anahtar, üretilmiş 38 ek dilin her birinde 1.563 anahtar bulundu. Eksik tek anahtar tüm ek dillerde aynıdır: `aiChatActionAppliedHealthTipCount`. Bu anahtar AI sağlık tavsiyesi sayısı eylemi uygulandığında doğrudan görünürse 38 dilde ham anahtar metni gösterebilir. Buna karşılık çeviri dosyasının geri kalan anahtar kapsamı sayısal olarak tamdır.

Uygulama toplamda Türkçe ve İngilizce dahil 40 dil sunuyor; kullanıcının ürün gereksiniminde belirtilen “38 dil” ifadesi toplam sayı olarak kastediliyorsa kapsam fazladır, 38 ek dil olarak kastediliyorsa UI ve mağaza metinleri netleştirilmelidir. AI sunucusu 40 dili desteklerken Flutter istemcisi 14 dil kabul ettiği için bu iki konu birbirinden ayrı ve önceliklidir.


### Test kapsamı

`translation_coverage_test.dart` İngilizce referansındaki tüm anahtarların her üretilmiş dilde bulunmasını bekliyor. Bu nedenle `aiChatActionAppliedHealthTipCount` anahtarının 38 dilde eksik olması, test çalıştırıldığında beklenen bir başarısızlık üretir; bu bir test kusuru değil, gerçek çeviri paketi eksikliğidir. Aynı test kritik kullanıcı anahtarlarını ve placeholder uyumunu da kontrol ediyor.

`multilingual_smoke_test.dart` 40 dili dolaşıyor; dolayısıyla ürünün fiili sözleşmesi test tarafında da 40 dil olarak kurulmuş. Ürün gereksinimindeki 38 sayısı bu testlerle yeniden mutabıklaştırılmalıdır.

`ai_service.dart` içindeki `_allowedResponseLanguages` yalnızca 14 kod içeriyor. `LanguageService.supportedLanguages`, `generatedLanguageData` ve AI Functions 40 kodu kapsadığı halde istemci doğrulaması 26 dili reddediyor. Bu bulgu doğrudan test edilmesi gereken P0 regresyonudur.


## 4. Davranış motoru — ara bulgular

Günlük adaptif plan aynı gün içinde cache’leniyor; bu, ana ekranı her açışta yeni görev üretme sorununu önlüyor. Plan; hareketli başarı/başarısızlık oranı, erteleme oranı, saatlik zorlanma profili, riskli saatler, uyku rutini çevresi ve kullanıcı frekans ayarıyla hesaplanıyor. Başarılı üç ardışık görev küçük bir ilerleme bonusu veriyor; başarısızlık veya tekrarlı erteleme streak’i sıfırlıyor. Bu tasarım, sessizce “uygulama açıldıkça öğrenme” yerine gerçek sonuçlara dayalı öğrenme açısından olumlu.

Süreler artık `barrierMinutes` etrafında yüzde 18 rastgelelik, saatlik zorlanma ofseti ve başarıya bağlı öğrenilmiş taban süre ile üretiliyor. Minimum görev aralığı 45 dakika veya mevcut bariyer süresi kadar; görevler uyku rutini ve çalışma gibi engelli pencerelere konulmuyor. Bu nedenle sabit dakikaya düşme riski önceki sürümlere göre azaltılmış.

Bununla birlikte uzun bariyer, dar uyanıklık penceresi, çok sayıda engelli saat ve yüksek görev hedefi birlikte geldiğinde gerçek görev sayısı hedefin altında kalabiliyor. Kod bunu dürüst sonuç olarak kabul ediyor; UI’nin `targetTaskCount` ile `items.length` farkını kullanıcıya “eksik görev” gibi göstermemesi, bunun fiziksel zaman uygunluğu nedeniyle azaltılmış plan olduğunu açıklaması gerekir. 300–500 senaryoda özellikle 4, 8, 16 ve 24 saat uyanıklık; 1–60 sigara/gün; gece vardiyası; hafta sonu/tatil; yüksek başarı, başarısızlık ve sessiz veri kombinasyonları koşulmalıdır.

`BehaviorEngine` ve `DisciplineProtocolService` için gerçek Flutter testleri bulunuyor görünse de bu denetim ortamında Flutter SDK olmadığı için testlerin çalıştırıldığı doğrulanamıyor. Statik sonuç, kaynak kodun ilerleme mantığını içerdiğini gösteriyor; ancak “kanıt yok” durumunda UI’nin ilerleme veya tasarruf rakamı üretmediği ayrıca uçtan uca doğrulanmalı.


## 5. Cihaz profilleri ve Android uyumluluğu — ara bulgular

Manifestte bildirim, konum/arka plan konumu, aktivite tanıma, telefon durumu, mikrofon, exact alarm, boot, tam ekran intent, overlay, usage access, battery-optimization exemption, Health Connect, foreground service ve özel kullanım foreground service izinleri bulunuyor. Bu kapsam uygulamanın işlevsel hedeflerini karşılıyor; ancak Play Store incelemesi için her hassas iznin kullanıcıya açık ve özelliğe bağlı gerekçesi olmalı. Özellikle `SYSTEM_ALERT_WINDOW`, `SCHEDULE_EXACT_ALARM`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, arka plan konumu ve gece mikrofonu yüksek inceleme riskidir.

`SmokedLogOverlayService` ekran açıkken hızlı kayıt overlay’ini tutmak için foreground service’i `START_STICKY` olarak çalıştırıyor; ekran kapanınca görünümü kaldırıyor ancak servis yaşamaya devam ediyor. Bu tasarım ekran kapalıyken pil maliyetini azaltıyor fakat uygulama izinli ve etkin olduğu sürece kalıcı foreground bildirim/servis maliyeti yaratabilir. Samsung/Xiaomi gibi agresif üretici optimizasyonlarında servis yine öldürülebilir; `START_STICKY` tek başına garanti değildir. Kullanıcıya overlay’in gerçek bir sürekli servis olduğu açıkça gösterilmeli ve kapatma kontrolü güvenilir olmalı.

`SleepProbeReceiver` uyku penceresinde varsayılan olarak her 5 dakikada bir exact `RTC_WAKEUP` alarmı kuruyor. Her tick ekran/şarj durumunu kaydediyor; ekran açıksa yaklaşık 600 ms ivmeölçer örneklemesi yapıyor; ekran kapalı ve horlama özelliği açıksa mikrofon foreground service’i başlatabiliyor. Bu, “iki OS sinyali ücretsiz” olsa bile gece boyunca çok sayıda wake-up ve exact alarm demektir. Pixel’de daha öngörülebilir, Samsung/Xiaomi’de Doze ve OEM politikaları nedeniyle gecikebilir veya tamamen bastırılabilir. Pil dostu hedef için 5 dakikalık örnekleme, gerçek kullanıcı ihtiyacıyla ölçülerek daha seyrek adaptif aralık veya yalnızca kullanıcı opt-in’i ile etkinleştirilmelidir.

Küçük ekranlar ve büyük yazı boyutları için çok sayıda sabit `width`/`height` kullanımı bulundu. Scrollable kapsayıcı sayısı yüksek olsa da özellikle ana sayfadaki 160 dp kartlar, sabit grafik yüksekliği ve karmaşık kart yığınları 320 dp genişlik, font ölçeği 1.3–1.5 ve RTL dillerde taşma adayıdır. Üretici profili testlerinde minimum 320×568, 360×800, 411×915 ve tablet/katlanabilir genişlikleri; yazı ölçeği 1.0, 1.3 ve 1.5; RTL ve uzun Almanca/Rusça metinleri çalıştırmak gerekir.


## 6. Pil ve performans — ara bulgular

Arka plan yükü tek bir mekanizmadan oluşmuyor: günlük plan yenileme alarmı, görev ve sağlık ipucu alarmları, ekran durumunu dinleyen overlay foreground service’i, yanıtsız görev watchdog’u, uyku probe’u, adım probe’u, isteğe bağlı konum zekâsı/geofence ve isteğe bağlı horlama mikrofon servisi birlikte çalışıyor. Bu bileşenler özellik bazında opt-in olsa da varsayılan açılış ve ayar geçişlerinde aynı anda etkinleşme ihtimali test edilmelidir.

En önemli pil adayı uyku probe’udur. Uyku penceresinde 5 dakikada bir `RTC_WAKEUP` exact alarm kuruluyor ve ekran açıksa kısa ivmeölçer örneklemesi yapılıyor. Gece başına 8 saat için yaklaşık 96 alarm uyanışı oluşabilir; bu kesin tüketim ölçümü değildir, fakat Android’in uyku/Doze faydasını azaltan anlamlı bir wake-up yüküdür. “Pil dostu” kabulü için Pixel, Samsung ve Xiaomi’de 8 saatlik ekran kapalı ölçüm; probe kapalı/açık ve horlama kapalı/açık karşılaştırması gereklidir.

Overlay servisi `START_STICKY` ile kalıcı foreground servis olarak tasarlanmış. Ekran kapalıyken view kaldırılıyor ancak servis ve ekran receiver yaşamaya devam ediyor. `NoResponseWatchdogService` de sticky foreground servis niteliğinde. Bu iki servisin aynı anda açık olduğu senaryoda sürekli bildirim, süreç yaşatma ve OEM optimizasyonlarına karşı daha yüksek maliyet oluşabilir. Servislerin yalnızca gerçekten bekleyen görev/aktif overlay olduğu sürede çalışması veya işlevsel olarak zorunlu olmayan izleme döngülerinin alarm/job tabanlı tasarıma çekilmesi P0/P1 optimizasyon adayıdır.

Adım probe’u sensörü kısa süre okuyup unregister ediyor; bu sürekli sensör listener’ı tutulmaması açısından olumlu. Nefes ve horlama akışlarında ham sesin tutulmaması ve yalnızca özet değerlerin işlenmesi mahremiyet açısından olumlu; buna rağmen gece mikrofon foreground servisi kullanıcı beklentisi, bildirim görünürlüğü ve Play Store izin gerekçesi açısından ayrıca doğrulanmalıdır.


## 7. Güvenlik, Firebase ve Play Store — ara bulgular

Functions içindeki 21 Node birim testi mevcut auth, geçmiş sanitizasyonu, plan çözümleme, satın alma token hash’i ve Play abonelik yorumlama davranışını başarıyla geçti. Bu, yardımcı modüller için olumlu bir temel oluşturuyor; ancak testler ana callable Functions modülünü gerçek deploy yüklemesiyle doğrulamıyor.

Kritik bulgu: `functions/index.js` içinde kullanılan `onCall` ve `HttpsError` sembolleri görünen import listesinde tanımlı değil; `functions/auth.js` içinde de `HttpsError` kullanılıyor ancak import edilmiyor. Yardımcı testler `auth.js`’yi yüklediğinde henüz hata vermemiş olsa da `requireAuth` hata yolunu gerçekten çağırdığında veya ana Functions modülü yüklenirken bu semboller runtime/deploy hatasına dönüşebilir. Daha önceki Firebase deploy timeout’u ile birlikte bu dosyalar yayın öncesi P0 doğrulama konusudur. Her Functions dosyası `node --check`, doğrudan import ve Firebase emulator/deploy analiz yüklemesiyle test edilmelidir.

Sunucu tarafında AI anahtarının Firebase Secret olarak tutulması olumlu. Geliştirme bypass’ı proje kimliği ve `debugClient` koşuluna bağlanmış; üretimde App Check zorunlu tutuluyor. Ancak geliştirme projesindeki bypass’ın kimlik doğrulaması sonrasında çalıştığı ve production konfigürasyonuna taşınamayacağı CI kontrolüyle güvence altına alınmalı. Kullanıcının kişisel Firebase/Play hesabı için e-posta veya şifre kaynak koda, loga ya da git geçmişine yazılmamalıdır.

Manifestteki hassas izinlerin sayısı yüksek olduğu için mağaza açıklaması ve Data safety beyanı özellik bazında hazırlanmalı. Arka plan konumu, overlay, exact alarm, tam ekran bildirim, mikrofon ve battery-optimization exemption izinlerinden her biri varsayılan olarak zorunlu görünmemeli; kullanıcı özelliği açtığında, neyin ne kadar süreyle işlendiği ve nasıl kapatılacağı gösterilmelidir. Horlama algılama ve sağlık/uyku verilerinin “cihazda kalır” iddiası ile Firebase/AI payload’larına giden alanlar ayrıca kaynak kod ve ağ loglarıyla doğrulanmalıdır.

Release Gradle yapılandırması, `android/key.properties` yoksa debug imzaya düşüyor ve açıkça uyarı yazıyor. Bu geliştirici için yararlı olsa da CI/Play yükleme pipeline’ı debug imzalı çıktıyı kesin olarak reddetmeli. Release keystore, package name, versionCode/versionName, R8 kuralları ve Firebase production project eşleşmesi tek bir release checklist’i ile doğrulanmadan AAB üretilmemeli.


## Onarım 1 sonucu — Firebase Functions importları

`functions/index.js` içine `onCall` ve `HttpsError`, `functions/auth.js` içine `HttpsError` importu eklendi. Yinelenen import kontrolü yapıldı. `node --check index.js`, `node --check auth.js` ve Functions test paketi çalıştırıldı; **21 test geçti, 0 başarısız**. Firebase gerçek deploy/emulator doğrulaması bu sandbox ortamında henüz yapılmadı.


## Onarım 2 sonucu — AI dil kapsamı ve çeviri anahtarı

`ai_service.dart` içindeki istemci AI cevap dili güvenlik listesi 14 dilden uygulamanın gerçek 40 dil listesine eşitlendi. `generated_language_data.dart` içindeki 38 ek dilin tamamına `aiChatActionAppliedHealthTipCount` yerelleştirilmiş mesajı eklendi. Çeviri denetimi artık 1.564 referans anahtarını 38 dilin her birinde `missing=0, extra=0` olarak raporluyor. `git diff --check` temiz. Functions paketindeki 21 test yeniden geçti.

Flutter SDK bu ortamda bulunmadığı için Dart/Flutter testleri hâlâ Windows/VS Code ortamında çalıştırılmalıdır.


## Nefes testi görsel onarımı sonucu

`breath_test_page.dart` içinde eski özel onay işareti çizimi kaldırıldı. Geçerli üfleme sonrasında artık yeşil daire, beyaz onay işareti, ince beyaz çerçeve ve hafif yeşil parlama kullanılıyor; ayrı bir “başardın” metni eklenmedi. Mikrofon kılavuzu yeniden çizildi: telefon gövdesi alt bölüme yerleşiyor, mikrofon alt kenarda kalıyor ve üç büyük ok üstten alta, doğrudan mikrofon yönüne hareket ediyor. Bu kılavuz ortak exhale render’ında olduğu için 1., 2. ve 3. denemede aynı yönde görünür. `git diff --check` temizdir. Bu sandbox’ta Flutter/Dart bulunmadığından gerçek cihaz ekran görüntüsü ve Flutter widget testi henüz yapılamadı.

## Onarım — overlay kullanıcı durdurma

`SmokedLogOverlayService` içinde kullanıcı tarafından verilen `ACTION_STOP` artık açıkça işaretleniyor, bekleyen 2 saniyelik restart alarmı iptal ediliyor ve `onDestroy` yeniden başlatma planlamıyor. Böylece kapatma düğmesi servisi hemen yeniden açmıyor. `git diff --check` başarılı; sandbox Android Gradle wrapper içermediği için Kotlin derlemesi çalıştırılamadı.

## Onarım — SleepProbe exact alarm fallback

`SleepProbeReceiver` artık Android 12+ cihazlarda `canScheduleExactAlarms()` kontrolü yapıyor. Exact alarm izni yoksa uyku zekâsı penceresi `setAndAllowWhileIdle` ile inexact olarak devam ediyor; böylece izin reddi nedeniyle gece probu tamamen kaybolmuyor. 5 dakikalık varsayılan örnekleme sıklığı bu değişiklikte korunmuştur. `git diff --check` başarılı; Android Gradle wrapper olmadığı için Kotlin derlemesi sandbox içinde çalıştırılamadı.

## Onarım — uyku probu pil optimizasyonu

Uyku probu varsayılan aralığı Dart ve native tarafta 5 dakikadan 15 dakikaya eşitlendi. Bu, tipik gece penceresindeki yaklaşık 100 wake-up yerine yaklaşık 30–40 wake-up sağlar; uyku öğrenmesi için yeterli kapsama korunurken pil maliyeti azaltılır. Exact alarm izni reddedilirse önceki inexact fallback aynen korunur. `git diff --check` başarılı; Gradle wrapper yokluğu nedeniyle Android derlemesi sandbox içinde çalıştırılamadı.

## Onarım — günlük plan yenileme alarmı

`DailyPlanRefreshService` günlük 00:05 civarı plan yenilemesini `exact: false` olarak çalıştıracak şekilde güncellendi. Bu iş saniyesi kritik olmadığından Android alarmı bakım işleriyle gruplayabilir; exact alarm izni gereksinimi ve gereksiz uyanma azaltılır. Görev bildirimlerinin kendi exact/inexact politikası korunmuştur. `git diff --check` başarılı.

## Onarım — adım probe exact alarm fallback

`StepProbeReceiver` Android 12+ exact alarm iznini kontrol ediyor; izin yoksa günlük adım sayacı snapshot’ı `setAndAllowWhileIdle` ile yine alınmaya çalışılıyor. Böylece exact alarm izni bulunmayan cihazlarda adım trendi sessizce durmuyor. `git diff --check` başarılı.

## Onarım — arşiv süresi teslimata bağlandı

Planlı bildirimler önceden veritabanına yazıldığı için `expiresAt` artık kayıt/planlama zamanından değil, `availableAt` (bildirimin kullanıcıya görünür olması gereken zaman) üzerinden hesaplanıyor. Böylece planlı bir bildirim 24 saatten erken arşivden düşmüyor. Anında bildirimlerde `availableAt` yoksa mevcut zaman kullanılıyor. `git diff --check` başarılı.
