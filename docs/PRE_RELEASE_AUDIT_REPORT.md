# Nicotine Away — Yayın Öncesi Kapsamlı Denetim Raporu

**Hazırlayan:** Manus AI  
**Tarih:** 22 Ağustos 2026  
**Kapsam:** Kaynak kodu, Android native katmanı, Firebase Functions, veri akışları, bildirimler, adaptif davranış motoru, AI Mentor, Uyku Zekâsı, nefes özellikleri, çoklu dil ve Play Store öncesi riskler.

> **Önemli sınır:** Bu rapor kullanıcı onayı olmadan kaynak kodunda onarım yapmaz. Flutter/Dart SDK’sı bu inceleme ortamında bulunmadığından `flutter analyze`, `flutter test`, gerçek cihaz ekran testi ve release AAB/APK üretimi burada çalıştırılamamıştır. Bulgular statik kaynak incelemesi, Functions birim testleri ve resmi Android/Google Play belgeleriyle oluşturulmuştur.

## 1. Yönetici özeti

Nicotine Away’in mevcut mimarisi, basit bir bildirim uygulamasından daha kapsamlıdır. Uygulama; sigara kaydı, günlük doğrulama, adaptif görev planı, davranış profili, sağlık tavsiyeleri, bildirim arşivi, AI Mentor, Uyku Zekâsı, nefes/solunum kayıtları, horlama denemesi, konum zekâsı, overlay hızlı kayıt, Health Connect, ses ve onboarding gibi birden fazla kullanıcı akışını aynı Android arka plan katmanında birleştiriyor.

Veri bütünlüğü ve adaptif görev mantığında önemli iyileştirmeler mevcut. Özellikle kanıt bulunmayan günlerin otomatik başarı sayılmaması, günlük sigara azaltımının doğrulanmış akşam verisine bağlanması, görevlerin aynı gün cache’lenmesi ve görev sürelerinin öğrenilmiş durum ile rastgelelikten üretilmesi doğru yöndedir.

Buna rağmen uygulama **henüz Play Store kapalı testine hazır kabul edilmemelidir**. En yüksek öncelikli riskler şunlardır: Firebase Functions ana yükleme/hata sınıfı importlarının doğrulanmamış olması, AI istemcisinin sunucudan çok daha az dili kabul etmesi, planlanan bildirimlerin teslim edilmeden arşivlenmesi, exact alarm ve tam ekran/overlay izinlerinin yüksek mağaza riski, uyku probe’unun varsayılan 5 dakikalık wake-up yükü ve kalıcı foreground servislerin pil/OEM davranışı.

| Alan | Mevcut değerlendirme | Öncelik |
|---|---|---:|
| Veri doğruluğu | Temel yaklaşım doğru; tüm UI yollarında uçtan uca eşleşme kanıtlanmalı | P1 |
| Adaptif davranış motoru | Öğrenme ve değişken süre mantığı mevcut; dar zaman pencereleri sınanmalı | P1 |
| Bildirim arşivi | 24 saat süresi planlama anından başlayabilir; gereksinimle çelişiyor | P0/P1 |
| AI Mentor | Sunucu 40 dil, istemci 14 dil; doğrudan uyumsuzluk | P0 |
| Firebase deploy | Functions yardımcı testleri geçiyor; ana callable yükleme yolu ayrıca doğrulanmalı | P0 |
| Uyku/pil | 5 dakikada bir exact wake-up, yaklaşık 8 saatte 96 uyanış adayı | P0/P1 |
| Android üretici uyumu | Pixel daha öngörülebilir; Samsung/Xiaomi’de servis ve alarm bastırılabilir | P1 |
| Play Store | Hassas izin yüzeyi geniş; açıklama ve politika eşleştirmesi gerekli | P0/P1 |
| Çoklu dil | 40 toplam dil, ek dil paketlerinde tek ortak eksik anahtar | P1 |

## 2. Özellik ve akış kapsamı

