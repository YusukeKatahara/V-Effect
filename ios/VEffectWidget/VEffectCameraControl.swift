import WidgetKit
import SwiftUI
import AppIntents

/// iOS 18+ 用の AppIntent: 1タップで veffect://camera を即時起動
@available(iOS 18.0, *)
struct VEffectCameraIntent: AppIntent {
    static var title: LocalizedStringResource = "ワンタップV"
    static var description = IntentDescription("1タップでV EFFECTの撮影カメラを直接起動します。")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let url = URL(string: "veffect://camera")!
        return .result(opensIntent: OpenURLIntent(url))
    }
    
    init() {}
}

/// iOS 18+ コントロールセンター / ロック画面コントロール / アクションボタン用 ControlWidget
@available(iOS 18.0, *)
struct VEffectCameraControl: ControlWidget {
    let kind: String = "com.veffect.app.oneTapVControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: kind
        ) {
            ControlWidgetButton(action: VEffectCameraIntent()) {
                Label("ワンタップV", systemImage: "v.circle.fill")
            }
        }
        .displayName("ワンタップV")
        .description("1タップでV EFFECTの全画面カメラを即時起動します。")
    }
}


