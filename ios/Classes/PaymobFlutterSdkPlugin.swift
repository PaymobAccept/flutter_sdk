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

        if let assetPath = arguments["iosAppLogo"] as? String {
            let candidates = [
                Bundle.main.bundlePath + "/flutter_assets/" + assetPath,
                Bundle.main.bundlePath + "/Frameworks/App.framework/flutter_assets/" + assetPath,
            ]
            paymob.paymobSDKCustomization.appIcon = candidates.compactMap { UIImage(contentsOfFile: $0) }.first
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

        if let showTransactionResult = arguments["showTransactionResult"] as? Bool {
            paymob.paymobSDKCustomization.showTransactionResult = showTransactionResult
        }

        if let failureCallBackVersion = arguments["failureCallBackVersion"] as? String {
            paymob.paymobSDKCustomization.setFailureCallBackVersion =
            (failureCallBackVersion.lowercased() == "v2" ? .V2 : .V1)

        }

        if let isKeyboardHandlingEnabled = arguments["isKeyboardHandlingEnabled"] as? Bool {
            paymob.paymobSDKCustomization.isKeyboardHandlingEnabled = isKeyboardHandlingEnabled
        }
        
        // MARK: - Call SDK
        if let publicKey = arguments["publicKey"] as? String,
           let clientSecret = arguments["clientSecret"] as? String {
            
            guard let topVC = UIApplication.shared.topMostViewController() else {
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
            } catch {
                self.pendingResult?(FlutterError(
                    code: "PAYMOB_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
                self.pendingResult = nil
            }
        } else {
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
        self.pendingResult?(["status": "Failure", "errorMessage": message ])
        self.pendingResult = nil
    }

    public func transactionCancelled() {
        print("⏳ [PaymobSDK] Transaction Cancelled")
        self.pendingResult?(["status": "Cancelled"])
        self.pendingResult = nil
    }
    
    public func transactionAccepted(transactionDetails: [String: Any]) {
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
