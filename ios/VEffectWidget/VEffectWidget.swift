import WidgetKit
import SwiftUI

private let appGroupId = "group.com.veffect.app.vEffect"

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> VEffectEntry {
        let dummyDates = ["2026-05-30", "2026-05-29", "2026-05-27", "2026-05-26"]
        return VEffectEntry(date: Date(), isCompleted: true, streakCount: 12, historyDates: dummyDates)
    }

    func getSnapshot(in context: Context, completion: @escaping (VEffectEntry) -> ()) {
        let entry = getEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = getEntry()
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
    
    private func getEntry() -> VEffectEntry {
        let userDefaults = UserDefaults(suiteName: appGroupId)
        let isCompleted = userDefaults?.bool(forKey: "isCompleted") ?? false
        let streakCount = userDefaults?.integer(forKey: "streakCount") ?? 0
        let historyDatesStr = userDefaults?.string(forKey: "historyDates") ?? ""
        
        let datesArray = historyDatesStr.split(separator: ",").map(String.init)
        
        return VEffectEntry(date: Date(), isCompleted: isCompleted, streakCount: streakCount, historyDates: datesArray)
    }
}

struct VEffectEntry: TimelineEntry {
    let date: Date
    let isCompleted: Bool
    let streakCount: Int
    let historyDates: [String]
}

struct CalendarCellData: Hashable {
    let id = UUID()
    let day: Int
    let isDone: Bool
    let isToday: Bool
    let isHidden: Bool
}

struct MonthlyCalendarView: View {
    @Environment(\.colorScheme) var colorScheme
    let cellRows: [[CalendarCellData]]
    let weekdays = ["日", "月", "火", "水", "木", "金", "土"]
    
    init(historyDates: [String]) {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: today)
        
        // 今月の初日を取得
        let components = calendar.dateComponents([.year, .month], from: today)
        guard let startOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            self.cellRows = []
            return
        }
        
        let numDays = range.count
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) // 1=日, 2=月...
        
        var rows = [[CalendarCellData]]()
        var currentRow = [CalendarCellData]()
        
        let totalCells = firstWeekday - 1 + numDays
        let totalRows = Int(ceil(Double(totalCells) / 7.0))
        
        for index in 0..<(totalRows * 7) {
            let dayNumber = index - (firstWeekday - 1) + 1
            if dayNumber > 0 && dayNumber <= numDays {
                // 日付を計算してhistoryDatesに含まれるかチェック
                if let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: startOfMonth) {
                    let dateString = formatter.string(from: date)
                    let isDone = historyDates.contains(dateString)
                    currentRow.append(CalendarCellData(day: dayNumber, isDone: isDone, isToday: dateString == todayString, isHidden: false))
                } else {
                    currentRow.append(CalendarCellData(day: dayNumber, isDone: false, isToday: false, isHidden: false))
                }
            } else {
                currentRow.append(CalendarCellData(day: 0, isDone: false, isToday: false, isHidden: true))
            }
            
            if currentRow.count == 7 {
                rows.append(currentRow)
                currentRow = []
            }
        }
        self.cellRows = rows
    }
    
    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        
        LazyVGrid(columns: columns, spacing: 4) {
            // 曜日ヘッダー (Apple公式に合わせ太さを調整し、すりガラス用の半透明白/黒にカラー連動)
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(colorScheme == .light ? Color.black.opacity(0.4) : Color.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
            }
            
            // カレンダーグリッド (2次元配列を平坦化して配置)
            ForEach(cellRows.flatMap { $0 }, id: \.self) { cell in
                if cell.isHidden {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    CalendarCell(day: cell.day, isDone: cell.isDone, isToday: cell.isToday)
                }
            }
        }
    }
}

struct CalendarCell: View {
    @Environment(\.colorScheme) var colorScheme
    let day: Int
    let isDone: Bool
    let isToday: Bool
    
    var body: some View {
        ZStack {
            if isDone {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.83, green: 0.69, blue: 0.22))
            } else if isToday {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(red: 0.83, green: 0.69, blue: 0.22), lineWidth: 1.5)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    // すりガラスの背景に馴染むように半透明白/黒にカラー連動
                    .fill(colorScheme == .light ? Color.black.opacity(0.06) : Color.white.opacity(0.08))
            }
            
            Text("\(day)")
                // Apple純正カレンダーに合わせ、Roundedを外しSF Proの美しいフォント(通常体)で統一
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isDone ? .black : (isToday ? Color(red: 0.83, green: 0.69, blue: 0.22) : (colorScheme == .light ? Color.black.opacity(0.65) : Color.white.opacity(0.7))))
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
}

