package com.paymob.flutter.flutter_paymob_sdk

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
