import 'package:flutter/material.dart';
import 'package:flutter_paymob_sdk/flutter_paymob_sdk.dart';

import '../../widgets/payment_result_sheet.dart';

class PaymentScreen extends StatefulWidget {
  final String publicKey;
  final String clientSecret;

  const PaymentScreen({
    super.key,
    required this.publicKey,
    required this.clientSecret,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final PaymobEmbeddedCheckoutController _controller;
  PaymobPaymentResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _controller = PaymobEmbeddedCheckoutController(
      onPaymentResult: (result) {
        setState(() => _lastResult = result);
        PaymentResultSheet.show(context, result);
      },
      onHeightChanged: (value) {
        print('Height changed: $value');
      },
    );
  }

  Future<void> _handleSetPaymentKeys() async {
    await _controller.setPaymentKeys(
      publicKey: widget.publicKey,
      clientSecret: widget.clientSecret,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F4),
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: const Color(0xFFF1F3F4),
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            const SizedBox(height: 52),

            const SizedBox(height: 12),

            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PaymobEmbeddedCheckoutView(
                config: PaymobEmbeddedViewConfig(
                  uiCustomization: null,
                  publicKey: widget.publicKey,
                  clientSecret: widget.clientSecret,
                  payFromOutside: false,
                  showSaveCard: true,
                  saveCardDefault: true,
                  showAddNewCard: true,
                ),
                controller: _controller,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: FilledButton(
            onPressed: _handleSetPaymentKeys,
            child: const Text('Set Payment Keys'),
          ),
        ),
      ),
    );
  }
}
