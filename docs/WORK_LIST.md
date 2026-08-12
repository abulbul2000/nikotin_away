# Güncel İş Listesi

> Oturum kapanıp açıldığında **buradan devam edilir.** Madde tamamlandıkça `[x]` işaretlenir ve
> yanına kısa not düşülür. Kararların gerekçeleri `docs/TASK_ASSIGNMENT_SYSTEM_DESIGN.md`
> dosyasında.
>
> Son güncelleme: 2026-07-28

## Teslim sırası

1. **Parça 1 — Hatalar** (aşağıda A-G): kullanıcının şikâyet ettiği, yeni sistem gerektirmeyen
   düzeltmeler. Bitince APK → cihazda test.
2. **Parça 2 — Yeni sistemler**: aralık algoritması, görev akışı, Sigara İçtim butonu, ilaç,
   anket yeniden düzeni.
3. **Parça 3 — Çeviri**: 40 dil, ~28.000 satır. En sona bırakıldı çünkü önce hangi metinlerin
   kalacağı netleşmeli.

---

# PARÇA 1 — Hatalar

## A. Görev bildirimi spam'i

- [x] **1.** Gecikmiş görevler artık 1 dakikaya yığılmıyor — 15 dakikalık ödemesiz süreyi aşan
      görev `missed` olarak kapatılıyor, geç teslim edilmiyor. (`home_page.dart`,
      `_overdueTaskGrace`)
- [x] **2.** `_ensureMinimumFiveNotificationsUntilSleep` silindi — plan boşken 5 ek bildirim
      üreten, hepsinde aynı metni kullanan eski yedek zamanlayıcı.

## B. Bildirim görünürlüğü

- [x] **3.** Planlı görevlerde de overlay çağrılıyor. Zamanlanmış bildirim overlay'i kendi
      başlatamadığı (ve uygulama kapalıyken o anda Dart çalışmadığı) için görev saatinde
      ateşlenen native alarm eklendi: `TaskTriggerReceiver`.
- [x] **4.** Aynı alarm watchdog'u da başlatıyor. Önceden watchdog zamanlama anında
      başlıyordu — görev 3 saat sonraysa foreground service 3 saat boyunca 15 sn'de bir
      yokluyordu, ayrıca `WatchdogStore` tek kayıt tuttuğu için iki görev birbirini eziyordu.
      Overlay izni yoksa bildirim yine kullanıcıya ulaşıyor (kademeli düşüş).

## B2. Saat dilimi hatası *(bu partide bulundu)*

- [x] **4b.** **Saat bazlı tüm bildirimler yanlış saatte geliyordu.** `setLocalLocation` hiç
      çağrılmadığı için `tz.local` = UTC idi; `tz.TZDateTime(tz.local, y, m, d, 21, 0)` "21:00
      UTC" demek oluyordu. UTC+3'teki kullanıcı 21:00 istediğinde bildirim ertesi gün 00:00'da
      geliyordu. Testle doğrulandı. `_atDeviceTimeOfDay` yardımcısıyla 6 çağrı düzeltildi.
      Etkilenen: günlük nefes hatırlatıcısı, sağlık ipuçları, **ilaç hatırlatmaları**,
      koç komutları, haftalık anket. (Görev bildirimleri gecikme tabanlı olduğu için
      etkilenmiyordu — hata bu yüzden fark edilmemiş.)

## C. Aksiyonlar uygulamayı açmasın

- [x] **5.** 10 bildirim aksiyonunun hepsi `showsUserInterface: false` oldu; işlem arka plan
      isolate'inde. (SOS aksiyonu henüz yok — Parça 2'de eklenecek ve tek istisna o olacak.)
- [x] **5a.** Arka plan isolate'i *soğuk* başlıyor: `initialize()` orada hiç çalışmadığı için
      `tz.initializeTimeZones()` yapılmamış oluyordu ve takip bildirimi zamanlamak
      `tz.TZDateTime` üzerinden patlardı. `_ensureIsolateReady()` eklendi.
