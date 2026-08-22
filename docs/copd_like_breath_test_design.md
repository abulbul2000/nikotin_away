# COPD-Like Breath Monitoring Design (Non-diagnostic)

This design defines a COPD-like breathing monitoring flow for Nicotine Away.
It is intentionally non-diagnostic and must not claim COPD diagnosis.

## 1) Clinical Boundaries

- The app does NOT diagnose COPD.
- Gold-standard diagnosis requires clinician-supervised spirometry and post-bronchodilator interpretation.
- App output language must be: "risk follow-up" and "clinical evaluation recommendation", not diagnosis.

References used in design:
- NHS COPD diagnosis + Spirometry pages
- NICE NG115 recommendations (spirometry, mMRC, symptom burden, follow-up)
- GOLD report portal (strategy context)

## 2) Product Goals

- Improve quality and repeatability of breathing tests in app.
- Capture symptom burden with a COPD-like weekly module.
- Detect deterioration trends early and trigger recommendations.
- Keep daily burden low but enforce minimum daily breathing check.

## 3) Test Stack

### 3.1 Daily Breath Performance Test (already close)

Protocol:
- 3 attempts per session
- 20s rest between attempts
- Store: best attempt, session average, consistency gap

Quality flags:
- consistency_gap >= 4s => low repeatability flag
- if low repeatability happens >=3 times/week => show coaching tip and suggest calmer environment before test

### 3.2 Weekly COPD-like Symptom Module (new)

Add to weekly survey payload:

```
respiratory: {
  mmrcGrade: int (1..5),
  catLike: {
    cough: 0..5,
    phlegm: 0..5,
    chestTightness: 0..5,
    breathlessnessStairs: 0..5,
    activityLimitation: 0..5,
    confidenceLeavingHome: 0..5,
    sleepQualityResp: 0..5,
    energyLevelResp: 0..5
  },
  warningSigns: {
    increasedNightBreathlessnessDays: 0..7,
    sputumIncreaseDays: 0..7,
    sputumColorChangeDays: 0..7,
    wheezeDays: 0..7
  }
}
```

Notes:
- This is a CAT-like structure, not official CAT replacement text.
- Use neutral wording and include disclaimer in UI.

## 4) Composite Scoring

### 4.1 Respiratory burden score (0..100)

- `mmrc_component = ((mmrcGrade - 1) / 4) * 100`
- `cat_component = (sum(catLike.values) / 40) * 100`
- `warning_component = min(100, ((night + sputumInc + sputumColor + wheeze) / 28) * 100)`

Final:
- `respiratory_burden = 0.35 * mmrc_component + 0.45 * cat_component + 0.20 * warning_component`

### 4.2 Weekly total risk blend

Current weekly risk can be extended:
- existing_behavioral_weekly_risk stays
- new blended formula:
- `weekly_risk_v2 = 0.82 * existing_behavioral_weekly_risk + 0.18 * respiratory_burden`

Escalation overrides:
- if `mmrcGrade >= 4` and `warning_component >= 50`, add +8 risk
- if `sputumColorChangeDays >= 3` and `increasedNightBreathlessnessDays >= 3`, add +6 risk

Safety floor/ceiling:
- clamp final risk to 0..100

## 5) Decision Rules (Non-diagnostic)

Create outcome states:
- `stable`
- `monitor_closer`
- `clinical_review_recommended`

Rule set:
- `stable`: respiratory_burden < 35 and no red warning pattern
- `monitor_closer`: respiratory_burden 35..64 or one warning pattern
- `clinical_review_recommended`: respiratory_burden >= 65 OR severe warning combo

Severe warning combo examples:
- mmrcGrade >= 4 with worsening trend 2+ weeks
- night breathlessness >= 4 days + sputum color change >= 3 days

## 6) UX + Messaging

Required text blocks on respiratory modules:
- "Bu test tani koymaz. KOAH tanisi icin spirometri ve doktor degerlendirmesi gerekir."
- "Sonuclar takip amaclidir; belirti kotulesmesi varsa saglik profesyoneline basvurun."

Alert copy examples:
- Monitor closer: "Nefes belirtilerinde artis izleniyor. Bu hafta olcum sikligini artir."
- Clinical recommendation: "Belirtiler belirgin artmis gorunuyor. Klinik degerlendirme onerilir."

## 7) Menu / Information Architecture

Home quick menu should include:
- Breath Test
- Weekly Survey
- Personal Progress
- Protocol Violations

Personal Progress screen sections:
- Respiratory Overview (mmrc, cat-like total, burden class)
- Weekly respiratory trend chart (last 12)
- Breath performance trend chart (daily avg, last 14)
- Alerts timeline (monitor/clinical recommendation events)
- Baseline vs current comparison

## 8) Daily Frequency Policy

- Minimum 1 breath test/day mandatory
- Preferred target from weekly survey: 1..4/day
- Dynamic scheduler respects user preference but never below 1/day

Adaptive frequency suggestions:
- if respiratory_burden >= 65 => suggest +1/day (max 4)
- if respiratory_burden < 30 for 3 consecutive weeks => suggest -1/day (min 1)

## 9) Data Schema Additions

No DB migration is required if using weekly payload JSON.
Add keys under `weeklyPayload.respiratory`.

Optional settings keys:
- `respiratory_monitoring_enabled` (1/0)
- `last_respiratory_burden` (0..100)
- `last_respiratory_state` (stable/monitor_closer/clinical_review_recommended)

## 10) Implementation Mapping (Current Codebase)

- Weekly survey form fields:
  - `lib/pages/weekly_survey_page.dart`
- Weekly risk integration logic:
  - `lib/services/behavior_engine.dart`
- Dashboard rendering and explanation lines:
  - `lib/services/storage_service.dart`
  - `lib/pages/home_page.dart`
- Personal progress respiratory blocks/charts:
  - `lib/pages/personal_progress_page.dart`

## 11) Acceptance Criteria

- User can enter weekly respiratory symptom data.
- Weekly risk includes respiratory burden contribution.
- App never labels output as diagnosis.
- Daily breath cadence remains >=1.
- Personal progress shows respiratory trends and status history.

## 12) Rollout Plan

Phase A (safe core):
- Add weekly respiratory fields + burden score + progress rendering.

Phase B (decisioning):
- Add monitor_closer / clinical_review_recommended rules and alerts.

Phase C (optimization):
- Tune weights with real-world outcomes and false-alert review.
