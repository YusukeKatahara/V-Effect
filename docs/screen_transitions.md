# V EFFECT 画面遷移図

```mermaid
flowchart TD
    %% ===== スタイル定義 =====
    classDef auth fill:#4a1942,stroke:#e91e63,color:#fff
    classDef setup fill:#1a237e,stroke:#42a5f5,color:#fff
    classDef main fill:#1b5e20,stroke:#66bb6a,color:#fff
    classDef sub fill:#e65100,stroke:#ffa726,color:#fff
    classDef shell fill:#004d40,stroke:#26a69a,color:#fff

    %% ===== 認証フロー =====
    LOGIN["LoginScreen\n/login\n(初期画面)"]:::auth
    REGISTER["RegisterScreen\n/register"]:::auth

    %% ===== 初期設定フロー =====
    PROFILE_SETUP["ProfileSetupScreen\n/profile-setup\n(Step 1/2)"]:::setup
    TASK_SETUP["TaskSetupScreen\n/task-setup\n(Step 2/2)"]:::setup

    %% ===== メインシェル =====
    MAIN_SHELL["MainShell\n/home\n(BottomNavigationBar)"]:::shell

    %% ===== メインタブ画面 =====
    HOME["HomeScreen\n(タブ0: ホーム)"]:::main
    PROFILE["ProfileScreen\n(タブ2: プロフィール)"]:::main

    %% ===== サブ画面 =====
    CAMERA["CameraScreen\n/camera"]:::sub
    FRIENDS["FriendsScreen\n/friends"]:::sub
    NOTIFICATIONS["NotificationsScreen\n/notifications"]:::sub
    EDIT_PROFILE["EditProfileScreen\n(MaterialPageRoute)"]:::sub
    FRIEND_FEED["FriendFeedScreen\n(Stories風ビューアー)"]:::sub

    %% ===== 認証フロー =====
    LOGIN -- "新規登録はこちら\n(push)" --> REGISTER
    LOGIN -- "ログイン成功\n(pushReplacement)" --> MAIN_SHELL
    LOGIN -- "Google/Appleログイン\n(pushReplacement)" --> MAIN_SHELL
    REGISTER -- "アカウント作成成功\n(pushReplacement)" --> PROFILE_SETUP
    REGISTER -- "Google/Apple登録\n(pushReplacement)" --> PROFILE_SETUP

    %% ===== 初期設定フロー =====
    PROFILE_SETUP -- "次へ\n(pushReplacement)" --> TASK_SETUP
    TASK_SETUP -- "設定を完了してはじめる\n(pushReplacement)" --> MAIN_SHELL

    %% ===== メインシェル内のタブ =====
    MAIN_SHELL -. "タブ0" .-> HOME
    MAIN_SHELL -. "タブ2" .-> PROFILE
    MAIN_SHELL -- "タブ1 (カメラアイコン)\n(push)" --> CAMERA

    %% ===== HomeScreen からの遷移 =====
    HOME -- "通知ベルアイコン\n(push)" --> NOTIFICATIONS
    HOME -- "フレンドアイコンタップ\n(push, 投稿済みの場合のみ)" --> FRIEND_FEED

    %% ===== ProfileScreen からの遷移 =====
    PROFILE -- "編集アイコン\n(push)" --> EDIT_PROFILE
    PROFILE -- "通知ベルアイコン\n(push)" --> NOTIFICATIONS
    PROFILE -- "フレンドボタン\n(push)" --> FRIENDS
    PROFILE -- "ログアウト\n(pushReplacement)" --> LOGIN

    %% ===== サブ画面からの戻り =====
    CAMERA -- "投稿完了 / 戻る\n(pop)" --> MAIN_SHELL
    EDIT_PROFILE -- "保存完了 / 戻る\n(pop)" --> PROFILE
    FRIEND_FEED -- "最後まで閲覧 / 閉じる\n(pop)" --> HOME
```

## 画面一覧

| 画面名 | ルート | 説明 |
|--------|--------|------|
| LoginScreen | `/login` | ログイン画面（初期画面） |
| RegisterScreen | `/register` | 新規登録画面 |
| ProfileSetupScreen | `/profile-setup` | プロフィール設定（Step 1/2） |
| TaskSetupScreen | `/task-setup` | タスク設定（Step 2/2） |
| MainShell | `/home` | BottomNavigationBar付きシェル |
| HomeScreen | (タブ0) | ホーム画面（ストリーク・タスク表示） |
| ProfileScreen | (タブ2) | プロフィール表示画面 |
| CameraScreen | `/camera` | 写真撮影・投稿画面 |
| FriendsScreen | `/friends` | フレンド管理画面 |
| NotificationsScreen | `/notifications` | 通知一覧画面 |
| EditProfileScreen | (MaterialPageRoute) | プロフィール編集画面 |
| FriendFeedScreen | (MaterialPageRoute) | フレンド投稿ビューアー（Stories風） |

## 遷移の種類

- **pushReplacement**: 現在の画面を置き換え（戻るボタンなし）
- **push**: 画面をスタックに追加（戻れる）
- **pop**: 前の画面に戻る
