import 'package:flutter/material.dart';
import 'package:flutter_paymob_sdk/flutter_paymob_sdk.dart';

import '../../model/product.dart';
import '../../widgets/payment_result_sheet.dart';

class PaymentScreen extends StatefulWidget {
  final Product product;
  final String publicKey;
  final String clientSecret;

  const PaymentScreen({
    super.key,
    required this.product,
    required this.publicKey,
    required this.clientSecret,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final PaymobEmbeddedCheckoutController _controller;
  PaymobPaymentResult? _lastResult;


  PaymobEmbeddedUiCustomization get _uiCustomization =>
      PaymobEmbeddedUiCustomization(
        primaryColor: widget.product.color,
        containerColor: const Color(0xFFFFFFFF),
        inputBorderColor: const Color(0xFFDADCE0),
        inputBackgroundColor: const Color(0xFFF8F9FA),
        labelTextColor: const Color(0xFF5F6368),
        inputTextColor: const Color(0xFF202124),
        placeholderColor: const Color(0xFF9AA0A6),
        payButtonTextColor: const Color(0xFFFFFFFF),
        errorColor: const Color(0xFFD93025),
        borderRadius: 10,
        containerPadding: 16,
        labelFontSize: 12,
        inputFontSize: 15,
        payButtonFontSize: 16,
        labelFontWeight: 500,
        inputFontWeight: 400,
        payButtonFontWeight: 600,
        payButtonTitle: 'Pay ${widget.product.price}',
      );

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
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
            // Card(
            //   color: Colors.white,
            //   clipBehavior: Clip.antiAlias,
            //   child: Row(
            //     children: [
            //       Container(
            //         width: 88,
            //         height: 88,
            //         color: product.color.withAlpha(255 * 0.08.toInt()),
            //         child: Icon(product.icon, size: 44, color: product.color),
            //       ),
            //       const SizedBox(width: 12),
            //       Expanded(
            //         child: Padding(
            //           padding: const EdgeInsets.symmetric(
            //             vertical: 12,
            //             horizontal: 4,
            //           ),
            //           child: Column(
            //             crossAxisAlignment: CrossAxisAlignment.start,
            //             children: [
            //               Text(
            //                 product.name,
            //                 style: theme.textTheme.titleSmall?.copyWith(
            //                   fontWeight: FontWeight.bold,
            //                 ),
            //               ),
            //               const SizedBox(height: 3),
            //               Text(
            //                 product.subtitle,
            //                 style: theme.textTheme.bodySmall?.copyWith(
            //                   color: Colors.grey[600],
            //                 ),
            //               ),
            //               const SizedBox(height: 3),
            //               Text(
            //                 product.description,
            //                 maxLines: 2,
            //                 overflow: TextOverflow.ellipsis,
            //                 style: theme.textTheme.bodySmall?.copyWith(
            //                   color: Colors.grey[500],
            //                 ),
            //               ),
            //             ],
            //           ),
            //         ),
            //       ),
            //       Padding(
            //         padding: const EdgeInsets.all(12),
            //         child: Text(
            //           product.price,
            //           style: theme.textTheme.titleSmall?.copyWith(
            //             fontWeight: FontWeight.bold,
            //             color: product.color,
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),

            const SizedBox(height: 52),

            // Card(
            //   color: Colors.white,
            //   child: Padding(
            //     padding: const EdgeInsets.all(16),
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         Text(
            //           'Order Summary',
            //           style: theme.textTheme.labelLarge?.copyWith(
            //             color: Colors.grey[600],
            //           ),
            //         ),
            //         const SizedBox(height: 8),
            //         SummaryRow(
            //           label: product.name,
            //           value: 'EGP ${_itemPrice.toStringAsFixed(2)}',
            //         ),
            //         SummaryRow(
            //           label: 'Shipping',
            //           value: 'Free',
            //           valueColor: Colors.green[700],
            //         ),
            //         SummaryRow(
            //           label: 'VAT (14%)',
            //           value: 'EGP ${_vat.toStringAsFixed(2)}',
            //         ),
            //         const Divider(height: 20),
            //         SummaryRow(
            //           label: 'Total',
            //           value: 'EGP ${_total.toStringAsFixed(2)}',
            //           bold: true,
            //         ),
            //       ],
            //     ),
            //   ),
            // ),

            const SizedBox(height: 12),

            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PaymobEmbeddedCheckoutView(
                config: PaymobEmbeddedViewConfig(
                  uiCustomization: _uiCustomization,
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
    );
  }
}
