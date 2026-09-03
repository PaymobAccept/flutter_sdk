package com.paymob.flutter.flutter_paymob_sdk

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
            // Delay setting keys slightly to ensure the view is ready and the loader triggers correctly
            rootView.postDelayed({
                checkoutView.setPaymentKeys(publicKey, clientSecret)
            }, 10)
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
            val sink = eventSink ?: return
            lastEmittedHeightDp = heightDp
            rootView.post { sink.success(mapOf("type" to "heightChanged", "height" to heightDp)) }
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

    override fun onFailure(msg: String) {
        emit(mapOf("type" to "transactionRejected", "message" to msg))
    }

    override fun onCancelled() {
        emit(mapOf("type" to "transactionCancelled"))
    }

    override fun onPending() {
        emit(mapOf("type" to "transactionPending"))
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
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
