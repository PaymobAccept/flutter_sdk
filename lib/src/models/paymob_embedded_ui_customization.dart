import 'dart:convert';

import 'package:flutter/material.dart';

class PaymobEmbeddedUiCustomization {
  final Color? primaryColor;
  final Color? containerColor;
  final Color? inputBorderColor;
  final Color? inputBackgroundColor;
  final Color? labelTextColor;
  final Color? inputTextColor;
  final Color? placeholderColor;
  final Color? payButtonTextColor;
  final Color? errorColor;
  final double? borderRadius;
  final double? containerPadding;
  final double? labelFontSize;
  final double? inputFontSize;
  final double? payButtonFontSize;
  final int? labelFontWeight;
  final int? inputFontWeight;
  final int? payButtonFontWeight;
  final String? payButtonTitle;

  const PaymobEmbeddedUiCustomization({
    this.primaryColor,
    this.containerColor,
    this.inputBorderColor,
    this.inputBackgroundColor,
    this.labelTextColor,
    this.inputTextColor,
    this.placeholderColor,
    this.payButtonTextColor,
    this.errorColor,
    this.borderRadius,
    this.containerPadding,
    this.labelFontSize,
    this.inputFontSize,
    this.payButtonFontSize,
    this.labelFontWeight,
    this.inputFontWeight,
    this.payButtonFontWeight,
    this.payButtonTitle,
  });

  String toJson() {
    final map = <String, String>{
      if (primaryColor != null) 'Color_Primary': _hex(primaryColor!),
      if (containerColor != null) 'Color_Container': _hex(containerColor!),
      if (inputBorderColor != null)
        'Color_Border_Input_Fields': _hex(inputBorderColor!),
      if (inputBackgroundColor != null)
        'Color_Input_Fields': _hex(inputBackgroundColor!),
      if (labelTextColor != null)
        'Text_Color_For_Label': _hex(labelTextColor!),
      if (inputTextColor != null)
        'Text_Color_For_Input_Fields': _hex(inputTextColor!),
      if (placeholderColor != null)
        'Color_For_Text_Placeholder': _hex(placeholderColor!),
      if (payButtonTextColor != null)
        'Text_Color_For_Payment_Button': _hex(payButtonTextColor!),
      if (errorColor != null) 'Color_Error': _hex(errorColor!),
      if (borderRadius != null)
        'Radius_Border': _num(borderRadius!),
      if (containerPadding != null)
        'Container_Padding': _num(containerPadding!),
      if (labelFontSize != null) 'Font_Size_Label': _num(labelFontSize!),
      if (inputFontSize != null)
        'Font_Size_Input_Fields': _num(inputFontSize!),
      if (payButtonFontSize != null)
        'Font_Size_Payment_Button': _num(payButtonFontSize!),
      if (labelFontWeight != null)
        'Font_Weight_Label': labelFontWeight.toString(),
      if (inputFontWeight != null)
        'Font_Weight_Input_Fields': inputFontWeight.toString(),
      if (payButtonFontWeight != null)
        'Font_Weight_Payment_Button': payButtonFontWeight.toString(),
      if (payButtonTitle != null) 'Payment_Button_Title': payButtonTitle!,
    };
    return jsonEncode(map);
  }

  static String _hex(Color color) {
    final value = color.toARGB32();
    return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static String _num(double value) =>
      value == value.truncateToDouble() ? value.toInt().toString() : value.toString();
}
