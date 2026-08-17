# Faz 3 — Veri, Hesap ve Bulut Senkronizasyonu

## Yapılan değişiklikler

- `FirestoreSyncService.syncLocalDatabaseBackup` artık başarı/başarısızlık durumunu `bool` olarak döndürüyor.
- Uygulama arka plandan tekrar öne geldiğinde tam yerel veritabanı snapshot senkronizasyonu başlatılıyor.
- E-posta/şifre ile girişte yeni tam veritabanı yedeği önce geri yükleniyor; bulunamazsa eski survey-only yedek formatı da geri yükleniyor.
- Manuel bulut yedekleme ve geri yükleme, kalıcı Google/e-posta hesabı yoksa başlamadan önce durduruluyor. Böylece anonim kullanıcıda görülen genel `Cloud Backup Failed` hatası yerine giriş gerekliliği gösteriliyor.
- Mevcut Firestore ve Storage kuralları UID sınırı açısından incelendi; dağıtım hedefleri raporlandı.

## Kapsanan kullanıcı verileri

Tam snapshot akışı StorageService tarafından dışa aktarılan SQLite tablolarını ve desteklenen SharedPreferences durumlarını kapsar. Bu kapsam anketler, testler, raporlar, sigara kayıtları, görevler, ilaçlar, davranış motoru durumu ve kullanıcı ayarlarını içerir.

## Doğrulama durumu

- `git diff --check`: başarılı.
- Çağrı noktaları taraması: tamamlandı.
- Flutter/Dart SDK bu sandbox ortamında PATH üzerinde bulunmadığından `flutter analyze` burada çalıştırılamadı.
- Kullanıcı cihazında `git pull origin main` ve `flutter analyze` çalıştırılmalıdır.
- Faz 3, kullanıcı bu analiz sonucunu kontrol edip `tamam` yazana kadar tamamlanmış sayılmayacaktır.

## Sonraki adım

Kullanıcı onayından sonra Faz 4'e geçilecek; onaylanan Ana Sayfa, nefes testi ve Uyku Zekâsı tasarımları uygulama koduna aktarılacaktır.

## Not

Bu fazda kullanıcıdan onay alınmadan Release AAB oluşturulmayacaktır.

