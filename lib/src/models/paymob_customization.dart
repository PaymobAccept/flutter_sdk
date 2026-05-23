import 'package:flutter/material.dart';

/// Customization options for the Paymob payment SDK UI
class PaymobCustomization {
  /// Custom app name to display in the payment screen
  final String? appName;

  /// Android drawable or mipmap resource name e.g. "ic_logo".
  final String? androidAppLogo;

  /// iOS asset catalog image name e.g. "AppLogo".
  final String? iosAppLogo;

  /// Background color for the payment button
  final Color? buttonBackgroundColor;

  /// Text color for the payment button
  final Color? buttonTextColor;

  /// Whether to save the card by default
  final bool? saveCardDefault;

  /// Whether to show the "save card" option
  final bool? showSaveCard;

  /// Whether to show the transaction result screen after payment
  final bool? showTransactionResult;

  /// Whether the SDK handles keyboard avoidance behavior
  final bool? isKeyboardHandlingEnabled;

  const PaymobCustomization({
    this.appName,
    this.androidAppLogo,
    this.iosAppLogo,
    this.buttonBackgroundColor,
    this.buttonTextColor,
    this.saveCardDefault,
    this.showSaveCard,
    this.showTransactionResult,
    this.isKeyboardHandlingEnabled,
  });

  /// Converts the customization to a map for platform channel communication
  Map<String, dynamic> toMap() {
    return {
      if (appName != null) 'appName': appName,
      if (androidAppLogo != null) 'androidAppLogo': androidAppLogo,
      if (iosAppLogo != null) 'iosAppLogo': iosAppLogo,
      if (buttonBackgroundColor != null)
        'buttonBackgroundColor': buttonBackgroundColor!.toARGB32(),
      if (buttonTextColor != null) 'buttonTextColor': buttonTextColor!.toARGB32(),
      if (saveCardDefault != null) 'saveCardDefault': saveCardDefault,
      if (showSaveCard != null) 'showSaveCard': showSaveCard,
      if (showTransactionResult != null) 'showTransactionResult': showTransactionResult,
      if (isKeyboardHandlingEnabled != null) 'isKeyboardHandlingEnabled': isKeyboardHandlingEnabled,
    };
  }
}