Kaynak envanterine göre ana kullanıcı yüzeyleri; Ana Sayfa, Ayarlar, Bildirimler/Arşiv, AI Mentor ve sohbet geçmişi, kişisel ilerleme/raporlar, günlük değerlendirme ve akşam rutini, nefes testi ve nefes analizi, haftalık anket, Uyku Zekâsı, sağlık iyileşme süreci, tasarruf, kriz/SOS, görev overlay’i, hızlı “Sigara İçtim” overlay’i, onboarding/izin kurulumu, konum zekâsı, giyilebilir/Health Connect ve deneysel horlama tespiti etrafında toplanıyor.

Navigasyonun önemli özelliği, bildirimin yalnızca işletim sistemi yüzeyinde kalmayıp uygulama içi arşiv ve gerektiğinde overlay’e bağlanmasıdır. Bu nedenle tek bir bildirim akışındaki hata, aynı içeriğin üç ayrı yüzeyde farklı davranmasına yol açabilir. Her bildirim türü için “planlandı → teslim edildi → kullanıcı açtı → arşive yazıldı → 24 saat sonra silindi” yaşam döngüsü ayrı test edilmelidir.

## 3. Veri bütünlüğü ve davranış motoru

`StorageService.loadReductionProgress` yaklaşımı olumlu bir temele sahiptir. Kayıt olmayan günlerin sigara içilmemiş gün gibi sayılmaması, hızlı kayıtların günlük gerçek toplam yerine alt sınır kanıtı olarak ele alınması ve akşam rutinindeki doğrulanmış günlük toplamın ilerleme hesabında kullanılması kullanıcı güvenini korur.

Gerekli ürün kuralı şudur: kullanıcı akşam doğrulamasını tamamlamadıysa uygulama “kaçınılan sigara”, tasarruf veya yaşam süresi kazancı gibi kesin görünen rakamları artırmamalıdır. Ana Sayfa, Kişisel İlerleme, Raporlar, AI Mentor ve bildirim metinleri bu konuda aynı sonucu üretmelidir. “Veri yok”, “kısmi kayıt” ve “doğrulanmış kayıt” görünür biçimde ayrılmalıdır.

Adaptif plan aynı gün cache’lenmektedir. Plan; riskli saatler, uyku rutini çevresi, engelli zaman pencereleri, hareketli başarı/başarısızlık oranı, erteleme oranı, saatlik zorlanma profili ve kullanıcı görev sıklığıyla şekillenmektedir. Üç ardışık başarı küçük bir ilerleme bonusu verirken başarısızlık veya tekrarlı erteleme streak’i sıfırlamaktadır. Süre üretiminde yaklaşık yüzde 18 jitter, öğrenilmiş taban süre ve saatlik zorlanma ofseti bulunur; bu nedenle aynı dakikaya kilitlenme önceki sürümlere göre azaltılmıştır.

Uzun bariyer, az uyanıklık süresi, gece vardiyası, çok sayıda engelli saat ve yüksek görev hedefi aynı anda bulunduğunda gerçek görev sayısı hedefin altında kalabilir. Bu matematiksel olarak dürüst olabilir; ancak UI bunu “başarısız plan” gibi göstermemeli, “bugün uygun zaman aralığı sınırlı olduğu için plan azaltıldı” şeklinde açıklamalıdır.

## 4. Bildirim ve arka plan mantığı

Görev, sağlık tavsiyesi, uyku raporu, nefes hatırlatıcısı, görev başarı/başarısızlık sonuçları, mentor önerileri ve diğer bildirimlerin arşive alınması istenmektedir. Denetimde kritik bir zamanlama problemi görülmüştür: planlanmış bildirimlerde arşiv kaydı planlama sırasında yazılıyor ve varsayılan `receivedAt` o anki zaman oluyor. Bu durumda bildirim kullanıcıya örneğin altı saat sonra gösterilecekse 24 saatlik saklama süresi teslimattan değil planlama anından başlar.

Bu gereksinim “teslimattan itibaren 24 saat” ise arşiv modeli planlama zamanı ile teslim zamanını ayırmalıdır. Native teslim callback’i veya güvenilir bir teslim sonrası işleme noktası gerekir. Ayrıca anlık gösterim ile planlı gösterim için dedupe anahtarları ve cleanup davranışı aynı test matrisiyle doğrulanmalıdır.