- [x] **5b.** **`followup_done` arka planda hiç işlenmiyordu.** Aksiyonlar uygulamayı
      açtığı sürece HomePage'in dinleyicisi hallediyordu; artık açmadıklarına göre
      "evet, tamamladım" cevabı — yani bir görevin başarılı olduğunu kanıtlayan tek çıktı —
      sessizce kaybolacaktı. Sonuç kaydı arka plana taşındı.
- [x] **5c.** `task_done` arka planda da ön plandakiyle aynı izi bırakıyor
      (`saveTaskResult` + `saveTaskFollowUp`).

> Not: Arka plan isolate şimdilik SQLite'a doğrudan yazıyor. Çakışma riski düşük (uygulama
> ayaktayken aksiyon ana isolate'e gidiyor), ama tasarımdaki kalıcı çözüm SharedPreferences
> kuyruğu — Parça 2'deki `TaskAssignment` işiyle birlikte yapılacak.

## D. Nefes testi

- [x] **6.** Ses tamponu nefes tutma başlarken temizleniyor, arama penceresi `searchFromMs`
      ile prompt sonrasına kısıtlandı. Sorun örnek azlığı değil içeriğiydi: gürültü tabanı
      tamponun başından ölçüldüğü için, oraya düşen derin nefes alma sesi eşiği hiçbir
      üflemenin aşamayacağı yere çıkarıyordu. 4 yeni motor testi bunu sabitliyor.
- [x] **7.** Üç deneme de aynı akışı yaşıyor: otur → derin nefes → tut → üfle. Denemeler arası
      otomatik başlama korundu, sadece atlanan adımlar geri geldi.
- [x] **8.** Spirometri tarzı protokol: hold süresi 5→3sn, üfleme "yavaş/kontrollü"den
      "ani/güçlü zorlu ekspirasyon"a değişti. `BreathAcousticEngine.estimateSpirometry()` ile
      FEV1/FVC oranı ve tepe akış endeksi (yüzde/endeks, sahte litre yok) tahmin ediliyor,
      yeni `BreathSpirometryResultPage`'de akış-zaman eğrisiyle gösteriliyor. Mevcut
      `breathScore`/risk formülüne bilerek karıştırılmadı (kalibrasyonsuz sinyal).
      **Not:** `behavior_engine.dart`'daki `calculateBreathTrendFromRecords`
      (`exhaleTestSeconds`/`inhaleTestSeconds` üzerinden) protokole dokunulmadan bırakıldı,
      ama "uzun üfleme = iyi" varsayımı artık geçerli olmayabilir (steady blow yerine forceful
      exhale) — gerçek kullanım verisiyle threshold'ların (`_breathRiskAdjustmentFromRecords`)
      gözden geçirilmesi gerekebilir.

## E. Logo ve tema

- [x] **8.** `assets/images/no_smoke_logo_transparent.png` üretildi (`tool/make_transparent_logo.dart`).
      Sabit renk karşılaştırması kartın gölge degradesini takip edemediği için bölge büyütmeye
      geçildi; parlaklık tabanı artwork'e taşmayı engelliyor. Ana ekran ikonu değişmedi.
- [x] **9.** Tema turkuaza geçti: `#00C853` → `#00B8D4`, ikincil `#3FD2B0`. Sabit adı da
      `noSmokeGreen` → `brandPrimary` yapıldı (11 dosya, 22 kullanım) — "yeşil" adında turkuaz
      tutmamak için.
- [x] **10.** Watermark saydam logoya geçti, opaklık %6 → %8.
- [x] **11.** `pubspec.yaml` kırık ikon referansı, ikonların gerçekte üretildiği dosyaya
      yönlendirildi. **İkonlar yeniden üretilmedi** — mevcut ana ekran ikonu kasıtlı olarak
      kartlı ve kullanıcı onu beğeniyor.

## F. İzin ekranı

- [x] **12.** `PermissionSetupPage` eklendi: her izin kendi durum satırında, verilmiş olan
      ✓ ile işaretli. İki pencere de kaldırıldı.
