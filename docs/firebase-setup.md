# Firebase Console — AI güvenlik açığı düzeltmesi sonrası elle yapılacaklar

`functions/index.js`'deki `aiChat` ve `verifySubscription`, artık Firebase Auth (anonim) +
App Check zorunlu kılıyor. Kod tarafı tamamlandı ama şu adımlar Firebase Console'dan elle
yapılmadan **prod'da her iki fonksiyon da bütün çağrıları reddeder.**

## 1. Anonymous Authentication'ı aç

Firebase Console → Authentication → Sign-in method → **Anonymous** → Enable.

Bu olmadan `main.dart`'taki `FirebaseAuth.instance.signInAnonymously()` çağrısı
`operation-not-allowed` hatasıyla başarısız olur (best-effort try/catch sayesinde uygulama
açılmaya devam eder, ama hiçbir kullanıcı `aiChat`'e erişemez).

## 2. App Check'i kaydet (Android — Play Integrity)

1. Firebase Console → App Check → **Get started**.
2. `com.nikotinaway.app` Android app'ini seç (2026-08-13'teki applicationId geçişinden sonraki
   yeni Firebase app kaydı — bkz. `google-services.json`, `mobilesdk_app_id:
   1:269922488535:android:76a3e835681baec3422092`).
3. Provider olarak **Play Integrity API** seç.
4. Google Cloud Console'da aynı proje (`no-smoke-7dd2e`) için **Play Integrity API**'yi
   etkinleştir (API'ler ve Hizmetler → Kitaplık → "Play Integrity API" ara → Etkinleştir).
5. Play Console → Uygulama bütünlüğü (App integrity) bölümünden bu Firebase projesini
   bağla/onayla (Play Integrity, uygulamanın Play Console'da kayıtlı olmasını ister — ilk
   yayından önce bu adım "Dahili test" track'i ile de yapılabilir).

## 3. SHA-256 parmak izini ekle

Play Integrity/App Check, imzalayan sertifikanın parmak izini bilmek zorunda.

```
# Release keystore için (android/key.properties'teki storeFile'a göre):
keytool -list -v -keystore <release-keystore-dosyasi> -alias <keyAlias>

# Debug için (App Check debug provider zaten debug build'lerde farklı çalışır,
# ama Play Integrity'nin debug/internal test track'inde de doğru imzayla
# eşleşmesi gerekebilir):
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android
```

Çıktıdaki **SHA-256** değerini Firebase Console → Project Settings → Genel sekmesi →
`com.nikotinaway.app` Android app'i → "SHA sertifika parmak izi ekle" kısmına ekle.

## 4. App Check enforcement'ı aç

Firebase Console → App Check → **APIs** sekmesi → Cloud Functions satırında **Enforce**'a
geç. Bunu yapmadan önce en az bir gerçek cihazdan/emülatörden başarılı bir `aiChat` çağrısı
yaparak (Play Integrity provider'ının doğru token ürettiğini) doğrula — enforcement açıkken
token üretemeyen her istemci (ör. henüz SHA-256'sı eklenmemiş bir debug build) tamamen
engellenir.

Debug/geliştirme sırasında `AndroidProvider.debug` (main.dart, `kDebugMode` kontrolü) devreye
girer — bu, App Check Console'da ayrıca bir "debug token" kaydı ister (ilk debug build
çalıştırıldığında logcat'e basılan token, Console → App Check → Apps → ⋮ → "Manage debug
tokens" kısmına elle eklenir).

## 5. Firestore'u etkinleştir

Bu değişiklikten önce projede Firestore hiç kullanılmıyordu. Firebase Console → Firestore
Database → **Create database** (Native mode, region: `europe-west1` — Cloud Functions ile
aynı bölge, gecikmeyi azaltır).

Kurallar repodaki `firestore.rules` dosyasından deploy edilir:

```
firebase deploy --only firestore:rules
```

Kural, istemcinin `users/*` koleksiyonuna hiçbir şekilde doğrudan erişemediğini garanti eder
(`allow read, write: if false`) — tüm okuma/yazma yalnızca Cloud Functions'daki Admin SDK
üzerinden olur, App Check/Firestore Security Rules bu yolu hiç etkilemez.

## 6. Fonksiyonları deploy et

```
cd functions
npm test        # önce yerel testler (auth.test.js) yeşil olmalı
firebase deploy --only functions,firestore:rules
```

---

**Sıra önemli:** 1-3 tamamlanmadan 4'ü (enforcement) açma — aksi halde gerçek kullanıcılar
dahil hiç kimse `aiChat`'e erişemez. Enforcement'ı açmadan önce mutlaka bir test cihazından
uçtan uca doğrula.
