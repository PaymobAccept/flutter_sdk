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
        resizeToAvoidBottomInset: false,
        body: Center(
          child: ElevatedButton(
            child: Text('Test Payment'),
            onPressed: () async {
              final service = PaymobService();

              // publicKey and clientSecret must come from your backend
              const publicKey = 'egy_pk_xxxxxxxxxxxxxxxxxxxxxx';
              const clientSecret = '<client_secret_from_your_backend>';

              final result = await service.payWithPaymob(
                publicKey: publicKey,
                clientSecret: clientSecret,
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


            },
          ),
        ),
      ),
    );
  }
}