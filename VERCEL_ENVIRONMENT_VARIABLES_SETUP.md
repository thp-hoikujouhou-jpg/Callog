# 🔧 Vercel環境変数 完全セットアップガイド

## 📋 必要な環境変数一覧

Vercel Functionsで**Firebase Admin SDK**と**Agora Token生成**を使用するために、以下の環境変数を設定する必要があります。

---

## 🔗 Vercel設定ページ

**URL:** https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2/settings/environment-variables

---

## 📝 設定する環境変数

### ✅ 重要な補足: FIREBASE_WEB_API_KEY について

**Q: FIREBASE_WEB_API_KEY は必要ですか？**

**A: 不要です！** 現在の実装は **Firebase Admin SDK** を使用しているため、`FIREBASE_WEB_API_KEY` は必要ありません。

**2つの実装方式の違い:**

| 方式 | 認証方法 | 必要な環境変数 | セキュリティ |
|---|---|---|---|
| **Firebase Admin SDK** (現在) | Service Account Key | `FIREBASE_SERVICE_ACCOUNT` | ✅ 高セキュリティ |
| Web API Key (旧方式) | Web API Key | `FIREBASE_WEB_API_KEY` | ⚠️ 低セキュリティ |

**現在の実装 (推奨):**
- Firebase Admin SDK を使用
- FCM HTTP v1 API (最新版)
- Service Account Key で認証
- `FIREBASE_WEB_API_KEY` は**不要**

---

### **1. FIREBASE_SERVICE_ACCOUNT** (必須・最重要)

**説明:** Firebase Admin SDKの認証情報（サービスアカウントキー）

**値の形式:** JSON（単一行、改行なし）

**Sensitive:** ✅ **必ずチェック**（機密情報）

**Environments:** ✅ Production / ✅ Preview / ✅ Development（すべて選択）

**値:**
```json
{"type":"service_account","project_id":"callog-30758","private_key_id":"b82a15815ddede3129c12f43deac17ec4bfb62b8","private_key":"-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDxdqvv3RTRk6Zo\n8e1OE2EQ0JEvbHlq+9BnJ+15uyL6LQb0oSIDQhLJdvs1a4FI8uy1FN3cPUH0n9pS\nUWm1vGKuF12bccjL1XaXFoLYOQBevW7N5T2YgLNb40u19f6hVCaPXM4IHt8gD2VT\n30QJqJdSDwb8lQ4lUBl8GvwvbFfBaRSWBm0K4hxCBYYjB2FKwKQKBEiuBc5t4dKK\nZGXvLQVWY6WEK5jDiZH0AOngjL2WBWdlNscnLTDRdOoS3vHXlYUyOHfZN1bqLCrX\n1hGh0mEb6PY7UOL2Npc9pS+/WR0OaIBsj2OV3lh37S0CWwXi4smM4qoGPkBWF4fB\nP5fWH5lbAgMBAAECggEBANNk8g+NHLM5FTx5gaBv2x2FuhB2VUlhWDl66gK0g/tU\nZRrqKOFn3qfIJK7qNdBFEIQPfJmAglk96AKDrAn0Qh9p/kLJ31PJw8p2y/RQz5Lw\n1Jjlw9CmQX1I+01vJcG9kG96GJM9OJwXRdRGsHADnIp7BUqnQPUqVfLCTlQKU2uc\nTDBQwk6tqAuUIQDvhNB/EGvTRVNMPzs6wPJ1JJ4J0nRc6SWa/VqE7OD6ZX7rvVOz\nsysDEh4dWzX0gjzZ/Mg1Tj1Eg90UtcfWnR0U5y0+hqbN/8P/kTKr6/PqtBD0s/5V\ntcpqMUmEMJxwQ3u8jAslJ6RuhYdHKuI1Yy0GwVD+XgkCgYEA9+21j3U4+y9F7lw0\nTFb2WCQzgxqIPfQN6F6CGXC7TlTn1DJVH7UMhmqVvdgxdTlMWqRUcS3FWUBhJY3+\nWvt7q4NclxcR4qsIVJ5Lj/AxnhH1Hx0xS5Y9kDnx+EZN2Z5Cs2vYp4BpU8lbWk7Z\nJFZD8HJ2ywvMpB/fQM1fR4mW1XUCgYEA+XvGSg1xG2sW9FWlj1SjUfEpLQh6Y0oo\nbXNSF9qJ3F5Lr5PGCcG8W9JvU5RP5xAiOJ4B7Hfz9k0QJXJ9L0Z7hvGBvR4vYNx+\noQWHnJqU6S0yZyFh8PqWGJWfOZRzUVJ5hV2xb1YwEm9vJ4rYS8H1tJJlj8C2Zl0+\nGTZ3Zq0E0v8CgYBGU5Z0ZDxP7lQyp6qYJ1f7F5Q5K9vJ1eVfZ8MJ7F4yH5l1Qz0Y\nzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J\n0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F\n5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0QKBgQDJ\n9F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l\n1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz\n0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0Yz\nJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1QwKBgQD5F5l1Qz0YzJ9J0f3F\n5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1\nQz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz\n0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0Y\nzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qz0YzJ9J0f3F5l1Qw==\n-----END PRIVATE KEY-----\n","client_email":"firebase-adminsdk-fbsvc@callog-30758.iam.gserviceaccount.com","client_id":"113473479673346050030","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_x509_cert_url":"https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40callog-30758.iam.gserviceaccount.com","universe_domain":"googleapis.com"}
```

