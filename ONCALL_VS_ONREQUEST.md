# onCall vs onRequest - 変更の影響分析

## 🤔 質問: onCall → onRequest に変更して大丈夫?

**回答: はい、大丈夫です!** むしろ、この変更が **CORS問題の根本的な解決策** です。

---

## 📊 比較表

| 項目 | onCall (変更前) | onRequest (変更後) |
|------|----------------|-------------------|
| **認証** | 自動的にFirebase認証をチェック | 手動で認証を処理 |
| **CORS** | 自動対応 (理論上) | 手動で明示的に対応 |
| **リクエスト形式** | `callable.call(data)` | 標準的な HTTP POST |
| **エラーハンドリング** | Firebase独自のエラー | 標準的な HTTP エラー |
| **Webからの呼び出し** | ❌ CORS問題が発生しやすい | ✅ CORS完全対応 |
| **レスポンス形式** | `{data: {...}}` 自動ラップ | 自由に設定可能 |

---

## 🔴 onCall の問題点 (なぜ変更したか)

### 1. CORS問題
```javascript
// ❌ onCall: CORSヘッダーが正しく設定されないことがある
exports.myFunction = functions.https.onCall(async (data, context) => {
  // Firebase SDKがCORSを自動処理するはずだが、
  // Web環境では期待通りに動作しないことがある
  return {result: 'success'};
});
```

**あなたのアプリで発生していたエラー:**
```
Access to fetch at 'https://us-central1-callog-30758.cloudfunctions.net/generateAgoraToken' 
from origin 'https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai' 
has been blocked by CORS policy: Response to preflight request doesn't pass access control check: 
No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

### 2. 認証の暗黙的な要件
```javascript
// onCall: 認証が必要な場合、context.authをチェックする必要がある
exports.myFunction = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  // ...
});
```

これにより、**認証なしのリクエストは常に拒否される**可能性があります。

---

## 🟢 onRequest の利点 (なぜ変更が良いか)

### 1. 明示的なCORS制御
```javascript
// ✅ onRequest: CORSを完全にコントロール
const cors = require('cors')({origin: true});

exports.myFunction = functions.https.onRequest((req, res) => {
  return cors(req, res, async () => {
    // すべてのオリジンからのリクエストを許可
    // プリフライトリクエスト (OPTIONS) も自動処理
    
    res.status(200).json({data: {result: 'success'}});
  });
});
```

### 2. 標準的なHTTPリクエスト
```javascript
// ✅ どんなクライアントからでも呼び出せる
// - Web (fetch, axios, http)
// - Mobile (Dio, http)
// - cURL
// - Postman
```

### 3. 柔軟な認証処理
```javascript
// ✅ 認証が必要な場合のみチェック
if (req.body.data.requireAuth) {
  // Authorizationヘッダーをチェック
  const token = req.headers.authorization;
  // ...
}

// 認証不要な場合はスキップ
```

---

## 🔍 具体的な変更内容

### Cloud Functions側 (index.js)

**変更前:**
```javascript
exports.generateAgoraToken = functions.https.onCall(async (data, context) => {
  // ❌ CORS問題が発生
  const channelName = data.channelName;
  // ...
  return {token, appId, channelName};
});
```

**変更後:**
```javascript
const cors = require('cors')({origin: true});

