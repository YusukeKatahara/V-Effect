import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes
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

// MARK: - Live Activity Widget UI
struct VEffectUploadLiveActivity: Widget {
    private let accentGold = Color(red: 0.83, green: 0.69, blue: 0.22)
    private let darkBackground = Color(red: 0.05, green: 0.05, blue: 0.05).opacity(0.85)

    private var thumbnailImage: UIImage? {
        guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.veffect.app.vEffect") else {
            return nil
        }
        let fileURL = sharedContainer.appendingPathComponent("upload_thumbnail.jpg")
        
        // UIImage(contentsOfFile:) は遅延デコードのため、ロック画面やWidgetのメモリ制限・権限によって
        // デコード失敗（グレーボックス化）を引き起こしやすくなります。
        // Data(contentsOf:) でその場で完全にロードしてからデコードする形式に移行します。
        do {
            let data = try Data(contentsOf: fileURL)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VEffectUploadAttributes.self) { context in
            HStack(alignment: .center, spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    if let uiImage = thumbnailImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 64)
                            .cornerRadius(6)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(accentGold.opacity(0.15))
                            .frame(width: 36, height: 64)
                            .overlay(
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 14))
                                    .foregroundColor(accentGold.opacity(0.8))
                            )
                    }
                    
                    Circle()
                        .fill(context.state.status == "error" ? Color.red : accentGold)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Image(systemName: context.state.status == "success" ? "checkmark" : (context.state.status == "error" ? "exclamationmark" : "arrow.up"))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 2, y: 2)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(context.attributes.taskName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 15, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(context.state.status == "error" ? .red : accentGold)
                    }
                    
                    HStack(alignment: .center, spacing: 8) {
                        Text(context.state.statusMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        LinearGradient(
                                            colors: context.state.status == "error" ? [.red, .red.opacity(0.7)] : [.yellow, accentGold, accentGold.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * CGFloat(context.state.progress), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
            }
            .padding(16)
            .background(Color.clear)
            .activityBackgroundTint(darkBackground)
            .activitySystemActionForegroundColor(accentGold)
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if let uiImage = thumbnailImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 27, height: 48)
                            .cornerRadius(4)
                            .clipped()
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(accentGold)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(context.state.status == "error" ? .red : accentGold)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.taskName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(context.state.statusMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: context.state.status == "error" ? .red : accentGold))
                        .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.status == "success" ? "checkmark.circle.fill" : (context.state.status == "error" ? "exclamationmark.circle.fill" : "arrow.up.circle.fill"))
                    .foregroundColor(context.state.status == "error" ? .red : accentGold)
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(context.state.status == "error" ? .red : accentGold)
            } minimal: {
                Image(systemName: context.state.status == "success" ? "checkmark.circle.fill" : (context.state.status == "error" ? "exclamationmark.circle.fill" : "arrow.up.circle.fill"))
                    .foregroundColor(context.state.status == "error" ? .red : accentGold)
            }
            .keylineTint(accentGold)
        }
    }
}
