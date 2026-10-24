import UserNotifications
import Intents
import UIKit

/// DM（ダイレクトメッセージ）受信時に、iOSの通知センターやバナーのアイコンを
/// LINEのように「送信者のユーザーアイコン」へ書き換える拡張機能（Notification Service Extension）
class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let userInfo = request.content.userInfo
        let type = userInfo["type"] as? String

        // DM（1対1ダイレクトメッセージ）通知の場合のみユーザーアイコン表示（Communication Notifications）を適用
        // それ以外の通常通知はそのまま従来のV EFFECTアプリアイコンで表示する
        guard type == "directMessage" else {
            contentHandler(bestAttemptContent)
            return
        }

        let senderId = userInfo["senderId"] as? String ?? "unknown_sender"
        // タイトル先頭の「💬 」を除去して純粋なユーザー名を取得
        let rawTitle = bestAttemptContent.title.replacingOccurrences(of: "^💬\\s*", with: "", options: .regularExpression)
        let senderName = (userInfo["senderName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = (senderName?.isEmpty == false) ? senderName! : rawTitle
        let messageText = bestAttemptContent.body
        let chatId = userInfo["chatId"] as? String ?? "dm_\(senderId)"
        let avatarUrlString = userInfo["senderAvatarUrl"] as? String

        // 1. 送信者のプロフィール画像を取得（未設定・通信失敗時はデフォルトのイニシャル/人型アイコンを生成）
        loadAvatarImage(from: avatarUrlString, displayName: displayName) { [weak self] avatarImage in
            guard let self = self, let bestAttemptContent = self.bestAttemptContent else {
                contentHandler(request.content)
                return
            }

            // 2. 送信者情報（INPerson）の作成
            let handle = INPersonHandle(value: senderId, type: .unknown)
            let sender = INPerson(
                personHandle: handle,
                nameComponents: nil,
                displayName: displayName,
                image: avatarImage,
                contactIdentifier: nil,
                customIdentifier: senderId,
                isMe: false,
                suggestionType: .none
            )

            // 自分自身（受信者）を表すダミーの INPerson（iOS 15+ の Communication Notifications 安定動作のため）
            let meHandle = INPersonHandle(value: "current_user", type: .unknown)
            let mePerson = INPerson(
                personHandle: meHandle,
                nameComponents: nil,
                displayName: nil,
                image: nil,
                contactIdentifier: nil,
                customIdentifier: "current_user",
                isMe: true,
                suggestionType: .none
            )

            // 3. メッセージ送信インテント（INSendMessageIntent）の作成
            let intent = INSendMessageIntent(
                recipients: [mePerson],
                outgoingMessageType: .outgoingMessageText,
                content: messageText,
                speakableGroupName: nil,
                conversationIdentifier: chatId,
                serviceName: nil,
                sender: sender,
                attachments: nil
            )

            // 送信者パラメータにアバター画像を明示的に関連付け（丸いユーザーアイコン表示に必須）
            if let avatarImage = avatarImage {
                intent.setImage(avatarImage, forParameterNamed: \.sender)
            }

            // 4. インタラクションを作成し、iOSシステムへ登録（donate）してから通知UIを更新
            // ※ donate() を呼ばないと iOS がユーザーアイコンへの差し替えを行わないため必須
            let interaction = INInteraction(intent: intent, response: nil)
            interaction.direction = .incoming

            interaction.donate { _ in
                do {
                    let updatedContent = try bestAttemptContent.updating(from: intent)
                    contentHandler(updatedContent)
                } catch {
                    // 万が一エラーが起きた場合は元の通知内容で安全に表示
                    contentHandler(bestAttemptContent)
                }
            }
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // 画像ダウンロード等のタイムアウト時（約30秒）の安全なフォールバック
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    /// URLからアイコン画像を非同期ダウンロードし、失敗時や未設定時はフォールバック用の丸アイコンを生成する
    private func loadAvatarImage(
        from urlString: String?,
        displayName: String,
        completion: @escaping (INImage?) -> Void
    ) {
        guard let urlString = urlString,
              !urlString.isEmpty,
              let url = URL(string: urlString) else {
            completion(createFallbackAvatarImage(displayName: displayName))
            return
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6.0
        config.timeoutIntervalForResource = 6.0
        let session = URLSession(configuration: config)

        session.dataTask(with: url) { [weak self] data, response, error in
            if let data = data,
               error == nil,
               let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode),
               UIImage(data: data) != nil {
                completion(INImage(imageData: data))
            } else {
                completion(self?.createFallbackAvatarImage(displayName: displayName))
            }
        }.resume()
    }

    /// プロフィール写真未設定時やオフライン時でもLINE風に表示するためのデフォルトアイコン生成
    private func createFallbackAvatarImage(displayName: String) -> INImage? {
        let size = CGSize(width: 160, height: 160)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)

            // ダークグレーの円形背景（V EFFECT テーマカラー）
            UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0).setFill()
            UIBezierPath(ovalIn: rect).fill()

            // ゴールドの細い内枠
            let borderRect = rect.insetBy(dx: 3, dy: 3)
            UIColor(red: 0.83, green: 0.69, blue: 0.22, alpha: 0.85).setStroke()
            let borderPath = UIBezierPath(ovalIn: borderRect)
            borderPath.lineWidth = 4
            borderPath.stroke()

            // 名前の頭文字1文字、または人型アイコンを描画
            let initial = String(displayName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
            if !initial.isEmpty {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 72, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let textSize = initial.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                initial.draw(in: textRect, withAttributes: attributes)
            }
        }

        guard let pngData = image.pngData() else { return nil }
        return INImage(imageData: pngData)
    }
}