Exact alarm fallback’i `NotificationService` içinde kısmen ele alınmış görünmektedir; fakat `DailyPlanRefreshService` doğrudan exact/wakeup alarm yaklaşımı kullanmakta, native adım ve uyku receiver’ları da doğrudan exact alarm kurmaktadır. Android 14 ve üzeri yeni kurulumlarda exact alarm erişimi reddedilebildiğinden, izin yokken hata, sessiz plan kaybı veya gecikmiş inexact fallback oluşup oluşmadığı gerçek cihazlarda sınanmalıdır. Günlük plan yenilemesi saniyesi kritik olmayan bir iş olduğu için exact alarm kullanımı ayrıca gerekçelendirilmelidir.

## 5. AI Mentor, Uyku Zekâsı ve çoklu dil

AI Functions sunucu tarafında 40 dil kodu desteklemektedir. Buna karşın Flutter `ai_service.dart` istemci tarafındaki `_allowedResponseLanguages` yalnızca 14 dil içeriyor. Bu, 26 dilde sunucudan cevap gelse bile istemcinin dili desteklenmiyor sayabilmesi anlamına gelir ve yayın öncesi **P0** uyumsuzluktur. Tek bir ortak dil manifestosu kullanılmalı veya istemci kümesi sunucuyla birebir eşitlenmelidir.

Çeviri karşılaştırmasında İngilizce referansında 1.564 anahtar, 38 ek dilin her birinde 1.563 anahtar bulunmuştur. Ortak eksik anahtar `aiChatActionAppliedHealthTipCount`’tır. AI sağlık tavsiyesi sayısı eylemi 38 dilde çalıştırıldığında ham anahtar veya eksik metin görünme ihtimali vardır. Uygulamadaki gerçek kapsam Türkçe ve İngilizce dahil 40 dildir; “38 dil” ifadesi toplam dil mi yoksa ek dil mi, ürün kararında netleştirilmelidir.

Uyku özelliği ekran ve şarj durumunu kullanarak pencere öğreniyor, tatil modunda probe’u kapatabiliyor ve sabah raporunu uyanıştan sonra göndermeyi hedefliyor. Ancak gerçek uyanış ile anketten alınan planlanan uyanış arasındaki fark, yetersiz örnekleme ve gece telefon kullanımının rapor saatine etkisi senaryolarla doğrulanmalıdır. Horlama tespiti opt-in olsa da mikrofon foreground service’i, kilit ekranı, Android 14 izinleri ve üretici kısıtlamalarıyla test edilmelidir.

## 6. Pil ve performans

`SleepProbeReceiver` uyku penceresinde varsayılan olarak beş dakikada bir `RTC_WAKEUP` exact alarm kuruyor. Sekiz saatlik bir uyku penceresi için teorik olarak yaklaşık 96 wake-up oluşabilir. Her çağrı kısa ekran/şarj okuması yapıyor; ekran açıksa yaklaşık 600 ms ivmeölçer örnekliyor. Tek tek işlemler küçük olsa da exact alarm + wake-up kombinasyonu Doze tasarrufunu azaltır ve pil dostu varsayılanla gerilim oluşturur.

`SmokedLogOverlayService` `START_STICKY` ile kalıcı foreground servis olarak çalışıyor. Ekran kapalıyken overlay görünümü kaldırılıyor ancak servis ve screen receiver yaşamaya devam ediyor. `NoResponseWatchdogService` de sticky foreground servis niteliğinde. İkisi aynı anda aktif olduğunda sürekli bildirim, süreç yaşatma ve OEM tarafından yeniden başlatılma maliyeti oluşabilir. Overlay’in gerçekten açık kalması gerektiği süre ile servis yaşam süresi birbirinden ayrılmalıdır.

Pil kabul kriteri belirlenmeden “battery-friendly” iddiası yapılmamalıdır. En azından aynı uygulama veri setiyle Pixel, Samsung ve Xiaomi’de sekiz saat ekran kapalı; uyku probe kapalı/açık; horlama kapalı/açık; overlay kapalı/açık karşılaştırması yapılmalıdır. Ölçülecek metrikler toplam pil yüzdesi, wake-up sayısı, foreground service süresi, alarm teslim gecikmesi ve gece raporu teslim oranıdır.

## 7. Cihaz, ekran ve üretici matrisi