- [x] **13.** Ekran `WidgetsBindingObserver` ile ayarlardan dönüşte tüm satırları yeniden
      okuyor. Uygulama içi çözülen izinler için istek sonrası da tazeleme var.
      OEM satırı okunabilir durum sunmadığı için asla "verildi" demiyor, sadece kısayol.
      Yeni metinler şimdilik TR/EN — 40 dil Parça 3'te.

## G. Silmeler

- [x] **14.** "Not ekle" alanı ve "Ek Notlar" başlığı silindi. `addNote` çeviri anahtarı
      artık öksüz — Parça 3 temizliğinde kaldırılacak.
- [x] **15.** İki giriş noktası da kaldırıldı, `daily_checkin_page.dart` silindi. Günlük nefes
      testi akışı artık doğrudan `BreathTestPage`'e gidiyor. `menuDailyCheckIn`,
      `dailyCheckIn*` anahtarları öksüz kaldı — Parça 3'te temizlenecek.
- [x] **16.** Menü butonu ve sayfaya özgü `_logSmokingNow` sarmalayıcısı kaldırıldı.
      **`StorageService.logSmokingNow()` korundu** — yüzen buton (madde 34-35) onu kullanacak.

- [x] **17.** Parça 1 doğrulandı: `flutter analyze` temiz, 145/145 test, debug APK derleniyor.
      **Cihaz testi bekliyor.**

---

# PARÇA 2 — Yeni sistemler

## H. Aralık algoritması (eski kademe merdiveninin yerine)

- [x] **18.** `SmokingIntervalService.naturalIntervalMinutes`
- [x] **19.** `startingBarrierMinutes` = doğal aralık × 1.25
- [x] **20.** `evolveWeeklyBarrierMinutes`, simetrik ±%15
- [x] **21.** `isGoodWeek` ikisini birden istiyor; kayıt hiç yoksa (sıfır değil, yokluk)
      görev başarısına düşüyor
- [x] **22.** `resolveDurationTierRange` ve gün içi kademeli artış silindi. Bariyer haftanın
      taahhüdü olduğu için gün içinde büyümesi, kullanıcıya söylenmemiş bir söz olurdu.
- [x] **23.** Görev sayısı 4–8, uyanık süreden ölçekleniyor (`dailyTaskCount`). İş saatleri
      hem bariyer hesabından hem görev zamanlamasından dışlanıyor (`blockedTaskWindows` →
      `generateUnpredictableMoments`). Molalar bilerek **açık** bırakılıyor — dumansız bir iş
      yerinde mola tam da dışarı çıkılan an. Pencere yetmezse görev sayısı düşürülüyor,
      mesaiye zorlanmıyor.
- [x] **24.** Altında gerçek bir hata vardı: görev aralığı bariyerden bağımsız sabit
      45 dakikaydı, yani 90 dakikalık bariyerde ikinci görev birincinin penceresi
      sürerken başlıyordu. Aralık artık en az bariyer kadar. Yedek yerleştirici de
      bariyere ve mesaiye saygılı hale getirildi, yoksa doğru aralık 4-8 bandını
      düşürecekti. Gün gerçekten yetmiyorsa görev sayısı düşüyor — üst üste binmiyor.
      3 test. **Ayrı bir "kontrol görevi" türü eklenmedi** — ne yapacağı ürün kararı.
- [x] **25.** `loadCurrentBarrierMinutes` ilk çağrıda anketten tohumluyor, 7 gün sonra
      gerçek kayıtlarla yeniden değerlendiriyor. Günlük değil haftalık: tek kötü gün gürültü,
      ayrıca hedefi hafta ortasında oynatmak kullanıcının onu tutturup tutturamayacağını
      hiç öğrenememesi demek.

## I. Görev akışı

- [x] **26.** `TaskAssignment` + `task_assignments` tablosu (şema v23) + durum makinesi.
      `transitionTaskAssignment` tek geçiş noktası: terminal durumlar kesin, böylece
      watchdog ile aynı anda gelen bir cevap görevi iki kez puanlayamıyor. 8 test.
