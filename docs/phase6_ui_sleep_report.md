# Faz 6 — Ana Sayfa, Nefes Testi ve Uyku Zekâsı

## Yapılanlar

- Ana Sayfa sağlık metrikleri ve nefes trendi kartları onaylanan düzene uyarlandı.
- Teknik `breathTestPendingToday` değeri kullanıcıya gösterilmiyor; veri yoksa açıklayıcı metin kullanılıyor.
- Nefes testi merkez göstergesi düzgün, dolu ve simetrik yeşil onay işaretine dönüştürüldü.
- Uyku sonucu bildirimi ayrı bir horlama testi gibi sunulmuyor; Uyku Zekâsı başlığıyla kısa ve yumuşak özet gösteriyor.
- Sabah uyku bildirimi ses ve titreşim üretmiyor.
- Ana Sayfa uyku özetinde kalp/uyku simgesi yerine ses analizi anlamına gelen grafik ekolayzır simgesi kullanılıyor.
- Ana Sayfa menüsündeki ayrı Horlama Testi düğmesi kaldırıldı. Gece analizi Uyku Zekâsı akışının parçası olarak devam ediyor.
- `sleepIntelligenceTitle` anahtarının 40 dilde bulunduğu statik olarak doğrulandı.

## Doğrulama

- `git diff --check`: temiz.
- Flutter SDK sandbox ortamında bulunmadığı için `flutter analyze` ve `flutter test` kullanıcı cihazında çalıştırılmalıdır.
- Faz sonunda yalnızca Faz 6 ile ilgili üç kaynak dosyası commit edilecek; mevcut ilgisiz `cloud_sync_audit.md` dosyası dahil edilmeyecek.
