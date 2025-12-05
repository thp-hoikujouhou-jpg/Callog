# 🔥 Firebase Cloud Functions - 完全セットアップ手順

## 📋 実行すべきコマンド (順番に)

### ステップ1: Firebase にログイン

```bash
cd /home/user/Callog
firebase login
```

**何が起こるか:**
- ブラウザが開きます
- Googleアカウントでログインします
- 「Google Cloud SDK に権限を付与しますか?」→ **許可** をクリック
- ターミナルに戻って「認証が完了しました」と表示されます

---

### ステップ2: Firebaseプロジェクトを設定

```bash
firebase use callog-30758
```

**期待される出力:**
```
Now using project callog-30758
```

または、プロジェクトリストから選択する方法:
```bash
firebase use --add
```
- 表示されるプロジェクトリストから `callog-30758` を選択
- エイリアス名を聞かれたら `default` と入力

---

### ステップ3: 現在のプロジェクト設定を確認

```bash
firebase projects:list
```

**期待される出力:**
```
✔ Preparing the list of your Firebase projects
┌──────────────────────┬──────────────┬────────────────┬──────────────────────┐
│ Project Display Name │ Project ID   │ Project Number │ Resource Location ID │
├──────────────────────┼──────────────┼────────────────┼──────────────────────┤
│ Callog               │ callog-30758 │ ...            │ ...                  │
└──────────────────────┴──────────────┴────────────────┴──────────────────────┘

1 project(s) total.
```

---

### ステップ4: 既存の関数を削除

```bash
# generateAgoraToken を削除
firebase functions:delete generateAgoraToken --region us-central1 --project callog-30758

# sendPushNotification を削除
firebase functions:delete sendPushNotification --region us-central1 --project callog-30758

# cleanupOldNotifications を削除
firebase functions:delete cleanupOldNotifications --region us-central1 --project callog-30758
```

**各コマンドで確認メッセージが表示されます:**
```
? Are you sure you want to delete generateAgoraToken(us-central1)? (y/N)
```
→ **y** を入力して Enter

**期待される出力:**
```
Function generateAgoraToken(us-central1) has been successfully deleted.
```

---

### ステップ5: 新しい関数をデプロイ

```bash
firebase deploy --only functions --project callog-30758
```

**期待される出力:**
```
=== Deploying to 'callog-30758'...

i  deploying functions
i  functions: ensuring required API cloudfunctions.googleapis.com is enabled...
✔  functions: required API cloudfunctions.googleapis.com is enabled
i  functions: preparing functions directory for uploading...
i  functions: packaged functions (XX KB) for uploading
✔  functions: functions folder uploaded successfully
i  functions: creating Node.js 20 function generateAgoraToken(us-central1)...
i  functions: creating Node.js 20 function sendPushNotification(us-central1)...
i  functions: creating Node.js 20 function cleanupOldNotifications(us-central1)...
✔  functions[generateAgoraToken(us-central1)]: Successful create operation.
✔  functions[sendPushNotification(us-central1)]: Successful create operation.
✔  functions[cleanupOldNotifications(us-central1)]: Successful create operation.

✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/callog-30758/overview
```

**重要**: `creating` (作成中) と表示されることを確認してください！

---

## 🧪 デプロイ成功の確認

### テスト1: cURL でテスト

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
→ まだデプロイされていません。上記の手順を再確認してください。

---

### テスト2: Flutterアプリで確認

1. **ブラウザでアプリを開く**
   - URL: https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai

2. **強制リロード**
   - Ctrl + Shift + R (Windows/Linux)
   - Cmd + Shift + R (Mac)

3. **通話機能をテスト**
   - ログイン
   - 友達を選択
   - 音声通話またはビデオ通話を開始

4. **コンソールを確認** (F12キー)

**成功の場合:**
```
[AgoraToken] 🎫 Generating token for channel: call_xxx
[AgoraToken] ✅ Token generated successfully
[Push] 📤 Sending notification via Cloud Functions
[Push] ✅ Notification sent successfully!
```

**❌ CORSエラーが表示されない** ことを確認してください！

---

## 🔧 トラブルシューティング

### エラー1: "Failed to authenticate"

```
Error: Failed to authenticate, have you run firebase login?
```

**解決策:**
```bash
firebase login --reauth
```

---

### エラー2: "You do not have permission to access project"

```
Error: HTTP Error: 403, The caller does not have permission
```

**解決策:**
```bash
# 現在のアカウントを確認
firebase login:list

# 正しいアカウントでログインし直す
firebase logout
firebase login
```

---

### エラー3: "Function not found"

```
Error: Function generateAgoraToken does not exist.
```

**対処法**: すでに削除されています。次のステップ (デプロイ) に進んでください。

---

### エラー4: デプロイ後も403エラーが出る

**対処法:**
1. 1〜2分待つ (反映に時間がかかる場合があります)
2. ブラウザのキャッシュをクリア
3. シークレットモードで開く
4. 再度cURLでテスト

---

## 📋 完全なコマンドリスト (コピペ用)

```bash
# ステップ1: ログイン
cd /home/user/Callog
firebase login

# ステップ2: プロジェクト設定
firebase use callog-30758

# ステップ3: 関数削除
firebase functions:delete generateAgoraToken --region us-central1 --project callog-30758
# 確認: y を入力

firebase functions:delete sendPushNotification --region us-central1 --project callog-30758
# 確認: y を入力

firebase functions:delete cleanupOldNotifications --region us-central1 --project callog-30758
# 確認: y を入力

# ステップ4: 再デプロイ
firebase deploy --only functions --project callog-30758

# ステップ5: テスト
curl -X POST https://us-central1-callog-30758.cloudfunctions.net/generateAgoraToken \
  -H "Content-Type: application/json" \
  -d '{"data":{"channelName":"test","uid":0,"role":"publisher"}}'
```

---

## ✅ チェックリスト

デプロイ前:
- [ ] `firebase login` 実行済み
- [ ] `firebase use callog-30758` 実行済み
- [ ] プロジェクトが正しく設定されている

デプロイ中:
- [ ] 3つの関数を削除済み
- [ ] `firebase deploy --only functions` 実行済み
- [ ] "creating" メッセージが表示された

デプロイ後:
- [ ] cURL でJSONレスポンスが返る
- [ ] Flutterアプリで通話が開始できる
- [ ] CORSエラーが表示されない

---

## 🎯 まとめ

### 実行する手順
1. **firebase login** - Googleアカウントでログイン
2. **firebase use callog-30758** - プロジェクト設定
3. **firebase functions:delete ...** - 3つの関数を削除 (各コマンドで y を入力)
4. **firebase deploy --only functions** - 再デプロイ
5. **curl テスト** - JSONレスポンス確認
6. **Flutterアプリテスト** - CORSエラーが消えたか確認

### 所要時間
約5〜10分

### 成功の証拠
- ✅ cURL で JSONが返る
- ✅ Flutterアプリで通話が開始できる
- ✅ コンソールに CORSエラーが表示されない

---

## 📊 現在のサービス状態

✅ **Flutterアプリ**: 正常稼働中
🌐 **プレビューURL**: https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai
🔄 **再起動**: 不要

---

**上記のコマンドを順番に実行してください！** 🚀

---

**最終更新**: 2024-12-04
**ステータス**: Firebase認証→プロジェクト設定→関数削除→再デプロイ
