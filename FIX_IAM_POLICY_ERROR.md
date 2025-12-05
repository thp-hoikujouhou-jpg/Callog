# 🔧 IAM Policy エラーの解決方法

## ❌ 発生したエラー

```
Failed to set the IAM Policy on the function projects/callog-30758/locations/us-central1/functions/generateAgoraToken
Failed to set the IAM Policy on the function projects/callog-30758/locations/us-central1/functions/sendPushNotification

Unable to set the invoker for the IAM policy on the following functions:
        generateAgoraToken(us-central1)
        sendPushNotification(us-central1)

One or more functions were being implicitly made publicly available on function create.
Functions are not implicitly made public on updates. To try to make these functions public on next deploy, 
configure these functions with invoker set to "public"
```

## 🎯 原因

関数は作成されましたが、**パブリックアクセス権限が設定されていません**。

Web環境からこれらの関数を呼び出すには、関数を**パブリック（誰でもアクセス可能）**に設定する必要があります。

## ✅ 良いニュース

関数自体は正常に作成されています:
- ✅ `generateAgoraToken` - 作成済み
- ✅ `sendPushNotification` - 作成済み
- ✅ `cleanupOldNotifications` - 更新済み

エラーメッセージにURLも表示されています:
- https://us-central1-callog-30758.cloudfunctions.net/generateAgoraToken
- https://us-central1-callog-30758.cloudfunctions.net/sendPushNotification

**あとは権限を設定するだけです！**

---

## 🟢 解決方法1: Firebase Console で設定 (推奨 - 最も簡単)

### ステップ1: Firebase Consoleを開く

1. https://console.firebase.google.com/ にアクセス
2. **Callog** プロジェクトを選択
3. 左メニューから **Functions** をクリック

### ステップ2: generateAgoraToken を公開設定

1. **generateAgoraToken** 関数を見つける
2. 右側の **︙** (3点メニュー) をクリック
3. **Permissions** を選択
4. **ADD PRINCIPAL** をクリック
5. 以下を入力:
   - **New principals**: `allUsers`
   - **Role**: `Cloud Functions Invoker`
6. **SAVE** をクリック

### ステップ3: sendPushNotification を公開設定

1. **sendPushNotification** 関数を見つける
2. 右側の **︙** をクリック
3. **Permissions** を選択
4. **ADD PRINCIPAL** をクリック
5. 以下を入力:
   - **New principals**: `allUsers`
   - **Role**: `Cloud Functions Invoker`
6. **SAVE** をクリック

---

## 🟡 解決方法2: gcloud コマンドで設定 (速い)

### 前提条件

Google Cloud SDK (gcloud) がインストールされている必要があります。

### コマンド実行

```bash
# generateAgoraToken を公開
gcloud functions add-iam-policy-binding generateAgoraToken \
  --region=us-central1 \
  --member=allUsers \
  --role=roles/cloudfunctions.invoker \
  --project=callog-30758

# sendPushNotification を公開
gcloud functions add-iam-policy-binding sendPushNotification \
  --region=us-central1 \
  --member=allUsers \
  --role=roles/cloudfunctions.invoker \
  --project=callog-30758
```

**成功メッセージ:**
```
Updated IAM policy for function [generateAgoraToken].
bindings:
- members:
  - allUsers
  role: roles/cloudfunctions.invoker
```

---

## 🟣 解決方法3: Firebase CLI で再デプロイ (自動設定)

Cloud Functions を**自動的に公開**するように設定してから再デプロイします。

### ステップ1: firebase.json を確認

```bash
cat /home/user/Callog/firebase.json
```

### ステップ2: firebase.json がない、または functions 設定がない場合

以下の内容で作成/更新します:

```json
{
  "functions": [
    {
      "source": "functions",
      "codebase": "default",
      "ignore": [
        "node_modules",
        ".git",
        "firebase-debug.log",
        "firebase-debug.*.log"
      ],
      "predeploy": []
    }
  ]
}
```

### ステップ3: 環境変数を設定して再デプロイ

```bash
cd /home/user/Callog

# 環境変数を設定（自動的に公開設定）
export GOOGLE_CLOUD_PROJECT=callog-30758

# 再デプロイ（--allow-unauthenticated フラグを追加）
firebase deploy --only functions
```

---

## 🔴 解決方法4: index.js を修正（最も確実）

**注意**: この方法は完全に公開される関数を作成します。セキュリティが必要な場合は認証チェックを追加してください。

