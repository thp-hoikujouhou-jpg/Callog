# 🔔 プッシュ通知セットアップガイド

## 現在の状況

- ✅ Agoraトークン生成: 動作中
- ⚠️ プッシュ通知: FCM_SERVER_KEY が必要

---

## 🔑 FCM Server Key の取得方法

### **Step 1: Firebase Console を開く**

以下のURLにアクセス:
```
https://console.firebase.google.com/project/callog-30758/settings/cloudmessaging
```

### **Step 2: Cloud Messaging タブを選択**

1. **Project settings** (歯車アイコン) をクリック
2. **Cloud Messaging** タブを選択
3. **Cloud Messaging API (Legacy)** セクションを探す

### **Step 3: Server Key をコピー**

**Server key** の値をコピーしてください。形式:
```
AAAAxxxxxxx:APA91bHxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**⚠️ 注意:** 
- この Server Key は**シークレット**です
- 絶対に公開リポジトリにコミットしないでください
- Vercel環境変数として安全に保管します

---

## 🚀 Vercel 環境変数の設定

### **Step 1: Vercel ダッシュボードを開く**

以下のURLにアクセス:
```
https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2/settings/environment-variables
```

### **Step 2: 新しい環境変数を追加**

| Key | Value | Environments | Sensitive |
|-----|-------|--------------|-----------|
| `FCM_SERVER_KEY` | `AAAAxxxxxxx:APA91bH...` (Firebase Consoleからコピー) | ✅ Production, Preview, Development | ✅ Enabled |

**重要:** 
- ✅ **Sensitive** を必ず有効化してください
- ✅ 全ての環境 (Production, Preview, Development) にチェック

### **Step 3: 再デプロイ**

環境変数を追加したら、必ず再デプロイが必要です:

```bash
cd C:\Users\admin\Downloads\callog-api-v2
vercel --prod
```

---

## 📊 必要な環境変数の一覧

現在設定されているべき環境変数:

| 変数名 | 値 | 用途 | 状態 |
|--------|-----|------|------|
| `FIREBASE_PROJECT_ID` | `callog-30758` | Firebase プロジェクト識別 | ✅ 設定済み |
| `AGORA_APP_ID` | `d1a8161eb70448d89eea1722bc169c92` | Agora トークン生成 | ✅ 設定済み |
| `AGORA_APP_CERTIFICATE` | `(Agora Consoleから取得)` | Agora トークン生成 | ✅ 設定済み |
| `FCM_SERVER_KEY` | `AAAAxxxxxxx:APA91bH...` | プッシュ通知送信 | ❌ **要追加** |

---

## 🧪 テスト手順

### **Step 1: デプロイ完了を確認**

再デプロイ後、以下のコマンドでテスト:

```bash
curl -X POST https://callog-api-v2.vercel.app/api/sendPushNotification \
  -H "Content-Type: application/json" \
  -d "{\"data\":{\"peerId\":\"test_user_id\",\"channelId\":\"test_channel\",\"callType\":\"voice_call\",\"callerName\":\"Test User\"}}"
```

### **Step 2: 期待されるレスポンス**

**✅ FCM_SERVER_KEY 設定済み:**
```json
{
  "data": {
    "success": true,
    "messageId": "0:1234567890123456%abcdef",
    "message": "Push notification sent successfully"
  }
}
```

**⚠️ FCM_SERVER_KEY 未設定:**
```json
{
  "data": {
    "success": true,
    "message": "Push notification simulated (FCM_SERVER_KEY not configured)",
    "messageId": null,
    "note": "Set FCM_SERVER_KEY environment variable to enable push notifications"
  }
}
```

---

## 📱 Flutter アプリでのテスト

### **Step 1: 2つのブラウザでログイン**

1. **ブラウザ A**: ユーザー1でログイン
2. **ブラウザ B**: ユーザー2でログイン

### **Step 2: 通話を開始**

1. **ブラウザ A**: ユーザー2に音声通話を発信
2. **ブラウザ B**: プッシュ通知を受信 (ブラウザ通知)

### **Step 3: コンソールログを確認**

**発信側 (ブラウザ A):**
```
[Push] 📤 Sending notification via Cloud Functions
[Push] ✅ Notification sent successfully!
[Push] Message ID: 0:1234567890123456%abcdef
```

**着信側 (ブラウザ B):**
```
[Push] Incoming call notification: voice_call from User1
```

---

## 🔧 トラブルシューティング

### **問題 1: FCM Server Key が見つからない**

**原因:** Cloud Messaging API (Legacy) が無効になっている

**解決策:**
1. Firebase Console → Cloud Messaging
2. **Cloud Messaging API (Legacy)** を有効化
3. Server Key が表示される

---

### **問題 2: プッシュ通知が届かない**

**考えられる原因:**

1. **FCM Token が登録されていない**
   - ユーザーが再ログインする必要がある
   - コンソールログで FCM Token を確認

2. **ブラウザ通知権限が拒否されている**
   - ブラウザの設定で通知を許可

3. **FCM_SERVER_KEY が間違っている**
   - Firebase Console で正しいキーをコピー
   - Vercel環境変数を再確認

---

### **問題 3: Firestore 接続エラー**

**エラーメッセージ:**
```
Error: Could not load the default credentials
```

**解決策:**
Vercelは自動的にFirestoreにアクセスできます。`FIREBASE_PROJECT_ID`環境変数が正しく設定されていることを確認してください。

---

## 📋 チェックリスト

プッシュ通知を有効化する前に:

- [ ] Firebase Console で FCM Server Key を取得
- [ ] Vercel環境変数 `FCM_SERVER_KEY` を追加 (Sensitive有効化)
- [ ] `vercel --prod` で再デプロイ
- [ ] API エンドポイントでテスト (`curl`コマンド)
- [ ] Flutter アプリで実際の通話テスト

---

## 🎯 次のステップ

1. **Firebase Console で FCM Server Key を取得**
   - URL: https://console.firebase.com/project/callog-30758/settings/cloudmessaging

2. **Vercel 環境変数に追加**
   - URL: https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2/settings/environment-variables

3. **再デプロイ**
   ```bash
   cd C:\Users\admin\Downloads\callog-api-v2
   vercel --prod
   ```

4. **Flutter アプリでテスト**
   - 2つのブラウザで通話テスト
   - プッシュ通知が表示されるか確認

---

## 💡 重要な注意事項

- **FCM Server Key**: 絶対に公開しないでください
- **再デプロイ必須**: 環境変数を追加したら必ず再デプロイ
- **ブラウザ通知権限**: ユーザーが通知を許可する必要があります
- **FCM Token**: ユーザーが最低1回ログインしている必要があります

プッシュ通知の設定が完了すれば、相手に着信通知が届くようになります! 🚀
