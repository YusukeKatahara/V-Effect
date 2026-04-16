import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// プライバシーポリシーを表示するスクリーン
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        title: const Text(
          'プライバシーポリシー',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: PrivacyPolicyContent(),
      ),
    );
  }
}

/// プライバシーポリシーの本文ウィジェット。
///
/// [PrivacyPolicyScreen] と [TermsAgreementScreen] の両方から利用される。
class PrivacyPolicyContent extends StatelessWidget {
  const PrivacyPolicyContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildParagraph(
          'V EFFECT（以下、「当アプリ」といいます。）は、ユーザーの皆様（以下、「ユーザー」といいます。）の個人情報およびプライバシーに関する情報の取り扱いについて、以下のとおりプライバシーポリシー（以下、「本ポリシー」といいます。）を定めます。',
        ),
        const SizedBox(height: 24),

        // 1. 取得する情報
        _buildSectionHeader('1.', '取得する情報'),
        _buildParagraph('当アプリでは、サービスの提供にあたり以下の情報を取得します。'),
        const SizedBox(height: 12),
        _buildSubHeader('(1) ユーザーから直接提供される情報'),
        _buildParagraph('アカウント登録およびプロフィールの設定、または当アプリの利用を通じて、以下の情報を取得します。'),
        const SizedBox(height: 6),
        _buildBulletItem('アカウント情報', 'メールアドレス、ユーザー名（ユーザーID）、表示名'),
        _buildBulletItem('属性情報', '生年月日、性別、職業'),
        _buildBulletItem('設定・習慣に関する情報', '起床時間、タスク実行時間、目標（ヒーロータスク）、テンプレート等の設定情報'),
        _buildBulletItem('コンテンツ情報', 'プロフィール画像、投稿内容（テキスト、写真等）、当アプリ内で作成したその他のデータ'),
        const SizedBox(height: 12),
        _buildSubHeader('(2) 自動的に取得される情報'),
        _buildParagraph('当アプリの利用に伴い、ユーザーの端末や利用状況に関する以下の情報が自動的に記録されることがあります。'),
        const SizedBox(height: 6),
        _buildBulletItem('行動履歴・利用状況', '当アプリ内の機能利用履歴（ログイン履歴、投稿、リアクション、フレンド申請・承認・ブロック、ストリーク更新等）、画面遷移、招待元（リファラル）情報'),
        _buildBulletItem('デバイスおよびシステム情報', '端末の識別子、OSの種類およびバージョン、言語設定、IPアドレスなど'),
        _buildBulletItem('センサー情報', '端末が搭載する各種センサー（加速度センサー等）より得られる情報'),
        _buildBulletItem('クラッシュ・エラー情報', '障害発生時の端末状況、エラーログ'),
        const SizedBox(height: 12),
        _buildSubHeader('(3) 端末の権限を必要とする情報'),
        _buildParagraph('当アプリでは、以下の端末機能にアクセスする場合があります。取得にはユーザーご自身の端末上での許可が必要です。'),
        const SizedBox(height: 6),
        _buildBulletItem('カメラ・写真ライブラリ', 'プロフィール画像や投稿写真の撮影・アップロードのため'),
        _buildBulletItem('プッシュ通知', 'リマインダーや他のユーザーからのリアクションなどをお知らせするため'),
        const SizedBox(height: 8),
        _buildParagraph('なお、当アプリは位置情報（GPS等）へのアクセスは行いません。'),
        const SizedBox(height: 24),

        // 2. 取得した情報の利用目的
        _buildSectionHeader('2.', '取得した情報の利用目的'),
        _buildParagraph('取得した情報は、以下の目的で利用します。'),
        const SizedBox(height: 6),
        _buildNumberedItem(1, 'サービスの提供および運営', '当アプリのアカウント作成、ログイン認証、本人確認、ユーザー間のコミュニケーション機能（投稿の共有、フレンド機能、リアクション等）の提供のため'),
        _buildNumberedItem(2, '機能の最適化およびパーソナライズ', '目標（ヒーロータスク）のカテゴリ分類、ストリークに応じた体験の提供、ユーザーの利用時間帯に合わせた機能の調整のため'),
        _buildNumberedItem(3, 'サービスの改善および分析', 'サービス利用状況の分析（アクセス解析など）、品質向上、新機能の開発、および障害や不具合の調査・対応のため'),
        _buildNumberedItem(4, '通知および連絡', 'プッシュ通知の送信、重要なお知らせ、規約変更などの連絡や、ユーザーからのお問い合わせへの対応のため'),
        _buildNumberedItem(5, '不正行為の防止', '当アプリの利用規約に違反する行為、不正アクセス等の調査および防止のため'),
        const SizedBox(height: 24),

        // 3. 第三者への情報の提供
        _buildSectionHeader('3.', '第三者への情報の提供'),
        _buildParagraph('当アプリは、以下の場合を除き、ユーザーの同意を得ることなく第三者に個人情報を提供することはありません。'),
        const SizedBox(height: 6),
        _buildNumberedItem(1, '法令に基づく場合', ''),
        _buildNumberedItem(2, '人の生命、身体または財産の保護のために必要があり、本人の同意を得ることが困難な場合', ''),
        _buildNumberedItem(
          3,
          '利用目的の達成に必要な範囲内で、個人情報の取り扱いの全部または一部を委託する場合',
          '当アプリでは、クラウドインフラ、認証機能、アクセス解析およびクラッシュレポートのツールとして、以下の外部サービスを利用しています。これらのサービスを通じて情報が処理・保存される場合があります。なお、これらのサービスのサーバーは日本国外（主に米国）に所在するため、情報が海外に転送されることがあります。',
        ),
        _buildIndentedBullet('Firebase関連サービス（Google LLC）', 'Authentication, Cloud Firestore, Firebase Storage, Firebase Analytics, Firebase Crashlytics, Firebase Cloud Messaging など'),
        const SizedBox(height: 8),
        _buildParagraph('また、当アプリはApple Inc.が提供する「Sign in with Apple」を利用しており、同機能の利用に際してApple Inc.が定めるプライバシーポリシーに従って情報が取り扱われます。'),
        const SizedBox(height: 24),