- [x] **27.** 4 aksiyon hem bildirimde hem overlay'de. Sadece SOS uygulamayı açıyor (nefes
      egzersizi doğası gereği ekran); diğer üçü arka planda. Overlay eskiden 2 butonluydu ve
      "done" dışındaki her şeyi erteleme sayıyordu — overlay üzerinden verilen bir ret
      öğrenme motoruna hiç başarısızlık olarak ulaşmıyordu.
- [x] **28.** Ertele → ayrı bildirimle 5/10/15 seçimi. Görev başına 2 erteleme / 2 SOS
      sınırı uygulanıyor: tükenen seçenek bildirimde hiç gösterilmiyor.
- [x] **29.** Reddet → `failed_declined`, öğrenmede `smoked` olarak puanlanıyor.
- [x] **30.** SOS → nefes (4-7-8) → aktivite önerisi → "ne zaman dönelim?" (30dk/1sa/2sa).
      Görev `postponed`'a geçiyor, asla terminal duruma değil. Nefeste geçen süre
      `sosTotalMinutes`'a yazılıyor ki watchdog'ın sessizlik penceresinden düşülmesin.
- [x] **31.** `scheduleTaskConfirmationPrompt` — tam ekran, "Bu süre içinde sigara içtiniz
      mi?". **Evet = başarısız, Hayır = başarılı.** Eski followup aksiyonları yeniden
      kullanılmadı, ayrı kimlikler verildi; ters kutup 3 testle sabitlendi. "Evet" ayrıca
      gerçek sigara kaydı yazıyor, yoksa riskli saat sıralaması bu itirafları hiç görmezdi.
- [x] **32.** Zincir (3 deneme × 5 dk) ve native watchdog zaten çalışıyordu; eksik olan
      görev satırının kapanmasıydı. Watchdog kuyruğu boşaltılırken artık failedMissed'e
      geçiriliyor — önceden ihlal kaydı ve motor sonucu yazılıyor ama satır sonsuza dek
      delivered kalıyordu. Geçiş sonucu kendisi yazdığı için alttaki açık kayıt atlanıyor,
      yoksa tek kaçırılan görev iki kez cezalandırılırdı. 3 test.
- [x] **33.** `DeliveryGateEvaluator` (native): DND kesin sinyal, oyun/video ise
      yatay + ses çalıyor + ekran 10+ dk açık sezgiseli. Engellenen görev aynı alarma
      10±3 dk sonraya yeniden kuruluyor, 90 dk üst sınırdan sonra kapı yok sayılıp
      teslim ediliyor. `AccessibilityService` kullanılmadı (Play yasağı — uygulamanın
      tamamını riske atardı).

## J. Sigara İçtim butonu

- [x] **34.** `SmokedLogOverlayService` + `SmokedLogButtonView`. Sürüklenebilir, konumu
      hatırlanıyor, `ACTION_SCREEN_ON/OFF` ile bağlı. Kartsız logo kullanıldı.
- [x] **35.** 3 sn basılı tut → dolan halka → tik + titreşim. Erken bırakma ve sürükleme
      kaydı iptal ediyor — butonu yoldan çekmek asla sigara kaydetmemeli.
- [x] **36.** Kalıcı bildirimde "Sigara İçtim" aksiyonu (`SmokedLogActionReceiver`).
      Overlay keyguard üstüne çizilemediği için kilit ekranında tek yol bu.
- [x] **37.** `smoking_events.placeId` (şema v22). Ham koordinat değil yer kimliği;
      `getLastKnownPosition` (GPS uyandırmadan), ~150 m eşleşme. Konum yoksa kayıt yine yazılıyor.
- [x] **38.** `SmokedLogConsentPage` — ilk açılıştan önce bir kez. `hasEverConsented`
      ayrı tutuluyor, böylece sonradan kapatıp açmak metni tekrar göstermiyor.
      `PLAY_STORE_DATA_SAFETY.md` yer kimliği bağlantısını beyan ediyor.
      `PLAY_STORE_PERMISSIONS_JUSTIFICATION.md` düzeltildi — eski metin overlay için
      "does not persist as a floating bubble/chat-head" diyordu, yeni buton tam olarak o;
      bu haliyle Play incelemesine gitse yanıltıcı beyan olurdu.