| Profil | Kritik koşullar | Beklenen risk |
|---|---|---|
| Pixel, Android 14–16 | Doze ve exact alarm izni | İzin yoksa alarm/fallback davranışı |
| Samsung One UI | Uyku optimizasyonu, arka plan sınırı | Sticky servis ve bildirimlerin bastırılması |
| Xiaomi/MIUI-HyperOS | Autostart, battery saver, overlay | Servisin öldürülmesi, yeniden başlatmanın gecikmesi |
| Düşük RAM cihaz | Süreç öldürme, yeniden açılma | Cache, alarm ve overlay durum kaybı |
| 320×568 ekran | Dar genişlik, font ölçeği 1.0–1.5 | Kart/grafik/text overflow |
| 411×915 ve tablet | Geniş düzen | Sabit ölçülerin gereksiz boşluk üretmesi |
| RTL dil | Arapça ve uzun yerelleştirilmiş metin | Hizalama, ikon yönü, taşma |
| Uzun metin dilleri | Almanca, Rusça, Lehçe | Buton ve bildirim gövdesi kesilmesi |
| Gece vardiyası/tatil | Uyku-uyanış gün bazında değişken | Yanlış rapor zamanı veya görev çakışması |

Ana Sayfa ve bazı widget/kartlarda sabit ölçüler bulunduğundan 320 dp genişlikte, büyük fontta ve RTL’de görsel regresyon testi gereklidir. Nefes testindeki yön göstergesi, başarı işareti ve arka plan logo/sloganının tüm dillerde aynı görsel niyeti koruduğu da ekran görüntüsü karşılaştırmasıyla doğrulanmalıdır.

## 8. Güvenlik, mahremiyet ve Play Store

Firebase Secret kullanımı olumlu; AI sağlayıcı anahtarının kaynak kodda tutulmaması gerekir. Geliştirme bypass’ı development proje kimliği ve debug istemci koşuluna bağlanmış görünmektedir. Bunun production’a taşınmaması CI ile kontrol edilmelidir. Kullanıcı hesabı `mehmet.bulbul0663@gmail.com` için şifre veya token kesinlikle kaynak koda, git geçmişine veya loglara yazılmamalıdır.

Kritik statik bulgu: `functions/index.js` içinde kullanılan `onCall` ve `HttpsError` sembollerinin importları görünen başlıkta yoktur. `functions/auth.js` içinde `HttpsError` kullanıldığı halde import edilmemiş görünmektedir. Yardımcı Functions testlerinin 21’i geçmiştir; fakat bu testler ana callable modülünün gerçek yükleme/deploy analizini kanıtlamaz. Daha önce görülen “Cannot determine backend specification / Timeout after 10000” hatasıyla birlikte bu konu P0 olarak ele alınmalıdır. Doğrudan modül importu, `node --check`, emulator yüklemesi ve Firebase deploy öncesi analiz çalıştırılmalıdır.

Manifestte `SYSTEM_ALERT_WINDOW`, `SCHEDULE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`, arka plan konumu, mikrofon, battery-optimization exemption ve çeşitli foreground service izinleri bulunuyor. Google Play ve Android belgeleri exact alarm ile full-screen intent kullanımını sınırlı/koşullu hale getirmektedir.[1] [2] Nicotine Away’in görev overlay’i alarm veya arama uygulaması değildir; bu nedenle tam ekran intent’in mağaza politikası karşısındaki konumu özellikle doğrulanmalı, izin reddedildiğinde heads-up bildirim fallback’i eksiksiz çalışmalıdır.

## 9. 300–500 hayali senaryo test planı

Bu ortamda Flutter SDK bulunmadığı için 300–500 senaryonun gerçek Dart test koşumu yapılmış gibi raporlanmamıştır. Onarım sonrasında Windows/VS Code ortamında çalıştırılacak test matrisi aşağıdaki boyutlarda yaklaşık 400 kombinasyondan oluşmalıdır:

