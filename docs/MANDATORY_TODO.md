# Mandatory / Kalan İşler Listesi

Bu dosya, 2026-07-24 tarihli büyük düzeltme partisinden kalan, henüz tamamlanmamış işleri takip eder. Tamamlanan bir madde işaretlenip not düşülür; oturum kesilirse (limit, kapanma vb.) buradan devam edilir.

## Tamamlanan (bu partide)
- [x] Uygulama ikonu ortalandı + büyütüldü
- [x] Anket alan etiketleri kutu içi placeholder stiline çevrildi
- [x] Nefes testi oturan figürü Material ikonla değiştirildi (tüm adım/denemeler kapsandı)
- [x] Ana Sayfa nefes trendi kartlarına ikon+trend oku eklendi
- [x] Zorunlu görev ekranında SOS butonu sigara ikonunun üstüne taşındı
- [x] Ana Sayfa'da SOS butonu AppBar'a (üstte sabit) taşındı
- [x] Ana Sayfa'daki eski "Gelişmiş" debug bölümü ve yinelenen görev listesi kaldırıldı

## Kalan İşler
- [ ] Mikrofon güvenilirlik sorununu yeniden araştır
- [ ] Nefes başlangıç/bitişini otomatik algıla (kullanıcı "Tamam"a basmadan)
- [ ] Süre bariyeri: minimum 30 dk + kademeli (tier) eşikleme sistemi (risk skoru/öz-kontrol iyileşmesine göre gün/2 gün/hafta adımlarıyla büyüyüp "bu ay içme" seviyesine ulaşacak)
- [ ] Cevapsız görev: 5 dk arayla 3 deneme, sonra "yapılamadı" sayılıp sıradaki göreve geç (önceki yanlış "4 dk'da sıraya koy" yaması kaldırılıp doğrusuyla değiştirilecek)
- [ ] "Ertele" butonu artık "ne zaman hatırlatayım?" diye sorsun, cevapsız kalırsa 5 dk kuralına düşsün
- [ ] Uyku saatinde gerçek zamanlı telefon aktivitesi algılama + günlük kotaya göre tam görev ya da küçük tavsiye bildirimi
- [ ] "Elinizde sigara varsa söndürün" mesajını sesli+yazılı süre bariyeri metinlerine ekle
- [ ] Horlama testi (isteğe bağlı, periyodik kısa ses örnekleme) — yeni özellik
- [ ] Yeni eklenen tüm çeviri anahtarlarını 24 dile uygula
- [ ] Tümü bitince: flutter analyze + flutter test + flutter build apk --debug, sonra kurulum için onay iste

## Not
Ayrıca ayrı, bağlantısız bir bulgu: `craving_sos_page.dart` içindeki "Görev ver" butonu bağlanmamış bir placeholder (`// Hook point: navigate to a distraction task`) — kullanıcı bunun ele alınıp alınmayacağına henüz karar vermedi, yukarıdaki listeye dahil değil.
