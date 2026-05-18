import 'package:flutter/material.dart';

/// Customization options for the Paymob payment SDK UI
class PaymobCustomization {
  /// Custom app name to display in the payment screen
  final String? appName;

  /// Background color for the payment button
  final Color? buttonBackgroundColor;

  /// Text color for the payment button
  final Color? buttonTextColor;

  /// Whether to save the card by default
  final bool? saveCardDefault;

  /// Whether to show the "save card" option
  final bool? showSaveCard;

  const PaymobCustomization({
    this.appName,
    this.buttonBackgroundColor,
    this.buttonTextColor,
    this.saveCardDefault,
    this.showSaveCard,
  });

  /// Converts the customization to a map for platform channel communication
  Map<String, dynamic> toMap() {
    return {
      if (appName != null) 'appName': appName,
      if (buttonBackgroundColor != null)
        'buttonBackgroundColor': buttonBackgroundColor!.toARGB32(),
      if (buttonTextColor != null) 'buttonTextColor': buttonTextColor!.toARGB32(),
      if (saveCardDefault != null) 'saveCardDefault': saveCardDefault,
      if (showSaveCard != null) 'showSaveCard': showSaveCard,
    };
  }
}
