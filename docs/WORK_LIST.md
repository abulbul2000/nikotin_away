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

- [ ] **12.** İki ayrı izin penceresi (MIUI + overlay, ikisi de aynı butonları kullanıyor) tek
      bir durum göstergeli ekranda birleşecek.
- [ ] **13.** `didChangeAppLifecycleState` ile ayarlardan dönüşte izin durumu tazelenecek. Şu an
      `requestOverlayPermission()` ayarı açıp devam ediyor, sonucu hiç öğrenmiyor.

## G. Silmeler

- [x] **14.** "Not ekle" alanı ve "Ek Notlar" başlığı silindi. `addNote` çeviri anahtarı
      artık öksüz — Parça 3 temizliğinde kaldırılacak.
- [x] **15.** İki giriş noktası da kaldırıldı, `daily_checkin_page.dart` silindi. Günlük nefes
      testi akışı artık doğrudan `BreathTestPage`'e gidiyor. `menuDailyCheckIn`,
      `dailyCheckIn*` anahtarları öksüz kaldı — Parça 3'te temizlenecek.
- [x] **16.** Menü butonu ve sayfaya özgü `_logSmokingNow` sarmalayıcısı kaldırıldı.
      **`StorageService.logSmokingNow()` korundu** — yüzen buton (madde 34-35) onu kullanacak.

- [ ] **17.** Parça 1 doğrulama: `flutter analyze` + `flutter test` + `flutter build apk --debug`

---

# PARÇA 2 — Yeni sistemler

## H. Aralık algoritması (eski kademe merdiveninin yerine)

- [ ] **18.** Doğal aralık hesabı: `(24s − uyku − iş saatleri) ÷ günlük sigara`
- [ ] **19.** Başlangıç bariyeri = doğal aralık × 1.25
- [ ] **20.** Haftalık değerlendirme: iyi hafta +%15, kötü hafta −%15
- [ ] **21.** Ölçüt: gerçek sigara kayıtları **ve** görev başarısı birlikte
- [ ] **22.** `resolveDurationTierRange` (6 kademeli merdiven) silinecek
- [ ] **23.** Günlük 4–8 görev, aktif saate göre; iş saatleri hariç, **molalar dahil**
- [ ] **24.** Uzun bariyerde kontrol görevleri (4–8 teması korumak için)
- [ ] **25.** İlk hafta anket verisiyle, hafta sonunda gerçek kayıtlarla yeniden kalibrasyon

## I. Görev akışı

- [ ] **26.** `TaskAssignment` modeli + SQLite tablosu (durum makinesi)
- [ ] **27.** 4 aksiyon: Kabul Et / Ertele / Reddet / SOS Krizdeyim
- [ ] **28.** Ertele → 5/10/15 dk alt seçenekleri, görev başına en fazla 2 kez
- [ ] **29.** Reddet → başarısız **+ sigara kaydı +1**
- [ ] **30.** SOS → nefes egzersizi → aktivite önerisi → kullanıcı erteleme süresi seçer
      (30dk/1sa/2sa), görev iptal olmaz, en fazla 2 SOS
- [ ] **31.** Süre bitince **aynı tam ekran**: "Bu süre içinde sigara içtiniz mi?"
      **Evet = başarısız, Hayır = başarılı** (mevcut sorunun tam tersi — ters bağlanırsa
      öğrenme motoru tüm veriyi ters kaydeder)
- [ ] **32.** Yanıtsızlık: 3 deneme × 5 dk → başarısız (uygulama kapalıyken de)
- [ ] **33.** Oyun/DND/tam ekran tespiti → kuyruk, max 90 dk, kuyrukta >2 görev birikirse
      `expired` (öğrenmeye nötr). `AccessibilityService` **kullanılmayacak** (Play yasağı).

## J. Sigara İçtim butonu

- [ ] **34.** Şeffaf yüzen buton, `no_smoke_splash_icon.png`, sürüklenebilir,
      **ekran her açıldığında** görünür (`ACTION_SCREEN_ON/OFF`)
- [ ] **35.** 3 saniye basılı tut → dolan halka → tik + titreşim. Erken bırakılırsa kayıt yok.
- [ ] **36.** Kilit ekranı için kalıcı bildirimde aksiyon + 5 sn "Geri Al"
- [ ] **37.** Konum: ham koordinat değil **yer kimliği**, otomatik etiket
      ("en sık gittiğiniz yer"). Konum alınamazsa kayıt yine yazılır.
- [ ] **38.** İlk kurulumda tanıtım + onay ekranı, KVKK dokümanı güncellenecek
- [ ] **39.** `riskyHours` hesabına bağlanacak — şu an sigara kayıtları oraya **girmiyor**
      (`storage_service.dart:2832` sadece anket zamanı, telefon kullanımı, görev başarısızlığı
      kullanıyor)
- [ ] **40.** `SmokingTimePredictionEngine` kalibrasyonu (sentetik veriyle birim testleri)

## K. İlaç sistemi

- [ ] **41.** "Günde kaç kez?" sorulacak, saatler uyanık saatlere eşit dağıtılıp önerilecek
- [ ] **42.** Hastalığa özel tavsiye her ilaç hatırlatmasına gömülecek, ayrı bildirim
      gönderilmeyecek (`scheduleHealthConditionAdviceNotifications` kaldırılacak)
