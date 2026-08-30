import Flutter
import UIKit
import PaymobSDK

final class PaymobCheckoutViewNative: NSObject {

    // MARK: - Views

    private let containerView: PaymobContainerView
    private var checkoutView: PaymobCheckoutView?

    // MARK: - Flutter Channels

    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?

    // MARK: - State

    private var lastEmittedHeight: CGFloat = 0

    // MARK: - Init

    init(
        frame: CGRect,
        viewId: Int64,
        args: Any?,
        messenger: FlutterBinaryMessenger
    ) {

        containerView = PaymobContainerView(frame: frame)
        containerView.backgroundColor = .clear
        containerView.clipsToBounds = false

        let baseChannel = "paymob_checkout_view/\(viewId)"

        methodChannel = FlutterMethodChannel(
            name: baseChannel,
            binaryMessenger: messenger
        )

        eventChannel = FlutterEventChannel(
            name: "\(baseChannel)/events",
            binaryMessenger: messenger
        )

        super.init()

        buildNativeView(frame: frame, args: args)
        bindChannels()
        observeKeyboard()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Flutter Platform View

extension PaymobCheckoutViewNative: FlutterPlatformView {

    func view() -> UIView {
        containerView
    }
}

// MARK: - View Setup

private extension PaymobCheckoutViewNative {

    func buildNativeView(frame: CGRect, args: Any?) {

        let checkoutView = PaymobCheckoutView()
        checkoutView.translatesAutoresizingMaskIntoConstraints = false
        checkoutView.delegate = self

        checkoutView.onHeightChanged = { [weak self] height in
            self?.emitHeight(height)
        }

        var publicKey: String?
        var clientSecret: String?

        if let params = args as? [String: Any] {

            checkoutView.configure(
                uiCustomization: params["uiCustomization"] as? String,
                showAddNewCard: params["showAddNewCard"] as? Bool ?? true,
                payFromOutside: params["payFromOutside"] as? Bool ?? false,
                showSaveCard: params["showSaveCard"] as? Bool ?? true,
                saveCardDefault: params["saveCardDefault"] as? Bool ?? false
            )

            publicKey = params["publicKey"] as? String
            clientSecret = params["clientSecret"] as? String
        }

        containerView.addSubview(checkoutView)

        NSLayoutConstraint.activate([
            checkoutView.topAnchor.constraint(equalTo: containerView.topAnchor),
            checkoutView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            checkoutView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])

        self.checkoutView = checkoutView
        containerView.checkoutView = checkoutView

        containerView.onHeightDetected = { [weak self] height in
            self?.emitHeight(height)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {

            guard
                let publicKey,
                let clientSecret
            else { return }

            checkoutView.setPaymentKeys(
                publicKey: publicKey,
                clientSecret: clientSecret
            )
        }
    }
}

// MARK: - Flutter Channels

private extension PaymobCheckoutViewNative {

    func bindChannels() {

        methodChannel.setMethodCallHandler { [weak self] call, result in

            guard let self else { return }

            switch call.method {

            case "setPaymentKeys":

                guard
                    let args = call.arguments as? [String: Any],
                    let publicKey = args["publicKey"] as? String,
                    let clientSecret = args["clientSecret"] as? String
                else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGS",
                            message: "publicKey and clientSecret are required",
                            details: nil
                        )
                    )
                    return
                }

                checkoutView?.setPaymentKeys(
                    publicKey: publicKey,
                    clientSecret: clientSecret
                )

                result(nil)

            case "payFromOutside":

                checkoutView?.payFromOutside()
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        eventChannel.setStreamHandler(self)
    }
}

// MARK: - Keyboard

private extension PaymobCheckoutViewNative {

    func observeKeyboard() {

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

    @objc
    func keyboardWillShow(_ notification: Notification) {

        guard
            let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else {
            return
        }

        emit([
            "type": "keyboardWillShow",
            "keyboardHeight": frame.height
        ])
    }

    @objc
    func keyboardWillHide() {
        emit(["type": "keyboardWillHide"])
    }
}

// MARK: - Events

private extension PaymobCheckoutViewNative {

    func emitHeight(_ height: CGFloat) {

        guard
            height > 0,
            abs(height - lastEmittedHeight) > 0.5
        else {
            return
        }

        lastEmittedHeight = height

        emit([
            "type": "heightChanged",
            "height": height
        ])
    }

    func emit(_ event: [String: Any]) {

        guard let sink = eventSink else { return }

        DispatchQueue.main.async {
            sink(event)
        }
    }
}

// MARK: - Flutter Stream Handler

extension PaymobCheckoutViewNative: FlutterStreamHandler {

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {

        eventSink = events

        if lastEmittedHeight > 0 {
            emit([
                "type": "heightChanged",
                "height": lastEmittedHeight
            ])
        }

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

// MARK: - Paymob Delegate

extension PaymobCheckoutViewNative: PaymobSDKDelegate {

    func transactionAccepted(transactionDetails: [String : Any]) {

        let details = transactionDetails.mapValues { "\($0)" }

        emit([
            "type": "transactionAccepted",
            "transactionDetails": details
        ])
    }

    func transactionRejected(message: String) {

        emit([
            "type": "transactionRejected",
            "message": message
        ])
    }

    func transactionCancelled() {

        emit([
            "type": "transactionCancelled"
        ])
    }

    func transactionPending() {

        emit([
            "type": "transactionPending"
        ])
    }
}

// MARK: - Container View

final class PaymobContainerView: UIView {

    weak var checkoutView: UIView?

    var onHeightDetected: ((CGFloat) -> Void)?

    private var lastReportedHeight: CGFloat = 0

    override func layoutSubviews() {

        super.layoutSubviews()

        guard let checkoutView else { return }

        let height = checkoutView.bounds.height

        guard
            height > 0,
            abs(height - lastReportedHeight) >= 2
        else {
            return
        }

        lastReportedHeight = height
        onHeightDetected?(height)
    }
}

// MARK: - UIColor

private extension UIColor {

    convenience init?(hexString: String) {

        var string = hexString.trimmingCharacters(in: .whitespacesAndNewlines)

        if string.hasPrefix("#") {
            string.removeFirst()
        }

        guard string.count == 6 else { return nil }

        var value: UInt64 = 0

        guard Scanner(string: string).scanHexInt64(&value) else {
            return nil
        }

        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
