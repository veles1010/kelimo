# Kelimo iOS reklam ve yayın hazırlığı

Bundle ID: `com.veles.kelimo`. Xcode hedefi ve CocoaPods için minimum iOS sürümü 15.0.

## Yerel uygulama kimliği

`ios/Flutter/AdMob.xcconfig.example` dosyasını `AdMob.xcconfig` adıyla kopyalayıp
`ADMOB_IOS_APP_ID` değerini AdMob'daki **Kelimo iOS** uygulama kimliğiyle doldurun.
Bu kimlik `ca-app-pub-…~…` biçimindedir. Yerel dosya Git tarafından yok sayılır.
CI kullanılıyorsa aynı Xcode build setting sağlanabilir.

Debug ve release aynı yerel uygulama kimliğini okuyabilir. Böylece UMP, Kelimo için
yayınlanan mesajları bulur. Debug'daki reklam birimi kimlikleri Dart servisleri
tarafından Google'ın demo birimlerine çevrilir; uygulama kimliği bu seçimi değiştirmez.

## Reklam birimleri

AdMob'da iOS uygulamasının altında iki banner ve bir geçiş birimi kullanılır:

| Yerleşim | Flutter derleme parametresi |
| --- | --- |
| Öğrenme bannerı | `ADMOB_IOS_LEARNING_BANNER_AD_UNIT_ID` |
| Quiz bannerı | `ADMOB_IOS_QUIZ_BANNER_AD_UNIT_ID` |
| Geçiş reklamı | `ADMOB_INTERSTITIAL_AD_UNIT_ID` |

Birim kimlikleri `ca-app-pub-…/…` biçimindedir. iOS arşivine bu iOS birimleri verilir.

Örnek release komutu; büyük harfli üç yer tutucuyu gerçek iOS birimleriyle değiştirin:

```bash
flutter build ipa --release \
  --dart-define=ENABLE_REMOVE_ADS=false \
  --dart-define=ADMOB_IOS_LEARNING_BANNER_AD_UNIT_ID=YOUR_IOS_LEARNING_BANNER_AD_UNIT_ID \
  --dart-define=ADMOB_IOS_QUIZ_BANNER_AD_UNIT_ID=YOUR_IOS_QUIZ_BANNER_AD_UNIT_ID \
  --dart-define=ADMOB_INTERSTITIAL_AD_UNIT_ID=YOUR_IOS_INTERSTITIAL_AD_UNIT_ID
```

## Onay mesajları ve ATT

AdMob > Gizlilik ve mesajlaşma bölümünde Kelimo iOS'u Avrupa düzenlemeleri mesajına
ekleyip mesajı yayınlayın. IDFA mesajını da Kelimo iOS için oluşturup yayınlayın.
Mevcut UMP servisi gerekli formları reklam SDK'sı başlatılmadan önce gösterir.
IDFA mesajı ve sistem ATT isteği UMP tarafından yönetilir; ayrıca bir yerel ATT
isteği eklenmez. `Info.plist` izin açıklamasını içerir ve Runner, Apple'ın
AppTrackingTransparency framework'ünü bağlar.

ATT reddedilirse uygulama kullanılmaya devam eder. Reklam istekleri UMP'nin
`canRequestAds()` sonucuna bağlıdır; ATT reddi ayrıca bir engel olarak kullanılmaz.

## Mac üzerinde doğrulama

```bash
flutter pub get
flutter analyze
flutter test
```

Ardından fiziksel iPhone/iPad'de debug sürümünde öğrenme ve quiz akışını, demo
bannerları ve quiz sonrası geçişi kontrol edin. Onay mesajlarını test etmek için
AdMob/UMP test cihazı ayarları kullanılır. İzin kabulü ve reddi sonrasında
uygulamanın çalışmaya devam ettiğini doğrulayın. Bu adımlar gerçekleşmeden cihaz
testi tamamlanmış olarak kaydedilmemelidir.

`ENABLE_REMOVE_ADS` mevcut varsayılanıyla kapalıdır. Bu hazırlık satın alma
özelliğini etkinleştirmez.

Release arşivini oluşturduktan sonra işlenmiş uygulamanın `Info.plist` dosyasında
`GADApplicationIdentifier` değerinin Kelimo iOS uygulama kimliği olduğunu kontrol
edin. Mağaza gizlilik beyanı kullanılan reklam verileriyle uyumlu doldurulmalıdır.
App Store sürümü yayınlandıktan sonra AdMob kaydı mağaza sayfasına bağlanır ve
uygulama/app-ads.txt doğrulaması tamamlanır.

## Kaynaklar

- [Flutter reklam kurulumu](https://developers.google.com/admob/flutter/quick-start)
- [UMP kurulumu](https://developers.google.com/admob/flutter/privacy)
- [IDFA mesajı ve ATT](https://developers.google.com/admob/ios/privacy/idfa)
- [AdMob'da IDFA mesajı oluşturma](https://support.google.com/admob/answer/10115331)
- [SKAdNetwork ve iOS 15 CocoaPods ayarı](https://developers.google.com/admob/ios/quick-start)

SKAdNetwork listesi 24 Ekim 2026 tarihinde Google'ın resmi iOS kurulum sayfasındaki
50 kimlikle eşleştirilmiştir.

## İlk iOS sürümünün kapsamı

İlk sürüm ücretsiz ve reklamlıdır. Reklam kaldırma ürünü gönderime eklenmez;
banka hesabı ve vergi formu adımları bekletilir. Ürünün gelecekteki sürüm için
hazırlandığı App Review notlarında açıklanır.

Mağaza taslakları: [Türkçe mağaza bilgileri](app-store-tr.md).
Politika ve destek sayfaları main dalındaki docs klasörü Pages'e yayımlandıktan
sonra canlı URL'lerden doğrulanır.

Gizlilik Merkezi'ndeki tam politika bağlantısı url_launcher ile cihazın
tarayıcısını açar. Bağlantı başarısız olursa URL kullanıcıya gösterilir.
Yeni bağımlılık için Mac'te flutter pub get çalıştırılıp oluşan pubspec.lock
ve platform kayıt değişiklikleri kontrol edilerek kaydedilmelidir.