- [ ] **43.** İpucu havuzu 10 → 150 (5 hastalık × 30)
- [ ] **44.** İlaç kullanmayan ama hastalığı olan kullanıcıya günde 1 tavsiye bildirimi
- [ ] **45.** Her ipucunun altına "doktorunuza danışın"

## L. Ana sayfa göstergeleri

- [ ] **46.** "🔥 Sigarasız Seri" kaldırılacak — `quitDate`'ten beri geçen günü sayıyor,
      kullanıcının içip içmediğine **hiç bakmıyor**
- [ ] **47.** Yerine üç metrikli azaltma kartı: hedef tutturma serisi + içilmeyen sigara +
      aralık ilerlemesi
- [ ] **48.** Ana ekran widget'ı (`NoSmokeWidgetProvider.kt`) aynı metriklere geçecek
- [ ] **49.** Başarımlar azaltma kilometre taşlarına bağlanacak; `AchievementsPage` şu an
      hiçbir yerden açılmıyor (ölü ekran), ana akışa bağlanacak

## M. Haftalık anket

- [ ] **50.** Detaylı mod tamamen kaldırılacak (~870 satırlık blok), mod seçici silinecek,
      "Hızlı (15 sn)" etiketi hiç görünmeyecek
- [ ] **51.** Uydurma veriler gerçek sorulara dönüşecek — `triggerExposureDays` sabitleri
      (kahve:3, yemek:3, araba:2, telefon:3, sosyal:3), `withdrawal` (hepsi `isBad ? 2 : 1`),
      `alcoholDays`, `familySupport`, `cravingMax`
- [ ] **52.** Kullanılmayan alanlar hem anketten hem skorlamadan çıkarılacak: tedavi/ilaç
      (artık ilaç sisteminde), danışmanlık hattı, "en yararlı kategori"
- [ ] **53.** Hızlı Solunum Kontrolü'ne 2 alan eklenecek (uykuya etkisi, enerjiye etkisi).
      `_quickRespiratoryBaselineSymptom` silinecek — solunum skoru sigara verisinden
      türetilmeyecek
- [ ] **54.** mMRC anlaşılır ifadelere geçecek, "Zorlanmıyorum" seçeneği eklenecek ve varsayılan
      olacak (şu an varsayılan 2 = kullanıcı dokunmasa bile hasta sayılıyor)
- [ ] **55.** 12 solunum sorusu anlaşılır ifadelere geçecek (8 şiddet: başlık + somut örnek,
      4 sıklık: gün sayısı yerine "bir iki gece / neredeyse her gece")
- [ ] **56.** Anket sonrası "ne değişti" özeti: risk skoru değişimi, öğrenilen riskli
      saat/tetikleyici, yarınki görev planına etkisi

## N. SOS ekranı

- [ ] **57.** "Görev ver" butonu bağlanacak (şu an `// Hook point` placeholder) — aktivite
      önerisi gösterecek
- [ ] **58.** Sayfanın tamamı çevrilecek — şu an sıfır `context.t()` kullanımı var, 24 dilin
      hepsinde Türkçe görünüyor

## O. iOS sınırı

- [ ] **59.** Üç noktada platform arayüzü çizilecek (teslim / zamanlama / meşguliyet tespiti).
      **iOS kodu bu partide yazılmayacak** — Mac + fiziksel cihaz gerektiriyor.
      Kabul edilen kısıt: iOS'ta overlay API'si yok, zorlayıcı tam ekran görev imkânsız.

---

# PARÇA 3 — Çeviri

- [ ] **60.** Çalışma zamanı Google Translate mekanizması kaldırılacak
      (`_requestTranslation` → `translate.googleapis.com` resmî olmayan iç endpoint;
      ToS riski + gizlilik beyanıyla çelişiyor + ilk açılışta ~95 ardışık istek)
- [ ] **61.** 24 dilin eksik 201 anahtarı tamamlanacak (~4.800 satır)
- [ ] **62.** Hiç çevirisi olmayan 14 dil sıfırdan çevrilecek (~10.600 satır):
      Filipince, Ukraynaca, Romence, Yunanca, Macarca, Çekçe, İsveççe, Danca, Norveççe,
      Fince, Felemenkçe, Belarusça, Sırpça, Hırvatça
- [ ] **63.** Yeni özelliklerin metinleri + 150 sağlık ipucu + 130 anket seçeneği (~13.000 satır)
- [ ] **64.** Sabit metinler `context.t()`'ye çevrilecek: `craving_sos`, `achievements`,
      `savings`, `health_recovery` (hiç çevrilmemiş) + diğerlerinde 27 sabit metin
- [ ] **65.** RTL desteği — Arapça için yönlü hizalama
- [ ] **66.** Taşma koruması — `Expanded`/`Flexible` + `maxLines`/`overflow`.
      Bilinen somut örnek: `it @ 320×568` anket sayfası 115 piksel taşıyor
- [ ] **67.** `PLAY_STORE_DATA_SAFETY.md` güncellenecek (artık gerçekten tamamen çevrimdışı)

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
