# Play Store Permissions Declaration — RECORD_AUDIO / FOREGROUND_SERVICE_MICROPHONE

Bu belge, Google Play Console'a yükleme yapılırken gece mikrofon kullanımıyla ilgili
çıkabilecek "Permissions declaration" / policy sorularında doğrudan referans alınmak
üzere hazırlanmıştır. Faz 2 kapsamında, `SnoringCaptureService`
(`android/app/src/main/kotlin/com/nikotinaway/app/SnoringCaptureService.kt`) için
hazırlandı — bu servis, opsiyonel "Horlama Testi" özelliği açıkken gece uyku
penceresinde kısa mikrofon örneklemesi yapıyor.

**Önemli:** Play Console'a gönderilmeden önce güncel kod durumuyla teyit edilmelidir.
`docs/PLAY_STORE_PERMISSIONS_JUSTIFICATION.md` bu belgenin kardeşi — SYSTEM_ALERT_WINDOW
iznini kapsıyor, mikrofonu kapsamıyor.

---

## Mikrofon gece neden açılıyor

Uygulamanın "Uyku Zekası" özelliği (opsiyonel, kapalı başlar) ekran açık/kapalı ve şarj
durumu gibi ücretsiz OS sinyallerini örnekleyerek uyku penceresini tahmin ediyor —
bu kısım mikrofon gerektirmiyor.

Bunun üzerine kurulu, ayrı bir opsiyonel özellik olan "Horlama Testi" (varsayılan kapalı,
Uyku Zekası zaten açık olmalı) açıldığında, aynı gece döngüsüne binerek ~5 dakikada bir
tetiklenen alarm sırasında (yalnızca ekran kapalıyken, yani kullanıcı muhtemelen
uyuyorken) 3 saniyelik bir ham ses örneği alınıp cihaz üzerinde analiz ediliyor: ritmik
bir yüksek/alçak ses paterni horlamaya benziyor mu diye bakılıyor. Sonuç yalnızca
evet/hayır + bir şiddet skoru olarak yerel veritabanına yazılıyor.

## Ses saklanıyor mu?

**Hayır.** `AudioRecord` ile okunan PCM ses arabelleği yalnızca bellekte, birkaç yüz
milisaniye boyunca, enerji zarfı hesaplanana kadar tutuluyor; hiçbir zaman diske
yazılmıyor, hiçbir zaman ağ üzerinden gönderilmiyor. Kayıt bittiğinde arabellek
serbest bırakılıyor. Kalıcı olarak saklanan tek şey: `snoreLikely` (bool),
`severityScore` (0-100), `severityLevel` (none/mild/moderate/severe) ve
`captureSucceeded` (bool) — dördü de yerel SQLite'ta.

## Neden foreground service + FOREGROUND_SERVICE_MICROPHONE?

Android 11'den itibaren uygulama ön planda değilken mikrofon erişimi engelleniyor;
düz bir `AlarmManager`-tetiklemeli `BroadcastReceiver` (önceki tasarım) bu şartı
karşılamıyordu ve sessizce hiçbir kayıt üretmiyordu (bkz. Faz 2 bulgu raporu).
Android 14'ten itibaren mikrofon kullanan bir foreground service'in
`foregroundServiceType="microphone"` ile tanımlanması ve `FOREGROUND_SERVICE_MICROPHONE`
izninin alınması zorunlu.

`SnoringCaptureService`, `SleepProbeReceiver`'ın alarm tetiklemesiyle başlatılıyor,
zorunlu bildirimini gösteriyor, ~3 saniyelik örneği alıp analiz ediyor, sonucu yazıyor
ve kendini durduruyor (`stopSelf`) — tipik ömrü birkaç saniye.

## Kullanıcı nasıl kapatabiliyor?

Ayarlar → Horlama Testi (Deneysel) anahtarından. Kapatıldığında
`SleepProbeService.setSnoringDetectionEnabled(false)` çağrılır, native taraf bir
sonraki alarm tetiklemesinde `SnoringCaptureService.start()` çağrısını atlar. Ayrıca
Uyku Zekası kapatılırsa (üst özellik) Horlama Testi de fiilen devre dışı kalır, çünkü
aynı alarm zincirine biniyor, kendi zincirini kurmuyor.

Özellik ilk açılırken kullanıcıya bir onay/açıklama ekranı gösteriliyor
(`SnoringDetectionService.consentTextVersion`, şu an `v2` — Faz 2'de foreground service
bildirimi bilgisi eklendiği için `v1`'den bump'landı) ve karar
`recordConsentDecision` ile KVKK denetim izine yazılıyor.

## İngilizce metin (Play Console'a doğrudan yapıştırılabilir taslak)

> Nikotin Away includes an optional, off-by-default "Snoring Test" feature (nested
> under an already-optional "Sleep Intelligence" feature) that briefly samples raw
> microphone audio a few times during the user's configured sleep window, purely to
> detect a rhythmic, snore-like sound pattern on-device.
>
> - The audio buffer is analyzed in memory only (a few hundred milliseconds) and is
>   never written to disk or transmitted anywhere. Only a boolean result and a 0-100
>   severity score are stored locally.
> - Each capture runs inside a short-lived foreground service
>   (`foregroundServiceType="microphone"`) that shows a visible, low-priority
>   notification for the few seconds it's active — the user can always see when the
>   microphone was used.
> - The feature is off by default, gated behind an explicit consent screen the user
>   must accept before it can be enabled, and can be turned off at any time from
>   Settings.
> - It requires the parent Sleep Intelligence feature (screen/charging-state-only,
>   no microphone) to already be enabled, and shares its existing overnight alarm
>   schedule rather than running an independent one.

## Play Store'a kayıt sırasında yapılacaklar (kontrol listesi)

- [ ] Yukarıdaki İngilizce metni RECORD_AUDIO / mikrofon ile ilgili Permissions
      declaration sorusuna yapıştır
- [ ] `PLAY_STORE_DATA_SAFETY.md`'de mikrofon/ses verisinin "toplanmıyor, cihazda
      işlenip atılıyor" olarak doğru göründüğünü teyit et
- [ ] `snoringDetectionDescription` rıza metninin (app_texts.dart, tr+en) foreground
      service bildirimini doğru anlattığını teyit et
- [ ] Android 14 hedefli bir build'de gece probunun gerçekten mikrofonu açtığını
      doğrula (bkz. Faz 2 doğrulama adımları)
