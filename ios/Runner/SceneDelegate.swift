import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    for context in connectionOptions.urlContexts
    where IOSNativeLinkBridge.shared.acceptInitial(context.url) {
      break
    }
    super.scene(
      scene,
      willConnectTo: session,
      options: connectionOptions
    )
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    var handled = false
    for context in URLContexts {
      handled =
        IOSNativeLinkBridge.shared.publishWarm(context.url) || handled
    }
    if !handled {
      super.scene(scene, openURLContexts: URLContexts)
    }
  }
}
