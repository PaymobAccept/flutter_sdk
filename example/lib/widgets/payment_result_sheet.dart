import 'package:flutter/material.dart';
import 'package:flutter_paymob_sdk/flutter_paymob_sdk.dart';

class PaymentResultSheet extends StatelessWidget {
  final PaymobPaymentResult result;

  const PaymentResultSheet({super.key, required this.result});

  static void show(BuildContext context, PaymobPaymentResult result) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PaymentResultSheet(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (result.status) {
      PaymentStatus.successful => (Icons.check_circle, 'Payment Accepted!', Colors.green),
      PaymentStatus.failure   => (Icons.cancel,        'Payment Rejected',  Colors.red),
      PaymentStatus.cancelled => (Icons.cancel,        'Payment Cancelled', Colors.grey),
      PaymentStatus.pending    => (Icons.hourglass_top, 'Payment Pending',   Colors.orange),
    };

    return SizedBox(width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 56),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
            if (result.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                result.errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (result.transactionDetails != null) ...[
              const SizedBox(height: 8),
              Text(
                'Txn: ${result.transactionDetails!['id'] ?? '—'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
