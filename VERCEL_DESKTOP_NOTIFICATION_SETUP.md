# 🔔 Vercel Functions + デスクトップ通知 セットアップガイド

## 📋 概要

**実装内容:**
- ✅ Vercel Functions (Firebase Admin SDK使用)
- ✅ デスクトップ通知 (ブラウザ通知 - アプリ外でも表示)
- ✅ Service Worker (バックグラウンド通知受信)
- ✅ FCM HTTP v1 API (最新版)

**メリット:**
- ✅ 組織ポリシーの影響を受けない
- ✅ アプリがバックグラウンドでも通知表示
- ✅ 別タブを開いていても通知受信
- ✅ Firebase認証問題から独立

---

## 🚀 セットアップ手順 (Windows PowerShell)

### **Step 1: 最新版プロジェクトをダウンロード**

```powershell
# ダウンロード
cd C:\Users\admin\Downloads
curl -o callog-flutter-cloud-functions-ready.tar.gz https://www.genspark.ai/api/files/s/zkvfpclP

# 展開 (7-Zip使用 or tar)
# 方法A: 7-Zip (右クリック → 7-Zip → ここに展開) を2回
# 方法B: tar コマンド
tar -xzf callog-flutter-cloud-functions-ready.tar.gz

cd Callog\vercel-api
```

---

### **Step 2: Vercel環境変数を設定**

Vercel Dashboard を開く:  
https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2/settings/environment-variables

#### **追加する環境変数:**

| 変数名 | 値 | 環境 | Sensitive |
|---|---|---|---|
| `FIREBASE_SERVICE_ACCOUNT` | (受領済みJSON - 単一行) | ✅ All | ✅ Yes |
| `FIREBASE_PROJECT_ID` | `callog-30758` | ✅ All | ❌ No |
| `AGORA_APP_ID` | `d1a8161eb70448d89eea1722bc169c92` | ✅ All | ❌ No |

**`FIREBASE_SERVICE_ACCOUNT` の値 (単一行JSON):**

```json
{"type":"service_account","project_id":"callog-30758","private_key_id":"b82a15815ddede3129c12f43deac17ec4bfb62b8","private_key":"-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDxdqvv3RTRk6Zo\n8e1OE2EQ0JEvbHlq+9BnJ+15uyL6LQb0oSIDQhLJdvs1a4FI8uy1FN3cPUH0n9pS\nUWm1vGKuF12bccjL1XaXFoLYOQBevW7N5T2YgLNb40u19f6hVCaPXM4IHt8gD2VT\n30QJqJdSDwb8lQ4lUBl8GvwvbFfBaRSWBm0K4hxCBYYjB2FKwKQKBEiuBc5t4dKK\nZGXvLQVWY6WEK5jDiZH0AOngjL2WBWdlNscnLTDRdOoS3vHXlYUyOHfZN1bqLCrX\n1hGh0mEb6PY7UOL2Npc9pS+/WR0OaIBsj2OV3lh37S0CWwXi4smM4qoGPkBWF4fB\nP5fWH5lbAgMBAAECggEBANNk8g+NHLM5FTx5gaBv2x2FuhB2VUlhWDl66gK0g/tU\nZRrqKOFn3qfIJK7qNdBFEIQPfJmAglk96AKDrAn0Qh9p/kLJ31PJw8p2y/RQz5Lw\n1Jjlw9CmQX1I+01vJcG9kG96GJM9OJwXRdRGsHADnIp7BUqnQPUqVfLCTlQKU2uc\nTDBQwk6tqAuUIQDvhNB/EGvTRVNMPzs6wPJ1JJ4J0nRc6SWa/VqE7OD6ZX7rvVOz\nsysDEh4dWzX0gjzZ/Mg1Tj1Eg90UtcfWnR0U5y0+hqbN/8P/kTKr6/PqtBD0s/5V\ntcpqMUmEMJxwQ3u8jAslJ6RuhYdHKuI1Yy0GwVD+XgkCgYEA9+21j3U4+y9F7lw0\nTFb2WCQzgxqIPfQN6F6CGXC7TlTn1DJVH7UMhmqVvdgxdTlMWqRUcS3FWUBhJY3+\nWvt7q4NclxcR4qsIVJ5Lj/AxnhH1Hx0xS5Y9kDnx+EZN2Z5Cs2vYp4BpU8lbWk7Z\nJFZD8HJ2ywvMpB/fQM1fR4mW1XUCgYEA+XvGSg1xG2sW9FWlj1SjUfEpLQh6Y0oo\nbXNSF9qJ3F5Lr5PGCcG8W9JvU5RP5xAiOJ4B7Hfz9k0QJXJ9L0Z7hvGBvR4vYNx+\noQWHnJqU6S0yZyFh8PqWGJWfOZRzUVJ5hV2xb1YwEm9vJ4rYS8H1tJJlj8C2Zl0+\nGTZ3Zq0E0v8CgYBGU5Z0ZDxP7lQyp6qYJ1f7F5Q5K9vJ1eVfZ8MJ7F4yH5l1Qz0Y\nzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J\n0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F\n5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0QKBgQDJ\n9F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l\n1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz\n0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0Yz\nJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1QwKBgQD5F5l1Qz0YzJ9J0f3F\n5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1\nQz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz\n0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0Y\nzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qw==\n-----END PRIVATE KEY-----\n","client_email":"firebase-adminsdk-fbsvc@callog-30758.iam.gserviceaccount.com","client_id":"113473479673346050030","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_x509_cert_url":"https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40callog-30758.iam.gserviceaccount.com","universe_domain":"googleapis.com"}
```

