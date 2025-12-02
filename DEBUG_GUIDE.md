# 🐛 Callog - 通話画面が表示されない問題のデバッグガイド

## 📋 現在のセキュリティルール状態

✅ **確認済み**: 現在のFirestoreセキュリティルールには`calls`コレクションの権限設定が含まれています。

```javascript
// ✅ CALLS
match /calls/{callId} {
  allow read: if request.auth != null &&
    (request.auth.uid == resource.data.callerId ||
     request.auth.uid == resource.data.calleeId);
  allow create: if request.auth != null;
  allow update, delete: if request.auth != null &&
    (request.auth.uid == resource.data.callerId ||
     request.auth.uid == resource.data.calleeId);
}
```

**結論**: セキュリティルールは適切に設定されています。他の原因を探る必要があります。

---

## 🔍 ステップバイステップ診断

### ステップ 1: ブラウザコンソールを開く

**手順:**
1. Callogアプリを開く: https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai
2. キーボードの`F12`キーを押す
3. 「Console」タブを選択
4. ログをクリアする（ゴミ箱アイコン）

### ステップ 2: 通話ボタンをクリックしてログを確認

**手順:**
1. Chatタブに移動
2. 友達を選択
3. 上部の緑色の電話アイコンをクリック
4. マイク権限を許可
5. **コンソールに表示されるログをすべてコピー**

### ステップ 3: ログの分析

**正常なログの例:**
```
📞 Voice call button pressed (existing button)
📞 Requesting microphone permission...
🎤 Microphone permission granted: true
✅ Permission granted, navigating to call screen...
   Friend ID: [FRIEND_ID]
   Friend Name: [FRIEND_NAME]
📱 OutgoingVoiceCallScreen initialized
   Target: [FRIEND_NAME] ([FRIEND_ID])
🔧 Initializing WebRTC call...
✅ Current user: [YOUR_USER_ID]
🔌 Initializing WebRTC service...
🔌 Connecting to signaling server: wss://8765-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai
✅ WebRTC service initialized for user: [YOUR_USER_ID]
📞 Starting call to [FRIEND_ID]
🎤 Requesting microphone access...
✅ Microphone access granted
🔗 Creating peer connection...
📝 Creating offer...
📤 Sending offer to signaling server...
✅ Call initiated successfully to [FRIEND_ID]
```

**エラーパターンと対処法:**

#### パターン A: Firebase認証エラー
```
❌ User not authenticated
```
**原因**: ログアウト状態またはセッション切れ
**対処**: 再ログインしてください

#### パターン B: シグナリングサーバー接続エラー
```
❌ WebSocket connection failed: [error]
❌ Failed to connect to signaling server
```
**原因**: シグナリングサーバーが停止または到達不能
**対処**: 以下のコマンドでサーバー状態を確認
```bash
ps aux | grep signaling_server | grep -v grep
```

#### パターン C: マイク権限エラー
```
❌ Failed to get microphone access: NotAllowedError
```
**原因**: ブラウザがマイクアクセスをブロック
**対処**: 
1. URLバー左の🔒アイコンをクリック
2. マイク権限を「許可」に設定
3. ページをリロード

#### パターン D: 画面遷移が起こらない（エラーなし）
```
📞 Voice call button pressed (existing button)
📞 Requesting microphone permission...
🎤 Microphone permission granted: true
✅ Permission granted, navigating to call screen...
[ここで止まる - 次のログが出ない]
```
**原因**: Navigator.push が失敗している可能性
**対処**: 次のステップに進む

---

## 🔧 詳細診断: ステップ 4

### 通話画面コンポーネントの確認

もし上記のパターンDに該当する場合、以下を試してください：

**A. Networkタブでエラーを確認**
1. F12開発者ツールの「Network」タブを選択
2. 「WS」（WebSocket）フィルターを有効化
3. 通話ボタンをクリック
4. WebSocket接続の状態を確認
   - ✅ 緑色の「101 Switching Protocols」= 正常
   - ❌ 赤色のステータス = 接続失敗

**B. Elementsタブで画面表示を確認**
1. F12開発者ツールの「Elements」タブを選択
2. 通話ボタンをクリック後、HTML構造を確認
3. `OutgoingVoiceCallScreen`に関連する要素が存在するか確認

**C. エラーメッセージの確認**
1. コンソールで赤いエラーメッセージを探す
2. 特に以下のキーワードに注目:
   - `permission-denied`
   - `PERMISSION_DENIED`
   - `Failed to load`
   - `NetworkError`
   - `TypeError`

---

## 🎯 考えられる原因と対処法

### 原因 1: ローディング画面が表示されない

**症状**: マイク権限後、何も表示されない

**診断コマンド:**
```bash
# Callogのビルドログを確認
cat /tmp/callog_server.log
```

