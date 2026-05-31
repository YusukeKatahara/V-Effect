import WidgetKit
import SwiftUI

private let appGroupId = "group.com.veffect.app.vEffect"

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> VEffectEntry {
        let dummyDates = ["2026-05-30", "2026-05-29", "2026-05-27", "2026-05-26"]
        return VEffectEntry(date: Date(), isCompleted: true, streakCount: 12, historyDates: dummyDates, monthlyRate: 0.75)
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
        let monthlyRate = userDefaults?.double(forKey: "monthlyRate") ?? 0.0
        
        let datesArray = historyDatesStr.split(separator: ",").map(String.init)
        
        return VEffectEntry(date: Date(), isCompleted: isCompleted, streakCount: streakCount, historyDates: datesArray, monthlyRate: monthlyRate)
    }
}

struct VEffectEntry: TimelineEntry {
    let date: Date
    let isCompleted: Bool
    let streakCount: Int
    let historyDates: [String]
    let monthlyRate: Double
}

struct CalendarCellData: Hashable {
    let id = UUID()
    let day: Int
    let isDone: Bool
    let isToday: Bool
    let isHidden: Bool
}

struct MonthlyCalendarView: View {
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
            // 曜日ヘッダー
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
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
                    .fill(Color.gray.opacity(0.15))
            }
            
            Text("\(day)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(isDone ? .black : (isToday ? Color(red: 0.83, green: 0.69, blue: 0.22) : .white.opacity(0.8)))
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
}

struct VEffectWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if family == .systemSmall {
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
                    
                    Text("Vを証明する")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(2.0)
                }
            }
            .widgetURL(URL(string: "veffect://task"))
        } else {
            ZStack {
                Color(white: 0.08) // Base background
                
                HStack(alignment: .center, spacing: 16) {
                    // 左側: テキスト情報
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("STREAK")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                            Text("\(entry.streakCount) Days")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("MONTHLY")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                            Text("\(Int(entry.monthlyRate * 100))%")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.22))
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    // 右側: 今月のカレンダー型ヒートマップ
                    MonthlyCalendarView(historyDates: entry.historyDates)
                }
                .padding()
            }
            // タップ時にアプリのホームへ
            .widgetURL(URL(string: "veffect://home"))
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
                    .containerBackground(.clear, for: .widget)
            } else {
                VEffectWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("V EFFECT")
        .description("日々のタスクと達成状況を確認します。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemMedium) {
    VEffectWidget()
} timeline: {
    VEffectEntry(date: .now, isCompleted: false, streakCount: 0, historyDates: ["2026-05-30", "2026-05-28", "2026-05-25"], monthlyRate: 0.4)
}
