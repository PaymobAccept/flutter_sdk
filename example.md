## 📦 Installation

Add to your `pubspec.yaml`:
```yaml
dependencies:
  flutter_paymob_sdk:
    git:
      url: https://github.com/PaymobAccept/flutter_sdk.git
```

Then run:
```bash
flutter pub get
```

---

## 🚀 Quick Start

### 1. Import & initialize
```dart
import 'package:flutter_paymob_sdk/flutter_paymob_sdk.dart';

final paymobService = PaymobService();
```

### 2. Get credentials from your backend

Your backend calls the Paymob intention API with your secret key and returns the `publicKey` and `clientSecret` to the app. Never put your secret key inside the Flutter app.

```dart
// Example: fetch credentials from your own backend
final response = await http.post(
  Uri.parse('https://your-backend.com/api/create-payment-intention'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'amount': 100,
    'currency': 'EGP',
    'billingData': {
      'first_name': 'John',
      'last_name': 'Doe',
      'email': 'customer@example.com',
      'phone_number': '+201000000000',
      'apartment': 'NA', 'floor': 'NA', 'street': 'NA',
      'building': 'NA', 'shipping_method': 'NA', 'postal_code': 'NA',
      'city': 'Cairo', 'country': 'EG', 'state': 'NA',
    },
  }),
);

final backendCreds = jsonDecode(response.body);
final publicKey = backendCreds['publicKey'] as String;
final clientSecret = backendCreds['clientSecret'] as String;
```

### 3. Launch the payment SDK

```dart
final result = await paymobService.payWithPaymob(
  publicKey: publicKey,
  clientSecret: clientSecret,
  customization: PaymobCustomization(
    appName: 'My Store',
    buttonBackgroundColor: Colors.blue,
    buttonTextColor: Colors.white,
    showSaveCard: true,
    saveCardDefault: false,
  ),
);

if (result.isSuccessful) {
  // Payment succeeded
} else if (result.isFailure) {
  // Payment failed
} else if (result.isPending) {
  // Payment is pending
}
```

---

## 🎨 Customization

```dart
PaymobCustomization(
  // Branding
  appName: 'My Store',
  androidAppLogo: 'ic_launcher',     // Android: drawable/mipmap resource name
  iosAppLogo: 'assets/logo.png',     // iOS: Flutter asset path

  // Button
  buttonBackgroundColor: Colors.blue,
  buttonTextColor: Colors.white,

  // Card saving
  showSaveCard: true,
  saveCardDefault: false,

  // Screens
  showTransactionResult: true,       // Show/hide the built-in result screen after payment

  // iOS only
  isKeyboardHandlingEnabled: true,   // SDK keyboard avoidance behavior
)
```

### App Logo

The logo is configured separately per platform since each platform handles images differently.

**Android** — pass the name of a resource that exists in `res/drawable/` or `res/mipmap/` inside your Android project. Every Flutter app ships with `ic_launcher` in `res/mipmap/` by default:

```dart
androidAppLogo: 'ic_launcher'  // uses the app launcher icon
androidAppLogo: 'my_logo'      // uses res/drawable/my_logo.png or res/mipmap/my_logo.png
```

**iOS** — pass a Flutter asset path. Add the image to your `pubspec.yaml` and pass the same path:

```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/logo.png
```

```dart
iosAppLogo: 'assets/logo.png'
```

---

## 🔧 API Reference

### `payWithPaymob()`

| Parameter | Type | Description |
|-----------|------|-------------|
| `publicKey` | `String` | Your Paymob public key |
| `clientSecret` | `String` | Client secret from your backend |
| `customization` | `PaymobCustomization?` | Optional UI customization |

**Returns:** `Future<PaymobPaymentResult>`

### `PaymobCustomization`

| Parameter | Type | Platform | Description |
|-----------|------|----------|-------------|
| `appName` | `String?` | Both | Branding label shown inside the SDK UI |
| `androidAppLogo` | `String?` | Android | Drawable/mipmap resource name e.g. `'ic_launcher'` |
| `iosAppLogo` | `String?` | iOS | Flutter asset path e.g. `'assets/logo.png'` |
| `buttonBackgroundColor` | `Color?` | Both | Payment button background color |
| `buttonTextColor` | `Color?` | Both | Payment button text color |
| `showSaveCard` | `bool?` | Both | Show/hide the save card checkbox |
| `saveCardDefault` | `bool?` | Both | Pre-check the save card checkbox |
| `showTransactionResult` | `bool?` | Both | Show/hide the built-in result screen after payment |
| `isKeyboardHandlingEnabled` | `bool?` | iOS | SDK keyboard avoidance behavior |

### `PaymobPaymentResult`

| Property | Type | Description |
|----------|------|-------------|
| `status` | `PaymentStatus` | `successful`, `failure`, `pending`, `unknown` |
| `isSuccessful` | `bool` | `true` if payment succeeded |
| `isFailure` | `bool` | `true` if payment failed |
| `isPending` | `bool` | `true` if payment is pending |
| `transactionDetails` | `Map<String, dynamic>?` | Transaction data (successful payments only) |
| `errorMessage` | `String?` | Error description if status is `unknown` |

---

## 🔧 Troubleshooting

**Android — MinSdkVersion error**  
Set `minSdkVersion 23` or higher in `android/app/build.gradle.kts`.

**iOS — Pod install fails**
```bash
cd ios && pod deintegrate && pod install --repo-update
```

**Payment callbacks not firing**  
Set the response callback URL for your integration ID in the Paymob dashboard:

| Region | URL |
|--------|-----|
| Egypt | `https://accept.paymob.com/api/acceptance/post_pay` |
| Oman | `https://oman.paymob.com/api/acceptance/post_pay` |
| Saudi Arabia | `https://ksa.paymob.com/api/acceptance/post_pay` |
| UAE | `https://uae.paymob.com/api/acceptance/post_pay` |