| Boyut | Örnek değerler |
|---|---|
| Günlük sigara | 1, 5, 10, 20, 40, 60 |
| Sigara kayıt davranışı | Tam kayıt, kısmi kayıt, hiç kayıt, akşam doğrulama |
| Görev sonucu | Başarılı, başarısız, ertelendi, yanıtsız, uygulama kapalı |
| Uyku düzeni | 4, 6, 8, 12, 16 saat; gece vardiyası; değişken hafta sonu |
| Kullanım paterni | Kahve, yemek, stres, araç, sosyal ortam, alkol, risksiz saat |
| Telefon | Pixel, Samsung, Xiaomi; düşük RAM; Android 13–16 |
| İzinler | Bildirim, exact alarm, overlay, mikrofon, konum tek tek reddedilmiş |
| Dil | Türkçe, İngilizce, Arapça RTL, Almanca, Rusça, Japonca, uzun metin |
| Bağlantı | Çevrim içi, çevrim dışı, geçici Firebase timeout, tekrar bağlanma |
| Pil | Doze, battery saver, şarjda, düşük pil, uygulama süreç öldürme |
| Özellik kombinasyonu | Overlay, horlama, Health Connect, konum, AI ayrı ve birlikte |

Her senaryoda şu invariant’lar kontrol edilmelidir: doğrulanmamış sigara verisi başarıya çevrilmemeli; aynı gün plan tekrar üretildiğinde saatler değişmemeli; ayar değişince eski alarm/PendingIntent kalmamalı; 0 sağlık tavsiyesi seçilince eski tavsiyeler gelmemeli; her arşiv kaydı doğru teslimat zamanı ve 24 saat cleanup kuralını kullanmalı; dil fallback’i ham anahtar göstermemeli; görev süresi minimum bariyerin altına inmemeli; uyku raporu yanlış gün veya yanlış uyanış saatine gönderilmemeli; servis/receiver süreç öldürülmesinden sonra güvenli biçimde toparlanmalıdır.

## 10. Öncelikli onarım sırası

| Sıra | Onarım | Gerekçe |
|---:|---|---|
| P0 | Firebase Functions import/deploy yükleme problemini düzeltmek ve callable modülünü gerçek yükleme testiyle doğrulamak | AI üretim/dev akışını tamamen durdurabilir |
| P0 | AI istemci dil kümesini sunucu ve uygulama dil manifestosuyla eşitlemek | 26 dilde AI erişimi reddedilebilir |
| P0/P1 | Bildirim arşivinde planlama ve teslim zamanını ayırmak; tüm türlerde 24 saat cleanup test etmek | Kullanıcı gereksinimiyle doğrudan çelişme riski |
| P0/P1 | Exact alarm, full-screen intent ve overlay izin reddi fallback’lerini cihazlarda doğrulamak | Android 14+ ve Play Store riski |
| P1 | Uyku probe’u için pil dostu aralık/fallback tasarlamak ve ölçmek | Gece başına yaklaşık 96 wake-up adayı |
| P1 | Kalıcı foreground servislerin yaşam süresini daraltmak veya gereksiz olanları alarm/job yaklaşımına taşımak | OEM ve pil riski |
| P1 | Doğrulanmış veri etiketlerini tüm ilerleme/tasarruf/AI yüzeylerinde birleştirmek | Kullanıcı güveni ve veri doğruluğu |
| P1 | 320 dp, büyük font, RTL ve uzun metin ekran testlerini eklemek | Görsel taşma ve erişilebilirlik |
| P1 | Eksik `aiChatActionAppliedHealthTipCount` çevirisini 40 dil paketine eklemek | 38 dilde görünür metin hatası |
| P2 | Release signing/production Firebase/package ve R8 doğrulamasını CI’da zorunlu kılmak | Debug imzalı veya yanlış proje AAB riskini engeller |
| P2 | Kapalı test geri bildirim, Data Safety, gizlilik politikası ve izin açıklamalarını hazırlamak | Play Store başvuru hazırlığı |

## 11. Kapalı test öncesi kabul kriterleri

Kapalı teste geçmeden önce uygulama en az bir gerçek Pixel, bir Samsung ve bir Xiaomi cihazında bildirim, boot sonrası toparlanma, uygulama Recents’tan silinmesi, Doze, exact alarm reddi, overlay reddi, mikrofon reddi ve düşük pil koşullarında denenmelidir. Test kullanıcılarının uygulamayı yalnızca kurması yeterli değildir; 14 gün boyunca opt-in durumda kalmaları, görevleri ve raporları kullanmaları ve geri bildirim üretmeleri gerekir. Google Play’in kişisel geliştirici hesapları için 12 test kullanıcısı ve 14 günlük kapalı test koşulunu belirttiği resmi rehber dikkate alınmalıdır.[3]

