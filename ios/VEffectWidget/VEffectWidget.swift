import WidgetKit
import SwiftUI

private let appGroupId = "group.com.veffect.app.vEffect"

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> VEffectEntry {
        VEffectEntry(date: Date(), isCompleted: false, streakCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (VEffectEntry) -> ()) {
        let entry = getEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = getEntry()
        // Flutter側から手動で更新をトリガーするため、定期的な自動更新は必要最低限（.never）
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
    
    private func getEntry() -> VEffectEntry {
        let userDefaults = UserDefaults(suiteName: appGroupId)
        // Flutter (home_widget) から書き込まれるキーを読み込む
        let isCompleted = userDefaults?.bool(forKey: "isCompleted") ?? false
        let streakCount = userDefaults?.integer(forKey: "streakCount") ?? 0
        return VEffectEntry(date: Date(), isCompleted: isCompleted, streakCount: streakCount)
    }
}

struct VEffectEntry: TimelineEntry {
    let date: Date
    let isCompleted: Bool
    let streakCount: Int
}

struct VEffectWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            if entry.isCompleted {
                // 完了時のデザイン: ベース背景黒
                Color.black
                
                // ゴールドオーラ (RadialGradient)
                RadialGradient(
                    gradient: Gradient(colors: [Color(red: 0.83, green: 0.69, blue: 0.22).opacity(0.8), Color.black.opacity(0.0)]),
                    center: .center,
                    startRadius: 10,
                    endRadius: 120
                )
                
                VStack(spacing: 8) {
                    Text("DONE")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                    Text("\(entry.streakCount) Streak")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
            } else {
                // 未完了時のデザイン: ダークグレー〜黒のグラデーション
                LinearGradient(
                    gradient: Gradient(colors: [Color(white: 0.15), Color.black]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                Text("Vを証明する")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(2.0) // 文字間隔を広げてスタイリッシュに
            }
        }
        // ウィジェットタップ時のDeepLink
        .widgetURL(URL(string: "veffect://task"))
    }
}

struct VEffectWidget: Widget {
    let kind: String = "VEffectWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                VEffectWidgetEntryView(entry: entry)
                    .containerBackground(.clear, for: .widget)
            } else {
                VEffectWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("V EFFECT")
        .description("今日のタスク状況を確認します。")
        .supportedFamilies([.systemSmall]) // 小サイズのみに制限
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    VEffectWidget()
} timeline: {
    VEffectEntry(date: .now, isCompleted: false, streakCount: 0)
    VEffectEntry(date: .now, isCompleted: true, streakCount: 12)
}
