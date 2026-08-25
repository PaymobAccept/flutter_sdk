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
} else if (result.isCancelled) {
  // Payment was cancelled by the user
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

  // Failure callback
  failureCallBackVersion: FailureCallBackVersion.V2,  // Sets the failure callback version

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
| `failureCallBackVersion` | `FailureCallBackVersion?` | Both | Sets the failure callback version — `V1` or `V2` |
| `isKeyboardHandlingEnabled` | `bool?` | iOS | SDK keyboard avoidance behavior |

### `PaymobPaymentResult`

| Property | Type | Description |
|----------|------|-------------|
| `status` | `PaymentStatus` | `successful`, `failure`, `cancelled`, `pending` |
| `isSuccessful` | `bool` | `true` if payment succeeded |
| `isFailure` | `bool` | `true` if payment failed |
| `isCancelled` | `bool` | `true` if payment was cancelled by the user |
| `isPending` | `bool` | `true` if payment is pending |
| `transactionDetails` | `Map<String, dynamic>?` | Transaction data (successful payments only) |
| `errorMessage` | `String?` | Error description if status is `failure` |

---

## 🧩 Embedded View

Besides the standalone `payWithPaymob()` flow, the SDK also supports embedding the card checkout directly inside a Flutter screen using `PaymobEmbeddedCheckoutView`. This keeps the user inside your own app UI while the card entry and payment processing happen in an embedded native view.

The embedded checkout is built around three main APIs:

- **`PaymobEmbeddedCheckoutView`** - The Flutter widget that renders the embedded card checkout UI in your screen.
- **`PaymobEmbeddedViewConfig`** - Configuration object used to set up the embedded view (keys, UI customization, and behavior flags).
- **`PaymobEmbeddedCheckoutController`** - Controller used to listen for payment results, height changes, and to programmatically interact with the embedded view.

### Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:flutter_paymob_sdk/flutter_paymob_sdk.dart';

class EmbeddedCheckoutScreen extends StatefulWidget {
  const EmbeddedCheckoutScreen({super.key});

  @override
  State<EmbeddedCheckoutScreen> createState() => _EmbeddedCheckoutScreenState();
}

class _EmbeddedCheckoutScreenState extends State<EmbeddedCheckoutScreen> {
  late final PaymobEmbeddedCheckoutController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PaymobEmbeddedCheckoutController(
      onPaymentResult: (result) {
        if (result.isSuccessful) {
          // Payment succeeded
        } else if (result.isFailure) {
          // Payment failed
        } else if (result.isCancelled) {
          // Payment was cancelled by the user
        } else if (result.isPending) {
          // Payment is pending
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: PaymobEmbeddedCheckoutView(
        controller: _controller,
        config: PaymobEmbeddedViewConfig(
          publicKey: publicKey,
          clientSecret: clientSecret,
        ),
      ),
    );
  }
}
```

### `PaymobEmbeddedViewConfig`

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `publicKey` | `String?` | `null` | Your Paymob public key, returned by your backend |
| `clientSecret` | `String?` | `null` | Client secret for the payment intention, returned by your backend |
| `uiCustomization` | `PaymobEmbeddedUiCustomization?` | `null` | Optional UI customization for the embedded checkout |
| `showAddNewCard` | `bool` | `true` | Show/hide the "Add new card" option |
| `payFromOutside` | `bool` | `false` | Enable triggering the payment externally through the controller instead of an in-view button |
| `showSaveCard` | `bool` | `true` | Show/hide the save card option |
| `saveCardDefault` | `bool` | `false` | Pre-check the save card option |

`PaymobEmbeddedCheckoutView` also accepts an `initialHeight` (`double`, default `300`) — the view's height before the embedded content reports its actual height via `onHeightChanged`.

### `PaymobEmbeddedCheckoutController`

| Callback | Type | Description |
|----------|------|-------------|
| `onHeightChanged` | `ValueChanged<double>?` | Called whenever the embedded view's content height changes, so the parent layout can adjust to fit it |
| `onPaymentResult` | `ValueChanged<PaymobPaymentResult>?` | Called when the payment completes — same `PaymobPaymentResult` used by `payWithPaymob()`, covering `successful`, `failure`, `cancelled`, and `pending` |

The controller also exposes:

| Method | Description |
|--------|-------------|
| `setPaymentKeys({required publicKey, required clientSecret})` | Sets or updates the `publicKey`/`clientSecret` dynamically after the controller is created |
| `payFromOutside()` | Triggers the payment programmatically; requires `payFromOutside: true` in `PaymobEmbeddedViewConfig` |
| `dispose()` | Releases the controller's native resources — call from your widget's `dispose()` |

### External Payment Trigger

To trigger the payment from your own UI (e.g. a custom "Pay Now" button outside the embedded view) instead of the in-view button, enable `payFromOutside` in the config, then call it on the controller:

```dart
PaymobEmbeddedViewConfig(
  publicKey: publicKey,
  clientSecret: clientSecret,
  payFromOutside: true,
)
```

```dart
ElevatedButton(
  onPressed: () => _controller.payFromOutside(),
  child: const Text('Pay Now'),
)
```

### `PaymobEmbeddedUiCustomization`

All properties are optional — only pass the ones you need to override.

| Property | Type | Description |
|----------|------|-------------|
| `primaryColor` | `Color?` | Primary accent color |
| `containerColor` | `Color?` | Background color of the checkout container |
| `inputBorderColor` | `Color?` | Border color of input fields |
| `inputBackgroundColor` | `Color?` | Background color of input fields |
| `labelTextColor` | `Color?` | Text color for field labels |
| `inputTextColor` | `Color?` | Text color inside input fields |
| `placeholderColor` | `Color?` | Color of placeholder text |
| `payButtonTextColor` | `Color?` | Text color of the pay button |
| `errorColor` | `Color?` | Color used for error states/messages |
| `borderRadius` | `double?` | Corner radius applied to inputs/container |
| `containerPadding` | `double?` | Padding applied around the checkout container |
| `labelFontSize` | `double?` | Font size for field labels |
| `inputFontSize` | `double?` | Font size for input field text |
| `payButtonFontSize` | `double?` | Font size for the pay button text |
| `labelFontWeight` | `int?` | Font weight for field labels |
| `inputFontWeight` | `int?` | Font weight for input field text |
| `payButtonFontWeight` | `int?` | Font weight for the pay button text |
| `payButtonTitle` | `String?` | Custom title text for the pay button |

### Scrollable Screen Usage

Since the embedded view's height can change dynamically as its content changes, wrap it in a `SingleChildScrollView` when placing it inside a screen with other scrollable content:

```dart
SingleChildScrollView(
  child: Column(
    children: [
      // Other widgets above the checkout
      PaymobEmbeddedCheckoutView(
        controller: _controller,
        config: PaymobEmbeddedViewConfig(
          publicKey: publicKey,
          clientSecret: clientSecret,
        ),
      ),
      // Other widgets below the checkout
    ],
  ),
)
```

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
