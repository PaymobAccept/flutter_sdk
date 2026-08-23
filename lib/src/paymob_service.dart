import 'package:flutter/services.dart';
import 'models/paymob_payment_result.dart';
import 'models/paymob_customization.dart';

/// Main service class for integrating Paymob payment SDK
class PaymobService {
  static const MethodChannel _methodChannel =
  MethodChannel('paymob_sdk_flutter');

  /// Initiates a payment using the Paymob SDK
  ///
  /// Parameters:
  /// - [publicKey]: Your Paymob public key
  /// - [clientSecret]: The client secret obtained from payment intention API
  /// - [customization]: Optional UI customization settings
  ///
  /// Returns a [PaymobPaymentResult] with the transaction status
  Future<PaymobPaymentResult> payWithPaymob({
    required String publicKey,
    required String clientSecret,
    PaymobCustomization? customization,
  }) async {
    try {
      final Map<String, dynamic> arguments = {
        'publicKey': publicKey,
        'clientSecret': clientSecret,
        ...?customization?.toMap(),
      };

      final dynamic result =
      await _methodChannel.invokeMethod('payWithPaymob', arguments);

      return _parsePaymentResult(result);
    } on PlatformException catch (e) {
      return PaymobPaymentResult(
        status: PaymentStatus.failure,
        errorMessage: e.message ?? 'platform error',
      );
    } catch (e) {
      return PaymobPaymentResult(
        status: PaymentStatus.failure,
        errorMessage: e.toString(),
      );
    }
  }

  /// Parses the native platform result into a [PaymobPaymentResult]
  PaymobPaymentResult _parsePaymentResult(dynamic result) {
    if (result is Map) {
      final status = result['status']?.toString().toLowerCase() ?? '';

      switch (status) {
        case 'successful':
          return PaymobPaymentResult(
            status: PaymentStatus.successful,
            transactionDetails: (result['details'] as Map?)?.cast<String, dynamic>(),
          );
        case 'failure':
          return PaymobPaymentResult(
            status: PaymentStatus.failure,
            errorMessage: result['errorMessage']?.toString(),
          );
        case 'cancelled':
          return PaymobPaymentResult(
            status: PaymentStatus.cancelled,
          );
        case 'pending':
          return PaymobPaymentResult(
            status: PaymentStatus.pending,
          );
        default:
          return PaymobPaymentResult(
            status: PaymentStatus.failure,
          );
      }
    }

    // Handle string result (legacy format)
    if (result is String) {
      final resultLower = result.toLowerCase();
      if (resultLower.contains('successful')) {
        return PaymobPaymentResult(status: PaymentStatus.successful);
      } else if (resultLower.contains('failure')) {
        return PaymobPaymentResult(status: PaymentStatus.failure);
      } else if (resultLower.contains('cancelled')) {
        return PaymobPaymentResult(status: PaymentStatus.cancelled);
      } else if (resultLower.contains('pending')) {
        return PaymobPaymentResult(status: PaymentStatus.pending);
      }
    }

    return PaymobPaymentResult(
      status: PaymentStatus.failure,
      errorMessage: 'Unexpected result format: $result',
    );
  }
}