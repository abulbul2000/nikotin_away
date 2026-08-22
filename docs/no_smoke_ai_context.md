# Nicotine Away - AI Context Pack

Bu dokuman, Nicotine Away projesini herhangi bir yapay zeka araci ile hizli ve dogru analiz ettirmek icin hazirlanmis teknik ozet dosyasidir.

## 1) Proje Kimligi

- Proje adi: Nicotine Away
- Platform: Flutter (Android agirlikli, iOS/web/desktop klasorleri mevcut)
- Amac: Sigara birakma surecini davranissal olarak yonetmek
- Ana yaklasim: Risk puani + gorev tabanli mudahale + takip + ihlal eskalasyonu

## 2) Kisa Urun Ozeti

Nicotine Away, kullanicinin sigara icme aliskanligini azaltmak ve birakma surecini disipline etmek icin tasarlanmis bir mobil uygulamadir.

Temel akis:
- Ilk kurulumda dil secimi ve anket
- Nefes testi ile risk seviyesi olcumu
- Risk seviyesine gore gorevler
- Gorev sonrasi takip (basari/basarisizlik)
- Yanitsizlik veya supheli davranista ihlal kaydi
- Gerektiginde zorunlu gorev ekranina gecis

## 3) Katmanli Mimari

### Presentation Layer

Ekranlar:
- Splash
- Language Selection
- Trial Info
- Survey
- Breath Test
- Risk Result
- Home
- Weekly Survey
- Mandatory Task
- Task Follow-up
- Protocol Violations
- Survey History
- Profile

Sorumluluk:
- Kullanici girdilerini toplamak
- Durum ve metrikleri gostermek
- Bildirim aksiyonlariyla ekran akisini yonetmek

### Business Logic Layer

Ana bilesenler:
- RiskEngine: Kullanici verilerinden 0-100 risk puani uretir
- TaskEngine: Risk seviyesine gore gorev seti belirler
- BehaviorEngine: Tetikleyiciler, riskli saatler, trend analizi
- DisciplineProtocolService: Adaptif sure, zamanlama jitter'i, ihlal kosullari

### Service Layer

- NotificationService: Gorev/follow-up/hatirlatma bildirimleri
- StorageService: SQLite islemleri
- LanguageService: Dil secimi ve kalicilik
- AndroidWatchdogService: Native tarafta no-response takibi
- Sensor ve kullanim verisi toplama mantigi

### Data Layer

- SQLite (ana kalicilik)
- SharedPreferences (dil ve basit ayarlar)

### Native Bridge Layer (Android)

- MethodChannel ile Dart <-> Kotlin iletisim
- Foreground watchdog service
- Alarm tabanli yedek tetikleme
- Native violation queue -> Dart tarafina import

## 4) Veri Modeli Ozet

Kritik tablolar:
- app_events
- app_settings
- survey_details
- user_profile_snapshots
- language_history
- sensor_usage_events
- behavior_snapshots
- task_followups
- protocol_violations

Veri rolleri:
- app_events: Olay gunlugu (anket, test, gorev sonucu vb.)
- survey_details: Detayli anket baglami
- user_profile_snapshots: Profilin zaman icindeki anlik goruntuleri
- sensor_usage_events: Kullanim/sensor davranis sinyalleri
- task_followups: Planlanan takip kayitlari
- protocol_violations: Kural ihlali kayitlari

## 5) Kritik Is Kurallari

- Risk puani cok faktorlu hesaplanir (yas, gunluk tuketim, ilk sigara zamani vb.)
- Risk seviyesi arttikca gorev sayisi/siddeti artar
- Gorev sonrasi takip sonucu davranis modelini gunceller
- Belirli sure yanitsizlik no-response ihlaline donusur
- Ihlal yogunlugu artarsa mandatory task zorlanir
- Haftalik anket sonuclari trend ve sonraki gorev stratejisini etkiler

## 6) Bildirim ve Watchdog Ozet Akisi

1. Home tarafinda gorev planlanir
2. NotificationService gorev bildirimi gonderir
3. Erteleme/yanitsizlik halinde watchdog devreye girer
4. Native servis sureyi izler, timeout olursa ihlal uretir
5. Uygulama acildiginda native ihlaller Dart tarafina import edilir
6. Ihlaller Protocol Violations ekraninda listelenir

## 7) Lokalizasyon

- Desteklenen diller: TR, EN, DE, AR, FR, ES
- Dil secimi kalici saklanir
- Uygulama ici metinler merkezi metin haritasi ile yonetilir

## 8) Bagimliliklar (Fonksiyonel Ozet)

- flutter_local_notifications, timezone: Bildirim ve zamanlama
- sqflite: Iliskisel yerel veri tabani
- shared_preferences: Kucuk ayarlar
- path, path_provider: Dosya/veritabani yolu
- permission_handler: Izin yonetimi
- flutter_svg: SVG cizimleri

## 9) Test Durumu ve Bosluklar

Mevcut guclu taraf:
- Engine ve storage tarafinda temel unit test kapsami var

Kritik bosluklar:
- Uctan uca entegrasyon testleri
- Notification + watchdog akislari
- Ana ekranlar icin widget testleri
- DB migration ve eszamanli yazma senaryolari
- Native watchdog dogrulama testleri
- Coklu dil render ve metin tutarlilik testleri

## 10) Bilinen Riskler

- Native watchdog akisinin platform bagimliligi
- Bildirim davranisinin cihaz/OS farkliliklarina duyarli olmasi
- Buyuyen tablo hacminde performans ve indeks ihtiyaci
- Is kurallarinin birden fazla yerde daginik kalma riski

## 11) AI Aracina Verilecek Gorev Cercevesi

Bu projeyi inceleyen yapay zekadan su tip ciktilar alinmasi onerilir:

1. Katman bazli teknik analiz (Presentation/Logic/Service/Data/Native)
2. Mimari iyilestirme plani (kisa, orta, uzun vade)
3. Risk odakli test plani (unit, widget, integration, native)
4. Uretim hazirlik kontrol listesi (performance, reliability, observability)
5. P0/P1/P2 onceliklendirmesi ile teknik borc plani

## 12) Yapay Zeka Icin Hazir Komut Sablonu

Asagidaki sablon herhangi bir AI aracta kullanilabilir:

"Bu dokumani temel alarak Nicotine Away uygulamasini teknik olarak analiz et. Once yonetici ozeti ver, sonra katmanli mimariyi acikla, sonra kritik riskleri severity seviyeleriyle listele (Critical/High/Medium/Low). Ardindan P0/P1/P2 aksiyon plani ve 30-60-90 gun yol haritasi cikar. Onerilerin her biri icin beklenen etkiyi ve tahmini eforu (S/M/L) belirt."

## 13) Hedeflenen Cikti Kalitesi

Beklenen AI cikti kriterleri:
- Somut ve uygulanabilir karar onerileri
- Belirsiz/genel gecis cümlelerinden kacinma
- Onceliklendirilmis teknik adimlar
- Dogrudan backlog'a donusturulebilir netlik

---

Bu dosya proje baglamini hizli aktarmak icin hazirlanmistir. Gerekirse bir sonraki adimda ayni icerigin daha kisa (1 sayfa) veya daha detayli (teknik denetim) versiyonu uretilmelidir.
