# 🔥 Cloud Functions デプロイガイド

## 📋 前提条件

✅ Service Account Keyが作成済み  
✅ 組織ポリシー `iam.disableServiceAccountKeyCreation` が削除済み  
✅ Firebase CLI がインストール済み (v14.20.0)

---

## 🚀 デプロイ手順

### **Step 1: Firebase ログイン**

```bash
# Firebase CLIでログイン
firebase login --no-localhost
```

このコマンドを実行すると、ブラウザでGoogleアカウント認証画面が開きます。  
`thp-hoikujouhou@tachanhao164.com` でログインしてください。

---

### **Step 2: Firebase プロジェクト設定**

```bash
cd /home/user/Callog

# 現在のプロジェクト確認
firebase projects:list

# callog-30758 プロジェクトを使用
firebase use callog-30758
```

---

### **Step 3: Agora App Certificate 設定**

Cloud Functionsで**Agora Token生成**を使用する場合、App Certificateが必要です。

**Agora Console から取得:**
1. https://console.agora.io/ を開く
2. プロジェクト `callog` を選択
3. **App Certificate** をコピー

**環境変数に設定:**

```bash
# Firebase環境変数に追加
firebase functions:config:set agora.app_certificate="YOUR_APP_CERTIFICATE_HERE"
```

---

### **Step 4: Cloud Functions デプロイ**

```bash
cd /home/user/Callog

# functions/index.js を確認
cat functions/index.js | head -50

# デプロイ実行
firebase deploy --only functions
```

**デプロイされる関数:**
- `generateAgoraToken` - Agora RTC Token生成
- `sendPushNotification` - FCM Push通知送信

---

### **Step 5: Cloud Functions URL確認**

デプロイ完了後、以下のようなURLが表示されます:

```
✔ functions[us-central1-generateAgoraToken] Successful create operation.
Function URL: https://us-central1-callog-30758.cloudfunctions.net/generateAgoraToken

✔ functions[us-central1-sendPushNotification] Successful create operation.
Function URL: https://us-central1-callog-30758.cloudfunctions.net/sendPushNotification
```

---

### **Step 6: Flutter アプリ設定更新**

Cloud Functions URLを Flutter アプリに設定します。

**lib/services/agora_token_service.dart:**
```dart
class AgoraTokenService {
  // Cloud Functions URL (Vercel APIから変更)
  static const String _tokenUrl = 
    'https://us-central1-callog-30758.cloudfunctions.net/generateAgoraToken';
  
  // ... 残りのコードは同じ
}
```

**lib/services/push_notification_service.dart:**
```dart
class PushNotificationService {
  // Cloud Functions URL (Vercel APIから変更)
  static const String _sendPushUrl = 
    'https://us-central1-callog-30758.cloudfunctions.net/sendPushNotification';
  
  // ... 残りのコードは同じ
}
```

---

### **Step 7: Flutter アプリ再ビルド & 再起動**

```bash
cd /home/user/Callog

# 変更をコミット
git add .
git commit -m "Update to use Cloud Functions URLs"

# Flutter Webアプリ再ビルド & 再起動
lsof -ti:5060 | xargs -r kill -9
sleep 2
flutter build web --release
cd build/web
python3 -m http.server 5060 --bind 0.0.0.0 &
```

---

## 🧪 動作テスト

### **1. Agora Token生成テスト:**

```bash
curl -X POST https://us-central1-callog-30758.cloudfunctions.net/generateAgoraToken \
  -H "Content-Type: application/json" \
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
  "appId": "d1a8161eb70448d89eea1722bc169c92",
  "channelName": "test-channel-123",
  "uid": "12345"
}
```

---

### **2. Push通知送信テスト:**

```bash
curl -X POST https://us-central1-callog-30758.cloudfunctions.net/sendPushNotification \
  -H "Content-Type: application/json" \
  -d '{
    "peerId": "test-user-456",
    "channelId": "test-channel-789",
    "callType": "voice_call",
    "callerName": "Test User",
    "fcmToken": "YOUR_FCM_TOKEN_HERE"
  }'
```

**期待される応答:**
```json
{
  "success": true,
  "notificationId": "abc123"
}
```

---

## 🔧 トラブルシューティング

### **エラー: "Failed to list Firebase projects"**

```bash
# 再ログイン
firebase logout
firebase login --no-localhost
```

### **エラー: "Permission denied on project"**

`thp-hoikujouhou@tachanhao164.com` アカウントに Firebase プロジェクト `callog-30758` への **Editor** または **Owner** 権限が必要です。

Firebase Console で確認:
https://console.firebase.com/project/callog-30758/settings/iam

### **エラー: "AGORA_APP_CERTIFICATE is not set"**

```bash
# App Certificate を設定
firebase functions:config:set agora.app_certificate="YOUR_CERTIFICATE"

# 再デプロイ
firebase deploy --only functions
```

---

## 📝 まとめ

**Cloud Functions を使用するメリット:**
- ✅ Firebase ネイティブ統合 (認証不要)
- ✅ 自動スケーリング
- ✅ Firebase Admin SDK が標準で利用可能
- ✅ Firestoreとの直接連携

**次のステップ:**
1. `firebase login` でログイン
2. `firebase use callog-30758` でプロジェクト設定
3. `firebase deploy --only functions` でデプロイ
4. Flutter アプリの URL を Cloud Functions に更新
5. 動作テスト実行

デプロイ完了後、Vercel API は不要になります (削除可能)。

---

**📚 参考リンク:**
- Firebase Console: https://console.firebase.google.com/project/callog-30758
- Cloud Functions ログ: https://console.firebase.google.com/project/callog-30758/functions/logs
- Agora Console: https://console.agora.io/
