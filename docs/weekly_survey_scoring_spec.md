# Nicotine Away Haftalik Anket ve Risk Skorlama Spesifikasyonu

Bu dokuman, haftalik anketin hangi sorulari toplamasini, bu cevaplarin nasil puanlanacagini ve dinamik risk skoruna nasil etki edecegini tanimlar.

## 1) Haftalik Anket JSON Semasi

Asagidaki sema, uygulama tarafinda weekly_survey payload olarak kullanilabilir:

{
  "surveyVersion": "2.0.0",
  "recordedAt": "ISO-8601",
  "userId": "string",
  "answers": {
    "avgCigarettesPerDay": 0,
    "deltaVsLastWeek": "decreased|same|increased",
    "lapseCount": 0,
    "cravingAvg": 0,
    "cravingMax": 0,

    "withdrawal": {
      "irritability": 0,
      "anxiety": 0,
      "sleepProblem": 0,
      "concentrationProblem": 0,
      "appetiteIncrease": 0
    },

    "triggerExposureDays": {
      "coffee": 0,
      "meal": 0,
      "driving": 0,
      "stress": 0,
      "phone": 0,
      "social": 0,
      "alcohol": 0
    },

    "alcoholDays": 0,
    "socialSmokingContextDays": 0,

    "treatment": {
      "medicationUse": "none|irregular|regular",
      "sideEffects": false,
      "adherence": 0
    },

    "support": {
      "usedCounselingOrQuitline": false,
      "familySupport": 0
    },

    "selfEfficacy": 0,
    "motivation": 0,

    "task": {
      "weeklyCompletionRate": 0,
      "mostHelpfulCategory": "breath|delay|trigger|reduction|routine"
    }
  }
}

Deger araliklari:
- cravingAvg, cravingMax: 0-10
- withdrawal alt alanlari: 0-3
- triggerExposureDays: 0-7
- alcoholDays, socialSmokingContextDays: 0-7
- adherence, familySupport, selfEfficacy, motivation, weeklyCompletionRate: 0-10

## 2) Haftalik Risk Skoru (WRS) Formulu

Haftalik Risk Skoru (WRS) 0-100 araliginda hesaplanir.

Temel form:

WRS = clamp(0, 100,
  0.22*C +
  0.18*L +
  0.18*W +
  0.14*T +
  0.08*A +
  0.08*M +
  0.06*S +
  0.06*P
)

Bilesenler:
- C: consumption skoru (0-100)
- L: lapse skoru (0-100)
- W: withdrawal skoru (0-100)
- T: trigger exposure skoru (0-100)
- A: alcohol/social risk skoru (0-100)
- M: motivation inverse skoru (0-100)
- S: self-efficacy inverse skoru (0-100)
- P: plan/task uyumsuzlugu skoru (0-100)

Alt skor donusumleri:

1) Consumption (C)
- avgCigarettesPerDay normalize edilir.
- onerilen map:
  - 0 => 0
  - 1-5 => 20
  - 6-10 => 40
  - 11-20 => 65
  - 21+ => 85
- deltaVsLastWeek etkisi:
  - decreased => -10
  - same => 0
  - increased => +10
- C = clamp(0,100, map + delta)

2) Lapse (L)
- L = clamp(0,100, lapseCount * 15)

3) Withdrawal (W)
- withdrawal toplam puan max 15
- W = (sumWithdrawal / 15) * 100

4) Trigger (T)
- triggerExposureDays toplam max 49
- T = (sumTriggerDays / 49) * 100
- stress ve alcohol gunleri icin +10 bonus risk eklenir (toplam 100’u gecmez)

5) Alcohol/Social (A)
- A = clamp(0,100, alcoholDays*8 + socialSmokingContextDays*6)

6) Motivation inverse (M)
- M = (10 - motivation) * 10

7) Self-efficacy inverse (S)
- S = (10 - selfEfficacy) * 10

8) Plan/task uyumsuzlugu (P)
- completion = weeklyCompletionRate
- adherence = treatment.adherence
- P = clamp(0,100, 100 - (0.6*completion*10 + 0.4*adherence*10))

## 3) Dinamik Motor Entegrasyonu

Mevcut dinamik risk hesaplamasina haftalik etkiler su sekilde baglanir:

nextDynamicRisk = clamp(0,100,
  currentDynamicRisk * 0.70 +
  WRS * 0.30
)

Acil risk kurali:
- Eger lapseCount >= 3 VE cravingMax >= 8 ise,
  nextDynamicRisk = min(100, nextDynamicRisk + 12)

Koruyucu iyilesme kurali:
- Eger lapseCount = 0 VE selfEfficacy >= 8 VE weeklyCompletionRate >= 8 ise,
  nextDynamicRisk = max(0, nextDynamicRisk - 8)

## 4) Komut Modu Secimi (Haftalik Ankete Gore)

aggressive:
- WRS >= 65 veya
- lapseCount >= 2 veya
- cravingMax >= 8

balanced:
- 40 <= WRS < 65

protective:
- WRS < 40 ve
- lapseCount = 0 ve
- weeklyCompletionRate >= 7

## 5) Haftalik Oneri Ciktisi (JSON)

Uygulamanin haftalik anket sonrasi uretecegi ozet:

{
  "weeklyRiskScore": 0,
  "weeklyRiskLevel": "low|medium|high|critical",
  "recommendedMode": "protective|balanced|aggressive",
  "topRiskDrivers": [
    "string",
    "string",
    "string"
  ],
  "coachFocus": [
    "breath",
    "trigger",
    "delay"
  ]
}

Risk seviyesi:
- 0-24: low
- 25-49: medium
- 50-74: high
- 75-100: critical

## 6) Minimum Uygulama Kurallari

- Haftalik anket 10-12 soruyu gecmemeli (tamamlama oranini korumak icin).
- Her soruda bos gecme olursa default risk-nötr deger atanir.
- Haftalik skor kaydi, behavior snapshot ile ayni timestamp penceresinde alinmalidir.
- Yeni sema gecisinde surveyVersion zorunlu tutulmalidir.

## 7) Kaynak Dayanaklari

- WHO: tütün izleme ve quit support gerekliligi (monitor + offer help)
- NCBI Treating Tobacco Use and Dependence: 5A modeli, izlem ve relaps onleme
- NHS stop smoking services: ilk haftalarda haftalik takip ve CO odakli izlem
- Smokefree: craving, trigger, withdrawal semptom yonetimi