struct VEffectWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: entry.date)
    }

    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                if entry.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 22, weight: .bold))
                }
            }
            .widgetURL(URL(string: "veffect://camera"))
        } else if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                    Text("V-EFFECT")
                        .font(.system(size: 10, weight: .bold))
                }
                if entry.isCompleted {
                    Text("今日のV達成！")
                        .font(.system(size: 12, weight: .bold))
                    Text("Streak: \(entry.streakCount)日")
                        .font(.system(size: 10))
                } else {
                    Text("📷 タスクを撮影")
                        .font(.system(size: 12, weight: .bold))
                    Text("1タップで全画面カメラ")
                        .font(.system(size: 10))
                }
            }
            .widgetURL(URL(string: "veffect://camera"))
        } else if family == .accessoryInline {
            HStack {
                Image(systemName: entry.isCompleted ? "checkmark.circle" : "camera")
                Text(entry.isCompleted ? "V完了 (\(entry.streakCount)日)" : "V撮影未完了")
            }
            .widgetURL(URL(string: "veffect://camera"))
        } else if family == .systemSmall {
            ZStack {
                if entry.isCompleted {
                    // 完了時のデザイン: ゴールド系のグラデーション
                    RadialGradient(
                        gradient: Gradient(colors: [Color(red: 0.9, green: 0.8, blue: 0.3), Color(red: 0.7, green: 0.5, blue: 0.1)]),
                        center: .center,
                        startRadius: 20,
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
                    
                    VStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Text("Vを証明する")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(2.0)
                    }
                }
            }
            .widgetURL(URL(string: "veffect://camera"))
        } else {
            ZStack {
                // 不透明背景を削除し、すりガラスのトーンを保護する半透明黒レイヤーを設置
                // ライトモード時は 0.03 (ドックのような高い透過感)、ダークモード時は 0.20
                Color.black.opacity(colorScheme == .light ? 0.03 : 0.20)
                
                HStack(alignment: .center, spacing: 16) {
                    // 左側: テキスト情報
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            // Apple公式ウィジェットに準拠したフォントサイズ・太さ・トラッキング（文字間隔）
                            Text("MONTH")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(colorScheme == .light ? Color.black.opacity(0.5) : Color.white.opacity(0.6))
                                .tracking(1.5)
                            Text(monthName)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(colorScheme == .light ? Color.black.opacity(0.85) : Color.white)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            // Apple公式ウィジェットに準拠したフォントサイズ・太さ・トラッキング（文字間隔）
                            Text("STREAK")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(colorScheme == .light ? Color.black.opacity(0.5) : Color.white.opacity(0.6))
                                .tracking(1.5)
                            Text("\(entry.streakCount) Days")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                // ライトモード時は少し暗めのゴールドにして白背景でも見えるようにする
                                .foregroundColor(colorScheme == .light ? Color(red: 0.68, green: 0.53, blue: 0.12) : Color(red: 0.83, green: 0.69, blue: 0.22))
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    // 右側: 今月のカレンダー型ヒートマップ
                    MonthlyCalendarView(historyDates: entry.historyDates)
                }
                .padding()
            }
            // ガラスの質感を高める立体グラデーション輪郭線をオーバーレイ（自動クリップされるため外枠にフィットします）
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(colorScheme == .light ? 0.35 : 0.25),
                                Color.white.opacity(colorScheme == .light ? 0.10 : 0.05),
                                Color.black.opacity(colorScheme == .light ? 0.05 : 0.20)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            // タップ時にアプリのカメラへ
            .widgetURL(URL(string: "veffect://camera"))
            .unredacted()
        }
    }
}

struct VEffectWidget: Widget {
    let kind: String = "VEffectWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                VEffectWidgetEntryView(entry: entry)
                    // iOS 17以降用：Apple公式すりガラス背景
                    .containerBackground(.ultraThinMaterial, for: .widget)
            } else {
                VEffectWidgetEntryView(entry: entry)
                    // iOS 17未満用フォールバック：すりガラス背景
                    .background(.ultraThinMaterial)
            }
        }
        .configurationDisplayName("V EFFECT")
        .description("日々のタスクと達成状況を確認します。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

struct CameraVIconView: View {
    var iconSize: CGFloat = 22
    var vSize: CGFloat = 10
    var color: Color = .white
    
    var body: some View {
        ZStack {
            Image(systemName: "camera.fill")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundColor(color)
            
            Text("V")
                .font(.system(size: vSize, weight: .black, design: .rounded))
                .foregroundColor(.black)
                .offset(y: 1)
        }
    }
}

struct VEffectWidget_Previews: PreviewProvider {
    static var previews: some View {
        VEffectWidgetEntryView(entry: VEffectEntry(date: Date(), isCompleted: false, streakCount: 0, historyDates: ["2026-05-30", "2026-05-28", "2026-05-25"]))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
