import Flutter
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let window = UIWindow(windowScene: windowScene)
    let appDelegate = UIApplication.shared.delegate as? AppDelegate
    if let flutterEngine = appDelegate?.flutterEngine {
      let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
      window.rootViewController = flutterViewController
    }
    self.window = window
    window.makeKeyAndVisible()
  }
}
