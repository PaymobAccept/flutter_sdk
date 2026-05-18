# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-05-18

### Added
- Initial release of `flutter_paymob_sdk`
- Native Android SDK integration (Paymob Android SDK 1.8.1) — bundled directly inside the plugin, no download required
- Native iOS SDK integration (PaymobSDK xcframework) — bundled directly inside `ios/Frameworks/`, no download on `pod install`
- Payment intention API support for creating secure payment sessions
- Customizable payment UI options:
  - Custom app name display
  - Customizable button background color
  - Customizable button text color
  - Save card functionality (optional)
  - Show/hide save card option
- Type-safe payment result handling with `PaymobPaymentResult`
- Comprehensive error handling and logging
- Support for Android (API 23+) and iOS (13.0+)
- Full null-safety implementation
- Example app demonstrating usage
- `PaymobService` class for all payment operations
- `createPaymentIntention()` method for server-side payment setup
- `payWithPaymob()` method for launching native payment SDK
- `PaymobPaymentResult` model for handling payment outcomes
- `PaymobCustomization` model for UI customization
