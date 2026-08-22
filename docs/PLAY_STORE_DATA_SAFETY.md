# Google Play Data Safety — Nicotine Away

Bu belge, Play Console Data Safety ve Health Apps beyanlarını doldurmak için kod tabanına göre hazırlanmış çalışma taslağıdır. Play Console formu gönderilmeden önce gerçek Firebase yapılandırması, kullanılan AI sağlayıcısının saklama politikası ve geliştirici bilgileriyle son kez doğrulanmalıdır.

## 1. Genel çalışma modeli

Uygulama varsayılan olarak cihaz-yerel çalışır. Kullanıcı Google veya e-posta hesabıyla giriş yaparsa, uygulama yedeği kullanıcı UID'si altında Firebase Firestore'a senkronize edilebilir. Kullanıcı parola tabanlı şifreli yedekleme seçerse yedek cihazda AES-256-GCM ile şifrelenir ve kullanıcı UID'si altındaki Firebase Storage yoluna yüklenir.

Uygulama Gmail, Drive, Fotoğraflar, rehber, takvim veya web geçmişine erişmez. Google girişi yalnızca Firebase kimlik doğrulama ve Nicotine Away hesabı eşleştirmesi içindir.

## 2. Toplanan veya işlenen veri türleri

| Play Console kategorisi | Durum | Kullanım |
|---|---|---|
| Kişisel bilgiler — ad | Evet | Profil ve kişiselleştirme |
| Kişisel bilgiler — e-posta ve hesap kimliği | Evet, hesap seçilirse | Firebase Authentication ve yedek eşleştirme |
| Kişisel bilgiler — yaş, cinsiyet, meslek | Evet | Risk değerlendirmesi ve koçluk |
| Sağlık ve fitness — sağlık bilgileri | Evet | Sigara, nefes, öksürük, uyku/horlama, isteğe bağlı Health Connect verileri |
| Sağlık ve fitness — fitness bilgileri | Evet | Adım ve aktivite ilişkisi |
| Konum — yaklaşık/özetlenmiş | İsteğe bağlı | Riskli ortamları öğrenmek; ham GPS rotası kalıcı tutulmaz |
| Ses — ses kaydı | Anlık işlenir, kalıcı saklanmaz | Nefes, öksürük ve gece ses analizi |
| Uygulama etkinliği | Evet | Görevler, bildirim yanıtları, AI sohbet ve kişiselleştirme |
| Uygulama bilgisi ve performansı — çökme günlükleri | Evet | Firebase Crashlytics ile hata düzeltme |
| Cihaz veya diğer kimlikler | Sınırlı | Firebase/Crashlytics teknik kurulum kimliği |
| Finansal bilgiler — satın alma geçmişi | Play Billing kullanılıyorsa evet | Abonelik doğrulaması; kart bilgisi uygulamaya gelmez |
| Fotoğraf/video, kişiler, takvim, mesajlar, web geçmişi | Hayır | Toplanmaz |

## 3. Veri paylaşımı

Veriler satılmaz ve reklam amacıyla paylaşılmaz. Hizmet sağlayıcı paylaşımı şu amaçlarla sınırlıdır:

1. Firebase Authentication, kullanıcı hesabını doğrular.
2. Firestore, kullanıcı UID'sine bağlı uygulama yedeğini saklar.
3. Firebase Storage, UID'ye bağlı ve cihazda şifrelenmiş yedek dosyasını saklar.
4. Firebase Crashlytics teknik hata raporlarını işler.
5. Firebase Functions ve yapılandırılmış AI sağlayıcısı, kullanıcı açıkça AI sohbetini kullandığında yanıt üretir. AI'ye Gmail, Drive veya uygulama dışı Google verileri gönderilmez.
6. Google Play Billing/Android Publisher, uygulama içi satın alma varsa abonelik doğrulaması yapar.

Tüm ağ aktarımı HTTPS üzerinden yapılır. Sağlık, sigara, uyku ve konum verileri AI isteğine yalnızca kişiselleştirilmiş yanıt için gerekli özet biçiminde dahil edilir.

## 4. Kullanıcı kontrolü ve silme

Konum, Health Connect, Uyku Zekâsı, gece ses analizi ve bildirim özellikleri kullanıcı tarafından açılıp kapatılabilir. Kullanıcı Ayarlar'dan cihaz verilerini sıfırlayabilir, buluta yedekleyebilir, yedekten geri yükleyebilir veya hesabını ve hesabına bağlı bulut verilerini silebilir.

Hesap silme işlemi; Firebase Authentication hesabını, kullanıcıya ait Firestore belgelerini, UID'ye bağlı Storage yedeklerini ve yerel verileri silmeyi hedefler. Parola tabanlı yedeklerin silinmesi için ilgili parola gerekebilir; parola unutulursa şifreli yedek çözülemez.

## 5. Health Apps beyanı için notlar

Uygulama sigara bırakma ve genel yaşam/sağlık koçluğu amacı taşır. Nefes, öksürük, uyku ve horlama analizleri tıbbi tanı değildir. Uygulama tanı koymaz, tedavi belirlemez, ilaç dozu önermez ve acil sağlık hizmetinin yerine geçmez. Mağaza açıklamasında ve uygulama içinde bu sınırlar açıkça belirtilmelidir.

Mikrofon, konum, Health Connect ve arka plan/foreground servis izinleri yalnızca ilgili kullanıcı özelliği için istenmeli; izin ekranından önce uygulama içinde açık amaç açıklaması gösterilmelidir.

## 6. Play Console'a girilmeden önce doldurulacaklar

- Her veri türü için “toplanıyor/paylaşılıyor”, amaç, saklama ve silme cevapları gerçek Firebase ve AI sağlayıcı yapılandırmasıyla doğrulanmalıdır.
- Gizlilik politikası gerçek geliştirici adı, iletişim e-postası ve herkese açık URL ile yayınlanmalıdır.
- Hesap silme web bağlantısı Play Console'daki hesap silme alanına eklenmelidir.
- Health Apps declaration doldurulmalıdır.
- Firebase Firestore ve Storage kuralları canlı projeye deploy edilip test edilmelidir.
