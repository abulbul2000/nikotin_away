# Nicotine Away - Claude Prompt (Profesyonel Türkçe Sürüm)

Nicotine Away adlı Flutter mobil uygulamasını uçtan uca teknik ve ürün perspektifiyle analiz etmeni istiyorum. Bu uygulama sigara bırakma sürecini desteklemek için tasarlandı ve şu bileşenleri içeriyor: başlangıç anketi, nefes testi, risk puanlama, görev atama, takip (follow-up), ihlal yönetimi, bildirim planlama ve çok dilli arayüz.

Tek bir dokümanda aşağıdaki çıktıları üret:

1. Ürün özeti: uygulamanın amacı, hedef kullanıcı profili ve değer önerisi
2. Teknik mimari: katmanlar, sorumluluklar, veri akışı
3. Mimari diyagram: bileşenler arası ilişki ve kritik akışlar
4. Özellik matrisi: tüm ana özellikler, bağımlılıklar ve iş değeri
5. Uçtan uca kullanıcı akışları: onboarding, günlük döngü, ihlal yönetimi, haftalık değerlendirme
6. Teknoloji ve bağımlılıklar: neden seçildiği ve alternatif değerlendirmesi
7. Test olgunluğu: mevcut kapsam, riskli boşluklar, test stratejisi
8. Teknik borç analizi: kısa/orta vadeli etkiler
9. İyileştirme planı: öncelikli teknik aksiyonlar
10. 30-60-90 gün yol haritası: ölçülebilir çıktılarla

## Mimariyi Şu Çerçevede Değerlendir

- Katmanlar: Presentation, Business Logic, Service, Data, Native Bridge
- Presentation ekranları: Splash, Dil Seçimi, Trial Info, Survey, Breath Test, Risk Result, Home, Weekly Survey, Mandatory Task, Task Follow-up, Protocol Violations, Survey History, Profile
- Business Logic: RiskEngine, TaskEngine, BehaviorEngine, DisciplineProtocolService
- Service: NotificationService, StorageService, LanguageService, AndroidWatchdogService
- Data: SQLite tabloları (app_events, app_settings, survey_details, user_profile_snapshots, language_history, sensor_usage_events, behavior_snapshots, task_followups, protocol_violations), SharedPreferences
- Native Bridge: MethodChannel ile watchdog başlatma, onaylama, ihlal tüketme; foreground service + alarm yedekleme

## Zorunlu Çıktı Beklentileri

- Belirsiz ifadeler kullanma, her iddiayı teknik gerekçeyle destekle
- Önce yönetici özeti ver, ardından teknik detaylara in
- Son bölümde P0, P1, P2 olarak önceliklendirilmiş aksiyon listesi üret
- Ek olarak production seviyesine geçiş için en kritik 10 teknik adımı ayrı listede ver

## Ek Not

Yanıtı hem ürün yöneticisi hem teknik ekip okuyacak şekilde yaz: sade, net, ölçülebilir ve uygulanabilir olsun.