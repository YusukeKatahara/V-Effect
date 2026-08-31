import Flutter
import UIKit
import UserNotifications
import ActivityKit
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  lazy var flutterEngine = FlutterEngine(name: "veffect_flutter_engine")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: self.flutterEngine)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    let channel = FlutterMethodChannel(
      name: "com.veffect.app/live_activity",
      binaryMessenger: flutterEngine.binaryMessenger
    )

    channel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in

      switch call.method {
      case "startActivity":
        if #available(iOS 16.2, *) {
          guard let args = call.arguments as? [String: Any],
                let taskName = args["taskName"] as? String,
                let progress = args["progress"] as? Double,
                let status = args["status"] as? String,
                let statusMessage = args["statusMessage"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Arguments missing", details: nil))
            return
          }

          let imageBytesData = args["imageBytes"] as? FlutterStandardTypedData
          let data = imageBytesData?.data

          self?.startLiveActivity(taskName: taskName, progress: progress, status: status, statusMessage: statusMessage, imageBytes: data, result: result)
        } else {
          result(FlutterError(code: "UNSUPPORTED_PLATFORM", message: "iOS 16.1 or higher is required", details: nil))
        }

      case "updateActivity":
        if #available(iOS 16.2, *) {
          guard let args = call.arguments as? [String: Any],
                let progress = args["progress"] as? Double,
                let status = args["status"] as? String,
                let statusMessage = args["statusMessage"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Arguments missing", details: nil))
            return
          }
          self?.updateLiveActivity(progress: progress, status: status, statusMessage: statusMessage, result: result)
        } else {
          result(FlutterError(code: "UNSUPPORTED_PLATFORM", message: "iOS 16.1 or higher is required", details: nil))
        }

      case "stopActivity":
        if #available(iOS 16.2, *) {
          guard let args = call.arguments as? [String: Any],
                let progress = args["progress"] as? Double,
                let status = args["status"] as? String,
                let statusMessage = args["statusMessage"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Arguments missing", details: nil))
            return
          }
          self?.stopLiveActivity(progress: progress, status: status, statusMessage: statusMessage, result: result)
        } else {
          result(FlutterError(code: "UNSUPPORTED_PLATFORM", message: "iOS 16.1 or higher is required", details: nil))
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    })

    // カスタム広告ファクトリを "customNativeAd" というIDで登録
    let factory = MyNativeAdFactory()
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
        self,
        factoryId: "customNativeAd",
        nativeAdFactory: factory
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  // MARK: - Live Activity Management

  @available(iOS 16.2, *)
  private func startLiveActivity(taskName: String, progress: Double, status: String, statusMessage: String, imageBytes: Data?, result: @escaping FlutterResult) {
    // 既存のアップロードLive Activityをすべて終了させる
    stopExistingActivities()
    
    // サムネイル画像の保存または削除
    if let data = imageBytes {
      saveImageToAppGroup(data: data)
    } else {
      removeImageFromAppGroup()
    }
    
    let attributes = VEffectUploadAttributes(taskName: taskName)
    let contentState = VEffectUploadAttributes.ContentState(
      progress: progress,
      status: status,
      statusMessage: statusMessage
    )
    
    do {
      let activity = try Activity<VEffectUploadAttributes>.request(
        attributes: attributes,
        content: ActivityContent(state: contentState, staleDate: nil),
        pushType: nil
      )
      result(activity.id)
    } catch {
      result(FlutterError(code: "START_FAILED", message: "Failed to start Live Activity: \(error.localizedDescription)", details: nil))
    }
  }
  
  private func saveImageToAppGroup(data: Data) {
    guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.veffect.app.vEffect") else {
      print("LiveActivity: App Group container URL is nil")
      return
    }
    let fileURL = sharedContainer.appendingPathComponent("upload_thumbnail.jpg")
    
    // 画像データを一度UIImageに変換し、サムネイルサイズにリサイズする
    guard let image = UIImage(data: data) else {
      print("LiveActivity: Failed to create UIImage from data")
      return
    }
    
    // サムネイルサイズ（高さ最大240、元画像のアスペクト比を維持）にリサイズ
    let maxImageHeight: CGFloat = 240
    let scaleFactor = maxImageHeight / image.size.height
    let finalScale = min(scaleFactor, 1.0)
    
    let scaledWidth = image.size.width * finalScale
    let scaledHeight = image.size.height * finalScale
    
    // UIGraphicsImageRendererFormatを使用し、スケールを1.0に強制設定します。
    // これを行わないとデバイスのデフォルト解像度（2xや3x）が適用され、
    // メモリ消費量が非常に大きくなってWidgetの表示制限（グレーボックス化）に引っかかります。
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: scaledWidth, height: scaledHeight), format: format)
    
    let resizedImage = renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: CGSize(width: scaledWidth, height: scaledHeight)))
    }
    
    // 圧縮率を下げて（JPEGで品質0.7程度）データサイズを数KBに抑える
    guard let resizedData = resizedImage.jpegData(compressionQuality: 0.7) else {
      print("LiveActivity: Failed to compress resized image")
      return
    }
    
    do {
      // ロック画面でもアクセス可能なオプション（noFileProtection）を追加して書き込み
      try resizedData.write(to: fileURL, options: [.atomic, .noFileProtection])
      
      // ファイル保護レベルを「なし」に明示的に設定（二重の安全策）
      var attributes = [FileAttributeKey: Any]()
      attributes[.protectionKey] = FileProtectionType.none
      try FileManager.default.setAttributes(attributes, ofItemAtPath: fileURL.path)
      
      print("LiveActivity: Successfully saved resized thumbnail image to App Group. Size: \(resizedData.count) bytes")
    } catch {
      print("LiveActivity: Failed to save thumbnail image to App Group: \(error.localizedDescription)")
    }
  }
  
  private func removeImageFromAppGroup() {
    guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.veffect.app.vEffect") else {
      return
    }
    let fileURL = sharedContainer.appendingPathComponent("upload_thumbnail.jpg")
    try? FileManager.default.removeItem(at: fileURL)
  }
  
  @available(iOS 16.2, *)
  private func updateLiveActivity(progress: Double, status: String, statusMessage: String, result: @escaping FlutterResult) {
    let contentState = VEffectUploadAttributes.ContentState(
      progress: progress,
      status: status,
      statusMessage: statusMessage
    )
    
    Task {
      for activity in Activity<VEffectUploadAttributes>.activities {
        await activity.update(ActivityContent(state: contentState, staleDate: nil))
      }
      result(nil)
    }
  }
  
  @available(iOS 16.2, *)
  private func stopLiveActivity(progress: Double, status: String, statusMessage: String, result: @escaping FlutterResult) {
    let contentState = VEffectUploadAttributes.ContentState(
      progress: progress,
      status: status,
      statusMessage: statusMessage
    )
    
    Task {
      // 完了ステータスを15秒間表示したのち、自動的にロック画面から非表示にします
      let autoDismissDate = Date(timeIntervalSinceNow: 15)
      for activity in Activity<VEffectUploadAttributes>.activities {
        await activity.end(ActivityContent(state: contentState, staleDate: nil), dismissalPolicy: .after(autoDismissDate))
      }
      result(nil)
    }
  }
  
  @available(iOS 16.2, *)
  private func stopExistingActivities() {
    for activity in Activity<VEffectUploadAttributes>.activities {
      Task {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
  }
}

// MARK: - Activity Attributes
// Widget ターゲット側と完全に同一の定義（シグネチャ）を持たせることで、
// 別モジュール間でも ActivityKit が正しくメッセージデータのシリアライズ・デシリアライズを行い動作します。
public struct VEffectUploadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var progress: Double
        public var status: String
        public var statusMessage: String

        public init(progress: Double, status: String, statusMessage: String) {
            self.progress = progress
            self.status = status
            self.statusMessage = statusMessage
        }
    }

    public var taskName: String

    public init(taskName: String) {
        self.taskName = taskName
    }
}
