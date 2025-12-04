# Cloud Functions デプロイメントガイド

## 📋 概要

Callog アプリは以下の Cloud Functions を使用します:

1. **sendPushNotification** - プッシュ通知の送信
2. **generateAgoraToken** - Agora RTCトークンの生成
3. **cleanupOldNotifications** - 古い通知の自動削除

## 🚀 デプロイ手順

### 1. Firebase CLI にログイン

```bash
cd /home/user/Callog
firebase login
```

### 2. プロジェクトを確認

```bash
firebase projects:list
```

### 3. 環境変数の設定 (オプション - Agoraトークン生成用)

Agora App Certificate を設定する場合:

```bash
firebase functions:config:set agora.app_certificate="YOUR_AGORA_APP_CERTIFICATE"
```

**重要**: App Certificate を設定しない場合、Agoraトークン生成は無効化され、null トークンが返されます。これはテスト環境では問題ありませんが、本番環境では設定を推奨します。

### 4. Cloud Functions をデプロイ

```bash
firebase deploy --only functions
```

または、特定の関数のみデプロイ:

```bash
# プッシュ通知関数のみ
firebase deploy --only functions:sendPushNotification

# Agoraトークン生成関数のみ
firebase deploy --only functions:generateAgoraToken

# 全ての関数
firebase deploy --only functions
```

## 🔧 デプロイ後の確認

### 1. Firebase Console で確認

https://console.firebase.google.com/ にアクセスし、以下を確認:

1. **Functions** セクションで3つの関数がデプロイされていることを確認
2. **ログ** で関数の実行状況を確認

### 2. Flutter アプリでテスト

1. Web版アプリにアクセス: https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai
2. 音声通話を開始
3. ブラウザの開発者ツールで以下を確認:
   - `[Push] 📤 Sending notification via Cloud Functions` のログ
   - `[AgoraToken] 🎫 Generating token for channel` のログ
   - エラーがないことを確認

## 📊 Cloud Functions の詳細

### sendPushNotification

**説明**: FCM を使用してプッシュ通知を送信

**パラメータ**:
- `peerId`: 送信先ユーザーID
- `channelId`: 通話チャンネルID
- `callType`: 'voice_call' または 'video_call'
- `callerName`: 発信者名

**利点**:
- ✅ CORS エラーなし (サーバーサイド実行)
- ✅ FCM Server Key をクライアントに露出しない
- ✅ より安全で管理しやすい

### generateAgoraToken

**説明**: Agora RTC トークンを安全に生成

**パラメータ**:
- `channelName`: チャンネル名
- `uid`: ユーザーID (0で自動割り当て)
- `role`: 'publisher' または 'audience'

**戻り値**:
- `token`: RTCトークン (App Certificate未設定の場合は null)
- `appId`: Agora App ID
- `channelName`: チャンネル名
- `uid`: ユーザーID
- `expiresAt`: トークン有効期限 (Unix timestamp)

**利点**:
- ✅ App Certificate をクライアントに露出しない
- ✅ トークン改ざん防止
- ✅ 本番環境でのセキュリティ強化

### cleanupOldNotifications

**説明**: 1時間ごとに古い通知を自動削除

**実行**: 自動 (Pub/Sub スケジュール)

**対象**: 1時間以上経過した通知レコード

## 🔍 トラブルシューティング

### エラー: "Failed to authenticate"

```bash
firebase login --reauth
```

### エラー: "Permission denied"

Firebase Console でプロジェクトの権限を確認してください。

### 関数が呼び出されない

1. Firebase Console の Functions ログを確認
2. Flutter アプリのブラウザコンソールでエラーを確認
3. 関数がデプロイされているか確認: `firebase functions:list`

### Agora エラー -17 (INVALID_TOKEN)

1. App Certificate が正しく設定されているか確認
2. トークンの有効期限が切れていないか確認
3. チャンネル名とUIDが一致しているか確認

## 📝 本番環境への移行

### 1. Agora App Certificate の設定

```bash
firebase functions:config:set agora.app_certificate="YOUR_APP_CERTIFICATE"
firebase deploy --only functions:generateAgoraToken
```

### 2. セキュリティルールの強化

Firestore セキュリティルールで、call_notifications コレクションへのアクセスを制限してください。

### 3. 監視とアラートの設定

Firebase Console で、関数のエラー率と実行時間を監視するアラートを設定してください。

## 🎉 完了!

これで Cloud Functions が正常にデプロイされ、Callog アプリで使用できるようになりました。

プッシュ通知と Agora トークン生成が Cloud Functions 経由で動作します!
