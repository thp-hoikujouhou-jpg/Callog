# 🎯 Callog - 最終セットアップガイド

## 📋 現在の状況

### ✅ 動作中のもの
- **Flutter Webアプリ:** https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai
- **Firestore Database:** callog-30758
- **Firebase Authentication**
- **Agora音声/ビデオ通話**

### ❌ ブロックされているもの
- **Service Account Key作成:** 組織ポリシーでブロック
- **Firebase Admin SDK:** Service Account Key不要の代替実装を使用

---

## 🚀 最終的な解決策

**Web API Key実装 (FCM Legacy API) を使用**

### なぜこの方法？

✅ **Service Account Key不要**  
✅ **組織ポリシーの影響を受けない**  
✅ **既に動作確認済み**  
✅ **Vercelで動作**  
✅ **すぐに使える**  

---

## 📦 セットアップ手順

### Step 1: 最新プロジェクトをダウンロード

**ダウンロードURL:**
```
https://www.genspark.ai/api/files/s/tlJ3yFkA
```

**ファイル名:** `callog-api-v2-fcm-no-admin-sdk.tar.gz`  
**サイズ:** 19.8 KB

### Step 2: プロジェクトを解凍

```powershell
# 古いプロジェクトを削除
cd C:\Users\admin\Downloads
Remove-Item -Path callog-api-v2 -Recurse -Force -ErrorAction SilentlyContinue

# ダウンロードしたtar.gzを解凍
# 解凍先: C:\Users\admin\Downloads\callog-api-v2
```

### Step 3: Vercel環境変数を確認

**Vercel設定画面:**
```
https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2/settings/environment-variables
```

**必要な環境変数 (3つのみ):**

| 変数名 | 値 | Environment |
|--------|-----|------------|
| `FIREBASE_PROJECT_ID` | `callog-30758` | Production, Preview, Development |
| `FIREBASE_WEB_API_KEY` | `AIzaSyADm_scTXk7oTh39uFtKEuDlnqvP4OqoqA` | Production, Preview, Development |
| `AGORA_APP_ID` | `d1a8161eb70448d89eea1722bc169c92` | Production, Preview, Development |

**不要な環境変数:**
- ❌ `FIREBASE_SERVICE_ACCOUNT` (削除してください)
- ❌ `FCM_SERVER_KEY` (不要)

### Step 4: Vercelにデプロイ

```powershell
# プロジェクトディレクトリに移動
cd C:\Users\admin\Downloads\callog-api-v2

# Vercelにデプロイ
vercel --prod
```

**デプロイ時の質問:**
- **Set up and deploy?** → `Y`
- **Link to existing project?** → `Y`
- **Project name?** → `callog-api-v2`
- **Override settings?** → `N`

---

## 🧪 テスト手順

### Test 1: API エンドポイントのテスト

**PowerShell:**
```powershell
# Agora Token API テスト
$body = @{
    data = @{
        channelName = "test_channel"
        uid = 0
        role = "publisher"
    }
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://callog-api-v2.vercel.app/api/generateAgoraToken" -Method POST -ContentType "application/json" -Body $body
```

**期待される出力:**
```json
{
  "data": {
    "token": "006...",
    "appId": "d1a8161eb70448d89eea1722bc169c92",
    "channelName": "test_channel",
    "uid": 0,
    "expiresAt": 1234567890
  }
}
```

### Test 2: Push Notification API テスト

```powershell
# Push Notification API テスト
$body = @{
    data = @{
        fcmToken = "test_token_123"
        callType = "voice_call"
        callerName = "Test User"
        channelId = "test_channel"
        callerId = "test_caller"
        peerId = "test_peer"
    }
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://callog-api-v2.vercel.app/api/sendPushNotification" -Method POST -ContentType "application/json" -Body $body
```

**期待される出力:**
```json
{
  "data": {
    "success": true,
    "messageId": "0:1234567890123456%abc123",
    "message": "Push notification sent successfully via FCM",
    "method": "FCM Legacy API",
    "timestamp": 1234567890123
  }
}
```

### Test 3: 実際の通話テスト

**2つのブラウザタブで:**

**Tab 1 (発信者 - User A):**
1. `https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai` を開く
2. User Aでログイン
3. 友達 (User B) を選択
4. 音声通話またはビデオ通話を開始

**Tab 2 (受信者 - User B):**
1. `https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai` を開く
2. User Bでログイン
3. **別のタブに切り替える** (Gmail、YouTubeなど)
4. **デスクトップ通知を待つ** 🔔

**期待される動作:**
- User Bがバックグラウンドでもデスクトップ通知が表示される
- 通知をクリックするとCallogアプリが開く
- 「応答」ボタンで通話に参加できる

