# Embedded View Migration — Claude Code Instructions

This file is an instruction set for Claude Code. When you read this file, execute every step
below exactly as written. Do not summarize or ask for confirmation — just do it.

The embedded card-checkout feature is being migrated from the source SDK at:
`/Users/moataz/Desktop/desktop/flutter_paymob_sdk_local`

into this new project (wherever you are running from).

Every file below is given **in full** — copy it verbatim (only substituting the package
placeholders called out in each step). Do not try to diff/merge against whatever already exists
at that path; overwrite the whole file. This SDK fork has no embedded-view-specific customizations
worth preserving, so a full overwrite is safe and is what avoids the partial-merge mistakes that
caused the previous migration attempt to fail.

---

## Step 0 — Pre-flight check: does the vendored PaymobSDK.xcframework actually support the embedded view?

**This is almost certainly why the previous migration crashed on iOS.** The embedded view depends
on a Swift class called `PaymobCheckoutView` inside `PaymobSDK.xcframework`
(`ios/Frameworks/PaymobSDK.xcframework` in this repo). If the target project's copy of that
xcframework predates the embedded-view feature, one of two things happens:

- The build fails outright (missing symbol / no member `configure` on `PaymobCheckoutView`), or
- It happens to compile against a stale/mismatched interface and then **crashes at launch** with
  something like `dyld: Symbol not found: _$s9PaymobSDK...17PaymobCheckoutViewC...` — a linker-level
  crash that only shows up at runtime, not at compile time.

Before touching any Dart/Kotlin/Swift files, run this in the **target project**:

```bash
grep -rl "class PaymobCheckoutView" ios/Frameworks/PaymobSDK.xcframework 2>/dev/null \
  || find / -path "*/PaymobSDK.xcframework" -prune 2>/dev/null
```

Then confirm the class actually exposes the `configure(...)`, `setPaymentKeys(...)`, and
`payFromOutside()` API used in Step 6 below:

```bash
grep -A3 "class PaymobCheckoutView " ios/Frameworks/PaymobSDK.xcframework/ios-arm64/PaymobSDK.framework/Modules/PaymobSDK.swiftmodule/arm64-apple-ios.swiftinterface
grep -n "func configure\|func setPaymentKeys\|func payFromOutside" ios/Frameworks/PaymobSDK.xcframework/ios-arm64/PaymobSDK.framework/Modules/PaymobSDK.swiftmodule/arm64-apple-ios.swiftinterface
```

If `PaymobCheckoutView` is missing entirely, or its `configure` signature doesn't match what
`PaymobCheckoutViewNative.swift` (Step 6) calls, **stop and copy the whole
`ios/Frameworks/PaymobSDK.xcframework` directory from this source repo into the target project's
`ios/Frameworks/` folder**, replacing the old one, before proceeding. Do the same check for the
Android side against `com.paymob.paymob_sdk:paymob_sdk` — confirm the dependency version in
`android/build.gradle` matches the one this repo uses, and bump it if not.

