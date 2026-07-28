# Nikotin Away — Proje Kuralları

Bu dosya her oturumda otomatik yüklenir. Kalıcı proje kuralları burada durur.

## Ürünün amacı

**Azaltarak bıraktırma.** Kullanıcı programa başladığında sigara içmeye devam ediyor; sistem
sigara arası süreyi kademeli uzatarak tüketimi düşürür. Bu yüzden "kaç gündür sigara içmedin"
tipi göstergeler bu ürüne uymaz — doğru göstergeler azalma odaklıdır (hedef tutturma serisi,
içilmeyen sigara sayısı, sigara arası sürenin uzaması).

## Değişmez kısıtlar

- **Paket adı, applicationId, bundle identifier, Firebase yapılandırması değişmez.**
- Uygulama **tamamen çevrimdışı** çalışır. Kullanıcı verisi cihazdan çıkmaz. Ağ çağrısı
  eklemeden önce `docs/PLAY_STORE_DATA_SAFETY.md` ve `docs/PRIVACY_POLICY.md` ile çelişip
  çelişmediği kontrol edilmeli.
- Sağlık/tıbbi metinler genel yaşam tarzı düzeyinde kalır. Doz, tanı veya tedavi önerisi
  verilmez; her tıbbi ipucunun altında "doktorunuza danışın" notu bulunur.

## Dil ve yerelleştirme

Uygulama **40 dil** sunuyor (`LanguageService.supportedLanguages`). Dil hassasiyeti dört
yüzeyi birden kapsar:

1. **Çeviri anahtarları** — yeni bir metin `app_texts.dart` (`_tr`/`_en`) içine eklendiğinde
   aynı işte `generated_language_data.dart`'taki tüm dil bloklarına da eklenmeli.
2. **Sabit metinler** — `Text('...')` şeklinde gömülü string kullanılmaz, her zaman
   `context.t('key')`.
3. **Sesli çıktı** — TTS de aynı anahtarları okur. Eksik anahtar, Fransızca sesin İngilizce
   kelime okuması demektir.
4. **RTL** — Arapça sağdan sola. `Alignment.centerLeft/Right`, `TextAlign.left/right`,
   `EdgeInsets.only(left:/right:)` yerine yönlü karşılıkları kullanılmalı.

Çeviriler Türkçeden uzundur (Almanca, Rusça, Tamilce özellikle). Metin içeren her `Row`
`Expanded`/`Flexible` ve `maxLines`/`overflow` ister.

## Cihaz kapsamı

Her düzeltme **tüm üreticiler** için geçerlidir. OEM'e özel çözümler (MIUI, EMUI, ColorOS,
One UI) yalnızca standart Android mekanizmasının üstüne en iyi çaba eklentisi olarak konur —
bir özellik asla tek üreticide çalışacak şekilde kurulmaz.

## Mimari desenler

- **Native → Dart veri akışı:** Native taraf sonucu SharedPreferences kuyruğuna yazar, Dart bir
  sonraki çalışmasında `drain()` ile alır (`TaskOverlayOutcomeStore`, `SleepActivityStore`
  örnekleri). Arka plan isolate doğrudan SQLite'a yazmaz.
- **Zamanlama:** Uzun süreli sayaçlar için foreground service + wakelock değil,
  `setExactAndAllowWhileIdle` alarmı kullanılır.
- **Saf motorlar:** `discipline_protocol_service`, `behavior_engine` gibi karar motorları I/O
  içermez, test edilebilir kalır. Yan etkiler servis katmanında toplanır.
- **Veritabanı göçü:** `storage_service.dart` içinde `version:` artırılır ve idempotent
  `_ensureXTable(db)` yardımcıları hem `onCreate` hem `onUpgrade` içinden çağrılır.

## Çalışma düzeni

- Her faz sonunda `flutter analyze` + `flutter test` çalıştırılır. Cihaza kurulum
  **kullanıcıya sorulmadan yapılmaz**.
- Güncel iş listesi: `docs/WORK_LIST.md` — madde tamamlandıkça işaretlenir. Oturum kapanıp
  açıldığında kaldığın yer oradan okunur.
