import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), streak: 0, status: "Today's Victory?")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = readData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = readData()
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
    
    private func readData() -> SimpleEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.yusukekatahara.veffect")
        let streak = userDefaults?.integer(forKey: "streak") ?? 0
        let postedToday = userDefaults?.bool(forKey: "postedToday") ?? false
        let isAllTasksCompleted = userDefaults?.bool(forKey: "isAllTasksCompleted") ?? false
        
        let status: String
        if isAllTasksCompleted {
            status = "Mission Complete!"
        } else if postedToday {
            status = "Keep going!"
        } else {
            status = "Today's Victory?"
        }
        
        return SimpleEntry(date: Date(), streak: streak, status: status)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let status: String
}

struct VEffectWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text("\(entry.streak)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.22)) // #D4AF37
            
            Text("STREAK")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
            
            Spacer().frame(height: 8)
            
            Text(entry.status)
                .font(.system(size: 12))
                .foregroundColor(.white)
            
            Spacer().frame(height: 12)
            
            Image(systemName: "camera.fill")
                .foregroundColor(.white)
                .font(.system(size: 16))
        }
        .containerBackground(for: .widget) {
            Color(red: 0.1, green: 0.1, blue: 0.1) // #1A1A1A
        }
        .widgetURL(URL(string: "veffect://camera"))
    }
}

struct VEffectWidget: Widget {
    let kind: String = "VEffectWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            VEffectWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("V-EFFECT")
        .description("現在のストリークを確認できます。")
        .supportedFamilies([.systemSmall])
    }
}
