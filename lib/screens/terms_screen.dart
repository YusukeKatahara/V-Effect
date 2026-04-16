import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// 利用規約を表示するスクリーン
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        title: const Text(
          '利用規約',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: TermsContent(),
      ),
    );
  }
}

/// 利用規約の本文ウィジェット。
///
/// [TermsScreen] と [TermsAgreementScreen] の両方から利用される。
class TermsContent extends StatelessWidget {
  const TermsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 前文
        _buildParagraph(
          '本利用規約（以下、「本規約」といいます。）は、本アプリ「V EFFECT」（以下、「本アプリ」といいます。）の利用条件を定めるものです。インストールおよび利用を開始する前に、必ず本規約をよくお読みください。',
        ),
        const SizedBox(height: 24),

        // 第1条
        _buildArticleHeader('第1条', '適用'),
        _buildParagraph('本規約は、ユーザーと開発者・運営者（以下、「運営者」といいます。）との間の、本アプリの利用に関わる一切の関係に適用されるものとします。'),
        const SizedBox(height: 24),

        // 第2条
        _buildArticleHeader('第2条', 'ユーザー登録とアカウント管理'),
        _buildArticleItem(1, '本アプリの利用を希望する者は、本規約に同意した上で、運営者の定める方法によりユーザー登録を行うものとします。'),
        _buildArticleItem(2, 'ユーザーは、自己の責任において、本アプリのアカウント情報およびパスワードを適切に管理・保管するものとし、これを第三者に利用させたり、貸与、譲渡、名義変更、売買等をしてはならないものとします。'),
        _buildArticleItem(3, 'アカウント情報およびパスワードの管理不十分、使用上の過誤、第三者の使用等によって生じた損害に関する責任はユーザーが負うものとします。'),
        _buildArticleItem(4, '本アプリは13歳以上の方を対象としています。13歳未満の方は利用できません。'),
        const SizedBox(height: 24),

        // 第3条
        _buildArticleHeader('第3条', 'サービスの内容'),
        _buildParagraph('本アプリは、成長とモチベーション維持を目的とした全肯定型のSNSとして、主に以下の機能を提供します。'),
        const SizedBox(height: 6),
        _buildSimpleBullet('日々の努力の過程を写真とともに共有する機能'),
        _buildSimpleBullet('自己成長の可視化機能（ストリーク要素）'),
        _buildSimpleBullet('自身の投稿を行ったユーザーのみが、友人などの限られたコミュニティ内で他のユーザーの投稿を閲覧できる機能'),
        _buildSimpleBullet('他のユーザーの投稿に対して称賛を送る機能'),
        const SizedBox(height: 24),

        // 第4条
        _buildArticleHeader('第4条', '禁止事項'),
        _buildParagraph('ユーザーは、本アプリの利用にあたり、以下の行為をしてはなりません。'),
        const SizedBox(height: 6),
        _buildArticleItem(1, '法令、裁判所の判決、決定もしくは命令、または法令上拘束力のある行政措置に違反する行為、またはこれらを助長する行為'),
        _buildArticleItem(2, '公序良俗に反する行為'),
        _buildArticleItem(3, '運営者、本アプリの他のユーザーまたは第三者の著作権、商標権等の知的財産権、肖像権、プライバシー権、名誉、その他の権利または利益を侵害する行為'),
        _buildArticleItem(4, '本アプリの趣旨に反する、暴力的、わいせつ的、差別的な表現や、他のユーザーに不快感を与えるコンテンツの投稿や送信'),
        _buildArticleItem(5, '面識のない第三者との出会いを目的とする行為'),
        _buildArticleItem(6, '本アプリの提供する機能、ネットワークまたはシステム等に過度な負荷をかける行為、または本アプリの不具合を意図的に利用する行為（チートツール等の不正利用を含む）'),
        _buildArticleItem(7, '運営者、他のユーザー、または第三者になりすます行為'),
        _buildArticleItem(8, '他のユーザーの個人情報等を無断で収集、蓄積する行為'),
        _buildArticleItem(9, 'その他、運営者が不適切と判断する行為'),
        const SizedBox(height: 24),

        // 第5条
        _buildArticleHeader('第5条', 'コンテンツの権利'),
        _buildArticleItem(1, 'ユーザーが本アプリに投稿した写真、テキスト等のコンテンツ（以下、「投稿データ」といいます。）の著作権は、当該ユーザーまたは当該ユーザーに利用を許諾した第三者に留保されます。'),
        _buildArticleItem(2, 'ユーザーは、本アプリ内でのサービス提供および本アプリの普及・宣伝等の目的の範囲内において、運営者が投稿データを無償で非独占的に使用、複製、改変、配布等をすることを許諾するものとします。'),
        _buildArticleItem(3, 'ユーザーは、投稿データについて、適法な権利を有していること、および第三者の権利を侵害していないことを運営者に対し表明し、保証するものとします。'),
        const SizedBox(height: 24),