Also diff the two podspecs — the target project's `ios/*.podspec` must have these exact settings
(they're what make `vendored_frameworks` resolve correctly):

```ruby
s.vendored_frameworks = 'Frameworks/PaymobSDK.xcframework'
s.dependency 'Flutter'
s.platform = :ios, '13.0'
s.pod_target_xcconfig = {
  'DEFINES_MODULE' => 'YES',
  'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  'FRAMEWORK_SEARCH_PATHS' => '$(PODS_XCFRAMEWORKS_BUILD_DIR)/flutter_paymob_sdk'
}
s.swift_version = '5.0'
```

If any of these are missing from the target's podspec, add them, then in the target project's
`example/ios` (or host app's `ios`) run:

```bash
cd ios && pod deintegrate && pod install --repo-update
```

Skipping this step and only copying the Dart/Kotlin/Swift glue code is the most common reason this
migration silently fails on iOS.

---

## Step 1 — Create Dart file: `lib/src/paymob_embedded_checkout_view.dart`

Create this file with the exact content below:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:talker/talker.dart';

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
          status: PaymentStatus.rejected,
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
    Talker talker = Talker();
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
```

---

## Step 2 — Create Dart file: `lib/src/models/paymob_embedded_ui_customization.dart`

Create this file with the exact content below:

```dart
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
```

---

## Step 3 — Create Android file: `android/src/main/kotlin/<YOUR_PACKAGE>/PaymobCheckoutViewFactory.kt`

**Before writing:** read `android/src/main/kotlin/` to find the existing package directory,
then use that exact path. Replace `<YOUR_PACKAGE_LINE>` below with the package name you find
(e.g. `package com.paymob.flutter.flutter_paymob_sdk`).

Create this file:

```kotlin
<YOUR_PACKAGE_LINE>

import android.content.Context
import androidx.activity.ComponentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class PaymobCheckoutViewFactory(
    private val messenger: BinaryMessenger,
    private val activityProvider: () -> ComponentActivity?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<*, *>
        return PaymobCheckoutViewNative(context, viewId, creationParams, messenger, activityProvider)
    }
}
```

---

## Step 4 — Create Android file: `android/src/main/kotlin/<YOUR_PACKAGE>/PaymobCheckoutViewNative.kt`

Use the same package path from Step 3. Replace `<YOUR_PACKAGE_LINE>` below.

Create this file:

```kotlin
<YOUR_PACKAGE_LINE>

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.util.Log
import android.view.View
import android.view.ViewTreeObserver
import android.widget.FrameLayout
import androidx.activity.ComponentActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.paymob.paymob_sdk.ui.PaymobSdkListener
import com.paymob.paymob_sdk.ui.embedded.PaymobCheckoutView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

private const val TAG = "PaymobCheckoutView"

internal class PaymobCheckoutViewNative(
    private val context: Context,
    viewId: Int,
    private val creationParams: Map<*, *>?,
    messenger: BinaryMessenger,
    private val activityProvider: () -> ComponentActivity?,
) : PlatformView, EventChannel.StreamHandler, PaymobSdkListener {

    private val checkoutView = PaymobCheckoutView(context)

    private val rootView: FrameLayout = FrameLayout(context).apply {
        setBackgroundColor(android.graphics.Color.TRANSPARENT)
        addView(
            checkoutView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
            )
        )
    }

    private val baseName = "paymob_checkout_view/$viewId"
    private val methodChannel = MethodChannel(messenger, baseName)
    private val eventChannel = EventChannel(messenger, "$baseName/events")
    private var eventSink: EventChannel.EventSink? = null

    private var keyboardVisible = false
    private var keyboardLayoutListener: ViewTreeObserver.OnGlobalLayoutListener? = null
    private var keyboardDecorView: View? = null

    private var lastEmittedHeightDp: Double = 0.0

    init {
        configureCheckoutView()
        bindChannels()
        observeKeyboard()
        observeHeight()
    }

    override fun getView(): View = rootView

    override fun dispose() {
        keyboardLayoutListener?.let { keyboardDecorView?.viewTreeObserver?.removeOnGlobalLayoutListener(it) }
        keyboardLayoutListener = null
        keyboardDecorView = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        Log.d(TAG, "[$baseName] disposed")
    }

    private fun configureCheckoutView() {
        val activity = activityProvider()
            ?: generateSequence(context) { (it as? ContextWrapper)?.baseContext }
                .filterIsInstance<ComponentActivity>()
                .firstOrNull()
        if (activity == null) {
            Log.e(TAG, "[$baseName] ComponentActivity not available — checkout view not configured")
            return
        }

        plantViewTreeOwners(checkoutView, activity)

        val uiCustomization = creationParams?.get("uiCustomization") as? String
        val showAddNewCard  = creationParams?.get("showAddNewCard")  as? Boolean ?: true
        val payFromOutside  = creationParams?.get("payFromOutside")  as? Boolean ?: false
        val showSaveCard    = creationParams?.get("showSaveCard")    as? Boolean ?: true
        val saveCardDefault = creationParams?.get("saveCardDefault") as? Boolean ?: false

        checkoutView.configure(
            activity,
            uiCustomization,
            showAddNewCard,
            showSaveCard,
            saveCardDefault,
            payFromOutside,
            this,
        )

        val publicKey    = creationParams?.get("publicKey")    as? String
        val clientSecret = creationParams?.get("clientSecret") as? String
        if (publicKey != null && clientSecret != null) {
            checkoutView.setPaymentKeys(publicKey, clientSecret)
        }
    }

    private fun observeKeyboard() {
        rootView.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) {
                val activity = generateSequence(v.context) {
                    (it as? ContextWrapper)?.baseContext
                }.filterIsInstance<Activity>().firstOrNull()

                val decorView = activity?.window?.decorView ?: return
                keyboardDecorView = decorView

                val listener = ViewTreeObserver.OnGlobalLayoutListener {
                    val insets = ViewCompat.getRootWindowInsets(decorView) ?: return@OnGlobalLayoutListener
                    val imeVisible = insets.isVisible(WindowInsetsCompat.Type.ime())
                    val imeHeight  = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom

                    if (imeVisible && !keyboardVisible) {
                        keyboardVisible = true
                        val density = decorView.resources.displayMetrics.density
                        val keyboardHeightDp = imeHeight / density
                        emit(mapOf("type" to "keyboardWillShow", "keyboardHeight" to keyboardHeightDp))
                    } else if (!imeVisible && keyboardVisible) {
                        keyboardVisible = false
                        emit(mapOf("type" to "keyboardWillHide"))
                    }
                }
                decorView.viewTreeObserver.addOnGlobalLayoutListener(listener)
                keyboardLayoutListener = listener
            }

            override fun onViewDetachedFromWindow(v: View) {}
        })
    }

    private fun observeHeight() {
        checkoutView.viewTreeObserver.addOnGlobalLayoutListener {
            measureAndEmitHeight()
        }
    }

    private fun measureAndEmitHeight() {
        val width = rootView.width
        if (width <= 0) return
        checkoutView.measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )
        val heightPx = checkoutView.measuredHeight
        if (heightPx <= 0) return
        val density = context.resources.displayMetrics.density
        val heightDp = (heightPx / density).toDouble()
        if (Math.abs(heightDp - lastEmittedHeightDp) > 0.5) {
            lastEmittedHeightDp = heightDp
            emit(mapOf("type" to "heightChanged", "height" to heightDp))
        }
    }

    private fun bindChannels() {
        methodChannel.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "setPaymentKeys" -> {
                    val pub = call.argument<String>("publicKey")
                    val cs  = call.argument<String>("clientSecret")
                    if (pub == null || cs == null) {
                        result.error("INVALID_ARGS", "publicKey and clientSecret are required", null)
                        return@setMethodCallHandler
                    }
                    checkoutView.setPaymentKeys(pub, cs)
                    result.success(null)
                }
                "payFromOutside" -> {
                    checkoutView.payFromOutside()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        eventChannel.setStreamHandler(this)
    }

    override fun onSuccess(payResponse: HashMap<String, String?>) {
        emit(mapOf("type" to "transactionAccepted", "transactionDetails" to payResponse))
    }

    override fun onFailure(msg: String?) {
        emit(mapOf("type" to "transactionRejected", "message" to (msg ?: "")))
    }

    override fun onPending() {
        emit(mapOf("type" to "transactionPending"))
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        rootView.post { measureAndEmitHeight() }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun emit(event: Map<String, Any>) {
        val sink = eventSink ?: return
        rootView.post { sink.success(event) }
    }

    private fun plantViewTreeOwners(view: View, activity: ComponentActivity) {
        listOf(
            "androidx.lifecycle.ViewTreeLifecycleOwner"        to "androidx.lifecycle.LifecycleOwner",
            "androidx.lifecycle.ViewTreeViewModelStoreOwner"   to "androidx.lifecycle.ViewModelStoreOwner",
            "androidx.savedstate.ViewTreeSavedStateRegistryOwner" to "androidx.savedstate.SavedStateRegistryOwner",
        ).forEach { (holderCls, ownerIface) ->
            runCatching {
                Class.forName(holderCls)
                    .getMethod("set", View::class.java, Class.forName(ownerIface))
                    .invoke(null, view, activity)
            }.onFailure { Log.w(TAG, "plantViewTreeOwners: $holderCls.set failed — ${it.message}") }
        }
    }
}
```

> Note: `showAddNewCard`, `payFromOutside`, `showSaveCard`, and `saveCardDefault` are read with
> `as? Boolean ?: <default>` instead of a force-cast `as Boolean`. A force-cast throws a
> `ClassCastException` (fatal, crashes the app) the moment `creationParams` is missing a key or the
> platform channel sends a value with a slightly different shape — use the safe form.

---

## Step 5 — Create iOS file: `ios/Classes/PaymobCheckoutViewFactory.swift`

Create this file with the exact content below:

```swift
import Flutter
import UIKit

final class PaymobCheckoutViewFactory: NSObject, FlutterPlatformViewFactory {

    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        PaymobCheckoutViewNative(
            frame: frame,
            viewId: viewId,
            args: args,
            messenger: messenger
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
```

---

## Step 6 — Create iOS file: `ios/Classes/PaymobCheckoutViewNative.swift`

Create this file with the exact content below:

```swift
import Flutter
import UIKit
import PaymobSDK

final class PaymobCheckoutViewNative: NSObject, FlutterPlatformView {

    private let containerView: PaymobContainerView
    private var checkoutView: PaymobCheckoutView?

    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?

    private var lastEmittedHeight: CGFloat = 0
    private var sdkLoadingCover: UIView?

    init(
        frame: CGRect,
        viewId: Int64,
        args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        containerView = PaymobContainerView(frame: frame)
        containerView.backgroundColor = .clear
        containerView.clipsToBounds = false

        let baseName = "paymob_checkout_view/\(viewId)"
        methodChannel = FlutterMethodChannel(name: baseName, binaryMessenger: messenger)
        eventChannel  = FlutterEventChannel(name: "\(baseName)/events", binaryMessenger: messenger)

        super.init()

        buildNativeView(frame: frame, args: args)
        bindChannels()
        observeKeyboard()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        sdkLoadingCover?.removeFromSuperview()
    }

    func view() -> UIView { containerView }

    private func buildNativeView(frame: CGRect, args: Any?) {
        let cv = PaymobCheckoutView()
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.alpha = 0
        cv.delegate = self

        cv.onHeightChanged = { [weak self] newHeight in
            self?.emitHeight(newHeight)
            self?.scheduleForceLayout()
        }

        if let params = args as? [String: Any] {
            cv.configure(
                uiCustomization: params["uiCustomization"] as? String,
                showAddNewCard:  params["showAddNewCard"]  as? Bool ?? true,
                payFromOutside:  params["payFromOutside"]  as? Bool ?? false,
                showSaveCard:    params["showSaveCard"]    as? Bool ?? true,
                saveCardDefault: params["saveCardDefault"] as? Bool ?? false
            )

            if let pub = params["publicKey"] as? String,
               let cs  = params["clientSecret"] as? String {
                cv.setPaymentKeys(publicKey: pub, clientSecret: cs)
            }
        }

        containerView.addSubview(cv)

        NSLayoutConstraint.activate([
            cv.topAnchor.constraint(equalTo: containerView.topAnchor),
            cv.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])

        checkoutView = cv
        containerView.checkoutView = cv
        containerView.onHeightDetected = { [weak self] h in
            self?.emitHeight(h)
        }

        let touchGR = UILongPressGestureRecognizer(target: self, action: #selector(handleTouch(_:)))
        touchGR.minimumPressDuration = 0
        touchGR.cancelsTouchesInView = false
        touchGR.delaysTouchesEnded = false
        touchGR.delegate = self
        containerView.addGestureRecognizer(touchGR)

        scheduleWindowCover(params: args as? [String: Any])
    }

    @objc private func handleTouch(_ gr: UILongPressGestureRecognizer) {
        guard gr.state == .began else { return }
        scheduleForceLayout()
    }

    private func scheduleWindowCover(params: [String: Any]?) {
        var bgColor = UIColor.white
        if let json = params?["uiCustomization"] as? String,
           let data = json.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
           let hex  = dict["Color_Container"] {
            bgColor = UIColor(hexString: hex) ?? .white
        }

        DispatchQueue.main.async { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.addWindowCover(bgColor: bgColor)
            }
        }
    }

    private func addWindowCover(bgColor: UIColor) {
        guard sdkLoadingCover == nil else { return }

        let window: UIWindow?
        if #available(iOS 15, *) {
            window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            window = UIApplication.shared.keyWindow
        }
        guard let window else { return }

        let cardFrameInWindow = containerView.convert(containerView.bounds, to: window)
        let coverTop    = cardFrameInWindow.maxY
        let coverHeight = max(0, window.bounds.height - coverTop)
        guard coverHeight > 0 else { return }

        let cover = UIView(frame: CGRect(x: 0, y: coverTop,
                                         width: window.bounds.width,
                                         height: coverHeight))
        cover.backgroundColor = bgColor
        cover.isUserInteractionEnabled = false

        window.addSubview(cover)
        sdkLoadingCover = cover
    }

    private func removeWindowCover(animated: Bool) {
        guard let cover = sdkLoadingCover else { return }
        sdkLoadingCover = nil
        if animated {
            UIView.animate(withDuration: 0.2, animations: { cover.alpha = 0 }) { _ in
                cover.removeFromSuperview()
            }
        } else {
            cover.removeFromSuperview()
        }
    }

    private func forceLayout() {
        checkoutView?.setNeedsLayout()
        checkoutView?.layoutIfNeeded()
    }

    private func scheduleForceLayout() {
        for delay in [0.05, 0.2, 0.5, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.forceLayout()
            }
        }
    }

    private func bindChannels() {
        methodChannel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return }
            switch call.method {

            case "setPaymentKeys":
                guard
                    let args = call.arguments as? [String: Any],
                    let pub  = args["publicKey"]    as? String,
                    let cs   = args["clientSecret"] as? String
                else {
                    result(FlutterError(code: "INVALID_ARGS",
                                        message: "publicKey and clientSecret are required",
                                        details: nil))
                    return
                }
                self.checkoutView?.setPaymentKeys(publicKey: pub, clientSecret: cs)
                result(nil)

            case "payFromOutside":
                self.checkoutView?.payFromOutside()
                self.scheduleForceLayout()
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        eventChannel.setStreamHandler(self)
    }

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        emit(["type": "keyboardWillShow", "keyboardHeight": frame.height])
        scheduleForceLayout()
    }

    @objc private func keyboardWillHide() {
        emit(["type": "keyboardWillHide"])
        scheduleForceLayout()
    }

    private func emitHeight(_ height: CGFloat) {
        guard height > 0, abs(height - lastEmittedHeight) > 0.5 else { return }
        let isFirst = lastEmittedHeight == 0
        lastEmittedHeight = height
        guard eventSink != nil else { return }
        if isFirst {
            UIView.animate(withDuration: 0.2) { self.checkoutView?.alpha = 1 }
            removeWindowCover(animated: true)
        }
        emit(["type": "heightChanged", "height": height])
        scheduleForceLayout()
    }

    private func emit(_ event: [String: Any]) {
        guard let sink = eventSink else { return }
        DispatchQueue.main.async { sink(event) }
    }
}

