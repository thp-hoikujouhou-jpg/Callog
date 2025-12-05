# Cloud Functions デプロイ手順

## 🎯 概要

CallogアプリのCORSエラーを解決するため、Cloud FunctionsをHTTPS関数に変更しました。
以下の手順で、修正されたCloud FunctionsをFirebaseにデプロイしてください。

## 🔧 変更内容

### 1. Cloud Functions (index.js)
- `onCall` → `onRequest` に変更
- CORS対応の追加 (`cors` パッケージ使用)
- すべてのCloud FunctionsがWeb環境からのリクエストを受け付けられるようになりました

### 2. Flutter アプリ (Dart)
- `httpsCallable()` → `http.post()` に変更
- 直接HTTPリクエストを送信するように変更
- `agora_token_service.dart` と `push_notification_service.dart` を更新

## 📝 デプロイ手順

### ステップ 1: Firebase CLIにログイン

```bash
firebase login
```

ブラウザが開き、Googleアカウントでログインします。

### ステップ 2: プロジェクトディレクトリに移動

```bash
cd /home/user/Callog
```

### ステップ 3: Cloud Functionsをデプロイ

```bash
firebase deploy --only functions
```

デプロイには数分かかります。完了すると、以下のようなメッセージが表示されます:

```
✔  functions: Finished running predeploy script.
i  functions: ensuring required API cloudfunctions.googleapis.com is enabled...
✔  functions: required API cloudfunctions.googleapis.com is enabled
i  functions: preparing functions directory for uploading...
i  functions: packaged functions (XX.XX KB) for uploading
✔  functions: functions folder uploaded successfully
i  functions: updating Node.js 20 function generateAgoraToken(us-central1)...
i  functions: updating Node.js 20 function sendPushNotification(us-central1)...
✔  functions[generateAgoraToken(us-central1)]: Successful update operation.
✔  functions[sendPushNotification(us-central1)]: Successful update operation.

✔  Deploy complete!
```

### ステップ 4: デプロイの確認

デプロイが成功したら、Firebase Consoleで確認できます:

1. https://console.firebase.google.com/
2. Callog プロジェクトを選択
3. 左メニューから「Functions」を選択
4. 以下の2つの関数が表示されていることを確認:
   - `generateAgoraToken`
   - `sendPushNotification`

## 🧪 テスト手順

### 1. Flutterアプリを再起動

デプロイ完了後、Flutterアプリを再起動してください:

```bash
cd /home/user/Callog
flutter clean
flutter pub get
flutter run -d chrome
```

### 2. 通話機能をテスト

1. アプリにログインします
2. 友達を選択して音声通話またはビデオ通話を開始します
3. コンソールログを確認します:
   - `[AgoraToken] ✅ Token generated successfully` が表示されること
   - `[Push] ✅ Notification sent successfully!` が表示されること
   - CORSエラーが表示されないこと

## 🔍 トラブルシューティング

### エラー: "CORS policy"

もしまだCORSエラーが発生する場合:

1. ブラウザのキャッシュをクリア
2. シークレットモードでアプリを開く
3. Cloud Functionsが正しくデプロイされているか確認:
   ```bash
   firebase functions:list
   ```

### エラー: "Failed to deploy functions"

デプロイエラーが発生する場合:

1. Firebase CLIのバージョンを確認:
   ```bash
   firebase --version
   ```
   最新版でない場合は更新:
   ```bash
   npm install -g firebase-tools
   ```

2. 依存関係を再インストール:
   ```bash
   cd functions
   rm -rf node_modules
   npm install
   cd ..
   firebase deploy --only functions
   ```

### エラー: "Agora App Certificate not configured"

Agora App Certificateが設定されていない警告が表示される場合:

1. Agora Consoleにアクセス: https://console.agora.io/
2. プロジェクトを選択
3. App Certificateを有効化してコピー
4. Firebase Consoleで環境変数を設定:
   - Functions → 設定 → 環境変数
   - `AGORA_APP_CERTIFICATE` = `<コピーしたApp Certificate>`

## 📦 デプロイされる関数

### 1. generateAgoraToken

**エンドポイント**: `https://us-central1-callog-30758.cloudfunctions.net/generateAgoraToken`

**リクエスト例**:
```json
{
  "data": {
    "channelName": "test_channel",
    "uid": 0,
    "role": "publisher"
  }
}
```

**レスポンス例**:
```json
{
  "data": {
    "token": "006...",
    "appId": "d1a8161eb70448d89eea1722bc169c92",
    "channelName": "test_channel",
    "uid": 0,
    "expiresAt": 1733378400
  }
}
```

### 2. sendPushNotification

**エンドポイント**: `https://us-central1-callog-30758.cloudfunctions.net/sendPushNotification`

**リクエスト例**:
```json
{
  "data": {
    "peerId": "user123",
    "channelId": "call_abc123",
    "callType": "voice_call",
    "callerName": "田中太郎",
    "callerId": "user456"
  }
}
```

**レスポンス例**:
```json
{
  "data": {
    "success": true,
    "messageId": "projects/callog-30758/messages/1234567890"
  }
}
```

## ✅ 完了チェックリスト

- [ ] Firebase CLIにログイン完了
- [ ] `firebase deploy --only functions` 実行完了
- [ ] Firebase Consoleで関数が表示されている
- [ ] Flutterアプリを再起動
- [ ] 通話機能が正常に動作している
- [ ] コンソールにCORSエラーが表示されない

## 📞 サポート

問題が解決しない場合は、以下の情報を含めてお問い合わせください:

1. エラーメッセージ全文
2. `firebase functions:log` の出力
3. ブラウザのコンソールログ
4. 実行したコマンドと出力

---

**最終更新**: 2024-12-04
**バージョン**: 1.0.0
