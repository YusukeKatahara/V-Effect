import UserNotifications
import Intents

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let userInfo = request.content.userInfo
        let type = userInfo["type"] as? String

        // DM（1対1ダイレクトメッセージ）通知の場合のみ Communication Notifications を構成
        guard type == "directMessage" else {
            contentHandler(bestAttemptContent)
            return
        }

        let senderId = userInfo["senderId"] as? String ?? "unknown_sender"
        let senderName = userInfo["senderName"] as? String ?? bestAttemptContent.title
        let messageText = bestAttemptContent.body
        let chatId = userInfo["chatId"] as? String ?? "direct_chat"
        let avatarUrlString = userInfo["senderAvatarUrl"] as? String

        // 1. 送信者アバター画像の取得（ダウンロード）
        var avatarImage: INImage? = nil
        if let avatarUrlString = avatarUrlString,
           !avatarUrlString.isEmpty,
           let url = URL(string: avatarUrlString) {
            if let imageData = try? Data(contentsOf: url) {
                avatarImage = INImage(imageData: imageData)
            }
        }

        // 2. 送信者 (INPerson) の作成
        let handle = INPersonHandle(value: senderId, type: .unknown)
        let sender = INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: senderName,
            image: avatarImage,
            contactIdentifier: nil,
            customIdentifier: nil,
            isMe: false
        )

        // 3. INSendMessageIntent の作成
        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: messageText,
            speakableGroupName: nil,
            conversationIdentifier: chatId,
            serviceName: nil,
            sender: sender,
            attachments: nil
        )

        // 送信者パラメータにアバター画像を関連付け（丸いアイコン表示に必須）
        if let avatar = avatarImage {
            intent.setImage(avatar, forParameterNamed: \.sender)
        }

        // 4. インタラクションを作成し、通知コンテンツを Communication UI に更新
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming

        do {
            let updatedContent = try bestAttemptContent.updating(from: intent)
            contentHandler(updatedContent)
        } catch {
            // エラー時はフォールバックとして元の通知内容で表示
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // 画像ダウンロード等のタイムアウト時（約30秒）の安全なフォールバック
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
