# 🔔 Firestore ベースの着信通知システム

## 🎯 概要

Firebase Admin SDKやFCM Server Keyが不要な、**Firestoreリアルタイムリスナー**を使用した着信通知システムです。

### **仕組み:**
1. 発信者が通話を開始
2. Vercel APIがFirestoreに`call_notifications`ドキュメントを作成
3. 着信側のアプリがFirestoreリアルタイムリスナーで検知
4. 着信ダイアログを表示

---

## ✅ 利点

- ✅ **Firebase Admin SDK不要** - 組織ポリシーの制限を回避
- ✅ **FCM Server Key不要** - サーバーキー管理不要
- ✅ **リアルタイム** - Firestoreの即時同期
- ✅ **シンプル** - 追加の環境変数不要
- ✅ **信頼性** - Firestoreの堅牢なインフラ

---

## 📦 必要な環境変数

| 変数名 | 値 | 状態 |
|--------|-----|------|
| `FIREBASE_PROJECT_ID` | `callog-30758` | ✅ 設定済み |
| `AGORA_APP_ID` | `d1a8161eb70448d89eea1722bc169c92` | ✅ 設定済み |
| `AGORA_APP_CERTIFICATE` | (Agora Consoleから取得) | ✅ 設定済み |

**追加の環境変数は不要です！**

---

## 🚀 デプロイ手順

### **Step 1: 新しいプロジェクトをダウンロード**

**ダウンロードリンク:**
```
https://www.genspark.ai/api/files/s/oxTLGtic
```

**ファイル名:** `callog-api-v2-firestore-notifications.tar.gz`

### **Step 2: 展開**

1. 古い`callog-api-v2`フォルダを削除
2. 新しいファイルを`C:\Users\admin\Downloads\callog-api-v2`に展開

### **Step 3: 再デプロイ**

```bash
cd C:\Users\admin\Downloads\callog-api-v2
vercel --prod
```

**デプロイ中のプロンプト:**
- `? Want to modify these settings?` → **N**

---

## 🧪 テスト手順

### **準備: 2つのブラウザ**

1. **ブラウザ A**: ユーザー1でログイン
2. **ブラウザ B**: ユーザー2でログイン

### **Step 1: 開発者ツールを開く**

両方のブラウザで`F12`キーを押して、**Console**タブを選択

### **Step 2: ブラウザ A から通話を発信**

1. ユーザー2を選択
2. 音声通話またはビデオ通話を開始
3. コンソールログを確認:
   ```
   [Push] 📤 Sending notification via Cloud Functions
   ```

### **Step 3: ブラウザ B で着信を確認**

**期待される動作:**

1. **コンソールログ:**
   ```
   [CallListener] 📞 Incoming call detected!
   [CallListener] From: ユーザー1
   [CallListener] Type: voice_call
   ```

2. **着信ダイアログが表示:**
   ```
   音声通話着信
   ユーザー1さんから音声通話がかかってきています
   
   [拒否] [応答]
   ```

3. **「応答」をクリック:**
   - 通話画面に遷移
   - Agoraチャンネルに参加
   - 通話開始

---

## 🔧 動作の仕組み

### **1. 発信側 (ブラウザ A)**

```dart
// 通話開始時
await pushService.sendCallNotification(
  peerId: friendId,
  channelId: channelName,
  callType: 'voice_call',
  callerName: callerName,
);
```

### **2. Vercel API**

```javascript
// Firestoreに通知ドキュメントを作成
await firestore
  .collection('call_notifications')
  .add({
    peerId: peerId,
    callerId: callerId,
    callerName: callerName,
    channelId: channelId,
    callType: callType,
    status: 'ringing',
    timestamp: new Date().toISOString(),
    createdAt: Date.now(),
  });
```

### **3. 着信側 (ブラウザ B)**

```dart
// Firestoreリアルタイムリスナー
_firestore
  .collection('call_notifications')
  .where('peerId', isEqualTo: userId)
  .where('status', isEqualTo: 'ringing')
  .snapshots()
  .listen((snapshot) {
    // 着信ダイアログを表示
    _handleIncomingCall(callData);
  });
```

