import Flutter
import UIKit

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
    case "setStickyNote",
         "updateTodayWidgetSnapshot",
         "widgetTodaySnapshot",
         "pushLockScreenTasks":
      result(FlutterMethodNotImplemented)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
