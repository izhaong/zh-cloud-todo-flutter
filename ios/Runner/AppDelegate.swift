import Flutter
import UIKit

struct IOSNativeShareRequest: Equatable {
  let text: String
  let subject: String?
}

enum IOSNativeIntentContract {
  private static let urlScheme = "zhcloudtodo"
  private static let taskHost = "task"
  private static let taskAddPath = "/add"

  static func acceptedIncomingLink(_ url: URL?) -> String? {
    guard
      let url,
      let components = URLComponents(
        url: url,
        resolvingAgainstBaseURL: false
      ),
      components.scheme?.lowercased() == urlScheme,
      components.host?.lowercased() == taskHost,
      components.path == taskAddPath,
      components.user == nil,
      components.password == nil,
      components.port == nil,
      components.fragment == nil
    else {
      return nil
    }
    return url.absoluteString
  }

  static func shareRequest(_ arguments: Any?) -> IOSNativeShareRequest? {
    guard let values = arguments as? [String: Any] else {
      return nil
    }
    let text = (values["text"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !text.isEmpty else {
      return nil
    }
    let subject = (values["subject"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return IOSNativeShareRequest(
      text: text,
      subject: subject?.isEmpty == false ? subject : nil
    )
  }

  static func keepScreenAwakeEnabled(_ arguments: Any?) -> Bool? {
    guard
      let values = arguments as? [String: Any],
      let enabled = values["enabled"] as? NSNumber,
      CFGetTypeID(enabled) == CFBooleanGetTypeID()
    else {
      return nil
    }
    return enabled.boolValue
  }
}

final class IOSNativeLinkBridge: NSObject, FlutterStreamHandler {
  static let shared = IOSNativeLinkBridge()

  private var initialLink: String?
  private var pendingWarmLink: String?
  private var eventSink: FlutterEventSink?

  @discardableResult
  func acceptInitial(_ url: URL?) -> Bool {
    guard let accepted = IOSNativeIntentContract.acceptedIncomingLink(url) else {
      return false
    }
    if initialLink == nil {
      initialLink = accepted
    }
    return true
  }

  func takeInitialLink() -> String? {
    defer { initialLink = nil }
    return initialLink
  }

  @discardableResult
  func publishWarm(_ url: URL?) -> Bool {
    guard let accepted = IOSNativeIntentContract.acceptedIncomingLink(url) else {
      return false
    }
    if let eventSink {
      eventSink(accepted)
    } else {
      pendingWarmLink = accepted
    }
    return true
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    if let pendingWarmLink {
      events(pendingWarmLink)
      self.pendingWarmLink = nil
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

private final class IOSNativeShareItem: NSObject, UIActivityItemSource {
  private let request: IOSNativeShareRequest

  init(request: IOSNativeShareRequest) {
    self.request = request
  }

  func activityViewControllerPlaceholderItem(
    _ activityViewController: UIActivityViewController
  ) -> Any {
    request.text
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    itemForActivityType activityType: UIActivity.ActivityType?
  ) -> Any? {
    request.text
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    subjectForActivityType activityType: UIActivity.ActivityType?
  ) -> String {
    request.subject ?? ""
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var nativeChannel: FlutterMethodChannel?
  private var linkEventsChannel: FlutterEventChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let nativeChannel = FlutterMethodChannel(
      name: "zh_cloud_todo/native",
      binaryMessenger: messenger
    )
    nativeChannel.setMethodCallHandler { [weak self] call, result in
      self?.handleNativeMethod(call, result: result)
    }
    self.nativeChannel = nativeChannel

    let linkEventsChannel = FlutterEventChannel(
      name: "zh_cloud_todo/native_links",
      binaryMessenger: messenger
    )
    linkEventsChannel.setStreamHandler(IOSNativeLinkBridge.shared)
    self.linkEventsChannel = linkEventsChannel
  }

  private func handleNativeMethod(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "supportsLinkEvents":
      result(true)
    case "getInitialLink":
      result(IOSNativeLinkBridge.shared.takeInitialLink())
    case "setKeepScreenAwake":
      guard let enabled = IOSNativeIntentContract.keepScreenAwakeEnabled(call.arguments) else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "屏幕常亮参数无效",
            details: nil
          )
        )
        return
      }
      UIApplication.shared.isIdleTimerDisabled = enabled
      result(true)
    case "share":
      guard let request = IOSNativeIntentContract.shareRequest(call.arguments) else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "分享文本不能为空",
            details: nil
          )
        )
        return
      }
      presentShare(request, result: result)
    case "setStickyNote",
         "updateTodayWidgetSnapshot",
         "widgetTodaySnapshot",
         "pushLockScreenTasks":
      result(FlutterMethodNotImplemented)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func presentShare(
    _ request: IOSNativeShareRequest,
    result: @escaping FlutterResult
  ) {
    guard let presenter = Self.topViewController() else {
      result(
        FlutterError(
          code: "share_unavailable",
          message: "当前没有可展示系统分享面板的页面",
          details: nil
        )
      )
      return
    }

    let shareController = UIActivityViewController(
      activityItems: [IOSNativeShareItem(request: request)],
      applicationActivities: nil
    )
    if let popover = shareController.popoverPresentationController {
      popover.sourceView = presenter.view
      popover.sourceRect = CGRect(
        x: presenter.view.bounds.midX,
        y: presenter.view.bounds.midY,
        width: 0,
        height: 0
      )
      popover.permittedArrowDirections = []
    }
    presenter.present(shareController, animated: true) {
      result(nil)
    }
  }

  private static func topViewController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController
    return topViewController(from: root)
  }

  private static func topViewController(
    from controller: UIViewController?
  ) -> UIViewController? {
    if let presented = controller?.presentedViewController {
      return topViewController(from: presented)
    }
    if let navigation = controller as? UINavigationController {
      return topViewController(from: navigation.visibleViewController)
    }
    if let tabs = controller as? UITabBarController {
      return topViewController(from: tabs.selectedViewController)
    }
    return controller
  }
}