        // 第6条
        _buildArticleHeader('第6条', '本アプリの提供の停止等'),
        _buildParagraph('運営者は、以下のいずれかの事由があると判断した場合、ユーザーに事前に通知することなく本アプリの全部または一部の提供を停止または中断することができるものとします。'),
        const SizedBox(height: 6),
        _buildArticleItem(1, '本アプリにかかるコンピュータシステムの保守点検または更新を行う場合'),
        _buildArticleItem(2, '地震、落雷、火災、停電または天災などの不可抗力により、本アプリの提供が困難となった場合'),
        _buildArticleItem(3, '通信回線等が事故により停止した場合'),
        _buildArticleItem(4, 'その他、運営者が本アプリの提供が困難と判断した場合'),
        const SizedBox(height: 24),

        // 第7条
        _buildArticleHeader('第7条', '利用制限および登録抹消'),
        _buildParagraph('運営者は、ユーザーが本規約のいずれかの条項に違反した場合、または運営者が本アプリの利用を適当でないと判断した場合には、事前の通知なく、ユーザーに対して本アプリの全部もしくは一部の利用を制限し、またはユーザーとしての登録を抹消することができるものとします。'),
        const SizedBox(height: 24),

        // 第8条
        _buildArticleHeader('第8条', '退会'),
        _buildParagraph('ユーザーは、運営者の定める退会手続きにより、本アプリ内の設定画面から退会できるものとします。'),
        const SizedBox(height: 24),

        // 第9条
        _buildArticleHeader('第9条', '保証の否認および免責事項'),
        _buildArticleItem(1, '運営者は、本アプリに事実上または法律上の瑕疵（安全性、信頼性、正確性、その他の欠陥）がないことを明示的にも黙示的にも保証しません。'),
        _buildArticleItem(2, '運営者は、運営者の故意または重過失に起因する場合を除き、本アプリに起因してユーザーに生じた損害について責任を負いません。ただし、消費者契約法の適用その他の理由により運営者の免責が認められない場合でも、運営者の責任は、運営者の過失（重過失を除きます。）による債務不履行または不法行為によりユーザーに生じた直接かつ通常の損害に限られるものとします。'),
        _buildArticleItem(3, '運営者は、本アプリに関して、ユーザーと他のユーザーまたは第三者との間において生じた取引、連絡または紛争等について一切責任を負いません。'),
        const SizedBox(height: 24),

        // 第10条
        _buildArticleHeader('第10条', 'サービス内容の変更等'),
        _buildParagraph('運営者は、ユーザーに通知することなく、本アプリの内容や仕様の変更、または本アプリの提供を中止・終了することができるものとし、これによってユーザーに生じた損害について一切の責任を負いません。'),
        const SizedBox(height: 24),

        // 第11条
        _buildArticleHeader('第11条', '利用規約の変更'),
        _buildParagraph('変更後の規約は、本アプリ内での掲示またはアップデート通知によりユーザーへ周知します。周知後に本アプリを継続利用した場合、変更後の規約に同意したものとみなします。'),
        const SizedBox(height: 24),

        // 第12条
        _buildArticleHeader('第12条', '個人情報の取扱い'),
        _buildParagraph('本アプリの利用によって取得する個人情報の取り扱いについては、別途定める「プライバシーポリシー」に従い適切に取り扱うものとします。'),
        const SizedBox(height: 24),

        // 第13条
        _buildArticleHeader('第13条', '分離可能性'),
        _buildParagraph('本規約のいずれかの条項またはその一部が、法令等により無効または執行不能と判断された場合であっても、本規約の残りの規定は、継続して完全に効力を有するものとします。'),
        const SizedBox(height: 24),

        // 第14条
        _buildArticleHeader('第14条', '準拠法・裁判管轄'),
        _buildArticleItem(1, '本規約の解釈にあたっては、日本法を準拠法とします。'),
        _buildArticleItem(2, '本アプリに関して紛争が生じた場合には、新潟地方裁判所または新潟簡易裁判所を第一審の専属的合意管轄裁判所とします。'),
        const SizedBox(height: 24),

        _buildParagraph('以上'),
        const SizedBox(height: 24),

        // お問い合わせ先
        _buildSubHeader('お問い合わせ先'),
        _buildParagraph('本アプリに関するお問い合わせは、以下の窓口までご連絡ください。'),
        const SizedBox(height: 8),
        _buildContactRow('V EFFECT開発チーム', 'V.EFFECT.developer@gmail.com'),
        const SizedBox(height: 32),

        const Divider(color: AppColors.border),
        const SizedBox(height: 12),
        _buildParagraph('制定日：2026年4月16日'),
        _buildParagraph('改訂日：2026年4月16日'),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 「第N条（タイトル）」形式の条見出し
  Widget _buildArticleHeader(String article, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        '$article（$title）',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
    );
  }

  /// 「お問い合わせ先」等の小見出し
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

  /// 本文段落
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

  /// 番号付き条文項目（「1. 条文テキスト」形式）
  Widget _buildArticleItem(int number, String text) {
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
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ラベルなし箇条書き（第3条のサービス内容リスト用）
  Widget _buildSimpleBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '・',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.7,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// お問い合わせ先のキーバリュー表示
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
