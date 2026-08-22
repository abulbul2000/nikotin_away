# Yayın öncesi dış kaynak bulguları

Tarih: 2026-08-22

## Google Play kapalı test

Google Play resmi yardım sayfasına göre 13 Kasım 2023 sonrası oluşturulmuş kişisel geliştirici hesaplarında üretim erişimi için en az 12 test kullanıcısının kapalı teste aralıksız en az 14 gün katılmış olması gerekiyor. Test kullanıcılarının yalnızca eklenmesi değil, opt-in durumunu koruması önemli. Üretim erişimi başvurusunda test süreci ve geri bildirim özeti istenebilir. Kaynak: https://support.google.com/googleplay/android-developer/answer/14151465?hl=en

## Full-screen intent

Android 14 ve üzeri sürümlerde USE_FULL_SCREEN_INTENT izni arama ve alarm işlevi sunan uygulamalarla sınırlandırılıyor. Google Play, arama/alarm işlevi olmayan uygulamalarda bu izni kurulum sonrası geri alabiliyor. Kullanıcı izni kapatırsa tam ekran yerine heads-up bildirim görülebilir. Nicotine Away'in bırakma görevi overlay'i alarm benzeri olsa da mağaza politikası açısından gerçek alarm işlevi iddiası ve izin kullanımının ayrıca değerlendirilmesi gerekir. Kaynak: https://source.android.com/docs/core/permissions/fsi-limits

## Exact alarm

Android 14+ yeni kurulumlarda SCHEDULE_EXACT_ALARM çoğu uygulamada varsayılan olarak reddedilebilir. Uygulama canScheduleExactAlarms() ile kontrol etmeli, reddedilirse kullanıcıya ayar yönlendirmesi ve inexact/WorkManager benzeri fallback sunmalı; izin verildikten sonra alarm planı yeniden kurulmalı. Exact alarm gereksiz kullanıldığında pil maliyeti yüksektir. Kaynak: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms ve https://developer.android.com/develop/background-work/services/alarms

## Kodla karşılaştırılacak kritik noktalar

- AndroidManifest exact alarm, full-screen intent, overlay, foreground service ve mikrofon izinlerini içeriyor; gerçek kullanım/politika gerekçeleri Play Console beyanıyla eşleştirilmeli.
- Bildirim servisinde günlük sağlık tavsiyesi kullanıcı limiti 15 olarak tanımlı; ancak dağılım sabitlerinde genel tavsiye sayısı 5 iken ürün gereksinimi 7 genel tavsiye olarak belirtilmiş. Bu bir onarım adayıdır.
- Manifestte çok sayıda boot receiver, foreground service ve özel erişim bulunması üretici bazlı pil/izin davranışı ve mağaza incelemesi açısından yüksek riskli yüzey oluşturuyor.
- Flutter/Dart SDK sandbox ortamında mevcut değil; bu nedenle burada flutter analyze/test/build doğrulaması yapılamadı. Windows/VS Code ortamında çalıştırılmalı.
