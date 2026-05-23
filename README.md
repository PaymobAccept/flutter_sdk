# Paymob Flutter SDK

A comprehensive Flutter plugin for integrating Paymob payment gateway with native Android and iOS SDK support. Accept payments seamlessly and securely in your Flutter applications with full customization support.

## ✨ Features

- 🚀 **Easy Integration** - Simple API with minimal setup required
- 📱 **Native SDKs** - Uses official Paymob Android and iOS SDKs under the hood
- 🎨 **Customizable UI** - Customize button colors, app name, app logo, and more
- 💳 **Save Card Feature** - Optional card saving functionality
- 🔒 **Secure Payments** - Industry-standard security with PCI compliance
- ✅ **Type-Safe Results** - Strongly typed payment result handling
- 🌍 **Multi-Currency** - Support for multiple currencies (EGP, USD, etc.)
- 📊 **Comprehensive Error Handling** - Clear error messages and states
- 🔄 **Null Safety** - Fully migrated to null-safe Dart
- 🛡️ **Backend-First Security** - Secret key stays on your server; the SDK never touches it

## 🚀 Installation

### 1. Add the dependency

```yaml
dependencies:
  flutter_paymob_sdk:
    git:
      url: https://github.com/PaymobAccept/flutter_sdk.git
```

Then run:

```
flutter pub get
```

### 2. Android — configure Gradle repositories

In `android/settings.gradle.kts`, add the following inside the `dependencyResolutionManagement` block:

```kotlin
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        maven { url = uri("https://jitpack.io") }

        val flutterPluginsDeps = file("../.flutter-plugins-dependencies")
        if (flutterPluginsDeps.exists()) {
            @Suppress("UNCHECKED_CAST")
            val json = groovy.json.JsonSlurper().parse(flutterPluginsDeps) as Map<String, Any>
            @Suppress("UNCHECKED_CAST")
            val androidPlugins = ((json["plugins"] as? Map<String, Any>)?.get("android")
                as? List<Map<String, Any>>) ?: emptyList()
            androidPlugins.find { it["name"] == "flutter_paymob_sdk" }
                ?.get("path")
                ?.let { maven { url = uri("${it}android/libs") } }
        }
    }
}
```

### 3. Android — enable Data Binding

In `android/app/build.gradle.kts`, inside the `android {}` block:

```kotlin
android {
    buildFeatures {
        dataBinding = true
    }
}
```

### 4. iOS — nothing extra

`pod install` picks up the bundled `PaymobSDK.xcframework` automatically.

---

## 📖 Documentation

For full usage examples, API reference, and troubleshooting, see the **[Example & API Docs](example.md)**.

## 🎯 Supported Platforms

| Platform | Minimum Version | Status |
|----------|----------------|--------|
| Android  | API 23 (6.0)   | ✅ Supported |
| iOS      | 13.0           | ✅ Supported |

## 🔐 Getting Your Paymob Credentials

1. **Sign up** at Paymob Dashboard
2. **Get your API keys**:
   - Public Key: `egy_pk_test_...`
   - Secret Key: `egy_sk_test_...`
3. **Get Integration ID**:
   - Go to Settings → Payment Integrations
   - Copy your integration ID

Your backend calls the Paymob intention API with the secret key and returns only the `publicKey` and `clientSecret` to the Flutter app.

### Test Mode

- No real money is charged in test mode
- For testing, use test credentials:

| Type   | Number / PIN        | Expiry | CVV | OTP    |
| ------ | ------------------- | ------ | --- | ------ |
| Card   | 5123 4567 8901 2346 | 12/30  | 123 | -      |
| Wallet | 01010101010         | -      | -   | 123456 |


### Production Mode

1. Switch to live API keys
2. Use live integration IDs
3. Complete Paymob verification process

## 🌍 Supported Currencies

The plugin supports multiple currencies including:
- EGP (Egyptian Pound)
- USD (US Dollar)
- SAR (Saudi Riyal)
- AED (UAE Dirham)
- And more...

Refer back to Paymob documentation for the complete list.

## 📱 Platform-Specific Notes

### Android
- Bundles Paymob Android SDK **1.8.1** inside the plugin
- Supports Android 6.0 (API 23) and above
- Works with AndroidX

Add the following inside `dependencyResolutionManagement.repositories` in your `android/settings.gradle.kts`:

```kotlin
maven { url = uri("https://jitpack.io") }

val flutterPluginsDeps = file("../.flutter-plugins-dependencies")
if (flutterPluginsDeps.exists()) {
    @Suppress("UNCHECKED_CAST")
    val json = groovy.json.JsonSlurper().parse(flutterPluginsDeps) as Map<String, Any>
    @Suppress("UNCHECKED_CAST")
    val androidPlugins = ((json["plugins"] as? Map<String, Any>)?.get("android")
        as? List<Map<String, Any>>) ?: emptyList()
    androidPlugins.find { it["name"] == "flutter_paymob_sdk" }
        ?.get("path")
        ?.let { maven { url = uri("${it}android/libs") } }
}
```

### iOS
- Bundles **PaymobSDK.xcframework** inside `ios/Frameworks/`
- Supports iOS 13.0 and above
- Requires Swift 5.0+

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📞 Support

- **Documentation**: [Paymob Developers](https://developers.paymob.com/)
- **Email**: support@paymob.com

## 🙏 Acknowledgments

- The Flutter team for the amazing framework
- All contributors who help improve this package

## 📈 Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes.

**Star ⭐ this repo if you find it useful!**