- [x] **39.** `riskyHours` hesabına bağlandı (son 28 gün). Ağırlık 12 — vekillerin
      *toplamının* üstünde, çünkü vekiller bağımsız değil: uygulamayı açıp nefes testi yapıp
      anket doldurmak tek bir oturum, üç kez sayılıyor. 3 yeni test.
- [x] **40.** `calibrateWithLoggedEvents` — yapısal önsel ile gerçek kayıtları harmanlıyor,
      ağırlık `n/(n+50)` ile kayıt biriktikçe gözleme kayıyor. Güven 0.85 tavanlı.
      Hafta içi/hafta sonu ayrı kalibre ediliyor. 5 test.

## K. İlaç sistemi

- [x] **41.** "Günde kaç kez?" (1-6) dropdown'ı saatlerden önce soruluyor, `_suggestTimes`
      dozları uyanık pencereye iki uçtan 1/8 içeri kaçırarak dağıtıyor, her saat
      `showTimePicker` ile düzenlenebiliyor. 3 test.
- [x] **42.** Tavsiye artık ilaç hatırlatmasının gövdesine ekleniyor (`💡` + uyarı satırı),
      ayrı bildirim gönderilmiyor. `scheduleHealthConditionAdviceNotifications`
      ilaç kullanan kullanıcıda erken dönüyor — kaldırılmadı çünkü 44 ona bağlı.
- [x] **43.** İpucu havuzu 10 → 150 (5 hastalık × 30). Her ipucu kriz anına bağlı tek somut
      eylem; doz/tanı/tedavi yok, altında "doktorunuza danışın". 5 test.
- [x] **44.** İlaç kullanmayan ama hastalığı olan kullanıcıya günde 1 tavsiye bildirimi
      (`_healthTipDailyCount` 3 → 1)
- [x] **45.** Her ipucunun altına `medicationAdviceDisclaimer` ("doktorunuza danışın")

## L. Ana sayfa göstergeleri

- [x] **46.** "🔥 Sigarasız Seri" kaldırıldı. Rapor sayfasındaki "Sigarasız geçen gün"
      satırı da aynı hatayı yapıyordu — silinmedi, ölçtüğü şeyle etiketi eşitlendi
      ("Programa başlayalı geçen gün").
- [x] **47.** `ReductionProgress` + `loadReductionProgress`: hedef tutturma serisi,
      içilmeyen sigara, aralık ilerlemesi. Kanıtı olmayan gün "bilinmiyor" sayılıyor,
      iyi güne yazılmıyor. Kayıt yoksa kart üç sıfır yerine ne eksik olduğunu söylüyor.
      11 test.
- [x] **48.** `NoSmokeWidgetProvider.kt` aynı seriye geçti (`reductionStreakDays`)
- [x] **49.** Rozetler üç eksene bağlandı (seri / içilmeyen sigara / aralık kazancı),
      `AchievementsPage` tamamen çevrildi (metin anahtarları hiç yoktu) ve azaltma
      kartına dokununca açılıyor. 9 test.

## M. Haftalık anket

- [x] **50.** Detaylı mod ve mod seçici silindi; sayfa 1792 → ~1440 satır, tek anket kaldı.
- [x] **51.** Uydurma alanların hepsi gerçek soruya döndü: `withdrawal` ve `triggers` artık
      çoklu seçim (5 slider + 7 slider yerine 2 soru), `cravingAvg`+`cravingMax` tek
      `cravingPeak` oldu (sadece peak skorlanıyordu zaten), `alcoholDays` ve
      `socialSmokingContextDays` tetikleyici cevabından türüyor — ayrı soru yok.
      `weeklyCompletionRate` sorulmuyor, `taskSuccessRateSince` ile ölçülüyor.
