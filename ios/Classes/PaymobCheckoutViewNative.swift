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
        }
        var publicKey: String?
        var clientSecret: String?

        if let params = args as? [String: Any] {
            cv.configure(
                uiCustomization: params["uiCustomization"] as? String,
                showAddNewCard: params["showAddNewCard"] as? Bool ?? true,
                payFromOutside: params["payFromOutside"] as? Bool ?? false,
                showSaveCard: params["showSaveCard"] as? Bool ?? true,
                saveCardDefault: params["saveCardDefault"] as? Bool ?? false
            )

            publicKey = params["publicKey"] as? String
            clientSecret = params["clientSecret"] as? String
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

       DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let publicKey,
                  let clientSecret else { return }

            print("window =", cv.window as Any)
            print("isAttached =", cv.window != nil)

            cv.setPaymentKeys(
                publicKey: publicKey,
                clientSecret: clientSecret
            )
        }
    }

    @objc private func handleTouch(_ gr: UILongPressGestureRecognizer) {
        guard gr.state == .began else { return }
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
    }

    @objc private func keyboardWillHide() {
        emit(["type": "keyboardWillHide"])
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
