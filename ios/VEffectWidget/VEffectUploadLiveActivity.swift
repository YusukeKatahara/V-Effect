import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes
// Live Activity の静的データと動的データを定義します。
public struct VEffectUploadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // アップロードの進捗率（0.0 〜 1.0）
        public var progress: Double
        // アップロードのステータス（"uploading", "success", "error"）
        public var status: String
        // ロック画面等に表示する詳細メッセージ
        public var statusMessage: String

        public init(progress: Double, status: String, statusMessage: String) {
            self.progress = progress
            self.status = status
            self.statusMessage = statusMessage
        }
    }

    // 静的な値（アップロード対象のタスク名など）
    public var taskName: String

    public init(taskName: String) {
        self.taskName = taskName
    }
}

// MARK: - Live Activity Widget UI
// Live Activity のロック画面UIおよび Dynamic Island での表示内容を定義します。
struct VEffectUploadLiveActivity: Widget {
    // V EFFECT ブランドのゴールドおよびダーク背景のカラー定義
    private let accentGold = Color(red: 0.83, green: 0.69, blue: 0.22)
    private let darkBackground = Color(red: 0.08, green: 0.08, blue: 0.08)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VEffectUploadAttributes.self) { context in
            // ロック画面および通知センターでの表示レイアウト
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    HStack(spacing: 10) {
                        // ステータスに応じたシステムアイコンと色を表示
                        Image(systemName: context.state.status == "success" ? "checkmark.circle.fill" : (context.state.status == "error" ? "exclamationmark.circle.fill" : "arrow.up.circle.fill"))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(context.state.status == "error" ? .red : (context.state.status == "success" ? .green : accentGold))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.taskName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(context.state.statusMessage)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                    
                    // 進捗パーセンテージ
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(context.state.status == "error" ? .red : (context.state.status == "success" ? .green : accentGold))
                }
                
                // プログレスバー
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: context.state.status == "error" ? [.red, .red.opacity(0.7)] : (context.state.status == "success" ? [.green, .green.opacity(0.7)] : [accentGold, accentGold.opacity(0.7)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(context.state.progress), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(16)
            .background(darkBackground)
            .activityBackgroundTint(darkBackground)
            .activitySystemActionForegroundColor(accentGold)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Dynamic Island 展開時の表示内容 (Expanded)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.status == "success" ? "checkmark.circle.fill" : (context.state.status == "error" ? "exclamationmark.circle.fill" : "arrow.up.circle.fill"))
                            .foregroundColor(context.state.status == "error" ? .red : (context.state.status == "success" ? .green : accentGold))
                        Text("V EFFECT")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(accentGold)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(context.state.status == "error" ? .red : (context.state.status == "success" ? .green : accentGold))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.taskName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.statusMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                        
                        ProgressView(value: context.state.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: context.state.status == "error" ? .red : (context.state.status == "success" ? .green : accentGold)))
                    }
                }
            } compactLeading: {
                // 通常時の Dynamic Island (左側)
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(accentGold)
            } compactTrailing: {
                // 通常時の Dynamic Island (右側)
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(accentGold)
            } minimal: {
                // 複数アクティビティが並んだ時の最小表示
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(accentGold)
            }
            .keylineTint(accentGold)
        }
    }
}
