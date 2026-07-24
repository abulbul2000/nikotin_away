# No Smoke — Gizlilik Politikası

**Son güncelleme:** [TARİH GİRİN]

> **Yayınlamadan önce doldurulması gerekenler** (aşağıda `[...]` ile işaretli): geliştirici/şirket adı, iletişim e-postası, ve bu belgenin barındırılacağı URL. Bu belge, `docs/PLAY_STORE_DATA_SAFETY.md` ile aynı kod-tabanlı denetime dayanır (2026-07-22) — kod değiştikçe ikisi birlikte güncellenmeli.

## 1. Bu Politika Neyi Kapsar

Bu Gizlilik Politikası, **No Smoke** mobil uygulamasının ("Uygulama") kişisel verilerinizi nasıl işlediğini açıklar. Uygulama [GELİŞTİRİCİ/ŞİRKET ADI] ("biz") tarafından geliştirilmiştir. Sorularınız için: [İLETİŞİM E-POSTASI].

## 2. Temel İlke: Verileriniz Varsayılan Olarak Cihazınızda Kalır

Uygulamaya girdiğiniz veya uygulamanın topladığı hemen hemen her şey **varsayılan olarak yalnızca telefonunuzda**, uygulamanın kendi özel deposunda saklanır ve bizimle veya üçüncü bir tarafla paylaşılmaz. Uygulamanın kendi sunucusu ve kullanıcı hesabı yoktur.

İki istisna var, ikisi de aşağıda (madde 3 ve 5) ayrıntılı açıklanmıştır: (a) isteğe bağlı, sizin açtığınız durumda kullanılan **şifreli bulut yedekleme** ve (b) uygulama çöktüğünde otomatik gönderilen **anonim hata raporları**.

## 3. Toplanan Veriler

| Veri türü | Ne topluyoruz | Neden |
|---|---|---|
| Profil bilgisi | Ad, yaş, cinsiyet, meslek (ilk anket) | Risk değerlendirmesini kişiselleştirmek |
| Sigara alışkanlığı | Günlük/haftalık anket cevapları | Risk skoru ve görev planlaması |
| Nefes testi | Test sırasında mikrofon kullanılır; ses **anlık işlenir, hiçbir zaman kaydedilmez** | Nefes performansı ölçümü |
| Uyku tahmini *(isteğe bağlı)* | Ekran açık/kapalı ve şarj durumu, gece boyunca birkaç kez | Uyku-risk ilişkisini öğrenmek |
| Konum *(isteğe bağlı)* | Sık gidilen yerlerin öğrenilmiş merkez noktaları (ham GPS geçmişi **saklanmaz**) | Riskli ortamları tanımak |
| Adım sayısı | Telefonun donanım adım sayacı | Aktivite-risk ilişkisi, raporlar |
| Nabız / uyku süresi *(isteğe bağlı)* | Health Connect üzerinden — yalnızca zaten bir akıllı saat/bileklik uygulamanız varsa okunur | Risk değerlendirmesine ek sinyal |
| Kullanım verisi | Görev tamamlama/erteleme, bildirim yanıtları | Kişiselleştirme, hatırlatma zamanlaması |

"İsteğe bağlı" olarak işaretlenen her özellik **varsayılan olarak kapalıdır**; siz açana kadar hiçbir veri toplanmaz. Her birini Ayarlar ekranından istediğiniz zaman açıp kapatabilirsiniz.

**Bulut yedekleme** *(isteğe bağlı, varsayılan kapalı):* Ayarlar → Bulut Yedekleme'den kendi belirlediğiniz bir şifreyle açabileceğiniz bir özellik. Açtığınızda, cihazınızdaki tüm uygulama verileri bu şifreyle (cihaz üzerinde, gönderilmeden önce) şifrelenir ve Google'ın Firebase Storage altyapısına yüklenir. Şifreniz bize hiçbir zaman gönderilmez ve sunucuda saklanmaz — yalnızca sizde bulunur; şifrenizi kaybederseniz yedeğinizi biz de geri getiremeyiz.

## 4. Toplamadığımız Veriler

Fotoğraf/video, kişi listesi, takvim, mesajlar, finansal bilgi, web geçmişi veya reklam kimliği toplamıyoruz. Uygulamada reklam SDK'sı veya analitik/izleme SDK'sı bulunmamaktadır.

## 5. Üçüncü Taraflarla Paylaşım

Verilerinizi **hiçbir zaman satmıyor veya reklam/analitik amacıyla paylaşmıyoruz.**

- **Çeviri:** Telefonunuzun dili, uygulamanın önceden hazırladığı 39 dilin dışında nadir bir dilse, arayüz metinlerini çevirmek için Google'ın çeviri servisine (`translate.googleapis.com`) tek seferlik, şifreli (HTTPS) bir istek gönderilir. Bu istekte yalnızca uygulamanın kendi İngilizce arayüz metinleri yer alır — anket cevabınız, sağlık veriniz veya başka bir kişisel veriniz **asla** gönderilmez.
- **Hata raporlama (Firebase Crashlytics):** Uygulama beklenmedik şekilde çökerse, hatanın türünü ve teknik ayrıntılarını (hangi ekranda, hangi hata) — isim, anket cevabı veya sağlık verisi **olmadan** — otomatik olarak Google'ın Firebase Crashlytics servisine göndeririz. Amaç yalnızca hataları bulup düzeltmektir.
- **Bulut yedekleme (Firebase Storage):** Yukarıda (madde 3) açıklandığı gibi, yalnızca siz açtığınızda ve yalnızca sizin şifrenizle şifrelenmiş halde, Google'ın Firebase Storage servisine gönderilir. Şifrelenmemiş içerik bize veya Google'a hiçbir zaman ulaşmaz.

## 6. Verilerinizin Güvenliği

Ana veriler, Android'in uygulamaya özel korumalı deposunda (SQLite veritabanı) saklanır ve cihazınızın otomatik bulut yedeklemesine dahil edilmez. Uygulamayı kaldırdığınızda cihazdaki tüm veriler silinir (yalnızca siz açtıysanız, bulutta şifreli yedeğiniz şifrenizle korunmuş halde kalmaya devam eder — istediğiniz zaman geri yükleyebilirsiniz).

## 7. Haklarınız

- **Görme:** Uygulama içindeki ilgili ekranlardan (Ayarlar, Raporlar, Anket Geçmişi) topladığımız verileri her zaman görebilirsiniz.
- **Silme:** Ayarlar → "Verilerimi Sıfırla" ile tüm verilerinizi (rıza kayıtları dahil) kalıcı olarak silebilirsiniz.
- **Rıza geri çekme:** İsteğe bağlı her özelliği (Uyku Zekası, Konum Zekası, Bileklik Verisi) istediğiniz an kapatabilirsiniz; her açma/kapama kararı, ne zaman ve hangi açıklama metnine göre verildiği bilgisiyle kaydedilir.

## 8. Çocukların Gizliliği

Uygulama genel kitleye yöneliktir ve bilerek 13 yaş altı çocuklardan veri toplamaz.

## 9. Bu Politikadaki Değişiklikler

Uygulamanın veri toplama şekli değiştiğinde bu belge güncellenir ve "Son güncelleme" tarihi buna göre yenilenir.

## 10. İletişim

Sorularınız için: [İLETİŞİM E-POSTASI]
