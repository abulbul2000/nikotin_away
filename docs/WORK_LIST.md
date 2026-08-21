# Güncel İş Listesi

> Oturum kapanıp açıldığında **buradan devam edilir.** Madde tamamlandıkça `[x]` işaretlenir ve
> yanına kısa not düşülür. Kararların gerekçeleri `docs/TASK_ASSIGNMENT_SYSTEM_DESIGN.md`
> dosyasında.
>
> Son güncelleme: 2026-08-20

---

# AKTİF — Bildirim mimarisi yeniden tasarımı + görevlendirme motoru + uyku alarmı
*(2026-08-20 kullanıcıyla detaylı konuşuldu — kapsam netleşti, uygulama başlıyor)*

## Karar özeti (kullanıcı onaylı)

**Bildirim/overlay mimarisi:**
- Native "diğer uygulamaların üstüne biner" `TaskOverlayService` (WindowManager overlay)
  **tamamen kaldırılır**. Yerine: bildirime basınca uygulama öne gelir (soğuksa önce ana ekran
  kısaca görünür, sonra üstüne biner), ilgili tam ekran **Flutter sayfası** açılır.
- Tüm bildirimler seslidir — hiçbiri sessiz değil.
  - Görevlendirme + ilaç hatırlatma → alarm sesi (`USAGE_ALARM`, ısrarcı/FLAG_INSISTENT).
  - Diğer tüm bildirimler (sağlık ipucu, anket, koç komutu, vb.) → normal bildirim sesi
    (`USAGE_NOTIFICATION`), alarm gibi değil.
- Görevlendirme bildirimi: başlık jenerik ("Yeni görevlendirme"), gövdede görev detayı YOK —
  detay sadece tam ekran sayfada görünür.
- İlaç hatırlatma bildirimi: **istisna** — ilaç adı bildirimde görünür (tıbbi açıdan kullanıcının
  uygulamayı açmadan bilmesi gerekiyor).
- Bildirim/alarm sesi, kullanıcı tam ekran sayfayı gördüğü an susar (şu anki bug: native overlay
  açılınca bildirim/alarm susmuyor — bu yeni mimariyle kendiliğinden çözülür, ayrı bir yama
  gerekmez çünkü native overlay yolu tamamen silinir).

**Görevlendirme motoru:**
- Sıklığı davranış motoru belirler, **günlük minimum 4** (başarı/başarısızlık sayıyı etkilemez).
- Başlangıç: gün içine eşit dağılım. Kullanıcı tanındıkça (bkz. haftalık analiz): riskli saatlere
  ağırlık kayar, hem görevlendirme sayısı hem süreler artar.
- **Haftada bir** büyük program analizi (sıklık/süre/riskli-saat ağırlıkları yeniden hesaplanır).
- **Gün içi küçük dokunuşlar**: o günkü gerçek sigara sayısı/aralık sürelerine göre küçük
  ayarlar — haftalık ana programı büyük ölçüde değiştirmez.
- Denge kuralı: **iyi gidiyorsa sıkılaştır, kötü gidiyorsa gevşet** (ters değil — başarı ödülü
  daha fazla zorluk, başarısızlık cezası değil esneme).
- Kullanıcı ayarlardan tavan belirleyebilir (mevcut Nazik/Dengeli/Sıkı intensity ayarı bu tavan
  rolünü görür — sistem bu seviyeyi aşacak şekilde sıkılaştırmaz) **+** anlık "bugün beni
  zorlama" düğmesi (yeni, henüz yok).

**Uyku Zekâsı alarmı + raporu (yeni özellik, sıfırdan):**
- Günlük ankete yeni soru: "Yarın kaçta uyanmak istersiniz?" — kullanıcı saat girer. Bu, gün
  bazlı farklı uyanma saati desteğinin kaynağı (haftalık anket alanı, günlük anket akışına
  eklenir — hangi anket olduğu koddan doğrulanmalı).
- Belirlenen saatte **yüksek alarm** çalar (görevlendirme/ilaç ile aynı ses kategorisi).
- Alarma basınca: uygulama açılır, tam ekran Uyku Zekâsı raporu (Flutter sayfa, native overlay
  DEĞİL) gösterilir. Altta **Tamam** + **Ertele** butonları.
  - Tamam → rapor teslim edilmiş sayılır, alarm/rapor kapanır.
  - Ertele → 10 dakika sonra aynı şekilde (yüksek alarm + tam ekran rapor) tekrar çalar.
- Ayarlardan açılıp kapanabilir olmalı.
- Görevlendirme planı bu gün-bazlı uyanma saatini hesaba katmalı (mevcut `wake_time` sabit
  ayarının yerini/yanını alacak şekilde).
