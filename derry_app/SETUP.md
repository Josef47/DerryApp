# 🏠 Household App — Kurulum Rehberi

## Ön Gereksinimler
- Flutter SDK (≥ 3.5.0)
- Firebase CLI (`npm install -g firebase-tools`)
- Node.js 20+
- Bir Google Hesabı (Firebase projesi için)

---

## 1. Firebase Projesi Oluştur

1. [console.firebase.google.com](https://console.firebase.google.com) adresine git
2. **"Add project"** → proje adı gir (örn. `household-app`)
3. **Authentication** → "Get started" → **Anonymous** yöntemini etkinleştir
4. **Firestore Database** → "Create database" → **Production mode** seç
5. **Storage** → "Get started" → Production mode
6. **Cloud Messaging (FCM)** → otomatik etkin

---

## 2. Flutter'ı Firebase'e Bağla

```bash
# FlutterFire CLI kur
dart pub global activate flutterfire_cli

# Proje dizinine gir
cd derry_app

# Firebase'i bağla (tarayıcı açılır, hesabını seç)
flutterfire configure --project=<firebase-proje-id>
```

Bu komut `lib/firebase_options.dart` dosyasını otomatik oluşturur/günceller.

---

## 3. Bağımlılıkları Yükle

```bash
flutter pub get
```

---

## 4. Firestore Güvenlik Kurallarını Deploy Et

```bash
firebase login
firebase use --add   # projeyi seç
firebase deploy --only firestore:rules
```

---

## 5. Cloud Functions'ı Deploy Et

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

### Google OAuth2 Yapılandırması (Drive/Sheets sync için)
1. [console.cloud.google.com](https://console.cloud.google.com) → API & Services → Credentials
2. **OAuth 2.0 Client ID** oluştur (Web application)
3. Redirect URI olarak `https://developers.google.com/oauthplayground` ekle
4. [OAuth Playground](https://developers.google.com/oauthplayground) ile refresh token al:
   - Scope: `https://www.googleapis.com/auth/spreadsheets`
   - "Exchange authorization code for tokens" → refresh_token'ı kopyala
5. Firebase Functions config'e ekle:
```bash
firebase functions:config:set google.client_id="YOUR_CLIENT_ID" google.client_secret="YOUR_CLIENT_SECRET"
firebase deploy --only functions
```
6. Uygulama içi **Ayarlar** ekranından:
   - `googleRefreshToken` değerini Firestore'daki `settings/appSettings` dökümanına ekle

---

## 6. PWA Olarak Build Al ve Deploy Et

```bash
# Web için build
flutter build web --release --web-renderer canvaskit

# Firebase Hosting'e deploy
firebase deploy --only hosting
```

Deploy sonrası uygulamanı şu adreste göreceksin:
```
https://<proje-id>.web.app
```

---

## 7. İlk Housemaster Hesabını Oluştur

Firebase'i ilk kurduğunda manuel olarak Firestore'a girip ilk Housemaster kaydını oluşturman gerekiyor:

### Adım 1 — Firestore'da kullanıcı oluştur
`users` koleksiyonuna yeni döküman ekle:
```json
{
  "name": "Ad Soyad",
  "role": "housemaster",
  "isHousemaster": true,
  "createdAt": <timestamp>
}
```
Döküman ID'sini kaydet (örn. `hm001`).

### Adım 2 — One-time key oluştur
`oneTimeKeys` koleksiyonuna ekle:
```json
{
  "key": "HM-INIT-0001",
  "userId": "hm001",
  "name": "Ad Soyad",
  "role": "housemaster",
  "isHousemaster": true,
  "used": false,
  "createdAt": <timestamp>
}
```

### Adım 3 — Giriş yap
Uygulamayı aç → `HM-INIT-0001` keyiyle giriş yap → **Ayarlar → Kullanıcı Yönetimi** ekranından diğer üyeler için anahtar oluştur.

---

## 8. Üye Ekleme Akışı

1. Housemaster → **Ayarlar** → **Kullanıcı Yönetimi** → **Üye Ekle**
2. İsim gir → Anahtar oluşturulur (örn. `HM-K7P2-MQRX`)
3. Anahtarı WhatsApp vb. ile üyeye gönder
4. Üye → uygulamayı telefon tarayıcısında açar → **"Ana Ekrana Ekle"** → Anahtar girer → Giriş yapar

---

## 9. Yapı Özeti

```
lib/
├── core/           ← Tema, router, sabitler
├── models/         ← Veri modelleri (Firestore serialize/deserialize)
├── services/       ← Firestore CRUD işlemleri
├── providers/      ← Riverpod state yönetimi
└── screens/
    ├── home/       ← Dashboard
    ├── tasks/      ← Görev listesi + form
    ├── finance/    ← Bakiye + harcamalar
    ├── shopping/   ← Alışveriş + sadakat kartları
    ├── activities/ ← Aktivite takibi
    ├── drive/      ← Google Drive dosyaları
    └── settings/   ← Ayarlar + kullanıcı yönetimi

functions/src/
└── index.ts        ← Günlük FCM bildirimleri + Sheets sync
```

---

## Sık Karşılaşılan Sorunlar

| Sorun | Çözüm |
|-------|-------|
| `firebase_options.dart` bulunamıyor | `flutterfire configure` komutunu çalıştır |
| Kamera/barkod tarama çalışmıyor | HTTPS gerekli; localhost'ta test et veya deploy sonrası dene |
| FCM bildirimleri gelmiyor | `firestore.rules` deploy edildi mi? FCM token Firestore'a yazıldı mı? |
| Sheets sync çalışmıyor | `googleRefreshToken` Firestore'a eklendi mi? Cloud Functions deploy edildi mi? |
| Build hatası: `intl` | `flutter pub get` yeniden çalıştır |

---

*Household App v1.0 — Hazırlayan: Claude (Anthropic)*
