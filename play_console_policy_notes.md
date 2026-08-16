# Play Console uygunluk denetimi — dış kaynak notları

## Resmi kaynaklar

1. Google Play Kullanıcı Verileri Politikası: https://support.google.com/googleplay/android-developer/answer/10144311?hl=tr
   - Kullanıcı verilerinin toplanması, işlenmesi ve paylaşılması şeffaf biçimde açıklanmalı.
   - Kişisel ve hassas kullanıcı verileri için ek şartlar var.
   - Üçüncü taraf SDK ve AI entegrasyonlarının veri işleme yaklaşımından geliştirici sorumlu.
   - Konum, sağlık verileri ve mikrofon gibi veriler hassas nitelikte olduğundan Data Safety ve gizlilik politikasında doğru beyan gerekir.

2. Google Play hesap silme gereklilikleri: https://support.google.com/googleplay/android-developer/answer/13327111?hl=tr
   - Uygulama hesap oluşturuyorsa kullanıcıya uygulama içinden hesap ve ilişkili verileri silme isteği sunmalı.
   - Kullanıcıların web üzerinden de silme isteği gönderebilmesi için dış web kaynağı bağlantısı sağlanmalı.
   - Play Console App content/Data Safety alanlarındaki hesap ve veri silme soruları doldurulmalı.

3. Google Play sağlık uygulaması kategorileri: https://support.google.com/googleplay/android-developer/answer/13996367?hl=tr
   - Sağlık ve fitness uygulamaları, tıbbi yönetimi veya fiziksel/mental sağlığı destekleyen uygulamalar sağlık uygulaması kapsamına girebilir.
   - Sağlık uygulaması beyanı App content > Health apps altında doldurulmalı.
   - Nikotin bırakma koçluğu, uyku/horlama analizi, nefes/öksürük ölçümü ve AI sağlık tavsiyesi nedeniyle Nikotin Away sağlık uygulaması olarak değerlendirilmelidir.

## Proje manifestinden ilk risk adayları

- RECORD_AUDIO ve FOREGROUND_SERVICE_MICROPHONE: mikrofonla AI konuşma ve gece horlama/uyku analizi için açıklama, açık rıza ve Data Safety beyanı gerekir.
- ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION ve ACCESS_BACKGROUND_LOCATION: “I Smoked” konum kaydı için yalnızca gerekli anda istenmeli; arka plan konumunun gerçek ve kullanıcıya açıklanmış bir temel kullanım amacı olmalı.
- SYSTEM_ALERT_WINDOW ve FOREGROUND_SERVICE_SPECIAL_USE: yüzen buton/overlay için özel izin gerekçesi, kullanıcı bilgilendirmesi ve Play Console ön plan servis beyanı gerekir.
- USE_FULL_SCREEN_INTENT: tüm bildirimleri tam ekran açmak Play açısından yüksek riskli olabilir; tam ekran intent yalnızca gerçekten uygun, zaman hassas ve kullanıcı beklentisine uygun durumlarda kullanılmalı.
- REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, RECEIVE_BOOT_COMPLETED ve exact alarm izinleri: arka plan davranışının temel işlevle doğrudan ilişkisi açıklanmalı; gereksiz veya zorlayıcı izin istemi reddedilme riski doğurabilir.
- READ_PHONE_STATE ve sağlık izinleri: kullanılmıyorsa kaldırılmalı, kullanılıyorsa Data Safety/Health declaration içinde açıklanmalı.

## Ön değerlendirme

Kod, Play Console’a kesinlikle aykırıdır denemez; ancak yayın öncesi kritik kontrol alanları hesap silme web bağlantısı, kapsamlı gizlilik politikası, sağlık uygulaması beyanı, arka plan mikrofon/konum gerekçeleri, tam ekran bildirim kullanımı, AI verilerinin üçüncü taraf işleme açıklaması ve Google Play Data Safety formudur.