- Mevcut `SleepIntelligenceService`/`SleepProbeService` sadece pasif gece ölçümü yapıyor (ekran
  etkileşimi + şarj durumu örnekleme) — alarm/erteleme/rapor sunumu yok, hepsi sıfırdan yazılacak.

## Uygulama adımları (taslak — ilerledikçe güncellenecek)

- [x] **1.** Native `TaskOverlayService.kt`'nin görevlendirme-overlay kısmı (`ACTION_SHOW`,
      `showOverlay`, `show()`) tamamen kaldırıldı — `showInfo`/`showConfirm`/`showReminder`
      (sağlık ipucu, "sigara içtin mi", hatırlatıcı) dokunulmadan kaldı, onlar Parça 4'te ele
      alınacak. `MainActivity.kt`'deki `showTaskOverlayFromNotification` case'i ve Dart tarafındaki
      `AndroidWatchdogService.showTaskOverlayFromNotification` de kaldırıldı. Bildirim body-tap'i
      artık `notification_service.dart`'ın `_typeTaskStart` kolunda `_mandatoryTaskRequestController`
      sinyali yayınlıyor, `home_page.dart` bunu dinleyip kendi `_presentMandatoryTaskIfNeeded
      (isRetry: true)`'ini çağırıyor.
      **Neden sinyal, doğrudan push değil:** İlk denemede body-tap kodu doğrudan
      `navigator.push(MandatoryTaskPage)` yapıyordu — ama `HomePage`'in kendi resume/foreground
      lifecycle'ı da bağımsız olarak aynı anda `_presentMandatoryTaskIfNeeded`'i çağırıyor, iki
      push birbirine çarpıp bazen hiçbiri görünmüyordu (cihazda tekrarlı test edildi, kanıtlandı).
      Sinyale geçildi ama **yeni bir kanıtlanmış hata daha bulundu**: bildirime dokunulduğu an
      `HomePage` henüz `initState` çalıştırmamış olabiliyor (soğuk/arka plandan foreground'a
      geçiş süresi), bu yüzden `_mandatoryTaskRequestController.hasListener` `false` dönüp sinyal
      kayboluyor — kanıt: `dumpsys notification` bildirimin iptal edildiğini (`cancel` çalıştı)
      ama hiçbir sayfa açılmadığını gösterdi. Düzeltme: `hasListener` olana kadar 300ms×10 (3sn)
      retry döngüsü eklendi (`notification_service.dart`, `_processNotificationResponse`).
      **Cihaz testi bekliyor** — kullanıcı bilgisayar başında değil, telefonu tekrar bağlayınca
      kurulup test edilecek.
- [x] **1b.** "Kabul Et" sonrası gelen "zamanlayıcı başladı" bildirimi (`showTaskTimerStartedNotification`)
      yanlışlıkla `_taskStartChannelId` (alarm sesi) kullanıyordu — kullanıcı onayladı: bu adımda
      alarm değil normal bildirim sesi istiyor. Yeni `_taskTimerStartedChannelId` eklendi,
      `AudioAttributesUsage.notificationRingtone` + `Importance.high` (alarm değil). Görev süresi
      bitince gelen "sigara içtiniz mi?" onay sorusu (`scheduleTaskConfirmationPrompt`,
      `task_confirm_channel_v2`) zaten alarm sesindeydi — kullanıcı bunu istediğini teyit etti,
      dokunulmadı. **Cihaz testi bekliyor.**