extension PaymobCheckoutViewNative: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        if lastEmittedHeight > 0 {
            checkoutView?.alpha = 1
            removeWindowCover(animated: false)
            emit(["type": "heightChanged", "height": lastEmittedHeight])
        }
        scheduleForceLayout()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

extension PaymobCheckoutViewNative: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let v = view {
            if v is UITextField || v is UITextView { return false }
            view = v.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension PaymobCheckoutViewNative: PaymobSDKDelegate {
    func transactionAccepted(transactionDetails: [String: Any]) {
        let stringDetails = transactionDetails.mapValues { "\($0)" }
        emit(["type": "transactionAccepted", "transactionDetails": stringDetails])
    }

    func transactionRejected(message: String) {
        emit(["type": "transactionRejected", "message": message])
    }

    func transactionPending() {
        emit(["type": "transactionPending"])
    }
}

final class PaymobContainerView: UIView {
    weak var checkoutView: UIView?
    var onHeightDetected: ((CGFloat) -> Void)?
    private var lastReportedHeight: CGFloat = 0

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let cv = checkoutView else { return }
        let h = cv.bounds.height
        guard h > 0, abs(h - lastReportedHeight) >= 2 else { return }
        lastReportedHeight = h
        onHeightDetected?(h)
    }
}

private extension UIColor {
    convenience init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        guard s.count == 6 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&value) else { return nil }
        self.init(
            red:   CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8)  & 0xFF) / 255,
            blue:  CGFloat( value        & 0xFF) / 255,
            alpha: 1
        )
    }
}
```

---

## Step 7 — Replace Android file (whole file): `android/src/main/kotlin/<YOUR_PACKAGE>/PaymobFlutterSdkPlugin.kt`

**Before writing:** read the existing file and note its package line (`package ...`) and note
whether it has any project-specific customizations in `callNativeSDK`/`onMethodCall` beyond what's
below — if it does, port those customizations into this template rather than dropping them.
Otherwise, overwrite the whole file with this (substitute `<YOUR_PACKAGE_LINE>`):

```kotlin
<YOUR_PACKAGE_LINE>