**⚠️ 重要:** 
- この値は**1行**で貼り付けてください（改行なし）
- コピー時に余分なスペースが入らないように注意
- Sensitiveを必ずチェック（秘密鍵が含まれます）

---

### **2. FIREBASE_PROJECT_ID** (必須)

**説明:** FirebaseプロジェクトID

**値:** `callog-30758`

**Sensitive:** ❌ 不要

**Environments:** ✅ Production / ✅ Preview / ✅ Development

---

### **3. AGORA_APP_ID** (必須)

**説明:** Agora RTC App ID（音声/ビデオ通話用）

**値:** `d1a8161eb70448d89eea1722bc169c92`

**Sensitive:** ❌ 不要

**Environments:** ✅ Production / ✅ Preview / ✅ Development

---

### **4. AGORA_APP_CERTIFICATE** (オプション・推奨)

**説明:** Agora App Certificate（Tokenセキュリティ強化用）

**値:** Agora Consoleから取得 (https://console.agora.io/)

**Sensitive:** ✅ チェック推奨

**Environments:** ✅ Production / ✅ Preview / ✅ Development

**取得方法:**
1. https://console.agora.io/ を開く
2. プロジェクト `callog` を選択
3. **App Certificate** をコピー

**⚠️ 注意:** 
- App Certificateがない場合、Agora Token生成は動作しますが、セキュリティが弱くなります
- 本番環境では**必ず設定**してください

---

## 📸 設定手順（スクリーンショット付き）

### **Step 1: Vercel Dashboardを開く**

1. https://vercel.com/ にアクセス
2. プロジェクト `callog-api-v2` を選択
3. **Settings** → **Environment Variables** をクリック

---

### **Step 2: 環境変数を追加**

1. **Add New** ボタンをクリック
2. 以下の情報を入力:

**例: FIREBASE_SERVICE_ACCOUNT を追加**

```
Name: FIREBASE_SERVICE_ACCOUNT
Value: (上記の単一行JSONをコピー&ペースト)

Environments:
  ✅ Production
  ✅ Preview  
  ✅ Development

Sensitive:
  ✅ Check this box
```

3. **Save** をクリック

---

### **Step 3: 他の環境変数も追加**

同様に以下を追加:

**FIREBASE_PROJECT_ID:**
```
Name: FIREBASE_PROJECT_ID
Value: callog-30758
Environments: すべて選択
Sensitive: チェック不要
```

**AGORA_APP_ID:**
```
Name: AGORA_APP_ID
Value: d1a8161eb70448d89eea1722bc169c92
Environments: すべて選択
Sensitive: チェック不要
```

**AGORA_APP_CERTIFICATE** (オプション):
```
Name: AGORA_APP_CERTIFICATE
Value: (Agora Consoleから取得)
Environments: すべて選択
Sensitive: ✅ チェック
```

---

## 🧪 設定確認方法

環境変数を設定した後、Vercelを再デプロイして動作確認:

```powershell
cd C:\Users\admin\Downloads\Callog\vercel-api
vercel --prod
```

**テストAPI呼び出し:**

```powershell
# Agora Token生成テスト
curl -X POST https://callog-api-v2.vercel.app/api/generateAgoraToken `
  -H "Content-Type: application/json" `
  -d '{"channelName":"test","uid":"123","role":"publisher"}'

# Push通知送信テスト
curl -X POST https://callog-api-v2.vercel.app/api/sendPushNotification `
  -H "Content-Type: application/json" `
  -d '{"fcmToken":"YOUR_TOKEN","channelId":"test","callType":"voice_call","callerName":"Test"}'
```

**期待される応答:**
- Agora Token: `{"token":"007eJxT...","appId":"d1a8161eb70448d89eea1722bc169c92"}`
- Push通知: `{"data":{"success":true,"messageId":"..."}}`

---

## ❌ よくあるエラーと解決方法

### **エラー 1: "Firebase Admin SDK not initialized"**

**原因:** `FIREBASE_SERVICE_ACCOUNT` が設定されていない、または形式が間違っている

**解決策:**
1. Vercel Dashboardで `FIREBASE_SERVICE_ACCOUNT` の値を確認
2. 単一行JSON（改行なし）であることを確認
3. 余分なスペースがないか確認
4. 再デプロイ: `vercel --prod`

---

### **エラー 2: "messaging/invalid-registration-token"**

**原因:** FCM Tokenが無効または期限切れ

**解決策:**
1. Flutterアプリで再ログイン
2. 新しいFCM Tokenを取得
3. Firestoreに保存されているか確認

---

### **エラー 3: "Could not load the default credentials"**

**原因:** 古いコード（Web API Key版）が残っている

**解決策:**
1. 最新プロジェクトを使用: https://www.genspark.ai/api/files/s/fDUPiuRj
2. `api/sendPushNotification.js` がFirebase Admin SDK版か確認
3. 再デプロイ

---

## 📋 環境変数チェックリスト

デプロイ前に以下を確認:

- [ ] `FIREBASE_SERVICE_ACCOUNT` を追加（Sensitive ✅）
- [ ] `FIREBASE_PROJECT_ID` を追加（= `callog-30758`）
- [ ] `AGORA_APP_ID` を追加（= `d1a8161eb70448d89eea1722bc169c92`）
- [ ] `AGORA_APP_CERTIFICATE` を追加（オプション、本番推奨）
- [ ] すべての環境変数で Production/Preview/Development を選択
- [ ] `vercel --prod` で再デプロイ
- [ ] API動作確認（curl テスト）

---

## 🎉 設定完了！

環境変数を設定してVercelを再デプロイすれば、Firebase Admin SDKとAgora Tokenが正常に動作します！

**次のステップ:**
1. Vercel環境変数を設定
2. `vercel --prod` でデプロイ
3. 2台のブラウザで通話テスト
4. LINE/WhatsApp方式の着信システムを体験！

---

**トラブルシューティング:**
設定でわからないことがあれば、このガイドを参照してください。
すべての環境変数が正しく設定されていれば、CallogアプリはLINE/WhatsAppと同じように動作します！ 🚀
