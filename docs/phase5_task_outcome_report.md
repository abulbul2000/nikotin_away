# Faz 5 — Görev sonucu bildirimi

## Yapılan değişiklikler

Görev süresi dolduğunda kullanıcı artık yalnızca Evet/Hayır görmeyecek. İki düğme açık sonucu gösteriyor:

- Sigara içmedim — Başarılı
- Sigara içtim — Başarısız

Metinler Türkçe, İngilizce ve uygulamadaki diğer 38 dil bloğunda güncellendi. Uzun yerelleştirilmiş metinlerin taşmaması için düğme yazı boyutu da 18sp olarak düzenlendi.

## Veri sonucu

Mevcut görev durum eşlemesi doğrulandı:

- `confirmSmokedNo` → `completed`
- `confirmSmokedYes` → `failed`

Bu nedenle ekranda gösterilen sonuç ile görev servisinin kaydettiği sonuç aynıdır. İçmedim seçimi başarılı, içtim seçimi başarısız olarak kaydedilir.

## Doğrulama

Yerel Flutter SDK sandbox ortamında bulunmadığı için Flutter analyze/test burada çalıştırılamadı. `git diff --check` başarılıdır. Kullanıcı cihazında faz sonunda `git pull origin main` ve `flutter analyze` çalıştırılmalıdır; görev akışı kritik olduğu için gerekirse `flutter test` de çalıştırılacaktır.
uy

## Değişen dosyalar

- `lib/core/app_texts.dart`
- `lib/core/generated_language_data.dart`
- `lib/pages/task_smoked_confirm_page.dart`
- `scripts/update_task_outcome_labels.py`
- `docs/phase5_task_outcome_report.md`
