# Nicotine Away - Claude Prompt (Tek Parca)

NO SMOKE adli Flutter mobil uygulamasini A'dan Z'ye teknik olarak analiz etmeni istiyorum. Uygulama sigara birakma surecini yonetiyor; baslangic anketi, nefes testi, risk puanlama, gorev atama, takip (follow-up), ihlal yonetimi, bildirim zamanlama ve cok dilli arayuz iceriyor. Bana tek dokumanda su ciktilari ver:

1. Uygulamanin amaci ve kapsami
2. Katmanli mimari aciklamasi
3. Mimari diyagram
4. Tum temel ozellikler
5. Uctan uca kullanici akislar
6. Teknik bagimliliklar ve neden kullanildiklari
7. Test kapsami ve bosluklar
8. Teknik borclar ve oncelikli iyilestirme plani
9. 30-60-90 gun gelistirme yol haritasi

## Mimari Ozeti (Bunu Esas Al)

Uygulama Flutter tabanlidir ve katmanlar Presentation, Business Logic, Service, Data, Native Bridge seklindedir.

Presentation tarafinda su ekranlar vardir:
- Splash
- Dil Secimi
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

Business Logic tarafinda su bilesenler vardir:
- RiskEngine (0-100 risk)
- TaskEngine (risk seviyesine gore gorev)
- BehaviorEngine (tetikleyici skorlari, riskli saatler, trend)
- DisciplineProtocolService (adaptif sure, ongorulemez zamanlama, supheli davranis tespiti)

Service katmaninda:
- NotificationService (task_start, followup, breath reminder)
- StorageService (SQLite)
- LanguageService (cok dil + kalicilik)
- AndroidWatchdogService (native kopru)
- Sensor benzeri kullanim verisi toplama mantigi

Data katmaninda SQLite tablolari:
- app_events
- app_settings
- survey_details
- user_profile_snapshots
- language_history
- sensor_usage_events
- behavior_snapshots
- task_followups
- protocol_violations

Ayrica SharedPreferences ile dil ve bazi bayraklar saklanir.

Native Bridge tarafinda Android MethodChannel uzerinden watchdog baslatma, onaylama, ihlal kuyrugu tuketme akisi vardir; native foreground service ve alarm yedek mekanizmasi ile 10 dakika yanitsizlik ihlali yakalanir.

## Mimari Diyagrami (Bunu Gorsellestir)

Mobil UI/Screens -> Engines/Business Rules -> Services -> SQLite + SharedPreferences.

Home ve NotificationService kolundan AndroidWatchdogService'e gecis var.
AndroidWatchdogService -> MethodChannel -> Native Watchdog Service + Alarm Receiver -> Violation Store -> tekrar Dart tarafinda violation import -> Protocol Violations ekranina yansima.

BehaviorEngine ve DisciplineProtocolService cift yonlu calisip gorev zorluk/sure/zamanlamasini adaptif guncelliyor.

## Temel Ozellikler

- Ilk kurulum akisi (dil + trial + anket)
- Nefes testi ile risk hesaplama
- Risk seviyesine gore gorev uretimi
- Gorev tamamlandi/ertelendi aksiyonlari
- Takip anketi ile basari-basarisizlik isleme
- Ihlal kaydi ve gecmisi
- Zorunlu gorev ekrani ile disiplin yukseltme
- Haftalik anket ve trend analizi
- Cok dil destegi (TR/EN/DE/AR/FR/ES)
- Yerel bildirimler
- SQLite kaliciligi
- Android watchdog guvenlik agi

## Kullanici Akislari

1. Ilk kullanici: Splash -> Dil Secimi -> Trial -> Survey -> Breath Test -> Risk Sonucu -> Home.
2. Gunluk dongu: Home -> Bildirimle gorev -> Tamamlandi veya Ertele -> Follow-up -> davranis guncelleme.
3. Ihlal akisi: Bildirime/goreve yanit yoksa watchdog ihlali -> ihlal kaydi -> Home yogunluk artisi -> gerekirse Mandatory Task.
4. Haftalik akis: Weekly Survey -> trend/tetikleyici/riskli saat guncellemesi -> yeni gorev stratejisi.

## Bagimliliklar

- Flutter cekirdegi
- flutter_local_notifications ve timezone (bildirim/zamanlama)
- sqflite (veri saklama)
- shared_preferences (ayar kaliciligi)
- path/path_provider (dosya-konum yonetimi)
- permission_handler (izinler)
- flutter_svg (gorsel varliklar)
- test ve lint paketleri (kalite)

## Test Durumu ve Aciklar

Mevcutta behavior, storage, discipline mantigina yonelik temel testler var. Ancak kritik aciklar:
- Uctan uca entegrasyon testleri
- notification + watchdog akis testleri
- widget testleri (ozellikle Home/Violations/Follow-up)
- migration ve eszamanli yazim senaryolari
- native Android watchdog testleri
- coklu dil render testleri

## Istedigim Cikti Formati

Once yonetici ozeti, sonra teknik mimari, sonra ozellik matrisi, sonra riskler, sonra iyilestirme plani ver. Her bolumde kisa ama somut ol; belirsiz ifadeler kullanma.

Sonunda onceliklendirilmis aksiyon listesi ver:
- P0
- P1
- P2

Ayrica bu projeyi production seviyesine tasimak icin en kritik 10 teknik adimi ayri bir liste halinde cikar.