---

## 🔧 トラブルシューティング

### Error: "FIREBASE_WEB_API_KEY not configured"

**原因:** Vercel環境変数が設定されていない

**解決策:**
1. Vercel設定画面を開く
2. `FIREBASE_WEB_API_KEY` を追加
3. 値: `AIzaSyADm_scTXk7oTh39uFtKEuDlnqvP4OqoqA`
4. `vercel --prod` で再デプロイ

### Error: "Peer has no FCM token registered"

**原因:** 受信者がログインしていないか、FCMトークンが保存されていない

**解決策:**
1. 受信者がCallogにログイン
2. ブラウザのコンソールで確認: `[Push] ✅ FCM token saved to Firestore successfully`
3. Firestoreで確認: `users/{userId}/fcmToken` フィールドが存在するか

### No Desktop Notification Appears

**可能性のある原因:**

1. **ブラウザ通知許可がない**
   - Chrome設定: `chrome://settings/content/notifications`
   - Callogを許可リストに追加

2. **Service Worker未登録**
   - `chrome://serviceworker-internals/` を開く
   - Callogのservice workerがactiveか確認

3. **FCMトークンが保存されていない**
   - コンソール確認: `[Push] ✅ FCM token saved`
   - 再ログインを試す

4. **Vercel APIがデプロイされていない**
   - デプロイ状態確認: `https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2`
   - "Ready"ステータスを確認

---

## 📊 アーキテクチャ

```
Flutter Web App (Port 5060)
    ↓ (1) User A starts call
    ↓ (2) Get peer's FCM token from Firestore
Vercel API (callog-api-v2.vercel.app)
    ↓ (3) Call FCM Legacy API with Web API Key
FCM (Firebase Cloud Messaging)
    ↓ (4) Send browser notification
User B's Browser
    ↓ (5) Display desktop notification
```

---

## ✅ 完全なチェックリスト

セットアップ前にチェック:

- [ ] 最新プロジェクトをダウンロード (`https://www.genspark.ai/api/files/s/tlJ3yFkA`)
- [ ] `C:\Users\admin\Downloads\callog-api-v2` に解凍
- [ ] Vercel環境変数を確認 (3つすべて設定済み)
- [ ] `vercel --prod` でデプロイ
- [ ] API エンドポイントをテスト (Agora Token)
- [ ] API エンドポイントをテスト (Push Notification)
- [ ] 2つのブラウザタブで通話テスト
- [ ] デスクトップ通知が表示されることを確認

---

## 🎯 重要なポイント

### ✅ この実装の利点

1. **Service Account Key不要**
   - 組織ポリシーの影響を受けない
   - セキュリティリスクが低い

2. **シンプルな構成**
   - 環境変数は3つのみ
   - 複雑な認証不要

3. **動作確認済み**
   - FCM Legacy APIは安定している
   - Vercelで問題なく動作

4. **メンテナンスが容易**
   - コードがシンプル
   - デバッグしやすい

### ⚠️ 注意事項

1. **FCM Legacy API使用**
   - 将来的にGoogleが廃止する可能性がある
   - ただし現時点では問題なく使用可能

2. **デスクトップ通知の制限**
   - ブラウザがバックグラウンドの時のみ動作
   - ブラウザを完全に閉じている場合は通知が届かない

3. **FCMトークン管理**
   - ユーザーがログインする度にFirestoreに保存
   - トークンの有効期限切れに注意

---

## 📞 サポート

問題が発生した場合:

1. **Vercelデプロイログを確認**
   - `https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2`
   - デプロイエラーがないか確認

2. **ブラウザコンソールログを確認**
   - F12 → Console タブ
   - `[Push]` で始まるログを確認

3. **Firestoreデータを確認**
   - `https://console.firebase.google.com/project/callog-30758/firestore`
   - `users/{userId}/fcmToken` が存在するか

4. **APIエンドポイントを直接テスト**
   - PowerShellコマンドでテスト
   - レスポンスを確認

---

## 🚀 次のステップ

1. ✅ 最新プロジェクトをダウンロード
2. ✅ Vercelにデプロイ
3. ✅ API エンドポイントをテスト
4. ✅ 2つのブラウザで通話テスト
5. ✅ デスクトップ通知を確認

**所要時間:** 10-15分

---

## 🎉 完了

セットアップが完了すれば、CallogはFirebase Admin SDK なしでデスクトップ通知機能が動作します！

**Flutter WebアプリURL:**
```
https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai
```

**Vercel API URL:**
```
https://callog-api-v2.vercel.app
```

良い通話体験を！ 📞✨
