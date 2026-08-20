# Nikotin Away — Gizlilik Politikası

**Son güncelleme:** 20 Ağustos 2026

> Bu metin hukuki danışmanlık değildir; yayın öncesi geliştirici tarafından doğrulanmalıdır. Play Console'a eklenmeden önce bu belgenin herkese açık bir URL'de yayınlanmış olması gerekir.

## 1. Kapsam

Bu Gizlilik Politikası, **Nikotin Away** mobil uygulamasının kişisel verileri nasıl işlediğini açıklar. Uygulama Nikotin Away geliştiricisi tarafından geliştirilmiştir. Sorular için `abulbul2000@gmail.com` adresi kullanılabilir.

## 2. Verilerin saklandığı yer

Uygulama temel olarak verileri Android uygulamasının korumalı alanındaki SQLite veritabanında ve cihaz ayarlarında saklar. Kullanıcı isteğine veya hesap girişine bağlı olarak bazı veriler Firebase altyapısına da aktarılabilir.

Google veya e-posta hesabıyla giriş yapan kullanıcının uygulama yedeği, Firebase Authentication tarafından verilen kullanıcı UID'si altında Firebase Firestore'da tutulur. Parola tabanlı şifreli yedekler ise `backups/{kullanıcı UID}/{parola özeti}.enc` yolunda Firebase Storage'da tutulur. Yedek içeriği cihazda AES-256-GCM ile şifrelenir; parola sunucuya gönderilmez.

Uygulama Gmail, Google Drive, Google Fotoğraflar, rehber veya takvim verilerine erişmez. Google hesabı yalnızca kullanıcı kimliği ve Nikotin Away hesabına ait bulut yedeğini eşleştirmek için kullanılır.

## 3. İşlenen veri türleri ve amaçları

| Veri türü | Amaç | Saklama şekli |
|---|---|---|
| Profil, yaş, cinsiyet ve meslek bilgileri | Kişiselleştirilmiş bırakma koçluğu | Cihazda; kullanıcı hesabıyla yedekleme seçilirse Firestore'da |
| Sigara kayıtları, tetikleyiciler ve zaman bilgileri | Davranış motoru ve ilerleme takibi | Cihazda; seçilen bulut yedekleme yönteminde |
| Öğrenilmiş yer kimlikleri ve isteğe bağlı konum özetleri | Riskli ortamları anlamak | Ham GPS rotası tutulmaz; seçilen bulut yedekleme yönteminde özetlenmiş veri bulunabilir |
| Nefes, öksürük ve uyku/horlama sonuçları | Sağlık ve yaşam koçluğu | Cihazda; seçilen bulut yedekleme yönteminde |
| Adım, Health Connect ve uyku sinyalleri | Aktivite ve uyku ile sigara davranışı arasındaki ilişkiyi anlamak | İlgili özellik açılırsa cihazda; bulut yedeği seçilirse yedekte |
| AI sohbet mesajları ve uygulama bağlamı | AI koçunun yanıt üretmesi | İstek sırasında Firebase Functions üzerinden AI sağlayıcısına gönderilebilir; kalıcı sunucu sohbet geçmişi tutulmaz |
| Hesap kimliği ve e-posta | Hesabı ve yedeği doğru kullanıcıya bağlamak | Firebase Authentication ve kullanıcıya özel Firestore yolu |
| Teknik çökme bilgileri | Hataları düzeltmek | Firebase Crashlytics |

Mikrofonla yapılan nefes, öksürük ve gece ses analizlerinde ham ses dosyası uygulamanın kalıcı veritabanına kaydedilmez; analiz için gereken sinyaller işlenerek sonuç olarak saklanır.

## 4. AI koçluğu

AI koçu; sigara bırakma, uyku, stres, günlük rutin, hareket, su tüketimi ve genel yaşam alışkanlıkları hakkında davranış değişikliği önerileri verir. AI tanı koymaz, tedavi belirlemez, ilaç başlatmaz veya doz önermez. Ciddi belirtilerde sağlık profesyoneline ve acil durumda yerel acil yardım hizmetine başvurulması gerektiğini belirtir.

Kullanıcı AI sohbetini açıp mesaj gönderdiğinde, mesaj ve ihtiyaç duyulan sınırlı uygulama özeti yanıt üretmek amacıyla Firebase Functions üzerinden yapılandırılmış AI sağlayıcısına gönderilebilir. Gmail, Drive veya uygulama dışı Google hesabı verileri AI'ye gönderilmez.

## 5. Üçüncü taraf hizmetleri

Veriler satılmaz ve reklam amacıyla paylaşılmaz. Kullanılan hizmetler şunlardır:

- **Firebase Authentication:** Google veya e-posta hesabıyla kimlik doğrulama.
- **Firebase Firestore:** Kullanıcıya özel uygulama yedekleri ve senkronizasyon.
- **Firebase Storage:** Kullanıcı UID'si altında saklanan, cihazda şifrelenmiş parola yedekleri.
- **Firebase Crashlytics:** Teknik hata ve çökme raporları.
- **Firebase Functions ve yapılandırılmış AI sağlayıcısı:** Kullanıcı AI sohbetini başlattığında yanıt üretimi.
- **Google Play Billing:** Uygulama içi satın alma varsa ödeme işlemi; kart bilgisi uygulamaya ulaşmaz.

## 6. Kullanıcı kontrolü

Konum, Health Connect, uyku zekâsı, gece ses/horlama analizi ve bildirim gibi özellikler kullanıcı ayarlarıyla açılıp kapatılabilir. Kullanıcı buluta yedekleme başlatabilir veya yedekten geri yükleyebilir. Geri yükleme mevcut yerel verinin üzerine yazabileceği için uygulama işlemden önce açık uyarı gösterir.

## 7. Verilerin silinmesi

- **Verilerimi Sıfırla:** Cihazdaki uygulama verilerini ve bildirim geçmişini siler.
- **Hesabımı ve bulut verilerimi sil:** Kullanıcı onayından sonra kullanıcıya ait Firestore verilerini, UID'ye bağlı Storage yedeğini, yerel verileri ve Firebase Authentication hesabını silmeyi dener.
- Parola tabanlı bir yedeğin silinmesi için kullanıcıdan yedekleme parolası istenebilir. Parola unutulursa yedek çözülemez ve geri getirilemez; kullanıcı bunu bilerek kullanır.

Hesap silme isteği tamamlanamazsa uygulama hata gösterir ve kullanıcıya hangi adımın başarısız olduğunu bildirir. Hesap silme akışı Play Console'daki hesap silme bağlantısıyla da erişilebilir olmalıdır.

## 8. Çocuklar

Uygulama genel kitleye yöneliktir ve bilerek 13 yaş altı çocuklardan veri toplamak amaçlanmaz.

## 9. Değişiklikler ve iletişim

Veri işleme biçimi değişirse bu politika güncellenir. Sorular için `abulbul2000@gmail.com` adresine başvurulabilir.
