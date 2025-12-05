# 🔄 Cloud Functions v2への完全な再デプロイ手順

## 🎯 現状の問題

```
+  functions[generateAgoraToken(us-central1)] Skipped (No changes detected)
+  functions[sendPushNotification(us-central1)] Skipped (No changes detected)
```

この "Skipped" メッセージの意味:
- ✅ デプロイ自体は成功
- ❌ ただし、Firebaseが「変更なし」と判断してスキップ
- ❌ **v2の設定 (`invoker: 'public'`) が適用されていない**

**結果**: まだ403 Forbiddenエラーが発生

---

## ✅ 解決方法: 関数を削除してから再作成

Firebase Functions v1 → v2 への移行には、**完全な再作成**が必要です。

---

## 🚀 完全な再デプロイ手順

### ステップ1: Firebase にログイン

```bash
cd /home/user/Callog
firebase login
```

### ステップ2: 既存の関数を削除

```bash
# generateAgoraToken を削除
firebase functions:delete generateAgoraToken --region us-central1

# sendPushNotification を削除  
firebase functions:delete sendPushNotification --region us-central1

# cleanupOldNotifications を削除
firebase functions:delete cleanupOldNotifications --region us-central1
```

各コマンド実行時に確認メッセージが表示されます:
```
? Are you sure you want to delete generateAgoraToken(us-central1)? (y/N)
```
**y** を入力して Enter

### ステップ3: 新しい関数をデプロイ

```bash
firebase deploy --only functions
```

**期待される出力:**
```
i  functions: creating Node.js 20 function generateAgoraToken(us-central1)...
i  functions: creating Node.js 20 function sendPushNotification(us-central1)...
i  functions: creating Node.js 20 function cleanupOldNotifications(us-central1)...
✔  functions[generateAgoraToken(us-central1)]: Successful create operation.
✔  functions[sendPushNotification(us-central1)]: Successful create operation.
✔  functions[cleanupOldNotifications(us-central1)]: Successful create operation.
```

**ポイント**: `creating` (作成中) と表示されることを確認してください。

---

## 🧪 デプロイ成功の確認

### テスト1: cURL テスト

```bash
curl -X POST https://us-central1-callog-30758.cloudfunctions.net/generateAgoraToken \
  -H "Content-Type: application/json" \
  -d '{"data":{"channelName":"test","uid":0,"role":"publisher"}}'
```

**成功の場合 (JSONレスポンス):**
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

**失敗の場合 (403 Forbidden):**
```html
<html><head>
<title>403 Forbidden</title>
...
```
→ まだv2設定が適用されていません。削除→再作成が必要です。

---

### テスト2: Flutterアプリで確認

1. **ブラウザでリロード**
   - URL: https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai
   - Ctrl + Shift + R

2. **通話機能をテスト**
   - ログイン
   - 友達を選択
   - 音声通話を開始

3. **コンソール確認** (F12)

**成功の場合:**
```
[AgoraToken] 🎫 Generating token for channel: call_xxx
[AgoraToken] ✅ Token generated successfully
[Push] 📤 Sending notification via Cloud Functions
[Push] ✅ Notification sent successfully!
```

**❌ CORSエラーが表示されない**ことを確認！

---

## 🔍 なぜ削除が必要なのか

### Firebase Functions v1とv2の違い

**v1 (既存の関数):**
```javascript
exports.myFunction = functions.https.onRequest((req, res) => {
  // v1 API
  // デフォルト: 認証が必要
});
```

**v2 (新しい関数):**
```javascript
setGlobalOptions({
  invoker: 'public', // ← この設定
});

exports.myFunction = onRequest((req, res) => {
  // v2 API  
  // invoker設定が適用される
});
```

**問題点**: 
- v1で作成された関数は、v1の設定を保持
- コードを変更しても、**関数のメタデータは更新されない**
- `invoker: 'public'` 設定は**新規作成時のみ適用される**

**解決策**:
- 既存の関数を**完全に削除**
- v2の設定で**新規作成**

---

## 📋 完全なコマンドリスト (コピペ用)

```bash
# ステップ1: ログイン
firebase login

# ステップ2: 関数削除
cd /home/user/Callog
firebase functions:delete generateAgoraToken --region us-central1
# 確認: y を入力

firebase functions:delete sendPushNotification --region us-central1
# 確認: y を入力

firebase functions:delete cleanupOldNotifications --region us-central1
# 確認: y を入力

# ステップ3: 再デプロイ
firebase deploy --only functions

# ステップ4: テスト
curl -X POST https://us-central1-callog-30758.cloudfunctions.net/generateAgoraToken \
  -H "Content-Type: application/json" \
  -d '{"data":{"channelName":"test","uid":0,"role":"publisher"}}'
```

---

## ⚠️ 重要な注意点

### 削除中の一時的な影響 (1〜2分間)

関数を削除してから再デプロイするまでの間、以下の機能が使用できません:
- ❌ Agoraトークン生成
- ❌ プッシュ通知送信

**対策**: 
- ユーザーが少ない時間帯に実施
- メンテナンス通知を出す（本番環境の場合）

### データへの影響

**心配不要**: 
- ✅ Firestore、Storage、Authenticationのデータは影響なし
- ✅ 削除されるのはCloud Functionsのコードのみ

---

## 🎯 まとめ

### 手順
1. **firebase login** - ログイン
2. **firebase functions:delete ...** - 3つの関数を削除
3. **firebase deploy --only functions** - 再デプロイ
4. **curl テスト** - JSONレスポンス確認
5. **Flutterアプリテスト** - CORSエラーが消えたか確認

### 所要時間
約5〜10分

### 成功の証拠
- ✅ cURL で JSONレスポンスが返る
- ✅ Flutterアプリで通話が開始できる
- ✅ コンソールに CORSエラーが表示されない

---

**これで完全に動作します！** 🚀

---

**最終更新**: 2024-12-04
**問題**: v2設定が適用されない
**解決策**: 関数を削除してから再作成