---

## 📊 Firestore データ構造

### **call_notifications コレクション**

```json
{
  "peerId": "user_id_2",           // 着信側のユーザーID
  "callerId": "user_id_1",         // 発信側のユーザーID
  "callerName": "ユーザー1",        // 発信側の表示名
  "channelId": "call_user_id_2",   // Agoraチャンネル名
  "callType": "voice_call",        // 'voice_call' or 'video_call'
  "status": "ringing",             // 'ringing', 'delivered', 'accepted', 'rejected'
  "timestamp": "2024-01-01T12:00:00Z",
  "createdAt": 1704110400000
}
```

### **Firestore セキュリティルール (推奨)**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to read their own call notifications
    match /call_notifications/{notification} {
      allow read: if request.auth != null && 
                     resource.data.peerId == request.auth.uid;
      allow write: if request.auth != null;
    }
  }
}
```

---

## 🔍 トラブルシューティング

### **問題 1: 着信ダイアログが表示されない**

**チェックポイント:**
1. ✅ 両方のユーザーがログイン済み
2. ✅ ブラウザ Bのコンソールログを確認:
   ```
   [CallListener] 🎧 Starting to listen for calls to: user_id
   ```
3. ✅ Firestore Rulesが正しく設定されている
4. ✅ ブラウザ Bがアクティブ (バックグラウンドではリスナーが停止する可能性)

### **問題 2: 古い通知が表示される**

**解決策:**
リスナーは過去1分以内の通知のみを検出します。通知は自動的にフィルタリングされます。

### **問題 3: Firestore接続エラー**

**解決策:**
1. Firebase Consoleで Firestore Databaseが作成されているか確認
2. Firestoreセキュリティルールが正しく設定されているか確認

---

## 📋 チェックリスト

デプロイ前の確認事項:

- [ ] 新しいプロジェクトをダウンロード & 展開
- [ ] `vercel --prod` で再デプロイ
- [ ] 2つのブラウザでログイン
- [ ] ブラウザ Aから通話発信
- [ ] ブラウザ Bで着信ダイアログ表示
- [ ] 「応答」をクリックして通話開始

---

## 🎯 期待される動作

### **成功のログ (ブラウザ A - 発信側):**
```
[Push] 📤 Sending notification via Cloud Functions
[Push] ✅ Notification sent successfully!
[Push] Message ID: null
[CallListener] Call notification created in Firestore
```

### **成功のログ (ブラウザ B - 着信側):**
```
[CallListener] 📞 Incoming call detected!
[CallListener] From: ユーザー1
[CallListener] Type: voice_call
[CallListener] Channel: call_user_id_2
[CallListener] Showing incoming call dialog
```

### **着信ダイアログ:**
```
┌─────────────────────────────────┐
│  音声通話着信                    │
│                                 │
│  ユーザー1さんから音声通話が    │
│  かかってきています             │
│                                 │
│  [拒否]              [応答]     │
└─────────────────────────────────┘
```

---

## 💡 重要なポイント

1. **FCM不要** - Firebase Admin SDKもFCM Server Keyも不要
2. **リアルタイム** - Firestoreの即時同期で遅延なし
3. **シンプル** - 追加の設定や環境変数不要
4. **アクティブアプリのみ** - アプリがバックグラウンドの場合は通知されない可能性
5. **ブラウザ通知は表示されない** - アプリ内ダイアログのみ

---

## 🚀 次のステップ

1. **新しいプロジェクトをダウンロード**
   - URL: https://www.genspark.ai/api/files/s/oxTLGtic

2. **再デプロイ**
   ```bash
   cd C:\Users\admin\Downloads\callog-api-v2
   vercel --prod
   ```

3. **2つのブラウザでテスト**
   - ブラウザ A: 通話発信
   - ブラウザ B: 着信ダイアログ確認

これで、相手に着信通知が届き、着信が取れるようになります! 🔔🚀

**注意:** この方式は**アプリがアクティブな場合のみ**動作します。アプリがバックグラウンドやクローズされている場合は、従来のFCMプッシュ通知が必要になります。
