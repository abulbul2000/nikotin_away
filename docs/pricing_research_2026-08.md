# Nikotin Away fiyatlandırma araştırması

## Resmi kaynaklar

1. Google Play hizmet ücretleri: https://support.google.com/googleplay/android-developer/answer/112622?hl=tr
   - Google Play yardım sayfası, otomatik yenilenen abonelik ürünlerinde genel hizmet ücretinin geliştiricinin yıllık gelirinden bağımsız olarak %15 olduğunu belirtir.
   - Sayfa, 30 Haziran 2026'dan itibaren AEA/Birleşik Krallık/ABD için %10 hizmet + %5 faturalandırma ücreti modelini de açıklar; toplam oran aboneliklerde yine %15'tir.

2. Google Play abonelik oluşturma ve yönetme: https://support.google.com/googleplay/android-developer/answer/140504?hl=tr
   - Abonelikler temel planlarla oluşturulur.
   - Ürün kimlikleri oluşturulduktan sonra değiştirilemez veya yeniden kullanılamaz.
   - Otomatik yenilenen temel plan, kullanıcının iptal etmemesi halinde yenilenir.
   - Google Play Console'da yerel fiyatlar ve ülke/bölge bazlı fiyat ayarları yapılabilir.

3. Gemini Developer API pricing: https://ai.google.dev/gemini-api/docs/pricing
   - Google, Gemini API için ücretsiz ve ücretli katmanlar sunar.
   - Üretim uygulamalarında ücretli katman, daha yüksek limitler ve üretim erişimi için kullanılır.
   - Model ve fiyatlar değişebileceğinden maliyet kontrolü için sunucu tarafı kota gereklidir.

4. Benzer ürün: https://www.quitnow.app/tr
   - QuitNow sigara bırakma uygulaması olarak Türkiye sayfasında çoklu dil, topluluk, sağlık/ilerleme özellikleri ve Google Play dağıtımı sunuyor.
   - Sayfada fiyat bilgisi açıkça görünmedi; bu nedenle fiyat karşılaştırması için doğrulanmış bir rakam kullanılmadı.

## Mevcut proje bulguları

- Repo: https://github.com/abulbul2000/nikotin_away
- Firebase projectId: no-smoke-7dd2e
- AI backend: Firebase Cloud Functions `aiChat`
- AI sağlayıcısı: Gemini API; `geminiApiKey` Firebase Secret üzerinden veriliyor.
- OpenAI anahtarı mevcut çağrıda null.
- Onaylanan ürün kimlikleri: `no_smoke_starter`, `no_smoke_plus`, `no_smoke_pro`.
- Onaylanan fiyatlar: Starter 4.99 USD/ay, Plus 9.99 USD/ay, Pro 19.99 USD/ay.
- Onaylanan aylık kotalar: sırasıyla 300, 900 ve 1.800 AI mesajı; günlük kotalar sırasıyla 10, 30 ve 60.
- Eski sunucu `hasAiAccess()` geçici herkese açık davranışı kaldırıldı; üretimde Google Play token doğrulaması ve server-side kota uygulanıyor.
- `verifySubscription` Cloud Function Google Play tokenını doğruluyor ve aktif ürün/token/plan bilgisini `users/{uid}.subscription` altında server-side kaydediyor. Cihazdaki `subscription_state` yalnızca kullanıcı deneyimi için yerel önbellek; AI erişiminin kaynağı sunucu doğrulaması.

## Onaylanan fiyatlandırma tasarımı

Kullanıcı üç ayrı ücretli kademeyi onayladı. Daha fazla AI konuşması isteyen kullanıcı daha yüksek plana geçer; hiçbir plan sınırsız olarak pazarlanmaz.

| Plan | Aylık fiyat | Günlük kota | Aylık kota |
| --- | ---: | ---: | ---: |
| Starter | 4.99 USD | 10 | 300 |
| Plus | 9.99 USD | 30 | 900 |
| Pro | 19.99 USD | 60 | 1.800 |

Yıllık planlar ilk sürümden sonra ayrıca eklenebilir. Her ürünün Play Console kimliği ve temel plan kimliği yayınlanmadan önce kesinleştirilmelidir.

## Kritik güvenlik/maliyet notu

Abonelik geliri - Google Play hizmet bedeli - vergi - Gemini - Cloud Functions - Firestore - iade/chargeback kalemleri pozitif kalmalıdır. Bu nedenle kota günlük ve aylık olarak Cloud Function içinde uygulanmalı; istemci tarafındaki kontrole güvenilmemeli. Debug sürümü üretim Gemini anahtarını kullanmamalı; ayrı geliştirme projesi veya ayrı anahtar/kota kullanılmalıdır.