- [x] **52.** Çıkarılanlar: tedavi/ilaç bloğu (`medicationUse`, `sideEffects`, `adherence` —
      skorun %40'ıydı ve hiç sorulmuyordu), `usedCounselingOrQuitline`, `familySupport`,
      `mostHelpfulCategory`, `dailyTaskAdherenceLevel`, `commandBurdenLevel`.
- [x] **53.** Uyku ve enerji etkisi soruluyor; `_quickRespiratoryBaselineSymptom` silindi.
      Motor artık sorulan CAT maddelerinin ortalamasını alıyor (8 sabitine bölmüyor).
- [x] **54.** mMRC 5 düz cümlelik radyo listesi, 0 = "Nefes darlığı yaşamıyorum" ve
      varsayılan. Motorda `clamp(1,5)` → `clamp(0,5)`.
- [x] **55.** Şiddet soruları başlık + somut örnek + sözel 6 kademe; gece nefes darlığı
      "hiç / bir iki gece / çoğu gece / neredeyse her gece".
- [x] **56.** Anket sonrası özet: skor değişimi, bildirilen tetikleyiciler, riskli saatler,
      yarınki bariyer ve tempo. Paylaşım teklifinden önce gösteriliyor.
- [x] **56b.** `saveSurveyDetail`'e `triggers: const []` gidiyordu — cevap toplanıp
      atılıyordu, artık gerçek liste gidiyor.
- [x] **56c.** Haftalık risk skorlaması hiç test edilmemişti: 12 test eklendi. Eski kayıtlar
      (map biçimli `withdrawal`/`triggers`) hâlâ skorlanıyor, sıfıra düşmüyor. Sayfa için
      7 widget testi.

## N. SOS ekranı

- [x] **57.** Placeholder kaldırıldı; buton artık aktivite önerisi gösteriyor.
- [x] **58.** SOS sayfası tamamen çevrildi (TR/EN); 40 dil Parça 3'te.

## O. iOS sınırı

- [ ] **59.** Üç noktada platform arayüzü çizilecek (teslim / zamanlama / meşguliyet tespiti).
      **iOS kodu bu partide yazılmayacak** — Mac + fiziksel cihaz gerektiriyor.
      Kabul edilen kısıt: iOS'ta overlay API'si yok, zorlayıcı tam ekran görev imkânsız.

---

# PARÇA 3 — Çeviri

- [x] **60.** Kaldırıldı. app_texts.dart artık hiçbir I/O yapmıyor; dosyada googleapis,
      HttpClient veya dart:io geçmediğini test koruyor.
- [~] **61-63.** Kritik yol anahtarları (92 adet: azaltma kartı, rozetler, yeni anket,
      ilaç akışı) 14 dilde tamamlandı → 1.472 giriş. 150 sağlık ipucu TR/EN yazıldı.
      Kalan boşluk `docs/TRANSLATION_GAP.md` içinde dil dil dökülü: 23.255 giriş,
      8 Hint dili %54, 13 dil %0.
- [~] **64.** `craving_sos` ve `achievements` çevrildi. `savings`, `health_recovery`
      ve diğerlerindeki sabit metinler duruyor.
- [x] **65.** 9 nokta yönlü karşılığına çevrildi; kaynak taraması testte.
- [x] **66.** 320×568 render testi tr/de/ru/ta/ar için anket, rozet ızgarası ve ilaç
      düzenleyicisini kapsıyor. Sebep: 31 dropdown'un hiçbirinde isExpanded yoktu.
- [x] **67.** Veri güvenliği belgesi, gizlilik politikası ve mimari yol haritası güncellendi.
      Uygulamanın artık yalnızca iki ağ yolu var: Crashlytics ve isteğe bağlı bulut yedekleme.

---

# PARÇA 4 — 14 Gün Deneme + Zorunlu Abonelik

> Gerekçe/mimari kararlar: `C:\Users\Dell\.claude\plans\validated-honking-pebble.md`. AI Mentör
> özelliği paylaşılan bir API anahtarı kullandığı için (her mesaj geliştiriciye fatura yazıyor),
> tüm uygulama 14 gün deneme sonrası abonelik gerektirecek şekilde kapatılıyor.

- [x] **68.** Faz 1 — `in_app_purchase` eklendi, `subscription_state` tablosu (şema v31) +
      `SubscriptionState` modeli + `startTrialIfNeeded`/`saveSubscriptionState`/
      `loadSubscriptionState`. `onUpgrade` migration'ı var olan kullanıcılara (anketi zaten
      tamamlamış) geriye dönük ceza vermeden bugünden 14 gün tanıyor — ham `db` sorgularıyla,
      `database` getter'ının `_initDatabase()` ortasında tekrar tetiklenip deadlock olmasını
      önleyerek. `survey_page.dart`'a trial-start tetikleyicisi eklendi. 4 test.