- [x] **1c. (kullanıcı cihazda bildirdi, 2026-08-21)** Bildirime dokunulup `MandatoryTaskPage`
      açıldığında bile native watchdog'un "Görev yanıtı bekleniyor" foreground bildirimi ekranda
      asılı kalıyordu. **Kök neden:** `home_page.dart`'ta `AndroidWatchdogService.
      acknowledgeWatchdogByTaskTitle` çağrısı sadece `result == true` (kullanıcı "Kabul Et"e
      bastığında) dalındaydı — "Reddet" ya da SOS'a gidip dönme durumunda hiç çağrılmıyordu,
      bildirim native 15 dakikalık zaman aşımına uğrayıp ihlal yazana kadar asılı kalıyordu. İki
      çağrı noktası da (mandatory-gate yolu ~satır 1401, `_startMissedTask` ~satır 2962) sayfa
      `Navigator.push` sonucu dönen anda, `result`'tan bağımsız acknowledge edecek şekilde
      düzeltildi. `flutter analyze` temiz (0 sorun). **Cihaz testi bekliyor.**
- [x] **2. (kapsam genişledi, kullanıcı talebiyle 2026-08-21)** Görevlendirme bildirimi artık
      **hiçbir aksiyon butonu içermiyor** — sadece görüntü/ses/titreşim. Kullanıcının talebi:
      "gelen bildirim ne olursa olsun uygulama tam ekran açılsın, Kabul/Reddet gibi seçimler
      bildirimde olmasın". Kapsam netleştirildi: SADECE görevlendirme (task trigger) bildirimi,
      diğer tüm bildirim türleri (ilaç, anket, koç komutu, eski `task_followups` takip sistemi)
      dokunulmadan aksiyon butonlu kaldı.
      - `showFirstTaskTriggerNotification`/`scheduleFirstTaskTriggerNotification`
        (`notification_service.dart`): `_taskTriggerActions` fonksiyonu tamamen kaldırıldı,
        bildirimler artık `actions` içermiyor, `fullScreenIntent: true` eklendi (kilit ekranında
        otomatik tam ekran açılış — Android kısıtı: ekran açıkken ve kullanıcı başka bir
        uygulamadaysa sistem yine de "heads-up" gösterir, dokunma gerekir, bu platform sınırı
        aşılamaz). Body artık görev detayı içermiyor, sadece jenerik `disciplineCommandBody`.
      - Görevlendirme retry bildirimi (`_scheduleUnansweredTaskUpdateReminder`, `isFollowUp ==
        false` dalı) aynı şekilde aksiyonsuz + `fullScreenIntent: true` yapıldı; eski
        `task_followups` sistemi (`isFollowUp == true`) dokunulmadan kaldı.
      - Ses/titreşim süresi 15sn → **20sn** (`_taskTriggerTimeoutMs`, sadece görevlendirmeye
        özel yeni sabit — diğer bildirimlerin 15sn'lik `_notificationTimeoutMs`'ine
        dokunulmadı). Kullanıcı onayı: "20sn sürsün ama dokunulursa hemen kesilsin, 20sn'nin
        bitmesini beklemeye gerek yok" — `MandatoryTaskPage.initState`'teki mevcut
        `cancelActiveTaskTriggerAlarm()` çağrısı zaten bunu sağlıyor (sayfa açılır açılmaz sesi
        kesiyor), timeout sadece kullanıcı hiç dokunmazsa üst sınır.
      - **`MandatoryTaskPage` tamamen yeniden tasarlandı**: artık `Navigator.pop(bool)` değil
        `Navigator.pop(String? actionId)` — `TaskActionId.done/decline/postpone5/10/15/sos`
        döner. Ertele'ye basınca sayfa içi 3 seçenekli (5/10/15 dk) görünüme geçiyor (eskiden
        ayrı bir bildirimle soruluyordu, kod yorumu: "aksiyonlar iç içe geçemediği için" — tam
        ekran sayfada bu kısıt yok). Postpone/SOS limitleri (`maxPostponesPerTask`/
        `maxSosPerTask`) doluysa ilgili buton hiç gösterilmiyor (`NotificationService.
        taskAllowanceFor`, eskiden private `_taskAllowanceFor`, şimdi public).
      - **Ayrı bulunan hata da düzeltildi:** Reddet butonu daha önce gerçekte hiçbir şey
        yapmıyordu (`TaskActionId.decline` hiç tetiklenmiyordu), sadece sayfayı kapatıp birkaç
        dakika sonra aynı görevi tekrar soruyordu (retry). Artık gerçekten reddediyor
        (`failedSmoked` gibi puanlanıyor, bildirimdeki eski doğru davranışla hizalandı).
      - `home_page.dart`'taki iki `MandatoryTaskPage` çağrı noktası (mandatory-gate yolu,
        `_startMissedTask`) yeni `String?` dönüş tipine göre yeniden yazıldı — artık
        `_handleTaskNotificationAction`'daki merkezi `TaskAssignmentService.handleTaskAction`
        akışını kullanıyorlar (SOS/uyku-rutini yönlendirmesi dahil), kod tekrarı azaldı.
      - Native tarafta `TaskTriggerReceiver`'a giden title/body/label extra'ları zaten hiç
        okunmuyordu (`onReceive` sadece taskTitle/watchdogId kullanıyor) — dokunulmadı, sadece
        Dart tarafında boş string geçiliyor artık (kod yorumuyla açıklandı, temizlik ayrı iş).
      - `flutter analyze` temiz (0 sorun), `flutter test` tam paket 1285 test — 2 başarısızlık
        (`craving_sos_flow_test.dart`, `sleep_routine_page_test.dart`) doğrulandı: bu iki dosya
        birlikte VE benim değişikliklerim olmadan (stash ile) çalıştırıldığında da 9/9 geçiyor —
        önceden var olan bir test-sıralama/izolasyon sorunu, bu işle ilgisi yok. **Cihaz testi
        bekliyor** (özellikle `fullScreenIntent` davranışı gerçek cihazda doğrulanmalı).
- [ ] **3.** İlaç hatırlatma bildirimleri bulunup (ayrı kanal/fonksiyon), ilaç adının bildirimde
      kaldığı doğrulanır (bunlar İSTİSNA, değişmeyecek).
- [ ] **4.** Diğer tüm bildirim kanalları (sağlık ipucu, anket, koç komutu vb.) taranıp hepsinin
      ses ayarı `USAGE_NOTIFICATION` + normal ses olduğu doğrulanır/düzeltilir (alarm sesine
      kaçanlar varsa düzeltilir).
- [x] **5.** ~~`NotificationBudget.dailyBudgetFor` gentle=2 → 4~~ **YANLIŞ VARSAYIMDI, kod okunmadan
      yazılmıştı.** `dailyBudgetFor` yalnızca `NotificationClass.offered` bildirimler için (sağlık
      ipucu, koç komutu vb.) — görevlendirmeler (`NotificationKind.taskAlert`) `owed` sınıfında,
      bu bütçeye hiç tabi değil. Gerçek "günlük minimum 4 görevlendirme" sınırı zaten
      `SmokingIntervalService.minDailyTasks = 4` / `maxDailyTasks = 8` olarak mevcut
      (`smoking_interval_service.dart:74-75`, `buildAdaptiveNoSmokePlan`'ın `.clamp()` çağrısında
      kullanılıyor) — kullanıcının istediği kural zaten koddaydı, değişiklik gerekmedi.
- [x] **6a. (araştırma tamamlandı, kod değişikliği bekliyor)** Explore ajanı ile mevcut adaptif plan
      motoru tam olarak dosya:satır kanıtıyla incelendi — özet:
      - **Riskli-saat yerleşimi zaten var**, ama "güven arttıkça artan ağırlık" YOK: `buildDailyAdaptivePlan`
        (`discipline_protocol_service.dart:347-450`) → `generateUnpredictableMoments` (`:98-187`)
        slotları sadece riskli-saat pencerelerinden seçiyor (`_resolveCandidateWindows`, `:223-262`),
        riskyHours boşsa genel 55dk-aralıklı pencerelere düşüyor. Ama pencere içi seçim tamamen
        rastgele (`:150`) — riski daha yüksek saate ekstra ağırlık yok, ve bu yerleşim ilk günden
        itibaren tam güçte, kademeli artmıyor.
      - **Güven/tanıma eşiği YOK**: Tek geçit `isAdaptivePlanningEligible` (`storage_service.dart:2127-2149`)
        — 24 saat + sonraki uyanma saati şartı, ikili (evet/hayır), kademeli değil. `_dataConfidence`
        (`behavior_engine.dart:1507-1516`) sadece dashboard'da gösterim için, planlamada hiç okunmuyor.
      - **Riskli saatte süre artışı YOK**: tek süre ayarı `strainOffset` (`discipline_protocol_service.dart:399-408`),
        risk değil "strainScore" (saat bazlı başarı/başarısızlık) bazlı küçük ±jitter.
      - **Haftalık yeniden analiz KISMİ** — sadece bariyer süresi için: `loadCurrentBarrierMinutes`
        (`storage_service.dart:2828-2877`) → `evolveWeeklyBarrierMinutes`/`isGoodWeek`
        (`smoking_interval_service.dart:235-261`, `weeklyStep=0.15`) 7 günde bir tetikleniyor (periyodik
        job değil, çağrı anında tembel kontrol). Görev SAYISI ve riskli-saat ağırlıkları haftalık
        döngüde YOK — sürekli/her plan üretiminde yeniden hesaplanıyor, "haftada bir büyük analiz"
        kavramı bunlar için mevcut değil.
      - **İyi/kötü gidişe göre sıkılaştırma/gevşetme KISMEN var**: `dailyTaskCount`
        (`smoking_interval_service.dart:280-295`) successRate≥0.75→+1, ≥0.88→+1 daha; failureRate≥0.45→-1;
        postponeRate≥0.5→-1. `computeUnpredictableDelay`/`computeAdaptiveTaskDuration`
        (`discipline_protocol_service.dart:28-76`) de successRate'e göre aralık sıkıştırıyor/süre uzatıyor.
        AMA bariyer süresi tarafı (`evolveWeeklyBarrierMinutes`) simetrik (%15 büyüt/küçült) — kullanıcının
        istediği "başarı ödülü daha fazla zorluk, başarısızlık cezası değil esneme" asimetrisi yok,
        şu an iki yön de aynı formülün ayna görüntüsü.
      - **Gün içi küçük dokunuş YOK**: `buildAdaptiveNoSmokePlan` günün planını bir kere üretip
        cache'liyor (`_adaptivePlanDateKey`, `:3209-3221`), gün boyu değişmiyor. Tek "esnetme" mekanizması
        `MentorReliefService` (kullanıcının "Zorlanıyorum" demesiyle tetiklenen), ve bu KASITLI olarak
        SADECE YARINA etki ediyor, bugüne asla (`storage_service.dart:4635-4639`'daki yorum: bugünü
        geriye dönük esnetmek ya no-op olur ya da kullanıcının zaten gördüğü görevlerle çakışır).
- [ ] **6b.** Yukarıdaki bulgulara göre gerçek eksikler: (1) riskli-saat pencere-içi ağırlıklandırma
      + güven eşiğine bağlı kademeli geçiş (yeni "confidence" kavramı gerekiyor, `_dataConfidence`
      genişletilip planlamaya bağlanabilir ya da yeni bir sayaç eklenebilir), (2) görev SAYISI ve
      riskli-saat ağırlıkları için haftalık kadans (mevcut günlük hesaplamanın üstüne haftalık
      "büyük" katman), (3) bariyer evrimini asimetrik yapma (`evolveWeeklyBarrierMinutes`'daki
      %15/%15 yerine farklı büyüt/küçült oranları), (4) gün içi küçük dokunuş için YENİ bir mekanizma
      (bugünün sigara sayısı/aralığını okuyup kalan plan öğelerini hafifçe ayarlayan, `MentorReliefService`'ten
      bağımsız, "yarına değil bugüne" çalışan bir yol).
- [ ] **9.** "Bugün beni zorlama" anlık düğmesi — UI + storage flag + motorun bunu okuyup o gün
      sıkılaştırmayı atlaması.
- [ ] **10.** Günlük ankete "yarın kaçta uyanmak istersiniz?" sorusu eklenir, gün-bazlı uyanma
      saati storage'a yazılır.
- [ ] **11.** Uyku alarmı native alarm (görev tetikleme ile aynı desen: `setExactAndAllowWhileIdle`
      + yüksek-önem bildirim kanalı, alarm sesi) + Ertele (10 dk yeniden kur) + Tamam (kapat,
      rapor teslim edildi işaretle).
- [ ] **12.** Uyku Zekâsı raporu tam ekran Flutter sayfası (yeni) — geceki veriyi
      `SleepProbeService`/mevcut analiz koduyla özetler, altta Tamam/Ertele.
- [ ] **13.** Ayarlara Uyku Zekâsı alarmı aç/kapa anahtarı eklenir (mevcut Sleep Intelligence
      ayarından ayrı ya da onun bir alt seçeneği — koddan karar verilecek).
- [ ] **14.** Görevlendirme planı, gün-bazlı uyanma saatini hesaba katacak şekilde güncellenir
      (`sleepAt`/`wakeRaw` sabit `wake_time` yerine o günün anket cevabını okur).
- [ ] Her adım sonunda `flutter analyze`, ardından cihazda gerçek doğrulama (bkz.
      [[feedback_root_cause_only]] — tahminle "düzelttim" denmeyecek, `dumpsys`/logcat ile
      kanıtlanacak).

---

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
- [x] **77.** AI Mentöre sesli giriş (`speech_to_text`, basılı tut → konuş) ve `set_permission`
      tool'u eklendi (mikrofon/konum/adım sayısı/sağlık verisi/kullanım erişimi izinlerini
      kullanıcı adına isteyebiliyor). Android bir izni programatik kapatmaya izin vermediği için
      sistem promptu kapatma isteklerini Ayarlar'a yönlendiriyor, tool sadece açma yönünde
      çalışıyor. Bu işle birlikte `aiChat*` ailesindeki 11 anahtarın (başlık/hint/gönder/hata/
      feragatname/aksiyon metinleri + yeni mikrofon/izin metinleri) hiçbiri 24 dilde
      (`generated_language_data.dart`) yoktu — hepsi İngilizce'ye düşüyordu; bu oturumda 24 dilin
      tamamına eklendi. `flutter analyze` temiz, 818 test geçiyor. **Cihaz testi bekliyor.**

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