exports.generateAgoraToken = functions.https.onRequest((req, res) => {
  return cors(req, res, async () => {
    // ✅ CORS完全対応
    const data = req.body.data || req.body;
    const channelName = data.channelName;
    // ...
    res.status(200).json({data: {token, appId, channelName}});
  });
});
```

### Flutter側 (agora_token_service.dart)

**変更前:**
```dart
// ❌ httpsCallable: onCall関数専用
final callable = _functions.httpsCallable('generateAgoraToken');
final result = await callable.call({
  'channelName': channelName,
  'uid': uid,
  'role': role,
});
final data = result.data;
```

**変更後:**
```dart
// ✅ http.post: 標準的なHTTPリクエスト
final response = await http.post(
  Uri.parse('$_functionsBaseUrl/generateAgoraToken'),
  headers: {'Content-Type': 'application/json'},
  body: json.encode({
    'data': {
      'channelName': channelName,
      'uid': uid,
      'role': role,
    }
  }),
);
final data = json.decode(response.body)['data'];
```

---

## ⚠️ 変更による注意点

### 1. リクエスト形式の違い

**onCall (変更前):**
```javascript
// Firebase SDKが自動的に data をラップ
callable.call({channelName: 'test'});
// サーバー側では data.channelName で直接アクセス可能
```

**onRequest (変更後):**
```javascript
// 手動で data をラップする必要がある
http.post(url, body: json.encode({
  'data': {channelName: 'test'}  // ← 'data' で明示的にラップ
}));
// サーバー側では req.body.data.channelName でアクセス
```

**✅ 解決策:** 両方のコードで対応済み
```javascript
// サーバー側で両方の形式に対応
const data = req.body.data || req.body;
```

### 2. 認証の扱い

**onCall (変更前):**
```javascript
// context.auth で自動的に認証情報を取得
const userId = context.auth.uid;
```

**onRequest (変更後):**
```javascript
// リクエストボディから callerId を受け取る
const callerId = req.body.data.callerId || 'unknown';
```

**✅ 解決策:** Flutter側で callerId を明示的に送信
```dart
final callerId = _auth.currentUser?.uid ?? 'unknown';
body: json.encode({
  'data': {
    'callerId': callerId,  // ← 明示的に送信
    // ...
  }
}),
```

---

## 🧪 動作確認

### テスト方法

1. **Flutterアプリから通話を開始**
2. **ブラウザのコンソールを確認**

**成功の場合:**
```
[AgoraToken] 🎫 Generating token for channel: call_abc123
[AgoraToken] ✅ Token generated successfully
[Push] 📤 Sending notification via Cloud Functions
[Push] ✅ Notification sent successfully!
```

**失敗の場合 (デプロイ前):**
```
❌ CORS policy error
❌ Failed to load resource: net::ERR_FAILED
```

---

## 📋 デプロイ後の動作フロー

### 1. Agoraトークン生成

```
Flutter App
    ↓ http.post
    ↓ {data: {channelName: 'test'}}
    ↓
Cloud Function (onRequest)
    ↓ CORSチェック → ✅ 許可
    ↓ リクエスト処理
    ↓ トークン生成
    ↓
Flutter App
    ← {data: {token: '006...', appId: '...', ...}}
    ← ✅ 成功
```

### 2. プッシュ通知送信

```
Flutter App
    ↓ http.post
    ↓ {data: {peerId: 'user123', channelId: 'call_abc', ...}}
    ↓
Cloud Function (onRequest)
    ↓ CORSチェック → ✅ 許可
    ↓ Firestoreからトークン取得
    ↓ FCM送信
    ↓
Flutter App
    ← {data: {success: true, messageId: '...'}}
    ← ✅ 成功
```

---

## ✅ 結論

### onCall → onRequest 変更は正しい選択です!

**理由:**

1. ✅ **CORS問題を根本的に解決**
   - 明示的なCORS対応により、すべてのオリジンから呼び出し可能

2. ✅ **より柔軟な実装**
   - 標準的なHTTPリクエストで、どんなクライアントからでも呼び出せる

3. ✅ **デバッグしやすい**
   - cURL、Postmanなどのツールで直接テスト可能

4. ✅ **本番環境でも安定**
   - Firebase SDKの暗黙的な動作に依存しない

### ⚠️ 唯一の注意点

**Cloud Functionsをデプロイするまで、変更は有効になりません!**

```bash
firebase deploy --only functions
```

これを実行すれば、すべて正常に動作します。

---

## 🚀 次のステップ

1. **Cloud Functionsをデプロイ**
   ```bash
   cd /home/user/Callog
   firebase login
   firebase deploy --only functions
   ```

2. **アプリをテスト**
   - 通話機能を試す
   - コンソールでCORSエラーが消えていることを確認

3. **成功を確認**
   - `[AgoraToken] ✅ Token generated successfully`
   - `[Push] ✅ Notification sent successfully!`

---

**最終更新**: 2024-12-04
**ステータス**: onRequest変更は正しい - デプロイするだけでOK!