### 現在の問題

`onRequest` 関数はデフォルトでは認証が必要です。Web環境から呼び出すには、明示的に公開する必要があります。

### 解決策

Cloud Functions 2nd gen の設定を使用して、関数を公開します。

#### 修正済み index.js

`/home/user/Callog/functions/index.js` に以下を追加:

```javascript
// ファイルの先頭に追加
const { onRequest } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');

// グローバル設定（すべての関数に適用）
setGlobalOptions({
  region: 'us-central1',
  invoker: 'public', // ← これが重要！
});
```

---

## 🧪 確認方法

### 方法1: cURL でテスト

```bash
# generateAgoraToken をテスト
curl -X POST https://us-central1-callog-30758.cloudfunctions.net/generateAgoraToken \
  -H "Content-Type: application/json" \
  -d '{"data":{"channelName":"test","uid":0,"role":"publisher"}}'
```

**期待される結果:**
```json
{
  "data": {
    "token": null,
    "appId": "d1a8161eb70448d89eea1722bc169c92",
    "channelName": "test",
    "uid": 0,
    "message": "Token generation disabled - App Certificate not configured"
  }
}
```

**エラーの場合:**
```
<html><head>
<meta http-equiv="content-type" content="text/html;charset=utf-8">
<title>403 Forbidden</title>
</head>
<body text=#000000 bgcolor=#ffffff>
<h1>Error: Forbidden</h1>
<h2>Your client does not have permission to get URL...</h2>
</body></html>
```

### 方法2: Flutterアプリで確認

1. ブラウザで Ctrl + Shift + R を押してアプリをリロード
2. 友達を選択して通話を開始
3. コンソール (F12) を確認

**成功の場合:**
```
[AgoraToken] 🎫 Generating token for channel: call_xxx
[AgoraToken] ✅ Token generated successfully
```

**失敗の場合:**
```
[AgoraToken] ❌ Error generating token: [firebase_functions/permission-denied]
```

---

## 📋 推奨する手順（最も簡単）

### ステップ1: Firebase Console で権限設定

1. https://console.firebase.google.com/
2. Callog → Functions
3. 各関数の **︙** → **Permissions**
4. `allUsers` に `Cloud Functions Invoker` ロールを追加

### ステップ2: 動作確認

```bash
# テスト
curl -X POST https://us-central1-callog-30758.cloudfunctions.net/generateAgoraToken \
  -H "Content-Type: application/json" \
  -d '{"data":{"channelName":"test","uid":0,"role":"publisher"}}'
```

### ステップ3: Flutterアプリで確認

ブラウザでアプリをリロードして通話機能をテスト

---

## ⚠️ セキュリティに関する注意

### 現在の設定: 完全に公開

```javascript
// 誰でも呼び出し可能
exports.generateAgoraToken = functions.https.onRequest((req, res) => {
  return cors(req, res, async () => {
    // 認証チェックなし
    // ...
  });
});
```

### 本番環境での推奨設定

認証が必要な場合は、Firebase Authトークンをチェックする必要があります:

```javascript
const admin = require('firebase-admin');

exports.sendPushNotification = functions.https.onRequest((req, res) => {
  return cors(req, res, async () => {
    // 🔒 Authorizationヘッダーをチェック
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    
    const idToken = authHeader.split('Bearer ')[1];
    try {
      const decodedToken = await admin.auth().verifyIdToken(idToken);
      const uid = decodedToken.uid;
      
      // 認証済みユーザーのみ処理
      // ...
      
    } catch (error) {
      return res.status(401).json({ error: 'Invalid token' });
    }
  });
});
```

**現時点では**: テスト目的で完全に公開しても問題ありません。
**本番リリース前**: 認証チェックを追加することを推奨します。

---

## 🎯 まとめ

### 最も簡単な解決方法

1. **Firebase Console** → **Functions**
2. 各関数の **Permissions** で `allUsers` を追加
3. Role: `Cloud Functions Invoker`
4. **SAVE**

### 確認方法

```bash
curl -X POST https://us-central1-callog-30758.cloudfunctions.net/generateAgoraToken \
  -H "Content-Type: application/json" \
  -d '{"data":{"channelName":"test","uid":0,"role":"publisher"}}'
```

レスポンスがJSONで返ってくれば成功！ 🎉

---

**最終更新**: 2024-12-04
**問題**: IAM Policy設定エラー
**解決策**: 関数をパブリックに設定
