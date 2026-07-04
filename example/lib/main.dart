import 'package:example/model/product.dart';
import 'package:example/widgets/payment_result_sheet.dart';
import 'package:example/widgets/payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_paymob_sdk/flutter_paymob_sdk.dart';
import 'package:talker/talker.dart';

void main() => runApp(const MyApp());

final _talker = Talker();

// publicKey and clientSecret must come from your backend
const _publicKey = 'egy_pk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
const _clientSecret = 'egy_csk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';

final _demoProduct = Product(
  name: 'iPhone',
  subtitle: '256 GB · Natural Titanium',
  description:
      'A17 Pro chip · 48 MP camera system · USB‑C with USB 3 · All-day battery',
  price: 'EGP 29,999',
  priceCents: 2999900,
  icon: Icons.phone_iphone,
  color: const Color(0xFF1A73E8),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomeScreen());
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = false;

  Future<void> _startNativePayment() async {
    setState(() => _loading = true);

    final service = PaymobService();
    final result = await service.payWithPaymob(
      publicKey: _publicKey,
      clientSecret: _clientSecret,
      customization: PaymobCustomization(
        appName: 'My Flutter App',
        androidAppLogo: 'ic_launcher',
        iosAppLogo: 'assets/logo.png',
        buttonBackgroundColor: Colors.blue,
        buttonTextColor: Colors.white,
        saveCardDefault: true,
        showSaveCard: true,
      ),
    );
    _talker.info(
      'Payment Status: ${result.status}, '
      'Error: ${result.errorMessage}, '
      'Details: ${result.transactionDetails}',
    );

    if (!mounted) return;
    setState(() => _loading = false);
    PaymentResultSheet.show(context, result);
  }

  void _startEmbeddedPayment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          product: _demoProduct,
          publicKey: _publicKey,
          clientSecret: _clientSecret,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paymob Test')),
      resizeToAvoidBottomInset: false,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: _loading ? null : _startNativePayment,
                child: const Text('Native Sheet'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _startEmbeddedPayment,
                child: const Text('Embedded View'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