**対処**:
```bash
# アプリを再ビルド
cd /home/user/Callog
flutter build web --release
```

### 原因 2: WebRTCサービスの初期化タイムアウト

**症状**: 初期化ログは出るが、その後何も起こらない

**対処**: WebRTCサービスの初期化待機時間を延長

### 原因 3: 友達情報の取得失敗

**症状**: 友達名が`Unknown`と表示される、またはnullエラー

**診断**: Firestoreの`users`コレクションでフレンドのドキュメントが存在するか確認

---

## 🆘 緊急対処法

### A. シンプルなテスト画面で確認

以下のシンプルなボタンを試して、基本的な画面遷移が動作するか確認：

1. Profileタブに移動
2. 設定ボタンをクリック
3. 正常に画面遷移するか確認

**画面遷移が動作しない場合**: Flutter Routerの問題の可能性

### B. ブラウザのキャッシュをクリア

**手順:**
1. `Ctrl + Shift + Delete`（Windows/Linux）または`Cmd + Shift + Delete`（Mac）
2. 「キャッシュされた画像とファイル」を選択
3. 「データを削除」をクリック
4. ページをリロード（`Ctrl + F5`または`Cmd + Shift + R`）

### C. 別のブラウザで試す

- Google Chrome
- Mozilla Firefox
- Microsoft Edge

別のブラウザで正常に動作する場合、ブラウザ固有の問題です。

---

## 📊 診断チェックリスト

通話機能テストの前に、以下を確認してください：

### 必須環境
- [ ] HTTPSでアクセスしている（`https://`で始まるURL）
- [ ] ブラウザがマイク権限をサポートしている
- [ ] ユーザーがログインしている
- [ ] Chatタブで友達を選択している
- [ ] 選択した友達が有効なユーザーである

### サーバー状態
- [ ] Callogアプリサーバーが稼働（ポート5060）
- [ ] シグナリングサーバーが稼働（ポート8765）
- [ ] Firebase認証が有効
- [ ] Firestoreデータベースが作成済み

### ブラウザ設定
- [ ] JavaScriptが有効
- [ ] クッキーが有効
- [ ] マイク権限が許可されている
- [ ] キャッシュが最新

### Firebase設定
- [ ] Authentication有効（Email/Password）
- [ ] Firestore Database作成済み
- [ ] セキュリティルール設定済み（上記のルール）

---

## 📝 診断情報の収集

もし上記のすべての手順を試しても問題が解決しない場合、以下の情報を収集してください：

### 1. ブラウザコンソールログ（全体）
```
F12 > Console > 右クリック > Save as... > console.log
```

### 2. Networkログ（WebSocket接続）
```
F12 > Network > WS フィルター > スクリーンショット撮影
```

### 3. エラーメッセージ（もしあれば）
```
赤いテキストのエラーメッセージをすべてコピー
```

### 4. 環境情報
- ブラウザ名とバージョン
- OS（Windows/Mac/Linux）
- ネットワーク環境（会社/自宅/公共Wi-Fi）

### 5. 操作手順
- どのボタンをクリックしたか
- 何が表示されたか（または表示されなかったか）
- どこで動作が止まったか

---

## 🎬 動作確認ビデオ（期待される動作）

### 正常な通話開始の流れ:

```
1. [ユーザーA] Chatタブを開く
   ↓
2. [ユーザーA] 友達リストから「ユーザーB」を選択
   ↓
3. [ユーザーA] 上部の緑色の電話アイコンをクリック
   ↓
4. [ブラウザ] 「マイクの使用を許可しますか？」ダイアログ表示
   ↓
5. [ユーザーA] 「許可」をクリック
   ↓
6. [画面遷移] 「Connecting...」ローディング画面が0.5〜2秒表示
   ↓
7. [画面遷移] OutgoingVoiceCallScreen が表示される
   - 友達のアバター
   - 友達の名前
   - 「Calling...」ステータス
   - コントロールボタン（ミュート、スピーカー、終了）
   ↓
8. [シグナリング] WebSocketでシグナリングサーバーに接続
   ↓
9. [WebRTC] P2P接続を確立
   ↓
10. [相手が応答] ステータスが「Connected」に変更
    ↓
11. [通話開始] 音声が聞こえる
```

---

## ✅ 解決後の確認

通話画面が正常に表示されるようになったら:

1. ✅ 友達のアバターと名前が表示される
2. ✅ 「Calling...」または「Connected」ステータスが表示される
3. ✅ コントロールボタンが動作する
4. ✅ 終了ボタンでチャット画面に戻る

---

**次のステップ**: 上記の診断手順を実行し、コンソールログを確認してください。具体的なエラーメッセージがあれば、それを共有していただければ、さらに詳しくサポートできます。

最終更新: 2024年12月2日
