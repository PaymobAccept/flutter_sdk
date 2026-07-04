import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/paymob_embedded_ui_customization.dart';
import 'models/paymob_payment_result.dart';

const String viewType = 'paymob_checkout_view';

class PaymobEmbeddedViewConfig {
  final String? publicKey;
  final String? clientSecret;
  final PaymobEmbeddedUiCustomization? uiCustomization;
  final bool showAddNewCard;
  final bool payFromOutside;
  final bool showSaveCard;
  final bool saveCardDefault;

  const PaymobEmbeddedViewConfig({
    this.publicKey,
    this.clientSecret,
    this.uiCustomization,
    this.showAddNewCard = true,
    this.payFromOutside = false,
    this.showSaveCard = true,
    this.saveCardDefault = false,
  });

  Map<String, dynamic> nativeParams() {
    return <String, dynamic>{
      'showAddNewCard': showAddNewCard,
      'payFromOutside': payFromOutside,
      'showSaveCard': showSaveCard,
      'saveCardDefault': saveCardDefault,
      if (publicKey != null) 'publicKey': publicKey!,
      if (clientSecret != null) 'clientSecret': clientSecret!,
      if (uiCustomization != null) 'uiCustomization': uiCustomization!.toJson(),
    };
  }
}

class PaymobEmbeddedCheckoutController {
  ValueChanged<double>? onHeightChanged;
  ValueChanged<PaymobPaymentResult>? onPaymentResult;

  PaymobEmbeddedCheckoutController({
    this.onHeightChanged,
    this.onPaymentResult,
  });

  MethodChannel? _methodChannel;
  StreamSubscription<dynamic>? _eventSub;

  ValueChanged<double>? _onKeyboardShow;
  VoidCallback? _onKeyboardHide;

  void _attach(int viewId) {
    final baseName = '$viewType/$viewId';
    _methodChannel = MethodChannel(baseName);
    _eventSub = EventChannel('$baseName/events')
        .receiveBroadcastStream()
        .listen(_handleEvent, onError: _handleError);
  }

  void _detach() {
    _eventSub?.cancel();
    _eventSub = null;
    _methodChannel = null;
    _onKeyboardShow = null;
    _onKeyboardHide = null;
  }

  void _handleEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'] as String?;
    switch (type) {
      case 'heightChanged':
        final raw = event['height'];
        final height = raw is num ? raw.toDouble() : null;
        if (height != null) onHeightChanged?.call(height);

      case 'transactionAccepted':
        final raw = event['transactionDetails'];
        final details = raw is Map ? raw.cast<String, dynamic>() : null;
        onPaymentResult?.call(PaymobPaymentResult(
          status: PaymentStatus.successful,
          transactionDetails: details,
        ));

      case 'transactionRejected':
        final message = event['message'] as String?;
        onPaymentResult?.call(PaymobPaymentResult(
          status: PaymentStatus.failure,
          errorMessage: message,
        ));

      case 'transactionPending':
        onPaymentResult?.call(PaymobPaymentResult(
          status: PaymentStatus.pending,
        ));

      case 'keyboardWillShow':
        final raw = event['keyboardHeight'];
        final height = raw is num ? raw.toDouble() : 0.0;
        debugPrint('[Paymob] keyboardWillShow height=$height  _onKeyboardShow=${_onKeyboardShow != null}');
        _onKeyboardShow?.call(height);

      case 'keyboardWillHide':
        debugPrint('[Paymob] keyboardWillHide');
        _onKeyboardHide?.call();
    }
  }

  void _handleError(Object error) {
    debugPrint('[PaymobEmbeddedCheckout] event channel error: $error');
  }

  Future<void> setPaymentKeys({
    required String publicKey,
    required String clientSecret,
  }) async {
    await _methodChannel?.invokeMethod<void>('setPaymentKeys', {
      'publicKey': publicKey,
      'clientSecret': clientSecret,
    });
  }

  Future<void> payFromOutside() async {
    await _methodChannel?.invokeMethod<void>('payFromOutside');
  }

  void dispose() => _detach();
}

class PaymobEmbeddedCheckoutView extends StatefulWidget {
  final PaymobEmbeddedViewConfig config;
  final PaymobEmbeddedCheckoutController controller;
  final double initialHeight;

  const PaymobEmbeddedCheckoutView({
    super.key,
    required this.config,
    required this.controller,
    this.initialHeight = 300,
  });

  @override
  State<PaymobEmbeddedCheckoutView> createState() =>
      _PaymobEmbeddedCheckoutViewState();
}

class _PaymobEmbeddedCheckoutViewState
    extends State<PaymobEmbeddedCheckoutView> {
  late double _height;
  double _keyboardSpacer = 0;
  bool _sdkReady = false;

  @override
  void initState() {
    super.initState();
    _height = widget.initialHeight;

    final userOnHeightChanged = widget.controller.onHeightChanged;
    widget.controller.onHeightChanged = (h) {
      if (mounted) setState(() { _height = h; _sdkReady = true; });
      userOnHeightChanged?.call(h);
    };

    final userOnPaymentResult = widget.controller.onPaymentResult;
    widget.controller.onPaymentResult = (result) {
      widget.controller._onKeyboardShow = null;
      widget.controller._onKeyboardHide = null;
      if (mounted) setState(() => _keyboardSpacer = 0);
      userOnPaymentResult?.call(result);
    };

    widget.controller._onKeyboardShow = _scrollIntoView;

    widget.controller._onKeyboardHide = () {
      if (mounted) setState(() => _keyboardSpacer = 0);
    };
  }

  @override
  void dispose() {
    widget.controller._onKeyboardShow = null;
    widget.controller._onKeyboardHide = null;
    widget.controller._detach();
    super.dispose();
  }

  void _scrollIntoView(double keyboardHeight) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;

      final widgetBottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      final screenHeight = MediaQuery.sizeOf(context).height;
      final visibleBottom = screenHeight - keyboardHeight - 24;

      if (widgetBottom <= visibleBottom) return;

      final scrollable = Scrollable.maybeOf(context);
      if (scrollable == null) return;

      final scrollBy = widgetBottom - visibleBottom;
      final deficit = scrollBy - scrollable.position.maxScrollExtent;

      if (deficit > 0 && defaultTargetPlatform == TargetPlatform.android) {
        setState(() => _keyboardSpacer = deficit);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          scrollable.position.animateTo(
            scrollable.position.pixels + scrollBy,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      } else {
        scrollable.position.animateTo(
          scrollable.position.pixels + scrollBy,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildPlatformView(),
              if (!_sdkReady) _buildLoadingPlaceholder(),
            ],
          ),
        ),
        SizedBox(height: _keyboardSpacer),
      ],
    );
  }

  Widget _buildLoadingPlaceholder() {
    final bg = widget.config.uiCustomization?.containerColor ?? const Color(0xFFFFFFFF);
    final accent = widget.config.uiCustomization?.primaryColor ?? const Color(0xFF6750A4);
    return Container(
      color: bg,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(accent),
        ),
      ),
    );
  }

  Widget _buildPlatformView() {
    final params = widget.config.nativeParams();

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: widget.controller._attach,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        );

      case TargetPlatform.android:
        return AndroidView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: widget.controller._attach,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        );

      default:
        return const Center(
          child: Text('PaymobEmbeddedCheckoutView is not supported on this platform.'),
        );
    }
  }
}
