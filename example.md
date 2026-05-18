## 📦 Installation

Add to your `pubspec.yaml`:
```yaml
dependencies:
  flutter_paymob_sdk: ^1.0.0
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

### 2. Create a payment intention

Choose one mode based on your environment:

#### 🛡️ Secure Mode — Recommended for Production

Keep your secret key on your backend and pass only the resulting credentials to the SDK:

```dart
// Fetch credentials from your backend
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

final credentials = await paymobService.createPaymentIntention(
  useSecureMode: true,
  publicKey: backendCreds['publicKey'],
  clientSecret: backendCreds['clientSecret'],
);
```

#### ⚠️ Direct Mode — Development & Testing Only

```dart
final credentials = await paymobService.createPaymentIntention(
  useSecureMode: false,
  secretKey: 'YOUR_SECRET_KEY',
  publicKey: 'YOUR_PUBLIC_KEY',
  amount: 100,
  currency: 'EGP',
  integrationId: 1234567,
  billingData: {
    'first_name': 'Test', 'last_name': 'User',
    'email': 'test@test.com', 'phone_number': '+201000000000',
    'apartment': 'NA', 'floor': 'NA', 'street': 'NA',
    'building': 'NA', 'shipping_method': 'NA', 'postal_code': 'NA',
    'city': 'Cairo', 'country': 'EG', 'state': 'NA',
  },
);
```

> **Never use Direct Mode in production.** Mobile apps can be decompiled and your secret key extracted.

### 3. Launch the payment SDK

```dart
final result = await paymobService.payWithPaymob(
  publicKey: credentials['publicKey']!,
  clientSecret: credentials['clientSecret']!,
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
} else if (result.isRejected) {
  // Payment was rejected
} else if (result.isPending) {
  // Payment is pending
}
```


---

## 🎨 Customization

```dart
PaymobCustomization(
  appName: 'My Store',
  buttonBackgroundColor: Colors.blue,
  buttonTextColor: Colors.white,
  showSaveCard: true,
  saveCardDefault: false,
)
```

---

## 🔧 API Reference

### `createPaymentIntention()`

| Mode | Parameter | Type | Description |
|------|-----------|------|-------------|
| Both | `useSecureMode` | `bool` | `true` for secure mode, `false` for direct |
| Secure | `publicKey` | `String` | Your Paymob public key |
| Secure | `clientSecret` | `String` | Client secret from your backend |
| Direct | `secretKey` | `String` | Your Paymob secret key |
| Direct | `amount` | `int` | Amount in currency's main unit |
| Direct | `currency` | `String` | Currency code (e.g. `'EGP'`) |
| Direct | `integrationId` | `int` | Your Paymob integration ID |
| Direct | `billingData` | `Map<String, dynamic>` | Customer billing info |
| Direct | `items` | `List<Map<String, dynamic>>?` | Optional item list |

**Returns:** `Future<Map<String, String>>` containing `publicKey` and `clientSecret`.

### `payWithPaymob()`

| Parameter | Type | Description |
|-----------|------|-------------|
| `publicKey` | `String` | Your Paymob public key |
| `clientSecret` | `String` | Client secret from payment intention |
| `customization` | `PaymobCustomization?` | Optional UI customization |

**Returns:** `Future<PaymobPaymentResult>`

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
