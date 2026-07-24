# Play Store Permissions Declaration — SYSTEM_ALERT_WINDOW

Bu belge, Google Play Console'a yükleme yapılırken "display over other apps" (SYSTEM_ALERT_WINDOW) izniyle ilgili çıkabilecek "Permissions declaration" / policy sorularında doğrudan referans alınmak üzere hazırlanmıştır. Faz 10 kapsamında, 2026-07-23'te eklenen `TaskOverlayService` (bkz. `android/app/src/main/kotlin/com/example/no_smoke/TaskOverlayService.kt`) için hazırlandı.

**Önemli:** Play Console'a gönderilmeden önce güncel kod durumuyla teyit edilmelidir. Bu izin Google Play'de "Special App Access" kategorisinde sıkı denetlenir — apps aşırı/gereksiz kullanımda manuel incelemeye düşebilir veya reddedilebilir.

---

## Nereye yapıştırılacak

Play Console → App content (Uygulama içeriği) → Permissions declaration / Sensitive permissions bölümünde bu izinle ilgili soru çıkarsa, aşağıdaki İngilizce metni kullan. İngilizce yaz — inceleme ekibi İngilizce okuyor, Türkçe yazarsan gecikme/ek soru riski var.

## İngilizce metin (doğrudan yapıştır)

> No Smoke is a smoking-cessation app built around scheduled, time-sensitive intervention prompts (e.g. "don't smoke in the next N minutes," breathing exercises, medication reminders). The app's core mechanism depends on the user actually seeing and responding to these prompts at the moment they're scheduled — a missed prompt during a craving window defeats the app's entire purpose.
>
> Android notifications with `fullScreenIntent` only auto-present when the device is locked. When the phone is unlocked and another app is in the foreground (the exact situation a craving is most likely to happen — mid-conversation, mid-browsing, mid-drive), the same notification only shows as a dismissible heads-up banner that the user can miss or swipe away without ever seeing the full prompt.
>
> SYSTEM_ALERT_WINDOW is used exclusively to draw this scheduled intervention screen over the foreground app at its exact scheduled time, so it functions the same way regardless of lock state. Specifics:
> - The permission is optional and requested once, with an explicit in-app explanation, during onboarding (Settings → the same screen also lets the user revoke it at any time).
> - The overlay is shown only when a scheduled task the user themself set up (via the app's onboarding survey) becomes due — never on app launch, never unprompted, never for advertising or unrelated content.
> - The overlay always presents two clear actions ("Done" / "Not now") and dismisses itself immediately on either tap; it does not block the device, does not persist as a floating bubble/chat-head, and does not run when no task is due.
> - If the permission is not granted, the app falls back to the standard notification-only behavior — no feature is otherwise gated behind this permission.
>
> We believe this qualifies as a core, non-substitutable use case per Play's overlay policy, since no alternative Android API reliably presents a foreground-app-agnostic, time-critical prompt without it.

## Video/ekran görüntüsü için not

Google genelde bu deklarasyona ek olarak kısa bir ekran kaydı ister (30-60 sn yeterli). Şunu göster:
1. Ayarlar'dan izni açma ekranı (izin diyaloğu + sistem ayar ekranı).
2. Telefon kilidi açıkken, başka bir uygulama (ör. tarayıcı) önde çalışırken, zamanlanmış görev geldiğinde overlay'in belirmesi.
3. "Yaptım"/"Şimdi değil" butonlarından birine basılınca overlay'in kapanması.

## Kısa Türkçe özet (form'a girmeyecek, hatırlatma amaçlı)

Gerekçe şunu diyor: bu bir sigara bırakma uygulaması, zamanlanmış müdahale ekranı kaçırılırsa uygulamanın amacı boşa çıkıyor; normal bildirim sadece kilitli ekranda tam ekran açılıyor, kilit açıkken başka uygulama önde ise sadece geçici banner oluyor ve kullanıcı kaçırabiliyor; bu yüzden izin isteğe bağlı, tek seferlik açıklamayla soruluyor, sadece kullanıcının kendi kurduğu görev zamanı geldiğinde gösteriliyor, reklam/başka içerik yok, iki net buton var ve hemen kapanıyor, izin verilmezse özellik bildirime düşüyor yani hiçbir şey kilitlenmiyor.

## Play Store'a kayıt sırasında yapılacaklar (kontrol listesi)

- [ ] Yukarıdaki İngilizce metni Permissions declaration formuna yapıştır
- [ ] 30-60 saniyelik ekran kaydını çek ve yükle (üstteki 3 adımı göster)
- [ ] `PLAY_STORE_DATA_SAFETY.md`'yi güncel kod durumuyla teyit et (bu dosyanın kardeşi, veri güvenliği formunu kapsıyor)
- [ ] Diğer hassas izinler (RECORD_AUDIO, ACCESS_BACKGROUND_LOCATION, ACTIVITY_RECOGNITION vb.) için de benzer deklarasyon gerekip gerekmediğini kontrol et