## 12. Sonuç ve onay talebi

Uygulamanın ürün fikri ve temel davranış motoru yayınlanabilir bir omurgaya yaklaşmıştır; ancak **P0 maddeleri çözülmeden ve gerçek Flutter/Android testleri çalıştırılmadan “hazır” kararı verilmemelidir**. Bu aşamada kod değişikliği yapılmamıştır. Önerilen sırayla önce Functions/AI, bildirim arşivi ve izin/fallback sorunları; ardından pil ve cihaz uyumluluğu; son olarak dil, UI taşma ve release pipeline ele alınmalıdır.

Kullanıcı onayından sonra onarım fazında şu sırayla ilerlenmesi önerilir: (1) Functions yükleme ve AI dil eşleşmesi, (2) bildirim teslim/arşiv yaşam döngüsü, (3) exact alarm ve overlay fallback, (4) uyku probe/foreground servis pil düzenlemesi, (5) doğrulanmış veri ve UI tutarlılığı, (6) çeviri ve responsive ekran testleri, (7) Flutter analyze/test, Node test, gerçek cihaz matrisi ve release AAB doğrulaması.

## References

[1]: https://source.android.com/docs/core/permissions/fsi-limits "Android Source — Full-screen intent limits"

[2]: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms "Android Developers — Schedule exact alarms"

[3]: https://support.google.com/googleplay/android-developer/answer/14151465?hl=en "Google Play Console Help — Closed testing requirements"


## 11. Bu oturumda uygulanan ek onarımlar — 22 Ağustos 2026

Bu oturumda `StorageService.saveBreathProgressRecord` sonrasında `markBehaviorDirty()` çağrısı eklendi. Böylece nefes ilerleme kaydı davranış motoru önbelleğini geçersiz kılıyor ve yeni ölçümün risk/trend hesaplarına gecikmeden alınması sağlanıyor.

`DailyProgressReport` ve `StorageService.buildDailyProgressReport` genişletildi. Günlük rapor artık gün içindeki uyku probe sayısını, şarj sırasında yakalanan probe sayısını, geçerli gece horlama sinyali sayısını ve son gece horlama şiddetini taşıyor. Manuel horlama testleri ve başarısız mikrofon yakalamaları gece özeti hesabına dahil edilmiyor.

`daily_progress_report_view.dart` içinde kullanıcıya nefes trendi, öksürük sonucu, uyku süresi, uyku kanıtı/probe sayısı, şarj örnekleri ve gece horlama özeti gösteriliyor. Daha önce gömülü bulunan Türkçe uyku açıklamaları kaldırılarak yeni yerelleştirme anahtarlarına taşındı. Yeni anahtarlar tüm derlenmiş dil haritalarına eklendi; Kurmancî ve Soranî için ilgili rapor etiketleri ayrıca yerelleştirildi.

`LanguageService.getDeviceLanguageCode` içindeki tekil locale fallback yolu, `ku` ve `Arab` script birleşimini `ku-arab` olarak koruyacak şekilde düzeltildi. Splash ekranı zaten marka adı ve slogan widget’ını kullanıyordu; Kürtçe marka metinleri güncellendi.

`git diff --check` başarılıdır. Ancak sandbox’ta Flutter SDK bulunmadığından `flutter analyze` komutu çalıştırılamadı. Ayrıca toplu Kürtçe çeviri işlemi servis yanıtı nedeniyle tamamlanamadı: son denetimde Kurmancî haritasında 1.521 anahtarın 435’i, Soranî haritasında 1.521 anahtarın 1.506’sı İngilizceyle aynı görünmektedir. Bu sebeple **tam Kürtçe yerelleştirme hâlâ açık iş olarak kalmaktadır**; mevcut değişiklikler tam çeviri tamamlandı şeklinde sunulmamalıdır.

Kullanıcı makinesinde kod doğrulaması için:

```bash
flutter pub get
flutter analyze
flutter test
flutter test test/storage_service_test.dart
flutter test test/sleep_routine_page_test.dart
```