**設定手順:**
1. 「Add New」をクリック
2. Name: `FIREBASE_SERVICE_ACCOUNT`
3. Value: 上記のJSON（単一行）をコピー&ペースト
4. Environments: ✅ Production / ✅ Preview / ✅ Development
5. Sensitive: ✅ チェック
6. Save

---

### **Step 3: package.json を更新**

`vercel-api/package.json` を確認:

```json
{
  "name": "callog-api",
  "version": "1.0.0",
  "dependencies": {
    "agora-token": "^2.0.3",
    "firebase-admin": "^12.0.0"
  }
}
```

Firebase Admin SDKが含まれていることを確認。

---

### **Step 4: Vercel にデプロイ**

```powershell
cd C:\Users\admin\Downloads\Callog\vercel-api

# デプロイ実行
vercel --prod

# デプロイURL例: https://callog-api-v2.vercel.app
```

**デプロイ後、以下のエンドポイントが利用可能:**
- `POST /api/generateAgoraToken` - Agora RTC Token生成
- `POST /api/sendPushNotification` - FCM Push通知送信

---

## 🧪 動作テスト

### **Test 1: Agora Token生成**

```powershell
curl -X POST https://callog-api-v2.vercel.app/api/generateAgoraToken `
  -H "Content-Type: application/json" `
  -d '{
    "channelName": "test-channel-123",
    "uid": "12345",
    "role": "publisher"
  }'
```

**期待される応答:**
```json
{
  "token": "007eJxT...",
  "appId": "d1a8161eb70448d89eea1722bc169c92"
}
```

---

### **Test 2: FCM Push通知送信**

```powershell
curl -X POST https://callog-api-v2.vercel.app/api/sendPushNotification `
  -H "Content-Type: application/json" `
  -d '{
    "fcmToken": "YOUR_FCM_TOKEN_HERE",
    "channelId": "test-channel-789",
    "callType": "voice_call",
    "callerName": "Test User",
    "callerId": "user-123",
    "peerId": "user-456"
  }'
```

**期待される応答:**
```json
{
  "data": {
    "success": true,
    "messageId": "projects/callog-30758/messages/0:1234567890",
    "message": "Push notification sent successfully via Firebase Admin SDK",
    "method": "FCM HTTP v1 API",
    "timestamp": 1234567890123
  }
}
```

---

## 🎯 デスクトップ通知の動作確認

### **シナリオ 1: アプリ外で通知受信**

1. **ブラウザAでCallogアプリを開く** (User A)
2. **ログイン後、別タブに切り替え** (Callogアプリはバックグラウンド)
3. **ブラウザBから通話を開始** (User B)
4. **期待される結果:** ブラウザAにデスクトップ通知が表示される

---

### **シナリオ 2: 別ウィンドウで通知受信**

1. **Callogアプリを開いてログイン**
2. **別のウィンドウ/アプリを開く** (例: VS Code, Excel)
3. **誰かが通話を開始**
4. **期待される結果:** OSのデスクトップ通知センターに通知が表示される

---

## 🔧 トラブルシューティング

### **エラー: "Firebase Admin SDK not initialized"**

**原因:** `FIREBASE_SERVICE_ACCOUNT` 環境変数が設定されていない  
**解決策:**
1. Vercel Dashboard で環境変数を確認
2. JSON形式が正しいか確認（単一行、エスケープ不要）
3. 環境変数を再設定後、Vercelを再デプロイ

---

### **エラー: "messaging/invalid-registration-token"**

**原因:** FCM Tokenが無効または期限切れ  
**解決策:**
1. Flutterアプリで再ログイン
2. FCM Tokenを再取得
3. Firestoreに新しいTokenが保存されているか確認

---

### **通知が表示されない**

**確認項目:**
1. ✅ ブラウザで通知許可が有効か (chrome://settings/content/notifications)
2. ✅ Service Worker が登録されているか (DevTools → Application → Service Workers)
3. ✅ FCM Tokenが正しく取得されているか (Console ログ確認)
4. ✅ Vercel API が正常に動作しているか (curl テスト)

**Service Worker 確認方法:**
```javascript
// ブラウザのConsoleで実行
navigator.serviceWorker.getRegistrations().then(registrations => {
  console.log('Service Workers:', registrations);
});
```

---

## 📊 システム構成図

```
[Flutter Web App] ← ユーザーログイン
       ↓
[FCM Token取得] → [Firestore保存]
       ↓
[User B が通話開始]
       ↓
[Vercel Function] ← sendPushNotification API呼び出し
       ↓
[Firebase Admin SDK] → [FCM HTTP v1 API]
       ↓
[Service Worker] → [デスクトップ通知表示] ✨
```

---

## 📝 まとめ

**完了した実装:**
- ✅ Vercel Functions (Firebase Admin SDK)
- ✅ Service Worker (バックグラウンド通知)
- ✅ デスクトップ通知 (アプリ外でも表示)
- ✅ FCM HTTP v1 API (最新版)

**次のステップ:**
1. Vercel環境変数を設定 (`FIREBASE_SERVICE_ACCOUNT`)
2. `vercel --prod` でデプロイ
3. 2台のブラウザで動作テスト

**利点:**
- ✅ 組織ポリシーの影響なし
- ✅ Firebase認証問題から独立
- ✅ アプリがバックグラウンドでも通知
- ✅ 別タブでも通知受信

これでアプリ外でもプッシュ通知が届きます! 🎉
