package com.paymob.flutter.flutter_paymob_sdk

import android.graphics.Color
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

class PaymobFlutterSdkPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PaymobSdkListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pendingResult: Result? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "paymob_sdk_flutter")
        channel.setMethodCallHandler(this)
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
        val appLogoName = call.argument<String>("androidAppLogo")
        val buttonBackgroundColorData = call.argument<Number>("buttonBackgroundColor")?.toInt()
        val buttonTextColorData = call.argument<Number>("buttonTextColor")?.toInt()
        val saveCardDefault = call.argument<Boolean>("saveCardDefault") ?: false
        val showSaveCard = call.argument<Boolean>("showSaveCard") ?: true
        val showTransactionResult = call.argument<Boolean>("showTransactionResult") ?: true

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
                .apply {
                    if (appLogoName != null) {
                        val resId = currentActivity.resources.getIdentifier(appLogoName, "mipmap", currentActivity.packageName)
                            .takeIf { it != 0 }
                            ?: currentActivity.resources.getIdentifier(appLogoName, "drawable", currentActivity.packageName)
                        if (resId != 0) setAppLogo(resId)
                    }
                }
                .showSaveCard(showSaveCard)
                .saveCardByDefault(saveCardDefault)
                .showTransactionResult(showTransactionResult)
                .build()

            paymobSdk.start()
        } catch (e: Exception) {
            pendingResult?.error("SDK_ERROR", e.message, null)
            pendingResult = null
        }
    }

    // PaymobSDK Listener Methods
    override fun onSuccess(payResponse: HashMap<String, String?>) {
        val resultMap = mapOf(
            "status" to "Successful",
            "details" to payResponse
        )
        pendingResult?.success(resultMap)
        pendingResult = null
    }

    override fun onFailure(msg: String?) {
        val resultMap = mapOf(
            "status" to "Failure",
            "errorMessage" to msg
        )
        pendingResult?.success(resultMap)
        pendingResult = null
    }

    override fun onPending() {
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