import android.graphics.Color
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.paymob.paymob_sdk.PaymobSdk
import com.paymob.paymob_sdk.ui.PaymobSdkListener
import android.app.Activity
import androidx.activity.ComponentActivity

class PaymobFlutterSdkPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PaymobSdkListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pendingResult: Result? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "paymob_sdk_flutter")
        channel.setMethodCallHandler(this)

        // Register the embedded card-checkout PlatformView factory.
        // This allows `AndroidView(viewType: 'paymob_checkout_view')` on the
        // Dart side to create a native view instance.
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "paymob_checkout_view",
            PaymobCheckoutViewFactory(flutterPluginBinding.binaryMessenger) {
                activity as? ComponentActivity
            }
        )
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        if (call.method == "payWithPaymob") {
            pendingResult = result
            callNativeSDK(call)
        } else {
            result.notImplemented()
        }
    }

    private fun callNativeSDK(call: MethodCall) {
        val currentActivity = activity
        if (currentActivity == null) {
            pendingResult?.error("NO_ACTIVITY", "Activity not available", null)
            pendingResult = null
            return
        }

        val publicKey = call.argument<String>("publicKey")
        val clientSecret = call.argument<String>("clientSecret")

        if (publicKey == null || clientSecret == null) {
            pendingResult?.error("INVALID_ARGS", "publicKey and clientSecret are required", null)
            pendingResult = null
            return
        }

        var buttonBackgroundColor: Int? = null
        var buttonTextColor: Int? = null
        val appName = call.argument<String>("appName")
        val buttonBackgroundColorData = call.argument<Number>("buttonBackgroundColor")?.toInt()
        val buttonTextColorData = call.argument<Number>("buttonTextColor")?.toInt()
        val saveCardDefault = call.argument<Boolean>("saveCardDefault") ?: false
        val showSaveCard = call.argument<Boolean>("showSaveCard") ?: true

        if (buttonTextColorData != null) {
            buttonTextColor = Color.argb(
                (buttonTextColorData shr 24) and 0xFF,
                (buttonTextColorData shr 16) and 0xFF,
                (buttonTextColorData shr 8) and 0xFF,
                buttonTextColorData and 0xFF
            )
        }

        if (buttonBackgroundColorData != null) {
            buttonBackgroundColor = Color.argb(
                (buttonBackgroundColorData shr 24) and 0xFF,
                (buttonBackgroundColorData shr 16) and 0xFF,
                (buttonBackgroundColorData shr 8) and 0xFF,
                buttonBackgroundColorData and 0xFF
            )
        }

        try {
            val paymobSdk = PaymobSdk.Builder(
                context = currentActivity,
                clientSecret = clientSecret,
                publicKey = publicKey,
                paymobSdkListener = this,
            )
                .setButtonBackgroundColor(buttonBackgroundColor ?: Color.BLACK)
                .setButtonTextColor(buttonTextColor ?: Color.WHITE)
                .setAppName(appName)
                .showSaveCard(showSaveCard)
                .saveCardByDefault(saveCardDefault)
                .build()

            paymobSdk.start()
        } catch (e: Exception) {
            Log.e("PaymobFlutterSDK", "Error starting SDK", e)
            pendingResult?.error("SDK_ERROR", e.message, null)
            pendingResult = null
        }
    }

    // PaymobSDK Listener Methods
    override fun onSuccess(payResponse: HashMap<String, String?>) {
        Log.d("PaymobFlutterSDK", "Payment Success: $payResponse")
        val resultMap = mapOf(
            "status" to "Successful",
            "details" to payResponse
        )
        pendingResult?.success(resultMap)
        pendingResult = null
    }

    override fun onFailure(msg: String?) {
        Log.e("PaymobFlutterSDK", "Payment rejected: $msg")
        val resultMap = mapOf("status" to "Rejected", "message" to (msg ?: ""))
        pendingResult?.success(resultMap)
        pendingResult = null
    }

    override fun onPending() {
        Log.d("PaymobFlutterSDK", "Payment pending")
        val resultMap = mapOf("status" to "Pending")
        pendingResult?.success(resultMap)
        pendingResult = null
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ActivityAware Methods
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
```

---

## Step 8 — Replace iOS file (whole file): `ios/Classes/PaymobFlutterSdkPlugin.swift`

**Before writing:** read the existing file and note whether it has any project-specific
customizations beyond what's below — if it does, port those into this template rather than
dropping them. Otherwise, overwrite the whole file with this:

```swift
import Flutter
import UIKit
import PaymobSDK

public class PaymobFlutterSdkPlugin: NSObject, FlutterPlugin {
    private var pendingResult: FlutterResult?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "paymob_sdk_flutter", binaryMessenger: registrar.messenger())
        let instance = PaymobFlutterSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Register the embedded card-checkout PlatformView factory.
        // This allows `UiKitView(viewType: 'paymob_checkout_view')` on the
        // Dart side to create a live PaymobCheckoutView instance.
        let factory = PaymobCheckoutViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "paymob_checkout_view")
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "payWithPaymob",
           let args = call.arguments as? [String: Any] {
            self.pendingResult = result
            self.callNativeSDK(arguments: args)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func callNativeSDK(arguments: [String: Any]) {
        let paymob = PaymobSDK()
        paymob.delegate = self
        
        // MARK: Customization (Optional)
        if let appName = arguments["appName"] as? String {
            paymob.paymobSDKCustomization.appName = appName
        }
        
        if let buttonBackgroundColor = arguments["buttonBackgroundColor"] as? NSNumber {
            let colorInt = buttonBackgroundColor.intValue
            let color = UIColor(
                red: CGFloat((colorInt >> 16) & 0xFF) / 255.0,
                green: CGFloat((colorInt >> 8) & 0xFF) / 255.0,
                blue: CGFloat(colorInt & 0xFF) / 255.0,
                alpha: CGFloat((colorInt >> 24) & 0xFF) / 255.0
            )
            paymob.paymobSDKCustomization.buttonBackgroundColor = color
        }
        
        if let buttonTextColor = arguments["buttonTextColor"] as? NSNumber {
            let colorInt = buttonTextColor.intValue
            let color = UIColor(
                red: CGFloat((colorInt >> 16) & 0xFF) / 255.0,
                green: CGFloat((colorInt >> 8) & 0xFF) / 255.0,
                blue: CGFloat(colorInt & 0xFF) / 255.0,
                alpha: CGFloat((colorInt >> 24) & 0xFF) / 255.0
            )
            paymob.paymobSDKCustomization.buttonTextColor = color
        }
        
        if let saveCardDefault = arguments["saveCardDefault"] as? Bool {
            paymob.paymobSDKCustomization.saveCardDefault = saveCardDefault
        }
        
        if let showSaveCard = arguments["showSaveCard"] as? Bool {
            paymob.paymobSDKCustomization.showSaveCard = showSaveCard
        }
        
        // MARK: - Call SDK
        if let publicKey = arguments["publicKey"] as? String,
           let clientSecret = arguments["clientSecret"] as? String {
            
            guard let topVC = UIApplication.shared.topMostViewController() else {
                print("❌ Could not find a top view controller to present from.")
                self.pendingResult?(FlutterError(
                    code: "VIEW_ERROR",
                    message: "Could not find a top view controller to present from.",
                    details: nil
                ))
                self.pendingResult = nil
                return
            }
            
            do {
                try paymob.presentPayVC(
                    VC: topVC,
                    PublicKey: publicKey,
                    ClientSecret: clientSecret
                )
                print("✅ Paymob SDK presented successfully")
            } catch {
                print("❌ PaymobSDK failed to start: \(error)")
                self.pendingResult?(FlutterError(
                    code: "PAYMOB_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
                self.pendingResult = nil
            }
        } else {
            print("⚠️ Missing publicKey or clientSecret in arguments")
            self.pendingResult?(FlutterError(
                code: "INVALID_ARGS",
                message: "publicKey and clientSecret are required",
                details: nil
            ))
            self.pendingResult = nil
        }
    }
}

// MARK: - PaymobSDKDelegate
extension PaymobFlutterSdkPlugin: PaymobSDKDelegate {
    public func transactionRejected(message: String) {
        print("❌ [PaymobSDK] Transaction Rejected: \(message)")
        self.pendingResult?(["status": "Rejected", "message": message])
        self.pendingResult = nil
    }
    
    public func transactionAccepted(transactionDetails: [String: Any]) {
        print("✅ [PaymobSDK] Transaction Accepted")
        print("📦 Details: \(transactionDetails)")
        self.pendingResult?(["status": "Successful", "details": transactionDetails])
        self.pendingResult = nil
    }
    
    public func transactionPending() {
        print("⏳ [PaymobSDK] Transaction Pending")
        self.pendingResult?(["status": "Pending"])
        self.pendingResult = nil
    }
}

// Helper extension to find the top-most view controller in the app.
extension UIApplication {
    func topMostViewController() -> UIViewController? {
        let keyWindow: UIWindow?
        
        if #available(iOS 13.0, *) {
            keyWindow = self.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            keyWindow = self.keyWindow
        }
        
        var topController = keyWindow?.rootViewController
        
        while let presentedViewController = topController?.presentedViewController {
            topController = presentedViewController
        }
        
        return topController
    }
}
```

---

## Step 9 — Replace main library Dart file (whole file): `lib/<package_name>.dart`

Read the main library file first (e.g. `lib/flutter_paymob_sdk.dart` — the one with `library ...;`
at the top and the other `export` lines). Keep its existing `library` declaration and any exports
unrelated to this migration, but make sure it ends up containing at least these exports:

```dart
export 'src/models/paymob_embedded_ui_customization.dart';
export 'src/paymob_embedded_checkout_view.dart';
```

For reference, the full file in the source SDK looks like this:

```dart
library flutter_paymob_sdk;

export 'src/paymob_service.dart';
export 'src/models/paymob_payment_result.dart';
export 'src/models/paymob_customization.dart';
export 'src/models/paymob_embedded_ui_customization.dart';
export 'src/paymob_embedded_checkout_view.dart';
```

---

## Step 10 — Add `talker` dependency to `pubspec.yaml`

Read `pubspec.yaml`. If `talker` is not already in `dependencies`, add it:

```yaml
dependencies:
  talker: ^5.1.16
```

Then run: `flutter pub get`

---

## Step 11 — Rebuild native dependencies and verify

Do not skip this — this is the step that actually catches the iOS crash class described in Step 0
before it reaches a device.

```bash
# Dart/Flutter side
flutter pub get

# Android — sanity compile
cd android && ./gradlew assembleDebug -x lint && cd ..

# iOS — reinstall pods against the (possibly updated) podspec/xcframework
cd example/ios && pod deintegrate && pod install --repo-update && cd ../..

# Then do an actual clean run on a real iOS device or simulator, not just a build:
flutter clean && flutter pub get
cd example/ios && pod install && cd ../..
flutter run -d <ios-device-id>
```

If it still crashes on iOS at launch, capture the exact crash log (`flutter run` console output or
Xcode's device console) and check for `dyld: Symbol not found` or `Fatal error: Unexpectedly found
nil` — the former means Step 0 wasn't actually resolved (xcframework still stale), the latter means
a force-unwrap in native code is hitting a nil that a real device/version delivers but the simulator
didn't.

---

## Done

All 11 steps complete. The embedded view is now fully wired using complete, drop-in file contents
— no partial edits to merge by hand. The feature is identical to the source SDK — same channel
names, same event contract, same native view logic.
