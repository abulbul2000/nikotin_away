# Nicotine Away - Claude Prompt (Kısa Sürüm)

Nicotine Away Flutter uygulamasını teknik olarak analiz et ve tek dokümanda aşağıdakileri kısa ve net şekilde ver:

1. Uygulamanın amacı ve ana değer önerisi
2. Katmanlı mimari özeti (Presentation, Business Logic, Service, Data, Native Bridge)
3. Mermaid mimari diyagramı
4. Ana özellikler listesi
5. Temel kullanıcı akışları
6. Kullanılan paketler ve amaçları
7. Test kapsamı ve kritik eksikler
8. Öncelikli teknik riskler
9. 30-60-90 gün geliştirme planı

Dikkat et:
- Cevabı önce yönetici özetiyle başlat
- Teknik kısımda somut ol, genel geçer cümle kurma
- Sonunda P0/P1/P2 aksiyonlarını ver
- Ayrıca production seviyesine taşımak için en kritik 10 adımı listele

Mimari referans:
- RiskEngine: risk skoru
- TaskEngine: risk seviyesine göre görev
- BehaviorEngine: tetikleyiciler, riskli saatler, trend
- DisciplineProtocolService: adaptif süre ve zamanlama
- NotificationService + AndroidWatchdogService: görev/ihlal akışı
- StorageService: SQLite
- LanguageService: çoklu dil
