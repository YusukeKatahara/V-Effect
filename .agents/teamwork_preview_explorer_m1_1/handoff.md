# Handoff Report — Role Model Feature Design

## 1. Observation (観察)
本調査において、既存コードおよびコマンドの実行から以下の事実を確認しました。

1.  **データモデル (`lib/models/app_user.dart`)**
    *   `AppUser` クラスは、`uid`（ユーザーUID）、`username`（ユーザー名）、`userId`（`@` から始まる個別ID）、`photoUrl`（アバター画像URL）、`following`（フォローしているUIDのリスト）、`followers`（フォロワーのUIDのリスト）、`tasks`（`AppTask` のリスト）、`totalPosts`（全投稿数）などの属性を持ちます。
    *   非公開データ（`email`, `birthDate`, `gender`, `occupation`）は、サブコレクション `users/{uid}/private/data` に格納されています（`UserService.saveProfile` などのバッチ書き込みにて確認）。
2.  **Firestore通信・バッチ・トランザクション処理 (`lib/services/friend_service.dart`, `lib/services/user_service.dart`)**
    *   `FriendService` はフォロー要求時に `FieldValue.arrayUnion` を含む `WriteBatch`（書き込みバッチ）を使用して、`following` および `followers` をアトミックに更新しています。
    *   `UserService` も同様に `writeBatch` を用いて、公開情報（`users/{uid}`）と非公開情報（`users/{uid}/private/data`）を同時に書き込んで整合性を担保しています。
    *   多重実行防止のために `final Set<String> _processingLocks = {};` というメモリ内ロック機構が導入されています。
3.  **UI構造と遷移フロー (`lib/screens/home_screen.dart`, `lib/screens/user_profile_screen.dart`, `lib/screens/home/components/feed_card.dart`)**
    *   Vタイムライン内のアバターをタップすると、`FeedCard` 内の `onProfileTap` が呼ばれ、`Navigator.pushNamed(context, AppRoutes.userProfile, arguments: {'uid': post.userId, 'username': username, 'photoUrl': photoUrl})` によって他ユーザーのプロフィール画面 `UserProfileScreen` に遷移します。
    *   `UserProfileScreen` では、`FriendService.getUserByUid` を使って相手の公開データおよびタスク一覧（`_user.tasks`）を表示しています。
4.  **Flutter Analyze 実行結果**
    *   `flutter analyze` の実行結果、`lib/` ディレクトリ配下の本番用ソースコードにはコンパイルエラーや静的解析エラーは存在せず、一部の `scratch/` ディレクトリ（検証用スクリプト等）で軽微な警告（`Empty catch block` や `avoid_print` 等）が発生しているのみであることを確認しました。

---

## 2. Logic Chain (論理の連鎖)
1.  **ロールモデルとの関連性表現 (Firestore)**
    *   既存のフォロー/フォロワー関係は `AppUser` ドキュメント内の `following`/`followers` 配列フィールドに格納されていますが、これは最大件数制限（Firestoreドキュメントの1MB上限）の影響を受けやすいため、ロールモデル関係（憧れのユーザーの登録）にはサブコレクション方式 `users/{uid}/role_models/{targetUid}` を採用します。
    *   これにより、ユーザーごとに無制限にロールモデルを登録でき、セキュリティルールも「自分自身のドキュメント配下のみ読み書き可能」と記述できるため堅牢です。
2.  **パフォーマンスとコストの最適化 (キャッシュ)**
    *   ロールモデル一覧画面で各ロールモデルの「アバター画像」「表示名」「ユーザー名」を表示する際、都度 `users/{targetUid}` を読み込むと、Firestoreの読み込み回数（Read）が急増します。
    *   これを解決するため、登録時に `displayName`、`username`、`photoUrl` を `users/{uid}/role_models/{targetUid}` 内にキャッシュ（冗長保存）する設計が合理的です。
3.  **アクティビティ（タスク達成率）の動的算出**
    *   ロールモデルのタスク達成率は、ロールモデルの `AppUser.tasks` に含まれるタスク総数（N）と、該当日に `posts` コレクションに投稿されたユニークな `taskName` の数（M）をクライアントサイドで動的にマッチングさせて `M / N` として算出します。
    *   このアプローチにより、データベース更新の不整合リスク（バグ）を排除しながら、常に正確な達成率（パーセンテージ）をリアルタイムに表示することができます。

---

## 3. Caveats (留保事項)
*   **キャッシュ情報の同期**: ロールモデルがプロフィール画像や表示名を更新した場合、`role_models` サブコレクションに保存されたキャッシュが古くなる可能性があります。これについては、Cloud Functionsを用いてプロフィール更新時に非同期でロールモデル側のキャッシュを更新する、あるいはアプリ起動時にバックグラウンドで同期する仕組みが将来的に必要となります。
*   **プライベートアカウント**: 対象ユーザーが非公開アカウント（`isPrivateAccount == true`）の場合、ロールモデルとして登録できるのは「相互フォロー」または「自分がフォロー承認されている」状態に限る必要があります。これに関する制限ロジックを `RoleModelService.registerRoleModel` でチェックする必要があります。

---

## 4. Conclusion (結論)
ロールモデル機能は、既存 Hug された `AppUser` データモデルや `FriendService` / `UserService` の設計思想（バッチ書き込み、非同期処理、型安全なDTO変換）と高い親和性を持って実装可能です。
具体的な設計詳細は、作成した設計書 `/Users/rennlikeu/development/V-Effect/docs/role_model_design.md` にすべて取りまとめました。この設計書は初学者である renn さんが容易に理解し実装を開始できるよう、分かりやすい言葉での用語説明や詳細な比較検討を含めて記述しています。

---

## 5. Verification Method (検証方法)
*   **設計書の確認**: `/Users/rennlikeu/development/V-Effect/docs/role_model_design.md` が正しく作成され、画面遷移・スキーマ定義・サービスレイヤーの規約が日本語で漏れなく記載されていることを確認する。
*   **静的解析の確認**: `/Users/rennlikeu/development/V-Effect` ディレクトリで `flutter analyze` を実行し、`lib/` ディレクトリ配下にエラーが発生していないことを確認する。