- [x] **69.** Faz 2 — `SubscriptionService.resolveAccess()` merkezi karar noktası (trial/active/
      grace/showGate/needsConnectionCheck). `SubscriptionGatePage` kilit ekranı (satın alma
      butonları bu fazda placeholder). `splash_page.dart` + `main.dart`'ın resume hook'u
      (5 dakika debounce'lu) gate'i tetikliyor. Offline grace period: 3 gün. 9 test.
- [x] **70.** Faz 3 kod tarafı — `functions/subscription.js` (`verifyPlaySubscription`,
      stateless — Firestore yok), `functions/index.js`'e `verifySubscription` export,
      `googleapis` dependency. **Kurulum (service account, Play Console izinleri, Blaze planına
      geçiş, deploy) kullanıcı tarafından yapılacak** — kod hazır, henüz deploy edilmedi.
- [x] **71.** Faz 4 — `aiChat` fonksiyonu artık `subscriptionProof` kontrolü yapıyor (abone
      değilse/deneme dışıysa `permission-denied`). `ai_service.dart` her çağrıya kanıt ekliyor,
      `ai_chat_page.dart` reddedilirse `SubscriptionGatePage`'e yönlendiriyor.
      `docs/PLAY_STORE_DATA_SAFETY.md` güncellendi (2026-08-13): "Finansal bilgiler → Satın
      alma geçmişi" satırı + abonelik doğrulama ağ yolu (Bölüm 1, 2, 3, 4) eklendi.
- [ ] **72.** Faz 5 — Manuel uçtan uca senaryolar (yeni kullanıcı → deneme → gate → satın alma →
      devam; offline grace period; Play Console'da manuel iptal → expired). Play Console Data
      Safety formunda "Finansal bilgiler → Satın alma geçmişi" **elle işaretlenecek** — referans
      metin `docs/PLAY_STORE_DATA_SAFETY.md` Bölüm 2 ve 6'da hazır, form doldurma Play Console
      üzerinden kullanıcı tarafından yapılmalı.

---

# PARÇA 5 — Watchdog ihlal/görev çelişkisi (kullanıcı bildirdi, 2026-08-12)

> Kullanıcı gerçek cihazda ekran görüntüleriyle bildirdi: aynı görev için hem "İhlal" bildirimi
> geliyor hem de dakikalar sonra ayrıca "Görevi tamamladın mı?" sorusu geliyor — birbirini
> çelişen iki bildirim.

- [x] **73.** Kök neden bulundu: `NoResponseWatchdogService.kt`'deki
      `NativeViolationStore.tryInsertNoResponseViolation` ihlali doğrudan SQLite'a
      (`protocol_violations`) yazıyordu, `task_assignments` satırını hiç güncellemiyordu. Bu
      yüzden görev sonsuza dek `accepted` durumunda asılı kalıyor, önceden planlanmış
      `scheduleTaskConfirmationPrompt` alarmı da normal şekilde ateşleniyordu — iki
      senkronize olmayan kaynak aynı kullanıcıya çelişkili mesaj gönderiyordu.
      **Düzeltme:** `NativeViolationStore` tamamen kaldırıldı, watchdog artık ihlali her zaman
      `WatchdogStore.enqueueViolation` kuyruğuna yazıyor (CLAUDE.md'nin "tek istisna" kuralı da
      böylece kapandı — artık istisna yok, hepsi kuyruk+drain). Dart tarafında
      `NotificationService.syncWatchdogViolationsFromNative` (artık public) hem ihlali kaydedip
      görevi `failedMissed`'e geçiriyor hem de `_plugin.cancel(_confirmIdFor(taskTitle))` ile
      artık geçersiz olan "tamamladın mı?" alarmını iptal ediyor.
- [x] **74.** İkinci kök neden: bu senkronizasyon yalnızca `main()`'de (soğuk açılış) bir kez
      çalışıyordu, resume'da tekrar tetiklenmiyordu — kullanıcı uygulamayı hiç tam açmadan
      sadece bildirimlerle etkileşiyorsa (ekran görüntülerindeki senaryo tam olarak bu)
      senkronizasyon hiç olmuyordu. `main.dart`'ın `didChangeAppLifecycleState` resume kolu
      artık `syncWatchdogViolationsFromNative()`'i de çağırıyor.
      `flutter analyze` temiz, `app:compileDebugKotlin` başarılı. **Cihaz testi bekliyor.**
- [x] **75.** Üçüncü, ayrı bir kök neden bulundu: uygulamada iki paralel görev-onay sistemi
      vardı. Yeni `TaskAssignment` state machine + `scheduleTaskConfirmationPrompt` ("Bu süre
      içinde sigara içtiniz mi?") ve eski, `task_followups` tablosuna dayanan sistem
      (`TaskOutcomeConfirmPage`/`_askTaskOutcome`, "Görev başarılı mı?" — ters kutup). Görev
      kabul edildiğinde ikisine birden yazılıyordu, kullanıcı aynı görev için iki farklı soru
      görüyordu. Eski sistemin normal-görev (ADAPTIVE_NO_SMOKE) yolu tamamen kaldırıldı;
      süre-bariyeri (duration-barrier) görevlerinin `task_followups`'a bağımlılığı korundu
      (araştırma bariyer yolunun şu an canlı bir üreticisi olmadığını gösterdi, ama kullanıcının
      isteği üzerine dokunulmadı). `task_outcome_confirm_page.dart` ve `task_follow_up_page.dart`
      silindi, yerine yeni `TaskSmokedConfirmPage` (doğru soru + doğru kutup) geldi.
      `_startTaskFromMandatoryScreen` de `TaskAssignmentService.handleTaskAction`'a
      yönlendirildi — bu, MandatoryTaskPage'den kabul edilen görevlerin "sigara içtiniz mi?"
      sorusunu hiç almadığı ayrı bir bug'ı da düzeltti.
- [x] **76.** Bildirim gövdesine (body, aksiyon butonuna değil) tıklandığında hiçbir şey
      olmuyordu — sadece aksiyon butonları işleniyordu. `_typeTaskConfirm` body-tap'i artık
      `TaskSmokedConfirmPage`'i `navigatorKey` üzerinden açıyor. `_typeTaskStart` body-tap'i
      ise doğrudan bir sayfa açmak yerine (MandatoryTaskPage'in kendi mandatory-gate
      mantığıyla çakışma riski taşırdı) `_presentMandatoryTaskIfNeeded()`'i yeniden
      tetikleyen bir sinyal gönderiyor — bu fonksiyon zaten kendi görevini kendi seçip
      `_mandatoryTaskShown` + cooldown ile korunuyor, çift ekran açılma riski yok.
      817 test geçiyor, `flutter analyze` temiz. **Cihaz testi bekliyor.**

---

# Ertelenmiş

- **Simülasyon testi** — 1000+ profil davranış simülasyonu + 40 dil × ekran boyutu taraması.
  Kanıt testi yazıldı ve çalıştı (İtalyanca taşmasını 4 saniyede buldu), kullanıcı sonraya
  bırakmayı seçti. Test dosyası scratchpad'de saklı.
- **Geçmişe sigara kaydı ekleme** — Günlük Değerlendirme kaldırıldığı için kullanıcı unuttuğu
  bir sigarayı sonradan ekleyemeyecek. Gerekirse raporlar ekranına eklenebilir.
- **Mentor + para kazanma sistemi**, **sigara içmeyenlerin mentor olarak katılması** — ayrı faz.

# Onay bekleyen

- 150 sağlık ipucunun tıbbi içeriği yayına çıkmadan gözden geçirilmeli.
- Asya dilleri (Tamilce, Kannada, Malayalam, Telugu) için anadili konuşan gözden geçirmesi
  önerilir.
