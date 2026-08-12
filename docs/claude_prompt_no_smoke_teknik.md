# Nikotin Away - Claude Prompt (Teknik Ekip Detay Sürümü)

Nikotin Away projesi için senior seviyede bir teknik değerlendirme raporu üretmeni istiyorum. Bu rapor bir mimari inceleme + iyileştirme taslağı olacak.

## Kapsam

Aşağıdaki katmanları ayrı ayrı incele:

1. Presentation
2. Business Logic
3. Service
4. Data
5. Native Bridge (Android)

## İnceleme Başlıkları

Her katman için şu başlıkları zorunlu kullan:

1. Sorumluluklar ve sınırlar
2. Güçlü yönler
3. Kırılgan noktalar
4. Ölçeklenebilirlik değerlendirmesi
5. Güvenilirlik ve hata toleransı
6. Test edilebilirlik
7. Refactor önerileri

## Mimari Referanslar

- Presentation ekranları:
  Splash, LanguageSelection, TrialInfo, Survey, BreathTest, RiskResult, Home, WeeklySurvey, MandatoryTask, TaskFollowUp, ProtocolViolations, SurveyHistory, Profile

- Business Logic:
  RiskEngine (0-100 risk hesaplama), TaskEngine (risk temelli görev üretimi), BehaviorEngine (tetikleyici/riskli saat/trend), DisciplineProtocolService (adaptif süre + jitter + şüpheli davranış)

- Service:
  NotificationService (task_start, followup, reminder), StorageService (SQLite v7), LanguageService (SharedPreferences), AndroidWatchdogService (MethodChannel)

- Data:
  app_events, app_settings, survey_details, user_profile_snapshots, language_history, sensor_usage_events, behavior_snapshots, task_followups, protocol_violations

- Native Bridge:
  MethodChannel akışı, foreground watchdog service, alarm fallback, violation queue import

## Beklenen Çıktı Formatı

Aşağıdaki sırayla ve tek doküman halinde ver:

1. Executive Summary (maksimum 15 madde)
2. System Architecture (metin + Mermaid)
3. Component-by-Component Deep Dive
4. Data Model and Integrity Risks
5. Notification/Watchdog Reliability Review
6. Localization and UX Consistency Review
7. Test Strategy (unit/widget/integration/native)
8. Technical Debt Register (etki x efor matrisiyle)
9. Prioritized Action Plan (P0/P1/P2)
10. 30-60-90 Day Delivery Roadmap

## Zorunlu Teknik Beklentiler

- Her kritik bulguya severity etiketi koy: Critical/High/Medium/Low
- Her bulgu için kanıt ve düzeltme önerisi ver
- Her düzeltme önerisi için tahmini efor belirt: S/M/L
- Mümkün olan yerlerde örnek refactor yapısı öner (service extraction, repository pattern, state management netleştirme, migration strategy)
- Son bölümde "Production Readiness Top 10" listesi ver

## Dil ve Üslup

- Teknik olarak kesin, kısa ve uygulanabilir yaz
- Gereksiz teoriye girme
- Karar verdiren öneriler üret
