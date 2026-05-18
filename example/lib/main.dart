import 'package:flutter/material.dart';
import 'package:flutter_paymob_sdk/flutter_paymob_sdk.dart';
import 'package:talker/talker.dart';

void main() => runApp(const MyApp());

final _talker = Talker();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Paymob Test')),
        body: Center(
          child: ElevatedButton(
            child: Text('Test Payment'),
            onPressed: () async {
              final service = PaymobService();

              final creds = await service.createPaymentIntention(
                useSecureMode: false,
                secretKey: 'xxxxxxxxxxxxxxx',
                publicKey: 'xxxxxxxxxxxxxxx',
                amount: 100,
                currency: 'EGP',
                integrationId: 123456,
                billingData: {
                  'first_name': 'Test',
                  'last_name': 'User',
                  'email': 'test@test.com',
                  'phone_number': '+201000000000',
                  'apartment': 'NA',
                  'floor': 'NA',
                  'street': 'NA',
                  'building': 'NA',
                  'shipping_method': 'NA',
                  'postal_code': 'NA',
                  'city': 'Cairo',
                  'country': 'EG',
                  'state': 'NA',
                },
              );
              final result = await service.payWithPaymob(
                publicKey: creds['publicKey']!,
                clientSecret: creds['clientSecret']!,
                customization: PaymobCustomization(
                  appName: 'My Flutter App',
                  buttonBackgroundColor: Colors.blue,
                  buttonTextColor: Colors.white,
                  saveCardDefault: true,
                  showSaveCard: true,
                ),
              );
              _talker.info('Payment result: ${result.status}');


            },
          ),
        ),
      ),
    );
  }
}