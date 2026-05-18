/// Represents the result of a Paymob payment transaction
class PaymobPaymentResult {
  final PaymentStatus status;
  final Map<String, dynamic>? transactionDetails;
  final String? errorMessage;

  PaymobPaymentResult({
    required this.status,
    this.transactionDetails,
    this.errorMessage,
  });

  /// Returns true if the payment was successful
  bool get isSuccessful => status == PaymentStatus.successful;

  /// Returns true if the payment was rejected
  bool get isRejected => status == PaymentStatus.rejected;

  /// Returns true if the payment is pending
  bool get isPending => status == PaymentStatus.pending;

  @override
  String toString() {
    return 'PaymobPaymentResult(status: $status, details: $transactionDetails, error: $errorMessage)';
  }
}

/// Enum representing possible payment statuses
enum PaymentStatus {
  successful,
  rejected,
  pending,
  unknown,
}