        // 4. 他のユーザーへの情報の公開
        _buildSectionHeader('4.', '他のユーザーへの情報の公開'),
        _buildParagraph('当アプリはSNS機能を提供するため、ユーザーが設定したプロフィール情報（表示名、ユーザー名、プロフィール画像）や、投稿した内容（写真・テキスト等）、目標（ヒーロータスク）、連続達成記録（ストリーク数）は、当アプリの仕様およびプライバシー設定に従って、他のユーザー（フレンドなど）に共有・公開されます。アカウントを非公開設定（プライベートアカウント）にすることで、閲覧できるユーザーを制限することが可能です。'),
        const SizedBox(height: 24),

        // 5. 情報の管理とセキュリティ
        _buildSectionHeader('5.', '情報の管理とセキュリティ'),
        _buildParagraph('当アプリは、取得した情報を適切に管理し、漏洩、滅失、または毀損の防止のために合理的なセキュリティ対策を講じます（パスワード情報を取り扱わず外部の認証プロバイダを利用する等）。'),
        const SizedBox(height: 24),

        // 6. 情報の保持期間
        _buildSectionHeader('6.', '情報の保持期間'),
        _buildParagraph('取得した情報は、サービスの提供に必要な期間保持します。アカウントが削除された場合の取り扱いについては、第9条をご参照ください。'),
        const SizedBox(height: 24),

        // 7. 未成年者の利用
        _buildSectionHeader('7.', '未成年者の利用'),
        _buildParagraph('当アプリは13歳以上の方を対象としています。13歳未満の方は当アプリをご利用いただけません。13歳未満の方から個人情報を取得したことが判明した場合、当該情報を速やかに削除します。'),
        const SizedBox(height: 24),

        // 8. 個人情報に関する権利
        _buildSectionHeader('8.', '個人情報に関する権利'),
        _buildParagraph('ユーザーは、当アプリが保有する自己の個人情報について、以下の請求を行うことができます。'),
        const SizedBox(height: 6),
        _buildBulletItem('開示の請求', '保有する個人情報の内容の確認'),
        _buildBulletItem('訂正・追加・削除の請求', '内容が事実でない場合の訂正等'),
        _buildBulletItem('利用停止・消去の請求', '法令に定める場合における利用の停止または消去'),
        const SizedBox(height: 8),
        _buildParagraph('請求は、第11条のお問い合わせ窓口までご連絡ください。法令に基づき対応いたします。'),
        const SizedBox(height: 24),

        // 9. アカウントの削除およびデータの消去
        _buildSectionHeader('9.', 'アカウントの削除およびデータの消去'),
        _buildParagraph('ユーザーは、当アプリ内の設定画面等からアカウントを削除することができます。アカウント削除の操作が行われた場合、法令に基づく保存義務がある場合を除き、ユーザーの個人情報や投稿データは速やかに消去または匿名化します。'),
        const SizedBox(height: 24),

        // 10. プライバシーポリシーの変更
        _buildSectionHeader('10.', 'プライバシーポリシーの変更'),
        _buildParagraph('当アプリは、必要に応じて本ポリシーの内容を変更することがあります。変更が生じた場合は、当アプリ内での掲示やアプリのアップデートを通じてお知らせいたします。変更後も引き続き当アプリをご利用いただいた場合、変更後のプライバシーポリシーに同意したものとみなします。'),
        const SizedBox(height: 24),

        // 11. お問い合わせ窓口
        _buildSectionHeader('11.', 'お問い合わせ窓口'),
        _buildParagraph('本ポリシーに関するお問い合わせや、個人情報の取り扱いに関するご質問等がございましたら、以下の連絡先までご連絡ください。'),
        const SizedBox(height: 10),
        _buildContactRow('運営者', 'V EFFECT'),
        _buildContactRow('メールアドレス', 'V.EFFECT.developer@gmail.com'),
        const SizedBox(height: 32),

        const Divider(color: AppColors.border),
        const SizedBox(height: 12),
        _buildParagraph('制定日：2026年4月17日'),
        _buildParagraph('改定日：2026年4月17日'),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionHeader(String number, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        '$number $title',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildSubHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.7,
        ),
      ),
    );
  }

  Widget _buildBulletItem(String label, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '・',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.7),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label：',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.7,
                    ),
                  ),
                  TextSpan(
                    text: description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedItem(int number, String label, String description) {
    final hasDescription = description.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number.  ',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.7,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: hasDescription ? '$label：' : label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.7,
                    ),
                  ),
                  if (hasDescription)
                    TextSpan(
                      text: description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.7,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndentedBullet(String label, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '・',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.7),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label：',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.7,
                    ),
                  ),
                  TextSpan(
                    text: description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label：',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.7,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
