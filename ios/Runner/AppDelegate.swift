import Flutter
import UIKit
import UserNotifications
import ActivityKit
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.veffect.app/live_activity", binaryMessenger: controller.binaryMessenger)
    
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
          self?.startLiveActivity(taskName: taskName, progress: progress, status: status, statusMessage: statusMessage, result: result)
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
    
    GeneratedPluginRegistrant.register(with: self)
    
    // カスタム広告ファクトリを "customNativeAd" というIDで登録
    let factory = MyNativeAdFactory()
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
        self,
        factoryId: "customNativeAd",
        nativeAdFactory: factory
    )
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Live Activity Management

  @available(iOS 16.2, *)
  private func startLiveActivity(taskName: String, progress: Double, status: String, statusMessage: String, result: @escaping FlutterResult) {
    // 既存のアップロードLive Activityをすべて終了させる
    stopExistingActivities()
    
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
      for activity in Activity<VEffectUploadAttributes>.activities {
        await activity.end(ActivityContent(state: contentState, staleDate: nil), dismissalPolicy: .default)
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
