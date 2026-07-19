# UI Catalog Pipeline

Bu altyapi, uygulamayi emulatorde gercek render ile yakalayip ekran-kaynak iliskisini kalici katalogda tutar.

## Klasorler

- `ui_catalog/screens`: Gercek render ekran goruntuleri (`<SCREEN_ID>.png`)
- `ui_catalog/catalog/screen_catalog.json`: Ekran katalogu (makine-okunur)
- `ui_catalog/catalog/screen_catalog.md`: Ekran katalogu (insan-okunur)
- `ui_catalog/reports/last_capture_report.json`: Son capture raporu
- `ui_catalog/reports/last_feedback_apply_report.json`: Son toplu duzeltme uygulama raporu

## Ilk Asama Komutlari

Tum ekranlari aktif dilde render edip katalog olustur:

```powershell
./scripts/ui_catalog_pipeline.ps1 -Mode capture -DeviceId emulator-5554 -CatalogRoot ui_catalog
```

Bu komut su adimlari yapar:
1. `flutter pub get`
2. integration test ile ekranlari tek tek gercek render eder
3. her ekrani `ui_catalog/screens` altina yazar
4. ekran ID -> kaynak dosyalar -> ceviri/stil/tema baglarini kataloga yazar

## Toplu Geri Bildirim Uygulama

Feedback dosyasi verip toplu replace uygula ve otomatik yeniden render et:

```powershell
./scripts/ui_catalog_pipeline.ps1 -Mode apply-feedback -FeedbackFile docs/ui_feedback.sample.json -DeviceId emulator-5554 -CatalogRoot ui_catalog
```

Bu mod:
1. `tool/apply_ui_feedback.dart` ile kaynak gunceller
2. tum katalogu yeniden render eder
3. rapor uretir

## Feedback JSON Formati

```json
{
  "updates": [
    {
      "screenId": "SCR-0008-HOME",
      "file": "lib/pages/home_page.dart",
      "find": "quickMenuTitle",
      "replace": "quickMenuTitle"
    }
  ]
}
```

Notlar:
- `screenId`, katalogdaki ekran kimligi olmali.
- `file`, ilgili ekranin `sourceFiles` listesinde olmali.
- `find` metni hedef dosyada bulunmazsa kayit `skipped` olur.

## Teknik Bilesenler

- Ekran registry: `lib/ui_catalog/ui_catalog_registry.dart`
- Gercek render testi: `integration_test/ui_catalog_capture_test.dart`
- Screenshot + katalog yazici driver: `test_driver/ui_catalog_driver.dart`
- Toplu feedback uygulayici: `tool/apply_ui_feedback.dart`
- Orkestrasyon scripti: `scripts/ui_catalog_pipeline.ps1`
